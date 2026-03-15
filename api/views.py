import logging
import math
import requests
from collections import defaultdict
from datetime import timedelta
from decimal import Decimal

from django.db.models import Q, Count, Sum, Avg, F
from django.utils import timezone

logger = logging.getLogger(__name__)
from django.contrib.auth import get_user_model
from rest_framework import viewsets, permissions, status, generics
from rest_framework.decorators import api_view, permission_classes, action
from django.shortcuts import get_object_or_404

User = get_user_model()
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework.response import Response
from rest_framework.throttling import UserRateThrottle
from django.conf import settings
from django.views.decorators.csrf import csrf_exempt
from django.core.cache import cache

from .models import (
    Property, PropertyImage, PropertyFloorplan, PropertyFeature,
    PriceHistory, SavedProperty, PropertyView,
    ViewingRequest, SavedSearch, PushNotificationDevice, Reply,
    ServiceCategory, ServiceProvider, ServiceProviderReview,
    SubscriptionTier, SubscriptionAddOn, ServiceProviderSubscription,
    ServiceProviderPhoto,
    ChatRoom, ChatMessage,
    ViewingSlot, ViewingSlotBooking,
    Offer, PropertyDocument, PropertyFlag,
    BuyerVerification, ConveyancingCase, ConveyancingStep,
    OpenHouseEvent, OpenHouseRSVP,
    ConveyancerQuoteRequest, ConveyancerQuote,
    NeighbourhoodReview, BoardOrder, BuyerProfile,
    ForumCategory, ForumTopic, ForumPost,
)
from .serializers import (
    PropertySerializer, PropertyListSerializer, PropertyImageSerializer,
    PropertyFloorplanSerializer, PropertyFeatureSerializer,
    SavedPropertySerializer, DashboardStatsSerializer,
    ViewingRequestSerializer, SavedSearchSerializer, UserProfileSerializer,
    ReplySerializer,
    ServiceCategorySerializer, ServiceProviderListSerializer,
    ServiceProviderDetailSerializer, ServiceProviderReviewSerializer,
    SubscriptionTierSerializer, SubscriptionAddOnSerializer,
    ServiceProviderSubscriptionSerializer, ServiceProviderPhotoSerializer,
    ChatRoomSerializer, ChatMessageSerializer,
    ViewingSlotSerializer,
    OfferSerializer, PropertyDocumentSerializer,
    PropertyFlagSerializer,
    BuyerVerificationSerializer,
    ConveyancingCaseSerializer, ConveyancingStepSerializer,
    OpenHouseEventSerializer, OpenHouseRSVPSerializer,
    ConveyancerQuoteRequestSerializer, ConveyancerQuoteSerializer,
    NeighbourhoodReviewSerializer, BoardOrderSerializer, BuyerProfileSerializer,
    ForumCategorySerializer, ForumTopicSerializer, ForumTopicDetailSerializer,
    ForumPostSerializer,
)


class IsOwnerOrReadOnly(permissions.BasePermission):
    """Allow read access to anyone, write access only to the property owner."""

    def has_object_permission(self, request, view, obj):
        if request.method in permissions.SAFE_METHODS:
            return True
        return obj.owner == request.user


# ── Haversine distance helper ────────────────────────────────────

def haversine_distance(lat1, lon1, lat2, lon2):
    """Calculate distance in miles between two lat/lon points."""
    R = 3959  # Earth radius in miles
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (math.sin(dlat / 2) ** 2 +
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
         math.sin(dlon / 2) ** 2)
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


class PropertyViewSet(viewsets.ModelViewSet):
    serializer_class = PropertySerializer

    def get_serializer_class(self):
        if self.action == 'list':
            return PropertyListSerializer
        return PropertySerializer

    def get_permissions(self):
        if self.action in ['list', 'retrieve']:
            return [permissions.AllowAny()]
        return [permissions.IsAuthenticated(), IsOwnerOrReadOnly()]

    def get_object(self):
        """Support lookup by slug as well as numeric pk."""
        lookup = self.kwargs.get('pk', '')
        queryset = self.filter_queryset(self.get_queryset())
        if lookup.isdigit():
            obj = get_object_or_404(queryset, pk=lookup)
        else:
            obj = get_object_or_404(queryset, slug=lookup)
        self.check_object_permissions(self.request, obj)
        return obj

    def get_queryset(self):
        queryset = Property.objects.all().select_related('owner').prefetch_related(
            'images', 'features',
        )
        status_filter = self.request.query_params.get('status')
        property_type = self.request.query_params.get('property_type')
        city = self.request.query_params.get('city')

        if not self.request.user.is_authenticated:
            queryset = queryset.filter(status='active')
        elif self.request.query_params.get('mine') == 'true':
            queryset = queryset.filter(owner=self.request.user)
        else:
            queryset = queryset.filter(
                Q(status='active') | Q(owner=self.request.user)
            )

        if status_filter:
            queryset = queryset.filter(status=status_filter)
        if property_type:
            queryset = queryset.filter(property_type=property_type)
        if city:
            queryset = queryset.filter(city__icontains=city)

        # Search filters
        location = self.request.query_params.get('location')
        min_price = self.request.query_params.get('min_price')
        max_price = self.request.query_params.get('max_price')
        min_bedrooms = self.request.query_params.get('min_bedrooms')
        min_bathrooms = self.request.query_params.get('min_bathrooms')
        epc_rating = self.request.query_params.get('epc_rating')

        if location:
            queryset = queryset.filter(
                Q(city__icontains=location) |
                Q(county__icontains=location) |
                Q(postcode__icontains=location) |
                Q(address_line_1__icontains=location)
            )
        if min_price:
            queryset = queryset.filter(price__gte=min_price)
        if max_price:
            queryset = queryset.filter(price__lte=max_price)
        if min_bedrooms:
            queryset = queryset.filter(bedrooms__gte=min_bedrooms)
        if min_bathrooms:
            queryset = queryset.filter(bathrooms__gte=min_bathrooms)
        if epc_rating:
            queryset = queryset.filter(epc_rating=epc_rating)

        # Radius/distance search
        lat = self.request.query_params.get('lat')
        lon = self.request.query_params.get('lon')
        radius = self.request.query_params.get('radius')  # in miles
        if lat and lon and radius:
            try:
                lat, lon, radius = float(lat), float(lon), float(radius)
                # Rough bounding box filter first for efficiency
                lat_range = radius / 69.0
                lon_range = radius / (69.0 * math.cos(math.radians(lat)))
                queryset = queryset.filter(
                    latitude__isnull=False,
                    longitude__isnull=False,
                    latitude__gte=lat - lat_range,
                    latitude__lte=lat + lat_range,
                    longitude__gte=lon - lon_range,
                    longitude__lte=lon + lon_range,
                )
            except (ValueError, TypeError):
                pass

        return queryset

    def perform_create(self, serializer):
        instance = serializer.save(owner=self.request.user)
        PriceHistory.objects.create(property=instance, price=instance.price)

    def perform_update(self, serializer):
        old_price = serializer.instance.price
        instance = serializer.save()
        if instance.price != old_price:
            PriceHistory.objects.create(property=instance, price=instance.price)

    def retrieve(self, request, *args, **kwargs):
        instance = self.get_object()
        try:
            ip = request.META.get('HTTP_X_FORWARDED_FOR', request.META.get('REMOTE_ADDR', '')).split(',')[0].strip()
            PropertyView.objects.create(
                property=instance,
                viewer_ip=ip or None,
                user=request.user if request.user.is_authenticated else None,
            )
        except Exception:
            pass
        serializer = self.get_serializer(instance)
        return Response(serializer.data)

    @action(detail=True, methods=['get'])
    def similar(self, request, pk=None):
        """Return similar properties based on type, location, and price range."""
        prop = self.get_object()
        price_range = prop.price * Decimal('0.3')
        similar = Property.objects.filter(
            status='active',
        ).filter(
            Q(property_type=prop.property_type) |
            Q(city__iexact=prop.city) |
            Q(price__gte=prop.price - price_range, price__lte=prop.price + price_range)
        ).exclude(pk=prop.pk).select_related('owner').prefetch_related('images')[:6]
        serializer = PropertyListSerializer(similar, many=True, context={'request': request})
        return Response(serializer.data)


class PropertyImageViewSet(viewsets.ModelViewSet):
    serializer_class = PropertyImageSerializer
    parser_classes = [MultiPartParser, FormParser]

    def get_permissions(self):
        if self.action in ['list', 'retrieve']:
            return [permissions.AllowAny()]
        return [permissions.IsAuthenticated()]

    def get_queryset(self):
        return PropertyImage.objects.filter(
            property_id=self.kwargs['property_pk']
        )

    def _get_property(self):
        return get_object_or_404(Property, pk=self.kwargs['property_pk'])

    def create(self, request, *args, **kwargs):
        try:
            return super().create(request, *args, **kwargs)
        except Exception as e:
            import traceback
            logger.error(f"Image upload failed: {e}\n{traceback.format_exc()}")
            return Response(
                {"detail": f"Upload error: {type(e).__name__}: {e}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

    def perform_create(self, serializer):
        property_obj = self._get_property()
        if property_obj.owner != self.request.user:
            raise PermissionDenied("You can only add images to your own properties.")
        if property_obj.images.count() >= 10:
            raise ValidationError("Maximum 10 images per property.")
        instance = serializer.save(property=property_obj)
        # Async image processing
        try:
            from .tasks import process_property_image
            process_property_image.delay(instance.id)
        except Exception:
            pass

    def perform_update(self, serializer):
        if serializer.instance.property.owner != self.request.user:
            raise PermissionDenied()
        serializer.save()

    def perform_destroy(self, instance):
        if instance.property.owner != self.request.user:
            raise PermissionDenied()
        was_primary = instance.is_primary
        prop = instance.property
        instance.image.delete(save=False)
        if instance.thumbnail:
            instance.thumbnail.delete(save=False)
        instance.delete()
        if was_primary:
            next_img = prop.images.first()
            if next_img:
                next_img.is_primary = True
                next_img.save(update_fields=['is_primary'])


class PropertyFloorplanViewSet(viewsets.ModelViewSet):
    serializer_class = PropertyFloorplanSerializer
    parser_classes = [MultiPartParser, FormParser]

    def get_permissions(self):
        if self.action in ['list', 'retrieve']:
            return [permissions.AllowAny()]
        return [permissions.IsAuthenticated()]

    def get_queryset(self):
        return PropertyFloorplan.objects.filter(
            property_id=self.kwargs['property_pk']
        )

    def _get_property(self):
        return get_object_or_404(Property, pk=self.kwargs['property_pk'])

    def perform_create(self, serializer):
        property_obj = self._get_property()
        if property_obj.owner != self.request.user:
            raise PermissionDenied("You can only add floorplans to your own properties.")
        if property_obj.floorplans.count() >= 5:
            raise ValidationError("Maximum 5 floorplans per property.")
        serializer.save(property=property_obj)

    def perform_update(self, serializer):
        if serializer.instance.property.owner != self.request.user:
            raise PermissionDenied()
        serializer.save()

    def perform_destroy(self, instance):
        if instance.property.owner != self.request.user:
            raise PermissionDenied()
        instance.file.delete(save=False)
        instance.delete()


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def reorder_images(request, property_pk):
    """Bulk-update image ordering. Expects {"order": [id1, id2, ...]}."""
    prop = get_object_or_404(Property, pk=property_pk)
    if prop.owner != request.user:
        raise PermissionDenied()
    order = request.data.get('order', [])
    for idx, image_id in enumerate(order):
        PropertyImage.objects.filter(pk=image_id, property=prop).update(order=idx)
    return Response({'status': 'ok'})


class SavedPropertyViewSet(viewsets.ModelViewSet):
    serializer_class = SavedPropertySerializer
    permission_classes = [permissions.IsAuthenticated]
    http_method_names = ['get', 'post', 'delete']

    def get_queryset(self):
        return SavedProperty.objects.filter(
            user=self.request.user
        ).select_related('property__owner').prefetch_related('property__images')

    def perform_create(self, serializer):
        prop = serializer.validated_data['property']
        if SavedProperty.objects.filter(user=self.request.user, property=prop).exists():
            raise ValidationError("Property already saved.")
        serializer.save(user=self.request.user)


@api_view(['POST', 'DELETE'])
@permission_classes([permissions.IsAuthenticated])
def toggle_saved(request, property_pk):
    """Toggle save/unsave a property. POST to save, DELETE to unsave."""
    try:
        prop = Property.objects.get(pk=property_pk)
    except Property.DoesNotExist:
        return Response({'detail': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)

    if request.method == 'POST':
        _, created = SavedProperty.objects.get_or_create(user=request.user, property=prop)
        return Response({'saved': True, 'created': created}, status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)
    else:
        deleted, _ = SavedProperty.objects.filter(user=request.user, property=prop).delete()
        return Response({'saved': False}, status=status.HTTP_200_OK)


class ViewingRequestViewSet(viewsets.ModelViewSet):
    serializer_class = ViewingRequestSerializer
    permission_classes = [permissions.IsAuthenticated]
    http_method_names = ['get', 'post', 'patch']

    def get_queryset(self):
        user = self.request.user
        return ViewingRequest.objects.filter(
            Q(requester=user) | Q(property__owner=user)
        ).select_related('property', 'requester').prefetch_related('replies__author')

    def perform_create(self, serializer):
        prop = serializer.validated_data['property']
        if prop.owner == self.request.user:
            raise ValidationError("You cannot request a viewing for your own property.")
        user = self.request.user
        name = serializer.validated_data.get('name') or user.get_full_name()
        email = serializer.validated_data.get('email') or user.email
        viewing = serializer.save(requester=user, name=name, email=email)
        try:
            from .tasks import send_viewing_notification
            send_viewing_notification.delay(viewing.id)
        except Exception:
            from .notifications import notify_viewing_request
            notify_viewing_request(viewing)

    def perform_update(self, serializer):
        instance = serializer.instance
        if instance.property.owner != self.request.user:
            raise PermissionDenied("Only the property owner can update viewing requests.")
        serializer.save()

    @action(detail=False, methods=['get'])
    def received(self, request):
        """Get viewing requests received for the user's properties."""
        qs = ViewingRequest.objects.filter(
            property__owner=request.user
        ).select_related('property', 'requester').prefetch_related('replies__author').order_by('-created_at')
        page = self.paginate_queryset(qs)
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)
        serializer = self.get_serializer(qs, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def reply(self, request, pk=None):
        """Post a reply to a viewing request."""
        viewing = self.get_object()
        user = request.user
        if user != viewing.requester and user != viewing.property.owner:
            raise PermissionDenied("You are not a participant in this conversation.")
        message = request.data.get('message', '').strip()
        if not message:
            raise ValidationError("Message cannot be empty.")
        reply_obj = Reply.objects.create(viewing_request=viewing, author=user, message=message)
        try:
            from .tasks import send_reply_notification
            send_reply_notification.delay(reply_obj.id)
        except Exception:
            from .notifications import notify_reply
            notify_reply(reply_obj)
        return Response(ReplySerializer(reply_obj).data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['patch'])
    def update_status(self, request, pk=None):
        """Property owner can confirm/decline a viewing request."""
        viewing = self.get_object()
        if viewing.property.owner != request.user:
            raise PermissionDenied()
        new_status = request.data.get('status')
        if new_status not in ['confirmed', 'declined', 'completed']:
            raise ValidationError("Invalid status.")
        viewing.status = new_status
        if 'seller_notes' in request.data:
            viewing.seller_notes = request.data['seller_notes']
        viewing.save(update_fields=['status', 'seller_notes', 'updated_at'])
        try:
            from .tasks import send_viewing_status_notification
            send_viewing_status_notification.delay(viewing.id)
        except Exception:
            pass
        return Response(ViewingRequestSerializer(viewing).data)


class SavedSearchViewSet(viewsets.ModelViewSet):
    serializer_class = SavedSearchSerializer
    permission_classes = [permissions.IsAuthenticated]
    http_method_names = ['get', 'post', 'patch', 'delete']

    def get_queryset(self):
        return SavedSearch.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class PropertyFeatureViewSet(viewsets.ReadOnlyModelViewSet):
    """Read-only list of available property features/tags."""
    serializer_class = PropertyFeatureSerializer
    queryset = PropertyFeature.objects.all()
    permission_classes = [permissions.AllowAny]
    pagination_class = None


# ── Dashboard & Analytics ────────────────────────────────────────

@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def dashboard_stats(request):
    """Get seller dashboard statistics with analytics."""
    user = request.user
    properties = Property.objects.filter(owner=user)
    total_views = PropertyView.objects.filter(property__owner=user).count()
    user_rooms = ChatRoom.objects.filter(Q(buyer=user) | Q(seller=user))
    total_messages = ChatMessage.objects.filter(room__in=user_rooms).exclude(sender=user).count()
    unread_messages = ChatMessage.objects.filter(
        room__in=user_rooms, is_read=False,
    ).exclude(sender=user).count()
    total_saves = SavedProperty.objects.filter(property__owner=user).count()
    pending_viewings = ViewingRequest.objects.filter(property__owner=user, status='pending').count()
    total_offers = Offer.objects.filter(property__owner=user).count()
    pending_offers = Offer.objects.filter(property__owner=user, status='submitted').count()

    # Views over last 30 days
    thirty_days_ago = timezone.now() - timedelta(days=30)
    views_by_day = (
        PropertyView.objects.filter(property__owner=user, viewed_at__gte=thirty_days_ago)
        .extra(select={'day': "date(viewed_at)"})
        .values('day')
        .annotate(count=Count('id'))
        .order_by('day')
    )

    # Message conversion rate (messages / views)
    message_rate = round((total_messages / total_views * 100), 1) if total_views > 0 else 0

    # Per-property stats
    property_stats = []
    for prop in properties:
        prop_views = prop.views.count()
        prop_messages = ChatMessage.objects.filter(room__property=prop).exclude(sender=user).count()
        has_floorplan = prop.floorplans.exists()
        image_count = prop.images.count()
        tips = []
        if image_count < 5:
            tips.append(f'Add more photos ({image_count}/10). Listings with 5+ photos get 40% more interest.')
        if not has_floorplan:
            tips.append('Add a floorplan. Listings with floorplans get 30% more interest.')
        if not prop.description or len(prop.description) < 100:
            tips.append('Write a longer description (100+ chars) to attract more interest.')
        if not prop.video_url:
            tips.append('Add a virtual tour video to stand out from other listings.')

        property_stats.append({
            'id': prop.id,
            'title': prop.title,
            'status': prop.status,
            'views': prop_views,
            'messages': prop_messages,
            'saves': prop.saved_by.count(),
            'offers': prop.offers.count(),
            'conversion_rate': round((prop_messages / prop_views * 100), 1) if prop_views > 0 else 0,
            'tips': tips,
        })

    data = {
        'total_listings': properties.count(),
        'active_listings': properties.filter(status='active').count(),
        'total_views': total_views,
        'total_messages': total_messages,
        'unread_messages': unread_messages,
        'pending_viewings': pending_viewings,
        'total_saves': total_saves,
        'total_offers': total_offers,
        'pending_offers': pending_offers,
        'message_conversion_rate': message_rate,
        'views_by_day': list(views_by_day),
        'property_stats': property_stats,
    }
    return Response(data)


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def notification_counts(request):
    """Lightweight endpoint for nav bell badge — returns unread/pending counts."""
    user = request.user
    pending = ViewingRequest.objects.filter(property__owner=user, status='pending').count()
    unread_chats = ChatMessage.objects.filter(
        room__in=ChatRoom.objects.filter(Q(buyer=user) | Q(seller=user)),
        is_read=False,
    ).exclude(sender=user).count()
    pending_offers = Offer.objects.filter(property__owner=user, status='submitted').count()
    total = pending + unread_chats + pending_offers
    return Response({
        'pending_viewings': pending,
        'unread_messages': unread_chats,
        'pending_offers': pending_offers,
        'total': total,
    })


@api_view(['GET', 'PATCH'])
@permission_classes([permissions.IsAuthenticated])
def user_profile(request):
    """Get or update the current user's profile."""
    if request.method == 'GET':
        serializer = UserProfileSerializer(request.user)
        return Response(serializer.data)
    serializer = UserProfileSerializer(request.user, data=request.data, partial=True)
    serializer.is_valid(raise_exception=True)
    serializer.save()
    return Response(serializer.data)


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def register_push_device(request):
    """Register a push notification device token for the current user."""
    token = request.data.get('token')
    platform = request.data.get('platform', 'android')
    if not token:
        return Response({'detail': 'Token is required.'}, status=status.HTTP_400_BAD_REQUEST)
    device, created = PushNotificationDevice.objects.update_or_create(
        token=token,
        defaults={'user': request.user, 'platform': platform, 'is_active': True},
    )
    return Response({'registered': True, 'created': created})


# ── Chat Views ───────────────────────────────────────────────────

class ChatRoomViewSet(viewsets.ModelViewSet):
    """Manage chat rooms between buyers and sellers."""
    serializer_class = ChatRoomSerializer
    permission_classes = [permissions.IsAuthenticated]
    http_method_names = ['get', 'post']

    def get_queryset(self):
        user = self.request.user
        return ChatRoom.objects.filter(
            Q(buyer=user) | Q(seller=user)
        ).select_related('property', 'buyer', 'seller').prefetch_related('messages')

    def perform_create(self, serializer):
        prop = serializer.validated_data['property']
        if prop.owner == self.request.user:
            raise ValidationError("You cannot start a chat about your own property.")
        # Get or create the room
        room, created = ChatRoom.objects.get_or_create(
            property=prop,
            buyer=self.request.user,
            defaults={'seller': prop.owner},
        )
        if not created:
            raise ValidationError("Chat room already exists for this property.")

    def create(self, request, *args, **kwargs):
        prop_id = request.data.get('property')
        if not prop_id:
            return Response({'detail': 'property is required.'}, status=status.HTTP_400_BAD_REQUEST)
        prop = get_object_or_404(Property, pk=prop_id)
        if prop.owner == request.user:
            return Response({'detail': 'Cannot chat about your own property.'}, status=status.HTTP_400_BAD_REQUEST)
        room, created = ChatRoom.objects.get_or_create(
            property=prop,
            buyer=request.user,
            defaults={'seller': prop.owner},
        )
        # If an initial message was provided, create it
        message_text = request.data.get('message', '').strip()
        if message_text:
            ChatMessage.objects.create(room=room, sender=request.user, message=message_text)
            room.save(update_fields=['updated_at'])
        serializer = self.get_serializer(room)
        return Response(serializer.data, status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)


class ChatMessageViewSet(viewsets.ModelViewSet):
    """Messages within a chat room."""
    serializer_class = ChatMessageSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = None
    http_method_names = ['get', 'post']

    def get_queryset(self):
        room_pk = self.kwargs.get('room_pk')
        if room_pk is None:
            return ChatMessage.objects.none()
        room = get_object_or_404(ChatRoom, pk=room_pk)
        user = self.request.user
        if user != room.buyer and user != room.seller:
            raise PermissionDenied()
        qs = ChatMessage.objects.filter(room=room).select_related('sender')
        logger.info(
            'ChatMessage list: room_pk=%s, user=%s, buyer=%s, seller=%s, msg_count=%d',
            room_pk, user.pk, room.buyer_id, room.seller_id, qs.count(),
        )
        return qs

    def perform_create(self, serializer):
        room = get_object_or_404(ChatRoom, pk=self.kwargs['room_pk'])
        user = self.request.user
        if user != room.buyer and user != room.seller:
            raise PermissionDenied()
        serializer.save(room=room, sender=user)
        room.save(update_fields=['updated_at'])

    @action(detail=False, methods=['post'])
    def mark_read(self, request, room_pk=None):
        room = get_object_or_404(ChatRoom, pk=room_pk)
        user = request.user
        if user != room.buyer and user != room.seller:
            raise PermissionDenied()
        updated = ChatMessage.objects.filter(
            room=room, is_read=False
        ).exclude(sender=user).update(is_read=True)
        return Response({'marked': updated})


# ── Viewing Slots ────────────────────────────────────────────────

class ViewingSlotViewSet(viewsets.ModelViewSet):
    """Manage viewing availability slots."""
    serializer_class = ViewingSlotSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = None

    def get_permissions(self):
        if self.action in ['list', 'retrieve']:
            return [permissions.AllowAny()]
        return [permissions.IsAuthenticated()]

    def get_queryset(self):
        return ViewingSlot.objects.filter(
            property_id=self.kwargs['property_pk']
        )

    def perform_create(self, serializer):
        prop = get_object_or_404(Property, pk=self.kwargs['property_pk'])
        if prop.owner != self.request.user:
            raise PermissionDenied("Only the property owner can manage viewing slots.")
        serializer.save(property=prop)

    def perform_update(self, serializer):
        if serializer.instance.property.owner != self.request.user:
            raise PermissionDenied()
        serializer.save()

    def perform_destroy(self, instance):
        if instance.property.owner != self.request.user:
            raise PermissionDenied()
        instance.delete()


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def book_viewing_slot(request, property_pk, slot_pk):
    """Book a viewing slot (creates a ViewingRequest tied to the slot)."""
    prop = get_object_or_404(Property, pk=property_pk)
    slot = get_object_or_404(ViewingSlot, pk=slot_pk, property=prop)

    if prop.owner == request.user:
        return Response({'detail': 'Cannot book a viewing for your own property.'}, status=status.HTTP_400_BAD_REQUEST)
    if not slot.get_is_available():
        return Response({'detail': 'This slot is no longer available.'}, status=status.HTTP_400_BAD_REQUEST)

    viewing = ViewingRequest.objects.create(
        property=prop,
        requester=request.user,
        preferred_date=slot.date or timezone.now().date(),
        preferred_time=slot.start_time,
        name=request.data.get('name', request.user.get_full_name()),
        email=request.data.get('email', request.user.email),
        phone=request.data.get('phone', ''),
        message=request.data.get('message', ''),
    )
    ViewingSlotBooking.objects.create(slot=slot, viewing_request=viewing)

    try:
        from .tasks import send_viewing_notification
        send_viewing_notification.delay(viewing.id)
    except Exception:
        pass

    return Response(ViewingRequestSerializer(viewing).data, status=status.HTTP_201_CREATED)


# ── Offers ───────────────────────────────────────────────────────

class OfferViewSet(viewsets.ModelViewSet):
    """Manage offers on properties."""
    serializer_class = OfferSerializer
    permission_classes = [permissions.IsAuthenticated]
    http_method_names = ['get', 'post', 'patch']

    def get_queryset(self):
        user = self.request.user
        return Offer.objects.filter(
            Q(buyer=user) | Q(property__owner=user)
        ).select_related('property', 'buyer')

    def perform_create(self, serializer):
        prop = serializer.validated_data['property']
        if prop.owner == self.request.user:
            raise ValidationError("You cannot make an offer on your own property.")
        offer = serializer.save(buyer=self.request.user, status='submitted')
        try:
            from .tasks import send_offer_notification
            send_offer_notification.delay(offer.id, 'new')
        except Exception:
            pass

    @action(detail=False, methods=['get'])
    def received(self, request):
        """Get offers received on the user's properties."""
        qs = Offer.objects.filter(
            property__owner=request.user
        ).select_related('property', 'buyer').order_by('-created_at')
        page = self.paginate_queryset(qs)
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)
        return Response(self.get_serializer(qs, many=True).data)

    @action(detail=True, methods=['patch'])
    def respond(self, request, pk=None):
        """Seller responds to an offer (accept, reject, counter)."""
        offer = self.get_object()
        if offer.property.owner != request.user:
            raise PermissionDenied()

        new_status = request.data.get('status')
        if new_status not in ['accepted', 'rejected', 'countered']:
            raise ValidationError("Status must be 'accepted', 'rejected', or 'countered'.")

        offer.status = new_status
        if 'seller_notes' in request.data:
            offer.seller_notes = request.data['seller_notes']
        if new_status == 'countered':
            counter = request.data.get('counter_amount')
            if not counter:
                raise ValidationError("counter_amount is required for counter offers.")
            offer.counter_amount = Decimal(str(counter))
        offer.save()

        try:
            from .tasks import send_offer_notification
            send_offer_notification.delay(offer.id, 'status_update')
        except Exception:
            pass

        return Response(OfferSerializer(offer).data)

    @action(detail=True, methods=['patch'])
    def withdraw(self, request, pk=None):
        """Buyer withdraws their offer."""
        offer = self.get_object()
        if offer.buyer != request.user:
            raise PermissionDenied()
        if offer.status not in ['submitted', 'under_review', 'countered']:
            raise ValidationError("Cannot withdraw this offer.")
        offer.status = 'withdrawn'
        offer.save(update_fields=['status', 'updated_at'])
        return Response(OfferSerializer(offer).data)


# ── Documents ────────────────────────────────────────────────────

class PropertyDocumentViewSet(viewsets.ModelViewSet):
    """Manage property documents (title deeds, EPC, etc.)."""
    serializer_class = PropertyDocumentSerializer
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def get_queryset(self):
        prop = get_object_or_404(Property, pk=self.kwargs['property_pk'])
        user = self.request.user
        if prop.owner == user:
            return PropertyDocument.objects.filter(property=prop)
        # Non-owners can only see public documents
        return PropertyDocument.objects.filter(property=prop, is_public=True)

    def perform_create(self, serializer):
        prop = get_object_or_404(Property, pk=self.kwargs['property_pk'])
        if prop.owner != self.request.user:
            raise PermissionDenied("Only the property owner can upload documents.")
        serializer.save(property=prop, uploaded_by=self.request.user)

    def perform_update(self, serializer):
        if serializer.instance.property.owner != self.request.user:
            raise PermissionDenied()
        serializer.save()

    def perform_destroy(self, instance):
        if instance.property.owner != self.request.user:
            raise PermissionDenied()
        instance.file.delete(save=False)
        instance.delete()


# ── Property Flagging / Moderation ──────────────────────────────

@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def flag_property(request, property_pk):
    """Flag a property listing for moderation."""
    prop = get_object_or_404(Property, pk=property_pk)
    if prop.owner == request.user:
        return Response({'detail': 'Cannot flag your own property.'}, status=status.HTTP_400_BAD_REQUEST)
    if PropertyFlag.objects.filter(property=prop, reporter=request.user).exists():
        return Response({'detail': 'You have already flagged this property.'}, status=status.HTTP_400_BAD_REQUEST)

    reason = request.data.get('reason', '')
    if reason not in dict(PropertyFlag.REASON_CHOICES):
        return Response({'detail': 'Invalid reason.'}, status=status.HTTP_400_BAD_REQUEST)

    flag = PropertyFlag.objects.create(
        property=prop,
        reporter=request.user,
        reason=reason,
        description=request.data.get('description', ''),
    )
    return Response(PropertyFlagSerializer(flag).data, status=status.HTTP_201_CREATED)



# ── Mortgage Calculator ─────────────────────────────────────────

@api_view(['GET'])
@permission_classes([permissions.AllowAny])
def mortgage_calculator(request):
    """Calculate estimated monthly mortgage payment."""
    try:
        price = float(request.query_params.get('price', 0))
        deposit_pct = float(request.query_params.get('deposit_pct', 10))
        interest_rate = float(request.query_params.get('interest_rate', 4.5))
        term_years = int(request.query_params.get('term_years', 25))
    except (ValueError, TypeError):
        return Response({'detail': 'Invalid parameters.'}, status=status.HTTP_400_BAD_REQUEST)

    buyer_type = request.query_params.get('buyer_type', 'standard')  # standard | first_time | additional
    repayment_type = request.query_params.get('repayment_type', 'repayment')  # repayment | interest_only

    if price <= 0 or term_years <= 0:
        return Response({'detail': 'Price and term must be positive.'}, status=status.HTTP_400_BAD_REQUEST)

    deposit = price * (deposit_pct / 100)
    loan = price - deposit
    monthly_rate = (interest_rate / 100) / 12
    num_payments = term_years * 12

    if repayment_type == 'interest_only':
        # Interest-only: pay only interest each month, loan repaid at end
        monthly_payment = loan * monthly_rate if monthly_rate > 0 else 0
        total_cost = (monthly_payment * num_payments) + loan
        total_interest = monthly_payment * num_payments
    else:
        # Standard repayment mortgage
        if monthly_rate > 0:
            monthly_payment = loan * (monthly_rate * (1 + monthly_rate) ** num_payments) / \
                              ((1 + monthly_rate) ** num_payments - 1)
        else:
            monthly_payment = loan / num_payments
        total_cost = monthly_payment * num_payments
        total_interest = total_cost - loan

    # Stamp duty (England/NI rates as of 2025)
    stamp_duty = _calculate_stamp_duty(price, buyer_type)

    return Response({
        'price': price,
        'deposit': round(deposit, 2),
        'loan_amount': round(loan, 2),
        'monthly_payment': round(monthly_payment, 2),
        'total_cost': round(total_cost, 2),
        'total_interest': round(total_interest, 2),
        'stamp_duty': round(stamp_duty, 2),
        'term_years': term_years,
        'interest_rate': interest_rate,
        'buyer_type': buyer_type,
        'repayment_type': repayment_type,
    })


def _calculate_stamp_duty(price, buyer_type='standard'):
    """Calculate stamp duty based on buyer type (England/NI rates)."""
    # First-time buyer relief
    if buyer_type == 'first_time':
        if price <= 625000:
            if price <= 425000:
                return 0
            return (price - 425000) * 0.05
        # Falls through to standard rates if price > £625k

    # Standard bands
    duty = 0
    bands = [
        (250000, 0),
        (925000, 0.05),
        (1500000, 0.10),
        (float('inf'), 0.12),
    ]
    remaining = price
    prev = 0
    for limit, rate in bands:
        taxable = min(remaining, limit - prev)
        duty += taxable * rate
        remaining -= taxable
        prev = limit
        if remaining <= 0:
            break

    # Additional property surcharge: 5% of entire price
    if buyer_type == 'additional':
        duty += price * 0.05

    return duty


# ── Neighbourhood Data ──────────────────────────────────────────

@api_view(['GET'])
@permission_classes([permissions.AllowAny])
def neighbourhood_info(request, property_pk):
    """Get neighbourhood information for a property's location."""
    prop = get_object_or_404(Property, pk=property_pk)
    postcode = prop.postcode.strip().replace(' ', '+')
    data = {'postcode': prop.postcode, 'city': prop.city, 'county': prop.county}

    # Crime data from police.uk API
    cache_key = f'neighbourhood_{prop.postcode}'
    cached = cache.get(cache_key)
    if cached:
        return Response(cached)

    if prop.latitude and prop.longitude:
        try:
            crime_resp = requests.get(
                'https://data.police.uk/api/crimes-street/all-crime',
                params={'lat': prop.latitude, 'lng': prop.longitude, 'date': '2024-01'},
                timeout=10,
            )
            if crime_resp.status_code == 200:
                crimes = crime_resp.json()
                crime_counts = defaultdict(int)
                for c in crimes:
                    crime_counts[c.get('category', 'other')] += 1
                data['crime_summary'] = dict(crime_counts)
                data['total_crimes_nearby'] = len(crimes)
        except Exception as e:
            logger.debug('Crime API error: %s', e)

    # Postcode data
    try:
        pc_resp = requests.get(
            f'https://api.postcodes.io/postcodes/{prop.postcode.replace(" ", "")}',
            timeout=10,
        )
        if pc_resp.status_code == 200:
            pc_data = pc_resp.json().get('result', {})
            data['region'] = pc_data.get('region')
            data['parliamentary_constituency'] = pc_data.get('parliamentary_constituency')
            data['admin_district'] = pc_data.get('admin_district')
            data['nuts'] = pc_data.get('nuts')
    except Exception as e:
        logger.debug('Postcode API error: %s', e)

    cache.set(cache_key, data, 86400)  # Cache for 24h
    return Response(data)


# ── Bulk Import/Export ───────────────────────────────────────────

@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def bulk_import_properties(request):
    """Import multiple properties from JSON data."""
    properties_data = request.data.get('properties', [])
    if not properties_data or not isinstance(properties_data, list):
        return Response({'detail': 'Provide a list of properties.'}, status=status.HTTP_400_BAD_REQUEST)
    if len(properties_data) > 50:
        return Response({'detail': 'Maximum 50 properties per import.'}, status=status.HTTP_400_BAD_REQUEST)

    created = []
    errors = []
    for idx, prop_data in enumerate(properties_data):
        try:
            prop = Property.objects.create(
                owner=request.user,
                title=prop_data['title'],
                property_type=prop_data.get('property_type', 'other'),
                price=Decimal(str(prop_data['price'])),
                address_line_1=prop_data['address_line_1'],
                city=prop_data['city'],
                postcode=prop_data['postcode'],
                bedrooms=prop_data.get('bedrooms', 0),
                bathrooms=prop_data.get('bathrooms', 0),
                reception_rooms=prop_data.get('reception_rooms', 0),
                description=prop_data.get('description', ''),
                status='draft',
            )
            PriceHistory.objects.create(property=prop, price=prop.price)
            created.append({'id': prop.id, 'title': prop.title, 'slug': prop.slug})
        except Exception as e:
            errors.append({'index': idx, 'error': str(e)})

    return Response({
        'created': len(created),
        'errors': len(errors),
        'properties': created,
        'error_details': errors,
    }, status=status.HTTP_201_CREATED if created else status.HTTP_400_BAD_REQUEST)


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def export_properties(request):
    """Export the user's properties as JSON."""
    properties = Property.objects.filter(owner=request.user).prefetch_related('images', 'features')
    data = []
    for prop in properties:
        data.append({
            'title': prop.title,
            'property_type': prop.property_type,
            'status': prop.status,
            'price': str(prop.price),
            'address_line_1': prop.address_line_1,
            'address_line_2': prop.address_line_2,
            'city': prop.city,
            'county': prop.county,
            'postcode': prop.postcode,
            'bedrooms': prop.bedrooms,
            'bathrooms': prop.bathrooms,
            'reception_rooms': prop.reception_rooms,
            'square_feet': prop.square_feet,
            'epc_rating': prop.epc_rating,
            'description': prop.description,
            'features': list(prop.features.values_list('name', flat=True)),
            'created_at': prop.created_at.isoformat(),
        })
    return Response({'properties': data, 'count': len(data)})


# ── Service Provider views ───────────────────────────────────────

class IsServiceProviderOwnerOrReadOnly(permissions.BasePermission):
    def has_object_permission(self, request, view, obj):
        if request.method in permissions.SAFE_METHODS:
            return True
        return obj.owner == request.user


class ServiceCategoryViewSet(viewsets.ReadOnlyModelViewSet):
    """Read-only list of available service categories."""
    serializer_class = ServiceCategorySerializer
    queryset = ServiceCategory.objects.all()
    permission_classes = [permissions.AllowAny]
    pagination_class = None


class ServiceProviderViewSet(viewsets.ModelViewSet):
    serializer_class = ServiceProviderDetailSerializer

    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get_serializer_class(self):
        if self.action == 'list':
            return ServiceProviderListSerializer
        return ServiceProviderDetailSerializer

    def get_permissions(self):
        if self.action in ['list', 'retrieve']:
            return [permissions.AllowAny()]
        return [permissions.IsAuthenticated(), IsServiceProviderOwnerOrReadOnly()]

    def get_object(self):
        lookup = self.kwargs.get('pk', '')
        queryset = self.filter_queryset(self.get_queryset())
        if lookup.isdigit():
            obj = get_object_or_404(queryset, pk=lookup)
        else:
            obj = get_object_or_404(queryset, slug=lookup)
        self.check_object_permissions(self.request, obj)
        return obj

    def get_queryset(self):
        queryset = ServiceProvider.objects.all().select_related('owner').prefetch_related(
            'categories', 'reviews', 'subscriptions__tier', 'photos',
        )

        if self.action == 'list':
            if self.request.user.is_authenticated and self.request.query_params.get('mine') == 'true':
                queryset = queryset.filter(owner=self.request.user)
            else:
                queryset = queryset.filter(status='active')

        category = self.request.query_params.get('category')
        if category:
            queryset = queryset.filter(categories__slug=category)

        location = self.request.query_params.get('location')
        if location:
            queryset = queryset.filter(
                Q(coverage_counties__icontains=location) |
                Q(coverage_postcodes__icontains=location)
            )

        if self.action == 'list' and not self.request.query_params.get('mine'):
            from django.db.models import Case, When, Value, IntegerField
            queryset = queryset.annotate(
                tier_priority=Case(
                    When(subscriptions__tier__slug='pro', subscriptions__status='active', then=Value(0)),
                    When(subscriptions__tier__slug='growth', subscriptions__status='active', then=Value(1)),
                    default=Value(2),
                    output_field=IntegerField(),
                )
            ).order_by('tier_priority', '-created_at')

        return queryset.distinct()

    def perform_create(self, serializer):
        if ServiceProvider.objects.filter(owner=self.request.user).exists():
            raise ValidationError("You already have a service provider listing.")
        provider = serializer.save(owner=self.request.user)
        free_tier = SubscriptionTier.objects.filter(slug='free', is_active=True).first()
        if free_tier:
            ServiceProviderSubscription.objects.create(
                provider=provider, tier=free_tier,
                billing_cycle='monthly', status='active',
                stripe_subscription_id=None,
            )

    def perform_update(self, serializer):
        instance = serializer.instance
        tier = instance.current_tier
        new_categories = serializer.validated_data.get('categories')
        if new_categories is not None and tier:
            max_cats = tier.max_service_categories
            if max_cats != -1 and len(new_categories) > max_cats:
                raise ValidationError(
                    f"Your {tier.name} plan allows a maximum of {max_cats} "
                    f"categor{'y' if max_cats == 1 else 'ies'}. Upgrade your plan for more."
                )
        if 'logo' in serializer.validated_data and tier and not tier.allow_logo:
            raise ValidationError(
                f"Your {tier.name} plan does not include logo uploads. Upgrade to add your logo."
            )
        serializer.save()


class ServiceProviderReviewViewSet(viewsets.ModelViewSet):
    serializer_class = ServiceProviderReviewSerializer
    permission_classes = [permissions.IsAuthenticated]
    http_method_names = ['get', 'post', 'delete']

    def get_queryset(self):
        return ServiceProviderReview.objects.filter(
            provider_id=self.kwargs['provider_pk']
        ).select_related('reviewer')

    def perform_create(self, serializer):
        provider = get_object_or_404(ServiceProvider, pk=self.kwargs['provider_pk'])
        if provider.owner == self.request.user:
            raise ValidationError("You cannot review your own service.")
        if ServiceProviderReview.objects.filter(
            provider=provider, reviewer=self.request.user
        ).exists():
            raise ValidationError("You have already reviewed this service provider.")
        serializer.save(provider=provider, reviewer=self.request.user)

    def perform_destroy(self, instance):
        if instance.reviewer != self.request.user:
            raise PermissionDenied("You can only delete your own reviews.")
        instance.delete()


@api_view(['GET'])
@permission_classes([permissions.AllowAny])
def property_services(request, property_pk):
    """Return active service providers that cover the property's location."""
    from django.db.models import Case, When, Value, IntegerField

    prop = get_object_or_404(Property, pk=property_pk)
    postcode_prefix = prop.postcode.split()[0] if prop.postcode else ''
    county = prop.county

    providers = ServiceProvider.objects.filter(status='active').prefetch_related(
        'categories', 'subscriptions__tier',
    )
    if postcode_prefix or county:
        providers = providers.filter(
            Q(coverage_postcodes__icontains=postcode_prefix) |
            Q(coverage_counties__icontains=county)
        ).distinct()
    else:
        providers = providers.none()

    category = request.query_params.get('category')
    if category:
        providers = providers.filter(categories__slug=category)

    providers = providers.annotate(
        tier_priority=Case(
            When(subscriptions__tier__slug='pro', subscriptions__status='active', then=Value(0)),
            When(subscriptions__tier__slug='growth', subscriptions__status='active', then=Value(1)),
            default=Value(2),
            output_field=IntegerField(),
        )
    ).order_by('tier_priority', '-created_at').distinct()

    serializer = ServiceProviderListSerializer(providers[:20], many=True, context={'request': request})
    return Response(serializer.data)


# ── Subscription / Stripe views ──────────────────────────────────

@api_view(['GET'])
@permission_classes([permissions.AllowAny])
def pricing_page(request):
    """Return all active tiers, add-ons, and billing info for the pricing page."""
    tiers = SubscriptionTier.objects.filter(is_active=True).order_by('display_order', 'monthly_price')
    addons = SubscriptionAddOn.objects.filter(is_active=True).order_by('display_order')
    return Response({
        'tiers': SubscriptionTierSerializer(tiers, many=True).data,
        'addons': SubscriptionAddOnSerializer(addons, many=True).data,
        'billing_cycles': ['monthly', 'annual'],
        'annual_discount_percent': 20,
        'currency': 'GBP',
    })


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def my_subscription(request):
    """Return the current user's subscription details and usage stats."""
    try:
        provider = ServiceProvider.objects.get(owner=request.user)
    except ServiceProvider.DoesNotExist:
        return Response({'detail': 'No service provider profile found.'}, status=status.HTTP_404_NOT_FOUND)

    tier = provider.current_tier
    sub = provider.active_subscription

    data = {
        'tier': SubscriptionTierSerializer(tier).data if tier else None,
        'subscription': ServiceProviderSubscriptionSerializer(sub).data if sub else None,
        'usage': {
            'categories_used': provider.categories.count(),
            'categories_max': tier.max_service_categories if tier else 1,
            'locations_used': 1,
            'locations_max': tier.max_locations if tier else 1,
            'photos_used': provider.photos.count(),
            'photos_max': tier.max_photos if tier else 0,
        },
    }
    return Response(data)


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def create_checkout(request):
    """Create a Stripe Checkout Session for subscribing to a tier."""
    import stripe
    stripe.api_key = settings.STRIPE_SECRET_KEY

    tier_slug = request.data.get('tier_slug')
    billing_cycle = request.data.get('billing_cycle', 'monthly')

    if not tier_slug:
        return Response({'detail': 'tier_slug is required.'}, status=status.HTTP_400_BAD_REQUEST)

    tier = SubscriptionTier.objects.filter(slug=tier_slug, is_active=True).first()
    if not tier:
        return Response({'detail': 'Tier not found.'}, status=status.HTTP_404_NOT_FOUND)

    if tier.slug == 'free':
        return Response({'detail': 'Free tier does not require payment.'}, status=status.HTTP_400_BAD_REQUEST)

    price_id = tier.stripe_annual_price_id if billing_cycle == 'annual' else tier.stripe_monthly_price_id
    if not price_id:
        return Response({'detail': 'Stripe price not configured for this tier/billing cycle.'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        provider = ServiceProvider.objects.get(owner=request.user)
    except ServiceProvider.DoesNotExist:
        return Response({'detail': 'Register as a service provider first.'}, status=status.HTTP_400_BAD_REQUEST)

    if provider.stripe_customer_id:
        customer_id = provider.stripe_customer_id
    else:
        customer = stripe.Customer.create(
            email=request.user.email,
            name=provider.business_name,
            metadata={'provider_id': provider.id, 'user_id': request.user.id},
        )
        customer_id = customer.id
        provider.stripe_customer_id = customer_id
        provider.save(update_fields=['stripe_customer_id'])

    site_url = request.build_absolute_uri('/').rstrip('/')

    session = stripe.checkout.Session.create(
        customer=customer_id,
        mode='subscription',
        line_items=[{'price': price_id, 'quantity': 1}],
        success_url=f'{site_url}/my-service/?subscription=success',
        cancel_url=f'{site_url}/pricing/?cancelled=true',
        metadata={
            'provider_id': provider.id,
            'tier_slug': tier.slug,
            'billing_cycle': billing_cycle,
        },
    )

    return Response({'checkout_url': session.url})


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def create_portal(request):
    """Create a Stripe Billing Portal session."""
    import stripe
    stripe.api_key = settings.STRIPE_SECRET_KEY

    try:
        provider = ServiceProvider.objects.get(owner=request.user)
    except ServiceProvider.DoesNotExist:
        return Response({'detail': 'No service provider profile found.'}, status=status.HTTP_404_NOT_FOUND)

    if not provider.stripe_customer_id:
        return Response({'detail': 'No billing account found.'}, status=status.HTTP_400_BAD_REQUEST)

    site_url = request.build_absolute_uri('/').rstrip('/')

    session = stripe.billing_portal.Session.create(
        customer=provider.stripe_customer_id,
        return_url=f'{site_url}/my-service/',
    )

    return Response({'portal_url': session.url})


@csrf_exempt
@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def stripe_webhook(request):
    """Handle Stripe webhook events for subscription lifecycle."""
    import stripe
    stripe.api_key = settings.STRIPE_SECRET_KEY

    payload = request.body
    sig_header = request.META.get('HTTP_STRIPE_SIGNATURE', '')
    webhook_secret = settings.STRIPE_WEBHOOK_SECRET

    if not webhook_secret:
        logger.error('STRIPE_WEBHOOK_SECRET not configured')
        return Response({'detail': 'Webhook not configured.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    try:
        event = stripe.Webhook.construct_event(payload, sig_header, webhook_secret)
    except ValueError:
        return Response({'detail': 'Invalid payload.'}, status=status.HTTP_400_BAD_REQUEST)
    except stripe.error.SignatureVerificationError:
        return Response({'detail': 'Invalid signature.'}, status=status.HTTP_400_BAD_REQUEST)

    event_type = event['type']
    data = event['data']['object']

    if event_type == 'checkout.session.completed':
        _handle_checkout_completed(data)
    elif event_type == 'customer.subscription.updated':
        _handle_subscription_updated(data)
    elif event_type == 'customer.subscription.deleted':
        _handle_subscription_deleted(data)
    elif event_type == 'invoice.payment_failed':
        _handle_payment_failed(data)
    elif event_type == 'invoice.paid':
        _handle_invoice_paid(data)

    return Response({'status': 'ok'})


def _handle_checkout_completed(session):
    """Process a completed Stripe Checkout Session."""
    import stripe

    stripe_sub_id = session.get('subscription')
    customer_id = session.get('customer')
    metadata = session.get('metadata', {})
    provider_id = metadata.get('provider_id')
    tier_slug = metadata.get('tier_slug')
    billing_cycle = metadata.get('billing_cycle', 'monthly')

    if not all([stripe_sub_id, provider_id, tier_slug]):
        logger.warning('Checkout session missing required metadata: %s', metadata)
        return

    try:
        provider = ServiceProvider.objects.get(pk=provider_id)
        tier = SubscriptionTier.objects.get(slug=tier_slug)
    except (ServiceProvider.DoesNotExist, SubscriptionTier.DoesNotExist):
        logger.error('Provider or tier not found for checkout: provider=%s tier=%s', provider_id, tier_slug)
        return

    stripe.api_key = settings.STRIPE_SECRET_KEY
    stripe_sub = stripe.Subscription.retrieve(stripe_sub_id)

    provider.subscriptions.filter(status='active').exclude(tier__slug='free').update(
        status='cancelled', cancelled_at=timezone.now()
    )
    provider.subscriptions.filter(status='active', tier__slug='free').update(status='cancelled')

    # Use get_or_create to handle webhook replays idempotently
    ServiceProviderSubscription.objects.get_or_create(
        stripe_subscription_id=stripe_sub_id,
        defaults={
            'provider': provider,
            'tier': tier,
            'billing_cycle': billing_cycle,
            'status': 'active',
            'stripe_customer_id': customer_id,
            'current_period_start': timezone.datetime.fromtimestamp(
                stripe_sub.current_period_start, tz=timezone.utc
            ),
            'current_period_end': timezone.datetime.fromtimestamp(
                stripe_sub.current_period_end, tz=timezone.utc
            ),
        },
    )

    if customer_id and not provider.stripe_customer_id:
        provider.stripe_customer_id = customer_id
        provider.save(update_fields=['stripe_customer_id'])

    logger.info('Subscription created: provider=%s tier=%s', provider.id, tier.slug)


def _handle_subscription_updated(sub_data):
    stripe_sub_id = sub_data.get('id')
    try:
        sub = ServiceProviderSubscription.objects.get(stripe_subscription_id=stripe_sub_id)
    except ServiceProviderSubscription.DoesNotExist:
        logger.warning('Subscription not found for update: %s', stripe_sub_id)
        return

    stripe_status = sub_data.get('status')
    status_map = {
        'active': 'active',
        'past_due': 'past_due',
        'canceled': 'cancelled',
        'unpaid': 'past_due',
    }
    sub.status = status_map.get(stripe_status, sub.status)
    sub.cancel_at_period_end = sub_data.get('cancel_at_period_end', False)

    if sub_data.get('current_period_start'):
        sub.current_period_start = timezone.datetime.fromtimestamp(
            sub_data['current_period_start'], tz=timezone.utc
        )
    if sub_data.get('current_period_end'):
        sub.current_period_end = timezone.datetime.fromtimestamp(
            sub_data['current_period_end'], tz=timezone.utc
        )

    items = sub_data.get('items', {}).get('data', [])
    if items:
        price_id = items[0].get('price', {}).get('id', '')
        new_tier = SubscriptionTier.objects.filter(
            Q(stripe_monthly_price_id=price_id) | Q(stripe_annual_price_id=price_id)
        ).first()
        if new_tier and new_tier != sub.tier:
            sub.tier = new_tier
            interval = items[0].get('price', {}).get('recurring', {}).get('interval', '')
            sub.billing_cycle = 'annual' if interval == 'year' else 'monthly'

    sub.save()
    logger.info('Subscription updated: %s status=%s', stripe_sub_id, sub.status)


def _handle_subscription_deleted(sub_data):
    stripe_sub_id = sub_data.get('id')
    try:
        sub = ServiceProviderSubscription.objects.get(stripe_subscription_id=stripe_sub_id)
    except ServiceProviderSubscription.DoesNotExist:
        return

    sub.status = 'cancelled'
    sub.cancelled_at = timezone.now()
    sub.save(update_fields=['status', 'cancelled_at'])

    provider = sub.provider
    free_tier = SubscriptionTier.objects.filter(slug='free', is_active=True).first()
    if free_tier and not provider.subscriptions.filter(status='active').exists():
        ServiceProviderSubscription.objects.create(
            provider=provider, tier=free_tier,
            billing_cycle='monthly', status='active',
            stripe_subscription_id=None,
        )

    logger.info('Subscription cancelled, free tier assigned: provider=%s', provider.id)


def _handle_payment_failed(invoice_data):
    stripe_sub_id = invoice_data.get('subscription')
    if not stripe_sub_id:
        return
    ServiceProviderSubscription.objects.filter(
        stripe_subscription_id=stripe_sub_id
    ).update(status='past_due')
    logger.warning('Payment failed for subscription: %s', stripe_sub_id)


def _handle_invoice_paid(invoice_data):
    stripe_sub_id = invoice_data.get('subscription')
    if not stripe_sub_id:
        return
    try:
        sub = ServiceProviderSubscription.objects.get(stripe_subscription_id=stripe_sub_id)
    except ServiceProviderSubscription.DoesNotExist:
        return

    sub.status = 'active'
    period_end = invoice_data.get('lines', {}).get('data', [{}])[0].get('period', {}).get('end')
    if period_end:
        sub.current_period_end = timezone.datetime.fromtimestamp(period_end, tz=timezone.utc)
    sub.save()
    logger.info('Invoice paid, subscription reactivated: %s', stripe_sub_id)


# ── Service Provider Photo ViewSet ───────────────────────────────

class ServiceProviderPhotoViewSet(viewsets.ModelViewSet):
    serializer_class = ServiceProviderPhotoSerializer
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def get_queryset(self):
        return ServiceProviderPhoto.objects.filter(
            provider_id=self.kwargs['provider_pk']
        )

    def perform_create(self, serializer):
        provider = get_object_or_404(ServiceProvider, pk=self.kwargs['provider_pk'])
        if provider.owner != self.request.user:
            raise PermissionDenied("You can only add photos to your own listing.")
        tier = provider.current_tier
        max_photos = tier.max_photos if tier else 0
        if max_photos != -1 and provider.photos.count() >= max_photos:
            raise ValidationError(
                f"Your {tier.name if tier else 'Free'} plan allows a maximum of {max_photos} photos. "
                "Upgrade your plan to add more."
            )
        serializer.save(provider=provider)

    def perform_update(self, serializer):
        if serializer.instance.provider.owner != self.request.user:
            raise PermissionDenied()
        serializer.save()

    def perform_destroy(self, instance):
        if instance.provider.owner != self.request.user:
            raise PermissionDenied()
        instance.image.delete(save=False)
        instance.delete()


@api_view(['GET'])
@permission_classes([permissions.AllowAny])
def house_price_lookup(request):
    """Proxy Land Registry Price Paid Data API."""
    postcode = request.query_params.get('postcode', '').strip().upper()
    if not postcode:
        return Response({'error': 'Postcode is required'}, status=400)
    try:
        resp = requests.get(
            'https://landregistry.data.gov.uk/data/ppi/transaction-record.json',
            params={
                'propertyAddress.postcode': postcode,
                '_pageSize': '50',
                '_sort': '-transactionDate',
            },
            timeout=30,
        )
        resp.raise_for_status()
        return Response(resp.json())
    except requests.RequestException as e:
        logger.warning('Land Registry API error: %s', e)
        return Response(
            {'error': 'Could not connect to Land Registry. Please try again.'},
            status=502,
        )


# ── Health Check ─────────────────────────────────────────────────

@api_view(['GET'])
@permission_classes([permissions.AllowAny])
def health_check(request):
    """Health check endpoint for monitoring."""
    return Response({'status': 'healthy', 'version': '2.0.0'})


# ══════════════════════════════════════════════════════════════════
# NEW FEATURES (#28-#45)
# ══════════════════════════════════════════════════════════════════


# ── #28 Listing Quality Score ────────────────────────────────────

@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def listing_quality_score(request, property_pk):
    """Return the listing quality score and improvement tips for a property."""
    prop = get_object_or_404(Property, pk=property_pk)
    if prop.owner != request.user:
        raise PermissionDenied('You can only view the quality score of your own listings.')
    return Response(prop.listing_quality_score())


# ── #29 Price Comparison & Valuation Tool ────────────────────────

@api_view(['GET'])
@permission_classes([permissions.AllowAny])
def price_comparison(request):
    """Compare property prices in an area using Land Registry data and local listings."""
    postcode = request.query_params.get('postcode', '').strip().upper()
    if not postcode:
        return Response({'error': 'Postcode is required'}, status=400)

    # Get the postcode district (e.g. "BS1" from "BS1 4DJ")
    postcode_district = postcode.split()[0] if ' ' in postcode else postcode[:3]

    # 1. Land Registry sold prices
    land_registry_data = []
    try:
        resp = requests.get(
            'https://landregistry.data.gov.uk/data/ppi/transaction-record.json',
            params={
                'propertyAddress.postcode': postcode,
                '_pageSize': '50',
                '_sort': '-transactionDate',
            },
            timeout=30,
        )
        resp.raise_for_status()
        data = resp.json()
        items = data.get('result', {}).get('items', [])
        for item in items:
            land_registry_data.append({
                'address': item.get('propertyAddress', {}).get('paon', ''),
                'price': item.get('pricePaid', 0),
                'date': item.get('transactionDate', ''),
                'property_type': item.get('propertyType', {}).get('prefLabel', [''])[0] if isinstance(item.get('propertyType', {}).get('prefLabel'), list) else item.get('propertyType', {}).get('prefLabel', ''),
                'is_new_build': item.get('newBuild', False),
            })
    except requests.RequestException:
        pass

    # 2. Local listings on our platform
    local_listings = Property.objects.filter(
        status='active',
        postcode__istartswith=postcode_district,
    ).values('id', 'title', 'price', 'property_type', 'bedrooms', 'square_feet', 'slug')[:20]

    # 3. Calculate statistics
    sold_prices = [item['price'] for item in land_registry_data if item.get('price')]
    listing_prices = [float(p['price']) for p in local_listings if p.get('price')]
    all_prices = sold_prices + listing_prices

    stats = {}
    if all_prices:
        stats = {
            'average_price': round(sum(all_prices) / len(all_prices)),
            'median_price': round(sorted(all_prices)[len(all_prices) // 2]),
            'min_price': round(min(all_prices)),
            'max_price': round(max(all_prices)),
            'total_comparables': len(all_prices),
        }

    # 4. Price per square foot from our listings
    sqft_data = [
        float(p['price']) / p['square_feet']
        for p in local_listings
        if p.get('square_feet') and p['square_feet'] > 0
    ]
    if sqft_data:
        stats['avg_price_per_sqft'] = round(sum(sqft_data) / len(sqft_data))

    return Response({
        'postcode': postcode,
        'postcode_district': postcode_district,
        'sold_prices': land_registry_data[:20],
        'local_listings': list(local_listings),
        'statistics': stats,
    })


# ── #30 Buyer Verification ──────────────────────────────────────

class BuyerVerificationViewSet(viewsets.ModelViewSet):
    """CRUD for buyer verification documents."""
    serializer_class = BuyerVerificationSerializer
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get_queryset(self):
        return BuyerVerification.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


@api_view(['GET'])
@permission_classes([permissions.AllowAny])
def buyer_verification_status(request, user_pk):
    """Check if a buyer is verified (public endpoint for sellers)."""
    user = get_object_or_404(User, pk=user_pk)
    verifications = BuyerVerification.objects.filter(user=user, status='verified')
    has_valid = any(v.is_valid for v in verifications)
    types_verified = [v.get_verification_type_display() for v in verifications if v.is_valid]
    return Response({
        'user_id': user.pk,
        'is_verified_buyer': has_valid,
        'verified_types': types_verified,
    })


# ── #31 Conveyancing Progress Tracker ────────────────────────────

class ConveyancingCaseViewSet(viewsets.ModelViewSet):
    """CRUD for conveyancing cases."""
    serializer_class = ConveyancingCaseSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        return ConveyancingCase.objects.filter(
            Q(buyer=user) | Q(seller=user)
        ).select_related('property', 'offer', 'buyer', 'seller').prefetch_related('steps')

    def perform_create(self, serializer):
        offer = serializer.validated_data.get('offer')
        if not offer:
            raise ValidationError('An accepted offer is required to create a conveyancing case.')
        if offer.status != 'accepted':
            raise ValidationError('Only accepted offers can start conveyancing.')
        if offer.property.owner != self.request.user and offer.buyer != self.request.user:
            raise PermissionDenied('You must be the buyer or seller.')

        case = serializer.save(
            buyer=offer.buyer,
            seller=offer.property.owner,
            property=offer.property,
        )
        # Create default steps
        default_steps = [
            ('offer_accepted', 0),
            ('memorandum_of_sale', 1),
            ('solicitors_instructed', 2),
            ('draft_contract', 3),
            ('searches_ordered', 4),
            ('searches_received', 5),
            ('survey_booked', 6),
            ('survey_received', 7),
            ('mortgage_offer', 8),
            ('enquiries_raised', 9),
            ('enquiries_answered', 10),
            ('ready_to_exchange', 11),
            ('exchanged', 12),
            ('completion', 13),
        ]
        for step_type, order in default_steps:
            ConveyancingStep.objects.create(
                case=case, step_type=step_type, order=order,
                status='completed' if step_type == 'offer_accepted' else 'pending',
                completed_at=timezone.now() if step_type == 'offer_accepted' else None,
            )


@api_view(['PATCH'])
@permission_classes([permissions.IsAuthenticated])
def update_conveyancing_step(request, case_pk, step_pk):
    """Update a conveyancing step status."""
    case = get_object_or_404(ConveyancingCase, pk=case_pk)
    if case.buyer != request.user and case.seller != request.user:
        raise PermissionDenied('You are not part of this conveyancing case.')

    step = get_object_or_404(ConveyancingStep, pk=step_pk, case=case)
    new_status = request.data.get('status')
    if new_status and new_status in dict(ConveyancingStep.STATUS_CHOICES):
        step.status = new_status
        if new_status == 'completed':
            step.completed_at = timezone.now()
        step.notes = request.data.get('notes', step.notes)
        step.save()

        # Trigger nudge check
        try:
            from .tasks import check_conveyancing_stale_steps
            check_conveyancing_stale_steps.delay(case.pk)
        except Exception:
            pass

    return Response(ConveyancingStepSerializer(step).data)


# ── #32 AI-Powered Listing Description Generator ─────────────────

@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def generate_listing_description(request):
    """Generate a property listing description based on provided details."""
    property_type = request.data.get('property_type', '')
    bedrooms = request.data.get('bedrooms', 0)
    bathrooms = request.data.get('bathrooms', 0)
    reception_rooms = request.data.get('reception_rooms', 0)
    square_feet = request.data.get('square_feet')
    features = request.data.get('features', [])
    location = request.data.get('location', '')
    epc_rating = request.data.get('epc_rating', '')
    tone = request.data.get('tone', 'professional')
    additional_notes = request.data.get('additional_notes', '')

    # Build description from property details
    type_display = dict(Property.PROPERTY_TYPES).get(property_type, property_type)

    # Construct structured description
    parts = []

    if tone == 'estate_agent':
        opener = f"A stunning {bedrooms} bedroom {type_display.lower()}"
    elif tone == 'casual':
        opener = f"This lovely {bedrooms} bedroom {type_display.lower()}"
    else:
        opener = f"A well-presented {bedrooms} bedroom {type_display.lower()}"

    if location:
        opener += f" located in the sought-after area of {location}"
    parts.append(opener + ".")

    # Accommodation details
    rooms = []
    if reception_rooms:
        rooms.append(f"{reception_rooms} reception room{'s' if reception_rooms > 1 else ''}")
    if bathrooms:
        rooms.append(f"{bathrooms} bathroom{'s' if bathrooms > 1 else ''}")
    if rooms:
        parts.append(f"The property comprises {', '.join(rooms)}.")

    if square_feet:
        parts.append(f"Offering approximately {square_feet} sq ft of living space.")

    # Features
    if features:
        feature_list = ', '.join(features[:-1])
        if len(features) > 1:
            feature_list += f" and {features[-1]}"
        else:
            feature_list = features[0]
        parts.append(f"Key features include {feature_list}.")

    # EPC
    if epc_rating:
        parts.append(f"The property has an EPC rating of {epc_rating}.")

    # Additional notes
    if additional_notes:
        parts.append(additional_notes)

    # Closing
    if tone == 'estate_agent':
        parts.append("Internal viewing is highly recommended to fully appreciate what this property has to offer.")
    elif tone == 'casual':
        parts.append("Come and see it for yourself — you won't be disappointed!")
    else:
        parts.append("Viewings are welcomed and encouraged.")

    description = " ".join(parts)

    return Response({
        'description': description,
        'tone': tone,
        'word_count': len(description.split()),
    })


# ── #33 Similar Properties ──────────────────────────────────────

@api_view(['GET'])
@permission_classes([permissions.AllowAny])
def similar_properties(request, property_pk):
    """Find properties similar to the given one."""
    prop = get_object_or_404(Property, pk=property_pk)

    # Match on same area, similar price (±25%), same type, similar bedrooms (±1)
    price_min = float(prop.price) * 0.75
    price_max = float(prop.price) * 1.25

    queryset = Property.objects.filter(
        status='active',
        price__gte=price_min,
        price__lte=price_max,
    ).exclude(pk=prop.pk)

    # Prefer same city/postcode area
    postcode_prefix = prop.postcode.split()[0] if ' ' in prop.postcode else prop.postcode[:3]
    same_area = queryset.filter(
        Q(city__iexact=prop.city) | Q(postcode__istartswith=postcode_prefix)
    )

    # Further filter by property type and similar bedrooms
    close_match = same_area.filter(
        property_type=prop.property_type,
        bedrooms__gte=max(0, prop.bedrooms - 1),
        bedrooms__lte=prop.bedrooms + 1,
    )

    # Fall back to broader matches if not enough results
    if close_match.count() >= 4:
        results = close_match[:8]
    elif same_area.count() >= 4:
        results = same_area[:8]
    else:
        results = queryset[:8]

    serializer = PropertyListSerializer(
        results, many=True, context={'request': request}
    )
    return Response(serializer.data)


# ── #35 Stamp Duty Calculator ────────────────────────────────────

@api_view(['GET'])
@permission_classes([permissions.AllowAny])
def stamp_duty_calculator(request):
    """Calculate UK Stamp Duty Land Tax."""
    try:
        price = float(request.query_params.get('price', 0))
    except (ValueError, TypeError):
        return Response({'error': 'Invalid price'}, status=400)

    is_first_time = request.query_params.get('first_time_buyer', 'false').lower() == 'true'
    is_additional = request.query_params.get('additional_property', 'false').lower() == 'true'
    country = request.query_params.get('country', 'england').lower()

    if country in ('england', 'northern_ireland'):
        # Standard SDLT rates (2024/25)
        if is_first_time and price <= 625000:
            bands = [
                (425000, 0.0),
                (625000, 0.05),
            ]
        else:
            bands = [
                (250000, 0.0),
                (925000, 0.05),
                (1500000, 0.10),
                (float('inf'), 0.12),
            ]
        additional_surcharge = 0.03 if is_additional else 0.0
    elif country == 'scotland':
        # Scottish LBTT
        bands = [
            (145000, 0.0),
            (250000, 0.02),
            (325000, 0.05),
            (750000, 0.10),
            (float('inf'), 0.12),
        ]
        additional_surcharge = 0.06 if is_additional else 0.0
    elif country == 'wales':
        # Welsh LTT
        bands = [
            (225000, 0.0),
            (400000, 0.06),
            (750000, 0.075),
            (1500000, 0.10),
            (float('inf'), 0.12),
        ]
        additional_surcharge = 0.04 if is_additional else 0.0
    else:
        return Response({'error': 'Invalid country. Use: england, scotland, wales, northern_ireland'}, status=400)

    # Calculate banded tax
    tax = 0
    remaining = price
    prev_threshold = 0
    band_breakdown = []

    for threshold, rate in bands:
        if remaining <= 0:
            break
        band_amount = min(remaining, threshold - prev_threshold)
        effective_rate = rate + additional_surcharge
        band_tax = band_amount * effective_rate
        band_breakdown.append({
            'from': prev_threshold,
            'to': min(threshold, price),
            'rate': effective_rate,
            'tax': round(band_tax, 2),
        })
        tax += band_tax
        remaining -= band_amount
        prev_threshold = threshold

    # Estimated total costs
    estimated_legal_fees = 1500 if price < 500000 else 2500
    estimated_survey_cost = 400 if price < 300000 else 700

    return Response({
        'price': price,
        'country': country,
        'is_first_time_buyer': is_first_time,
        'is_additional_property': is_additional,
        'stamp_duty': round(tax, 2),
        'effective_rate': round((tax / price) * 100, 2) if price > 0 else 0,
        'band_breakdown': band_breakdown,
        'total_purchase_costs': {
            'property_price': price,
            'stamp_duty': round(tax, 2),
            'estimated_legal_fees': estimated_legal_fees,
            'estimated_survey_cost': estimated_survey_cost,
            'total': round(price + tax + estimated_legal_fees + estimated_survey_cost, 2),
        },
    })


# ── #36 Property History & Title Insights ────────────────────────

@api_view(['GET'])
@permission_classes([permissions.AllowAny])
def property_history(request, property_pk):
    """Return property price history and days on market."""
    prop = get_object_or_404(Property, pk=property_pk)

    # Internal price history
    price_changes = PriceHistory.objects.filter(property=prop).order_by('changed_at')
    history = [
        {
            'price': float(ph.price),
            'date': ph.changed_at.isoformat(),
        }
        for ph in price_changes
    ]

    # Days on market
    days_on_market = (timezone.now() - prop.created_at).days

    # Land Registry previous sales for this postcode
    land_registry = []
    try:
        resp = requests.get(
            'https://landregistry.data.gov.uk/data/ppi/transaction-record.json',
            params={
                'propertyAddress.postcode': prop.postcode,
                'propertyAddress.paon': prop.address_line_1.split()[0] if prop.address_line_1 else '',
                '_pageSize': '10',
                '_sort': '-transactionDate',
            },
            timeout=15,
        )
        resp.raise_for_status()
        items = resp.json().get('result', {}).get('items', [])
        for item in items:
            land_registry.append({
                'price': item.get('pricePaid', 0),
                'date': item.get('transactionDate', ''),
            })
    except requests.RequestException:
        pass

    return Response({
        'property_id': prop.pk,
        'current_price': float(prop.price),
        'days_on_market': days_on_market,
        'listed_date': prop.created_at.isoformat(),
        'price_changes': history,
        'land_registry_sales': land_registry,
    })


# ── #37 Open House Events ───────────────────────────────────────

class OpenHouseEventViewSet(viewsets.ModelViewSet):
    """CRUD for open house events."""
    serializer_class = OpenHouseEventSerializer

    def get_permissions(self):
        if self.action in ['list', 'retrieve']:
            return [permissions.AllowAny()]
        return [permissions.IsAuthenticated()]

    def get_queryset(self):
        property_pk = self.kwargs.get('property_pk')
        if property_pk:
            return OpenHouseEvent.objects.filter(property_id=property_pk)
        if self.request.user.is_authenticated:
            return OpenHouseEvent.objects.filter(property__owner=self.request.user)
        return OpenHouseEvent.objects.none()

    def perform_create(self, serializer):
        property_pk = self.kwargs.get('property_pk')
        prop = get_object_or_404(Property, pk=property_pk)
        if prop.owner != self.request.user:
            raise PermissionDenied('Only the property owner can create open house events.')
        serializer.save(property=prop)

    def perform_update(self, serializer):
        if serializer.instance.property.owner != self.request.user:
            raise PermissionDenied()
        serializer.save()

    def perform_destroy(self, instance):
        if instance.property.owner != self.request.user:
            raise PermissionDenied()
        instance.delete()


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def rsvp_open_house(request, event_pk):
    """RSVP to an open house event."""
    event = get_object_or_404(OpenHouseEvent, pk=event_pk, is_active=True)

    if not event.has_capacity:
        return Response({'error': 'This event is at full capacity.'}, status=400)

    if event.property.owner == request.user:
        return Response({'error': 'You cannot RSVP to your own open house.'}, status=400)

    rsvp, created = OpenHouseRSVP.objects.get_or_create(
        event=event,
        user=request.user,
        defaults={
            'attendees': request.data.get('attendees', 1),
            'message': request.data.get('message', ''),
        }
    )

    if not created:
        return Response({'error': 'You have already RSVPd to this event.'}, status=400)

    # Notify the seller
    try:
        from .tasks import send_email_task
        send_email_task.delay(
            f'New RSVP for {event.title}',
            f'Hi {event.property.owner.first_name or event.property.owner.email},\n\n'
            f'{request.user.get_full_name() or request.user.email} has RSVPd to your '
            f'open house event for "{event.property.title}" on {event.date}.\n\n'
            f'— For Sale By Owner',
            settings.DEFAULT_FROM_EMAIL,
            [event.property.owner.email],
        )
    except Exception:
        pass

    return Response(OpenHouseRSVPSerializer(rsvp).data, status=201)


@api_view(['DELETE'])
@permission_classes([permissions.IsAuthenticated])
def cancel_rsvp(request, event_pk):
    """Cancel an RSVP to an open house event."""
    rsvp = get_object_or_404(OpenHouseRSVP, event_id=event_pk, user=request.user)
    rsvp.delete()
    return Response(status=204)


# ── #38 QR Code Property Flyers ──────────────────────────────────

@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def generate_property_flyer(request, property_pk):
    """Generate a printable property flyer with QR code."""
    prop = get_object_or_404(Property, pk=property_pk)
    if prop.owner != request.user:
        raise PermissionDenied('Only the property owner can generate flyers.')

    property_url = f"{settings.SITE_URL}/properties/{prop.slug or prop.pk}/"

    # Generate QR code
    try:
        import qrcode
        from io import BytesIO
        import base64

        qr = qrcode.QRCode(version=1, box_size=10, border=4)
        qr.add_data(property_url)
        qr.make(fit=True)
        qr_img = qr.make_image(fill_color="black", back_color="white")
        qr_buffer = BytesIO()
        qr_img.save(qr_buffer, format='PNG')
        qr_base64 = base64.b64encode(qr_buffer.getvalue()).decode()
    except ImportError:
        qr_base64 = None

    # Get primary image
    primary_image = None
    primary = prop.images.filter(is_primary=True).first()
    if primary and primary.image:
        primary_image = primary.image.url

    # Build flyer data
    flyer_data = {
        'property': {
            'title': prop.title,
            'price': f"£{prop.price:,.0f}",
            'address': f"{prop.address_line_1}, {prop.city}, {prop.postcode}",
            'bedrooms': prop.bedrooms,
            'bathrooms': prop.bathrooms,
            'reception_rooms': prop.reception_rooms,
            'square_feet': prop.square_feet,
            'property_type': prop.get_property_type_display(),
            'epc_rating': prop.epc_rating,
            'description': prop.description[:300] + ('...' if len(prop.description) > 300 else ''),
            'primary_image': primary_image,
        },
        'qr_code': qr_base64,
        'property_url': property_url,
        'generated_at': timezone.now().isoformat(),
    }

    return Response(flyer_data)


# ── #39 Solicitor / Conveyancer Matching ─────────────────────────

class ConveyancerQuoteRequestViewSet(viewsets.ModelViewSet):
    """CRUD for conveyancer quote requests."""
    serializer_class = ConveyancerQuoteRequestSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return ConveyancerQuoteRequest.objects.filter(
            requester=self.request.user
        ).prefetch_related('quotes__provider')

    def perform_create(self, serializer):
        quote_request = serializer.save(requester=self.request.user)

        # Notify matching conveyancers
        prop = quote_request.property
        postcode_prefix = prop.postcode.split()[0] if ' ' in prop.postcode else prop.postcode[:3]

        # Find conveyancers covering this area
        conveyancing_categories = ServiceCategory.objects.filter(
            slug__in=['conveyancing', 'solicitor', 'conveyancer']
        )
        matching_providers = ServiceProvider.objects.filter(
            status='active',
            categories__in=conveyancing_categories,
        ).filter(
            Q(coverage_postcodes__icontains=postcode_prefix) |
            Q(coverage_counties__icontains=prop.county)
        ).distinct()[:10]

        try:
            from .tasks import send_email_task
            for provider in matching_providers:
                send_email_task.delay(
                    f'New conveyancing quote request for {prop.city}',
                    f'Hi {provider.business_name},\n\n'
                    f'A new conveyancing quote request has been submitted for a property in '
                    f'{prop.city} ({prop.postcode}).\n\n'
                    f'Transaction type: {quote_request.get_transaction_type_display()}\n\n'
                    f'Submit your quote on the platform:\n'
                    f'{settings.SITE_URL}/my-service/\n\n'
                    f'— For Sale By Owner',
                    settings.DEFAULT_FROM_EMAIL,
                    [provider.contact_email],
                )
        except Exception:
            pass


class ConveyancerQuoteViewSet(viewsets.ModelViewSet):
    """Viewset for service providers to submit and manage quotes."""
    serializer_class = ConveyancerQuoteSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        # Providers see quotes they've made; requesters see quotes on their requests
        user = self.request.user
        return ConveyancerQuote.objects.filter(
            Q(provider__owner=user) | Q(request__requester=user)
        )

    def perform_create(self, serializer):
        try:
            provider = self.request.user.service_provider
        except ServiceProvider.DoesNotExist:
            raise PermissionDenied('You must be a registered service provider to submit quotes.')
        serializer.save(provider=provider)


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def accept_conveyancer_quote(request, quote_pk):
    """Accept a conveyancing quote."""
    quote = get_object_or_404(ConveyancerQuote, pk=quote_pk)
    if quote.request.requester != request.user:
        raise PermissionDenied('Only the requester can accept quotes.')

    quote.is_accepted = True
    quote.save()
    quote.request.status = 'accepted'
    quote.request.save()

    # Reject other quotes
    ConveyancerQuote.objects.filter(
        request=quote.request
    ).exclude(pk=quote.pk).update(is_accepted=False)

    # Notify accepted provider
    try:
        from .tasks import send_email_task
        send_email_task.delay(
            'Your conveyancing quote has been accepted',
            f'Hi {quote.provider.business_name},\n\n'
            f'Your quote of £{quote.total:,.2f} has been accepted.\n\n'
            f'Please contact the client to proceed.\n\n'
            f'— For Sale By Owner',
            settings.DEFAULT_FROM_EMAIL,
            [quote.provider.contact_email],
        )
    except Exception:
        pass

    return Response(ConveyancerQuoteSerializer(quote).data)


# ── #40 Neighbourhood Reviews ───────────────────────────────────

class NeighbourhoodReviewViewSet(viewsets.ModelViewSet):
    """CRUD for neighbourhood reviews."""
    serializer_class = NeighbourhoodReviewSerializer

    def get_permissions(self):
        if self.action in ['list', 'retrieve']:
            return [permissions.AllowAny()]
        return [permissions.IsAuthenticated()]

    def get_queryset(self):
        postcode_area = self.request.query_params.get('postcode_area', '').strip().upper()
        qs = NeighbourhoodReview.objects.all()
        if postcode_area:
            qs = qs.filter(postcode_area__iexact=postcode_area)
        return qs

    def perform_create(self, serializer):
        serializer.save(reviewer=self.request.user)


@api_view(['GET'])
@permission_classes([permissions.AllowAny])
def neighbourhood_summary(request, postcode_area):
    """Aggregate neighbourhood review scores."""
    postcode_area = postcode_area.strip().upper()
    reviews = NeighbourhoodReview.objects.filter(postcode_area__iexact=postcode_area)

    if not reviews.exists():
        return Response({'postcode_area': postcode_area, 'review_count': 0})

    agg = reviews.aggregate(
        avg_overall=Avg('overall_rating'),
        avg_community=Avg('community_rating'),
        avg_noise=Avg('noise_rating'),
        avg_parking=Avg('parking_rating'),
        avg_shops=Avg('shops_rating'),
        avg_safety=Avg('safety_rating'),
        avg_schools=Avg('schools_rating'),
        avg_transport=Avg('transport_rating'),
        count=Count('id'),
    )

    return Response({
        'postcode_area': postcode_area,
        'review_count': agg['count'],
        'ratings': {
            'overall': round(agg['avg_overall'], 1) if agg['avg_overall'] else None,
            'community': round(agg['avg_community'], 1) if agg['avg_community'] else None,
            'noise': round(agg['avg_noise'], 1) if agg['avg_noise'] else None,
            'parking': round(agg['avg_parking'], 1) if agg['avg_parking'] else None,
            'shops': round(agg['avg_shops'], 1) if agg['avg_shops'] else None,
            'safety': round(agg['avg_safety'], 1) if agg['avg_safety'] else None,
            'schools': round(agg['avg_schools'], 1) if agg['avg_schools'] else None,
            'transport': round(agg['avg_transport'], 1) if agg['avg_transport'] else None,
        },
    })


# ── #41 "For Sale" Board Ordering ────────────────────────────────

BOARD_PRICES = {
    'standard': Decimal('29.99'),
    'premium': Decimal('49.99'),
    'solar_lit': Decimal('79.99'),
}


class BoardOrderViewSet(viewsets.ModelViewSet):
    """CRUD for board orders."""
    serializer_class = BoardOrderSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return BoardOrder.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        prop = serializer.validated_data['property']
        if prop.owner != self.request.user:
            raise PermissionDenied('Only the property owner can order boards.')
        board_type = serializer.validated_data.get('board_type', 'standard')
        price = BOARD_PRICES.get(board_type, BOARD_PRICES['standard'])
        serializer.save(user=self.request.user, price=price)


@api_view(['GET'])
@permission_classes([permissions.AllowAny])
def board_pricing(request):
    """Return board pricing options."""
    return Response({
        'boards': [
            {
                'type': 'standard',
                'name': 'Standard Board',
                'price': float(BOARD_PRICES['standard']),
                'description': 'Professional "For Sale" board with property details and website URL.',
            },
            {
                'type': 'premium',
                'name': 'Premium Board with QR Code',
                'price': float(BOARD_PRICES['premium']),
                'description': 'Premium board with QR code linking directly to your listing.',
            },
            {
                'type': 'solar_lit',
                'name': 'Solar-Lit Board',
                'price': float(BOARD_PRICES['solar_lit']),
                'description': 'Solar-powered illuminated board visible day and night.',
            },
        ],
    })


# ── #42 EPC Energy Improvement Suggestions ───────────────────────

EPC_IMPROVEMENTS = {
    'G': [
        {'improvement': 'Loft insulation (270mm)', 'estimated_cost': '£300-£500', 'annual_saving': '£150-£250', 'rating_improvement': '+5-10'},
        {'improvement': 'Cavity wall insulation', 'estimated_cost': '£500-£1,500', 'annual_saving': '£100-£200', 'rating_improvement': '+5-10'},
        {'improvement': 'Draught-proofing', 'estimated_cost': '£100-£300', 'annual_saving': '£25-£50', 'rating_improvement': '+1-3'},
        {'improvement': 'Upgrade boiler to A-rated condensing', 'estimated_cost': '£2,000-£3,500', 'annual_saving': '£200-£350', 'rating_improvement': '+10-15'},
        {'improvement': 'Double glazing', 'estimated_cost': '£3,000-£7,000', 'annual_saving': '£75-£150', 'rating_improvement': '+3-5'},
        {'improvement': 'Solar panels (4kW)', 'estimated_cost': '£5,000-£8,000', 'annual_saving': '£300-£500', 'rating_improvement': '+10-15'},
    ],
    'F': [
        {'improvement': 'Loft insulation top-up', 'estimated_cost': '£200-£400', 'annual_saving': '£100-£150', 'rating_improvement': '+3-5'},
        {'improvement': 'Cavity wall insulation', 'estimated_cost': '£500-£1,500', 'annual_saving': '£100-£200', 'rating_improvement': '+5-10'},
        {'improvement': 'Upgrade boiler to A-rated condensing', 'estimated_cost': '£2,000-£3,500', 'annual_saving': '£200-£350', 'rating_improvement': '+10-15'},
        {'improvement': 'Smart heating controls', 'estimated_cost': '£200-£400', 'annual_saving': '£75-£125', 'rating_improvement': '+2-4'},
        {'improvement': 'Solar panels (4kW)', 'estimated_cost': '£5,000-£8,000', 'annual_saving': '£300-£500', 'rating_improvement': '+10-15'},
    ],
    'E': [
        {'improvement': 'Upgrade boiler to A-rated condensing', 'estimated_cost': '£2,000-£3,500', 'annual_saving': '£150-£250', 'rating_improvement': '+8-12'},
        {'improvement': 'Smart heating controls', 'estimated_cost': '£200-£400', 'annual_saving': '£75-£125', 'rating_improvement': '+2-4'},
        {'improvement': 'Solar panels (4kW)', 'estimated_cost': '£5,000-£8,000', 'annual_saving': '£300-£500', 'rating_improvement': '+10-15'},
        {'improvement': 'External wall insulation', 'estimated_cost': '£8,000-£15,000', 'annual_saving': '£200-£400', 'rating_improvement': '+10-15'},
    ],
    'D': [
        {'improvement': 'Solar panels (4kW)', 'estimated_cost': '£5,000-£8,000', 'annual_saving': '£300-£500', 'rating_improvement': '+10-15'},
        {'improvement': 'Heat pump (air source)', 'estimated_cost': '£7,000-£14,000', 'annual_saving': '£200-£400', 'rating_improvement': '+10-20'},
        {'improvement': 'Smart heating controls', 'estimated_cost': '£200-£400', 'annual_saving': '£50-£100', 'rating_improvement': '+2-3'},
        {'improvement': 'LED lighting throughout', 'estimated_cost': '£100-£300', 'annual_saving': '£30-£60', 'rating_improvement': '+1-2'},
    ],
    'C': [
        {'improvement': 'Solar panels (4kW)', 'estimated_cost': '£5,000-£8,000', 'annual_saving': '£300-£500', 'rating_improvement': '+5-10'},
        {'improvement': 'Heat pump (air source)', 'estimated_cost': '£7,000-£14,000', 'annual_saving': '£200-£400', 'rating_improvement': '+5-10'},
        {'improvement': 'Battery storage', 'estimated_cost': '£3,000-£6,000', 'annual_saving': '£150-£300', 'rating_improvement': '+2-5'},
    ],
    'B': [
        {'improvement': 'Solar panels (if not already fitted)', 'estimated_cost': '£5,000-£8,000', 'annual_saving': '£300-£500', 'rating_improvement': '+3-5'},
        {'improvement': 'Battery storage', 'estimated_cost': '£3,000-£6,000', 'annual_saving': '£150-£300', 'rating_improvement': '+1-3'},
    ],
}


@api_view(['GET'])
@permission_classes([permissions.AllowAny])
def epc_improvement_suggestions(request, property_pk):
    """Suggest energy improvements based on EPC rating."""
    prop = get_object_or_404(Property, pk=property_pk)

    if not prop.epc_rating:
        return Response({
            'error': 'This property has no EPC rating set.',
            'suggestion': 'Add your EPC rating to receive improvement suggestions.',
        }, status=400)

    if prop.epc_rating == 'A':
        return Response({
            'epc_rating': 'A',
            'message': 'This property already has the highest EPC rating. No improvements needed.',
            'improvements': [],
        })

    improvements = EPC_IMPROVEMENTS.get(prop.epc_rating, [])

    # Find relevant service providers on the platform
    related_categories = ServiceCategory.objects.filter(
        slug__in=['epc', 'insulation', 'solar', 'boiler', 'heating', 'electrician']
    )
    postcode_prefix = prop.postcode.split()[0] if ' ' in prop.postcode else prop.postcode[:3]
    local_providers = ServiceProvider.objects.filter(
        status='active',
        categories__in=related_categories,
    ).filter(
        Q(coverage_postcodes__icontains=postcode_prefix) |
        Q(coverage_counties__icontains=prop.county)
    ).distinct()[:5]

    provider_data = [
        {
            'id': p.pk,
            'business_name': p.business_name,
            'slug': p.slug,
            'average_rating': p.average_rating,
        }
        for p in local_providers
    ]

    return Response({
        'epc_rating': prop.epc_rating,
        'improvements': improvements,
        'local_service_providers': provider_data,
    })


# ── #43 Buyer Affordability Profile ──────────────────────────────

@api_view(['GET', 'PUT', 'PATCH'])
@permission_classes([permissions.IsAuthenticated])
def buyer_profile_view(request):
    """Get or update the buyer's affordability profile."""
    profile, created = BuyerProfile.objects.get_or_create(user=request.user)

    if request.method == 'GET':
        return Response(BuyerProfileSerializer(profile).data)

    serializer = BuyerProfileSerializer(profile, data=request.data, partial=True)
    serializer.is_valid(raise_exception=True)
    serializer.save()
    return Response(serializer.data)


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def affordable_properties(request):
    """Return properties within the buyer's budget."""
    try:
        profile = request.user.buyer_profile
    except BuyerProfile.DoesNotExist:
        return Response(
            {'error': 'Please set up your buyer profile first.'},
            status=400,
        )

    if not profile.max_budget:
        return Response(
            {'error': 'Please set your maximum budget in your buyer profile.'},
            status=400,
        )

    queryset = Property.objects.filter(
        status='active',
        price__lte=profile.max_budget,
    )

    # Filter by preferred areas
    if profile.preferred_areas:
        areas = [a.strip() for a in profile.preferred_areas.split(',') if a.strip()]
        if areas:
            area_q = Q()
            for area in areas:
                area_q |= Q(city__icontains=area) | Q(postcode__istartswith=area.upper())
            queryset = queryset.filter(area_q)

    queryset = queryset.order_by('-created_at')[:20]
    serializer = PropertyListSerializer(
        queryset, many=True, context={'request': request}
    )
    return Response(serializer.data)


# ── #44 Two-Factor Authentication ────────────────────────────────

@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def setup_2fa(request):
    """Generate a TOTP secret and provisioning URI for 2FA setup."""
    import secrets
    import base64
    import hmac
    import struct
    import time as time_module

    user = request.user
    if user.two_fa_enabled:
        return Response({'error': '2FA is already enabled.'}, status=400)

    # Generate a random secret
    secret_bytes = secrets.token_bytes(20)
    secret = base64.b32encode(secret_bytes).decode('utf-8').rstrip('=')

    user.two_fa_secret = secret
    user.save(update_fields=['two_fa_secret'])

    # Build otpauth URI
    issuer = 'ForSaleByOwner'
    provisioning_uri = (
        f'otpauth://totp/{issuer}:{user.email}'
        f'?secret={secret}&issuer={issuer}&digits=6&period=30'
    )

    return Response({
        'secret': secret,
        'provisioning_uri': provisioning_uri,
        'message': 'Scan the QR code with your authenticator app, then confirm with /api/2fa/confirm/',
    })


def _generate_totp(secret, time_step=30):
    """Generate a TOTP code from a base32 secret."""
    import base64
    import hmac
    import hashlib
    import struct
    import time as time_module

    # Pad the secret if needed
    padding = 8 - (len(secret) % 8)
    if padding != 8:
        secret += '=' * padding

    key = base64.b32decode(secret.upper())
    counter = int(time_module.time()) // time_step
    counter_bytes = struct.pack('>Q', counter)
    hmac_hash = hmac.new(key, counter_bytes, hashlib.sha1).digest()
    offset = hmac_hash[-1] & 0x0F
    code = struct.unpack('>I', hmac_hash[offset:offset + 4])[0]
    code = (code & 0x7FFFFFFF) % 1000000
    return f'{code:06d}'


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def confirm_2fa(request):
    """Confirm 2FA setup with a TOTP code."""
    user = request.user
    code = request.data.get('code', '')

    if not user.two_fa_secret:
        return Response({'error': 'Please set up 2FA first via /api/2fa/setup/'}, status=400)

    expected = _generate_totp(user.two_fa_secret)
    if code != expected:
        return Response({'error': 'Invalid code. Please try again.'}, status=400)

    user.two_fa_enabled = True
    user.save(update_fields=['two_fa_enabled'])

    return Response({'message': '2FA has been successfully enabled.'})


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def disable_2fa(request):
    """Disable 2FA for the current user."""
    user = request.user
    code = request.data.get('code', '')

    if not user.two_fa_enabled:
        return Response({'error': '2FA is not enabled.'}, status=400)

    expected = _generate_totp(user.two_fa_secret)
    if code != expected:
        return Response({'error': 'Invalid code.'}, status=400)

    user.two_fa_enabled = False
    user.two_fa_secret = ''
    user.save(update_fields=['two_fa_enabled', 'two_fa_secret'])

    return Response({'message': '2FA has been disabled.'})


@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def verify_2fa(request):
    """Verify a 2FA code during login."""
    from django.contrib.auth import get_user_model
    User = get_user_model()

    email = request.data.get('email', '')
    code = request.data.get('code', '')

    try:
        user = User.objects.get(email=email)
    except User.DoesNotExist:
        return Response({'error': 'Invalid credentials.'}, status=400)

    if not user.two_fa_enabled:
        return Response({'error': '2FA is not enabled for this account.'}, status=400)

    expected = _generate_totp(user.two_fa_secret)
    if code != expected:
        return Response({'error': 'Invalid 2FA code.'}, status=400)

    # Generate or retrieve token
    from rest_framework.authtoken.models import Token
    token, _ = Token.objects.get_or_create(user=user)

    return Response({
        'auth_token': token.key,
        'message': '2FA verified successfully.',
    })


# ── #45 Community Forum ──────────────────────────────────────────

class ForumCategoryViewSet(viewsets.ReadOnlyModelViewSet):
    """List forum categories."""
    serializer_class = ForumCategorySerializer
    permission_classes = [permissions.AllowAny]
    queryset = ForumCategory.objects.all()


class ForumTopicViewSet(viewsets.ModelViewSet):
    """CRUD for forum topics."""

    def get_serializer_class(self):
        if self.action == 'retrieve':
            return ForumTopicDetailSerializer
        return ForumTopicSerializer

    def get_permissions(self):
        if self.action in ['list', 'retrieve']:
            return [permissions.AllowAny()]
        return [permissions.IsAuthenticated()]

    def get_queryset(self):
        qs = ForumTopic.objects.select_related('category', 'author')
        category_slug = self.request.query_params.get('category')
        if category_slug:
            qs = qs.filter(category__slug=category_slug)
        search = self.request.query_params.get('search')
        if search:
            qs = qs.filter(Q(title__icontains=search) | Q(content__icontains=search))
        return qs

    def perform_create(self, serializer):
        serializer.save(author=self.request.user)

    def retrieve(self, request, *args, **kwargs):
        instance = self.get_object()
        # Increment view count
        ForumTopic.objects.filter(pk=instance.pk).update(view_count=F('view_count') + 1)
        instance.refresh_from_db()
        serializer = self.get_serializer(instance)
        return Response(serializer.data)


class ForumPostViewSet(viewsets.ModelViewSet):
    """CRUD for forum posts (replies to topics)."""
    serializer_class = ForumPostSerializer

    def get_permissions(self):
        if self.action in ['list', 'retrieve']:
            return [permissions.AllowAny()]
        return [permissions.IsAuthenticated()]

    def get_queryset(self):
        topic_pk = self.kwargs.get('topic_pk')
        if topic_pk:
            return ForumPost.objects.filter(topic_id=topic_pk)
        return ForumPost.objects.all()

    def perform_create(self, serializer):
        topic_pk = self.kwargs.get('topic_pk')
        topic = get_object_or_404(ForumTopic, pk=topic_pk)
        if topic.is_locked:
            raise PermissionDenied('This topic is locked.')
        serializer.save(author=self.request.user, topic=topic)

    def perform_destroy(self, instance):
        if instance.author != self.request.user:
            raise PermissionDenied()
        instance.delete()


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def mark_solution(request, post_pk):
    """Mark a forum post as the solution (by topic author only)."""
    post = get_object_or_404(ForumPost, pk=post_pk)
    if post.topic.author != request.user:
        raise PermissionDenied('Only the topic author can mark a solution.')
    # Unmark any existing solution
    ForumPost.objects.filter(topic=post.topic, is_solution=True).update(is_solution=False)
    post.is_solution = True
    post.save(update_fields=['is_solution'])
    return Response(ForumPostSerializer(post).data)
