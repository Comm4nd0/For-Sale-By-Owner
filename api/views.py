import logging
import math
import requests
from collections import defaultdict
from datetime import timedelta
from decimal import Decimal

from django.db.models import Q, Count, Sum, Avg, F
from django.utils import timezone

logger = logging.getLogger(__name__)
from rest_framework import viewsets, permissions, status, generics
from rest_framework.decorators import api_view, permission_classes, action
from django.shortcuts import get_object_or_404
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework.response import Response
from rest_framework.throttling import UserRateThrottle
from django.conf import settings
from django.views.decorators.csrf import csrf_exempt
from django.core.cache import cache

from .models import (
    Property, PropertyImage, PropertyFloorplan, PropertyFeature,
    PriceHistory, SavedProperty, Enquiry, PropertyView,
    ViewingRequest, SavedSearch, PushNotificationDevice, Reply,
    ServiceCategory, ServiceProvider, ServiceProviderReview,
    SubscriptionTier, SubscriptionAddOn, ServiceProviderSubscription,
    ServiceProviderPhoto,
    ChatRoom, ChatMessage,
    ViewingSlot, ViewingSlotBooking,
    Offer, PropertyDocument, PropertyFlag, Referral,
)
from .serializers import (
    PropertySerializer, PropertyListSerializer, PropertyImageSerializer,
    PropertyFloorplanSerializer, PropertyFeatureSerializer,
    SavedPropertySerializer, EnquirySerializer, DashboardStatsSerializer,
    ViewingRequestSerializer, SavedSearchSerializer, UserProfileSerializer,
    ReplySerializer,
    ServiceCategorySerializer, ServiceProviderListSerializer,
    ServiceProviderDetailSerializer, ServiceProviderReviewSerializer,
    SubscriptionTierSerializer, SubscriptionAddOnSerializer,
    ServiceProviderSubscriptionSerializer, ServiceProviderPhotoSerializer,
    ChatRoomSerializer, ChatMessageSerializer,
    ViewingSlotSerializer,
    OfferSerializer, PropertyDocumentSerializer,
    PropertyFlagSerializer, ReferralSerializer,
)


class EnquiryRateThrottle(UserRateThrottle):
    rate = '10/hour'


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


class EnquiryViewSet(viewsets.ModelViewSet):
    serializer_class = EnquirySerializer
    permission_classes = [permissions.IsAuthenticated]
    http_method_names = ['get', 'post', 'patch']

    def get_throttles(self):
        if self.action == 'create':
            return [EnquiryRateThrottle()]
        return []

    def get_queryset(self):
        user = self.request.user
        return Enquiry.objects.filter(
            Q(sender=user) | Q(property__owner=user)
        ).select_related('property', 'sender').prefetch_related('replies__author')

    def perform_create(self, serializer):
        prop = serializer.validated_data['property']
        if prop.owner == self.request.user:
            raise ValidationError("You cannot enquire about your own property.")
        enquiry = serializer.save(sender=self.request.user, is_read=False)
        # Use async task instead of blocking
        try:
            from .tasks import send_enquiry_notification
            send_enquiry_notification.delay(enquiry.id)
        except Exception:
            from .notifications import notify_new_enquiry
            notify_new_enquiry(enquiry)

    def perform_update(self, serializer):
        if serializer.instance.property.owner != self.request.user:
            raise PermissionDenied()
        serializer.save()

    @action(detail=False, methods=['get'])
    def received(self, request):
        """Get enquiries received for the user's properties."""
        qs = Enquiry.objects.filter(
            property__owner=request.user
        ).select_related('property', 'sender').prefetch_related('replies__author').order_by('-created_at')
        page = self.paginate_queryset(qs)
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)
        serializer = self.get_serializer(qs, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def reply(self, request, pk=None):
        """Post a reply to an enquiry. Both sender and property owner can reply."""
        enquiry = self.get_object()
        user = request.user
        if user != enquiry.sender and user != enquiry.property.owner:
            raise PermissionDenied("You are not a participant in this conversation.")
        message = request.data.get('message', '').strip()
        if not message:
            raise ValidationError("Message cannot be empty.")
        reply_obj = Reply.objects.create(enquiry=enquiry, author=user, message=message)
        if user == enquiry.property.owner and not enquiry.is_read:
            enquiry.is_read = True
            enquiry.save(update_fields=['is_read'])
        try:
            from .tasks import send_reply_notification
            send_reply_notification.delay(reply_obj.id)
        except Exception:
            from .notifications import notify_reply
            notify_reply(reply_obj)
        return Response(ReplySerializer(reply_obj).data, status=status.HTTP_201_CREATED)


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
        viewing = serializer.save(requester=self.request.user)
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
    total_enquiries = Enquiry.objects.filter(property__owner=user).count()
    unread_enquiries = Enquiry.objects.filter(property__owner=user, is_read=False).count()
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

    # Enquiry conversion rate (enquiries / views)
    enquiry_rate = round((total_enquiries / total_views * 100), 1) if total_views > 0 else 0

    # Per-property stats
    property_stats = []
    for prop in properties:
        prop_views = prop.views.count()
        prop_enquiries = prop.enquiries.count()
        has_floorplan = prop.floorplans.exists()
        image_count = prop.images.count()
        tips = []
        if image_count < 5:
            tips.append(f'Add more photos ({image_count}/10). Listings with 5+ photos get 40% more enquiries.')
        if not has_floorplan:
            tips.append('Add a floorplan. Listings with floorplans get 30% more enquiries.')
        if not prop.description or len(prop.description) < 100:
            tips.append('Write a longer description (100+ chars) to attract more interest.')
        if not prop.video_url:
            tips.append('Add a virtual tour video to stand out from other listings.')

        property_stats.append({
            'id': prop.id,
            'title': prop.title,
            'status': prop.status,
            'views': prop_views,
            'enquiries': prop_enquiries,
            'saves': prop.saved_by.count(),
            'offers': prop.offers.count(),
            'conversion_rate': round((prop_enquiries / prop_views * 100), 1) if prop_views > 0 else 0,
            'tips': tips,
        })

    data = {
        'total_listings': properties.count(),
        'active_listings': properties.filter(status='active').count(),
        'total_views': total_views,
        'total_enquiries': total_enquiries,
        'unread_enquiries': unread_enquiries,
        'pending_viewings': pending_viewings,
        'total_saves': total_saves,
        'total_offers': total_offers,
        'pending_offers': pending_offers,
        'enquiry_conversion_rate': enquiry_rate,
        'views_by_day': list(views_by_day),
        'property_stats': property_stats,
    }
    return Response(data)


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def notification_counts(request):
    """Lightweight endpoint for nav bell badge — returns unread/pending counts."""
    user = request.user
    unread = Enquiry.objects.filter(property__owner=user, is_read=False).count()
    pending = ViewingRequest.objects.filter(property__owner=user, status='pending').count()
    unread_chats = ChatMessage.objects.filter(
        room__in=ChatRoom.objects.filter(Q(buyer=user) | Q(seller=user)),
        is_read=False,
    ).exclude(sender=user).count()
    pending_offers = Offer.objects.filter(property__owner=user, status='submitted').count()
    total = unread + pending + unread_chats + pending_offers
    return Response({
        'unread_enquiries': unread,
        'pending_viewings': pending,
        'unread_chats': unread_chats,
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
        serializer = self.get_serializer(room)
        return Response(serializer.data, status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)


class ChatMessageViewSet(viewsets.ModelViewSet):
    """Messages within a chat room."""
    serializer_class = ChatMessageSerializer
    permission_classes = [permissions.IsAuthenticated]
    http_method_names = ['get', 'post']

    def get_queryset(self):
        room = get_object_or_404(ChatRoom, pk=self.kwargs['room_pk'])
        user = self.request.user
        if user != room.buyer and user != room.seller:
            raise PermissionDenied()
        return ChatMessage.objects.filter(room=room).select_related('sender')

    def perform_create(self, serializer):
        room = get_object_or_404(ChatRoom, pk=self.kwargs['room_pk'])
        user = self.request.user
        if user != room.buyer and user != room.seller:
            raise PermissionDenied()
        serializer.save(room=room, sender=user)
        room.save(update_fields=['updated_at'])


# ── Viewing Slots ────────────────────────────────────────────────

class ViewingSlotViewSet(viewsets.ModelViewSet):
    """Manage viewing availability slots."""
    serializer_class = ViewingSlotSerializer
    permission_classes = [permissions.IsAuthenticated]

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


# ── Referrals ────────────────────────────────────────────────────

@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def my_referrals(request):
    """Get the user's referral code and referral history."""
    user = request.user
    referrals = Referral.objects.filter(referrer=user).select_related('referred_user')
    return Response({
        'referral_code': user.referral_code,
        'total_referrals': referrals.count(),
        'referrals': ReferralSerializer(referrals, many=True).data,
    })


@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def apply_referral(request):
    """Apply a referral code during registration."""
    code = request.data.get('referral_code', '').strip().upper()
    user_id = request.data.get('user_id')

    if not code or not user_id:
        return Response({'detail': 'referral_code and user_id are required.'}, status=status.HTTP_400_BAD_REQUEST)

    from django.contrib.auth import get_user_model
    User = get_user_model()
    try:
        referrer = User.objects.get(referral_code=code)
        referred = User.objects.get(pk=user_id)
    except User.DoesNotExist:
        return Response({'detail': 'Invalid referral code or user.'}, status=status.HTTP_404_NOT_FOUND)

    if referrer == referred:
        return Response({'detail': 'Cannot refer yourself.'}, status=status.HTTP_400_BAD_REQUEST)
    if Referral.objects.filter(referred_user=referred).exists():
        return Response({'detail': 'This user was already referred.'}, status=status.HTTP_400_BAD_REQUEST)

    Referral.objects.create(referrer=referrer, referred_user=referred)
    return Response({'status': 'ok', 'referrer': referrer.email})


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

    def get_parsers(self):
        if self.action in ['create', 'update', 'partial_update']:
            return [MultiPartParser(), FormParser(), JSONParser()]
        return super().get_parsers()

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

    ServiceProviderSubscription.objects.create(
        provider=provider,
        tier=tier,
        billing_cycle=billing_cycle,
        status='active',
        stripe_subscription_id=stripe_sub_id,
        stripe_customer_id=customer_id,
        current_period_start=timezone.datetime.fromtimestamp(
            stripe_sub.current_period_start, tz=timezone.utc
        ),
        current_period_end=timezone.datetime.fromtimestamp(
            stripe_sub.current_period_end, tz=timezone.utc
        ),
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
