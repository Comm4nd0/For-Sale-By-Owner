import logging
import requests
from decimal import Decimal

from django.db.models import Q, Count

logger = logging.getLogger(__name__)
from rest_framework import viewsets, permissions, status, generics
from rest_framework.decorators import api_view, permission_classes, action
from django.shortcuts import get_object_or_404
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.response import Response
from rest_framework.throttling import UserRateThrottle
from django.conf import settings
from django.views.decorators.csrf import csrf_exempt

from .models import (
    Property, PropertyImage, PropertyFloorplan, PropertyFeature,
    PriceHistory, SavedProperty, Enquiry, PropertyView,
    ViewingRequest, SavedSearch, PushNotificationDevice, Reply,
    ServiceCategory, ServiceProvider, ServiceProviderReview,
    SubscriptionTier, SubscriptionAddOn, ServiceProviderSubscription,
    ServiceProviderPhoto,
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
)
from .notifications import notify_new_enquiry, notify_viewing_request, notify_reply


class EnquiryRateThrottle(UserRateThrottle):
    rate = '10/hour'


class IsOwnerOrReadOnly(permissions.BasePermission):
    """Allow read access to anyone, write access only to the property owner."""

    def has_object_permission(self, request, view, obj):
        if request.method in permissions.SAFE_METHODS:
            return True
        return obj.owner == request.user


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
        queryset = Property.objects.all().select_related('owner').prefetch_related('images')
        status_filter = self.request.query_params.get('status')
        property_type = self.request.query_params.get('property_type')
        city = self.request.query_params.get('city')

        if not self.request.user.is_authenticated:
            queryset = queryset.filter(status='active')
        elif self.request.query_params.get('mine') == 'true':
            # Only show the current user's own properties
            queryset = queryset.filter(owner=self.request.user)
        else:
            # Authenticated users see active + their own
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

        return queryset

    def perform_create(self, serializer):
        instance = serializer.save(owner=self.request.user)
        # Record initial price in history
        PriceHistory.objects.create(property=instance, price=instance.price)

    def perform_update(self, serializer):
        old_price = serializer.instance.price
        instance = serializer.save()
        # Track price change
        if instance.price != old_price:
            PriceHistory.objects.create(property=instance, price=instance.price)

    def retrieve(self, request, *args, **kwargs):
        instance = self.get_object()
        # Track view (non-critical, should not block response)
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
        serializer.save(property=property_obj)

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
        # Users can see enquiries they sent or received (as property owner)
        return Enquiry.objects.filter(
            Q(sender=user) | Q(property__owner=user)
        ).select_related('property', 'sender').prefetch_related('replies__author')

    def perform_create(self, serializer):
        prop = serializer.validated_data['property']
        if prop.owner == self.request.user:
            raise ValidationError("You cannot enquire about your own property.")
        # Force is_read=False on create so sender can't mark their own enquiry as read
        enquiry = serializer.save(sender=self.request.user, is_read=False)
        notify_new_enquiry(enquiry)

    def perform_update(self, serializer):
        # Only property owner can mark as read
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
        # Auto-mark as read when owner replies
        if user == enquiry.property.owner and not enquiry.is_read:
            enquiry.is_read = True
            enquiry.save(update_fields=['is_read'])
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
        notify_viewing_request(viewing)

    def perform_update(self, serializer):
        instance = serializer.instance
        # Only property owner can update status/seller_notes
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
        """Post a reply to a viewing request. Both requester and property owner can reply."""
        viewing = self.get_object()
        user = request.user
        if user != viewing.requester and user != viewing.property.owner:
            raise PermissionDenied("You are not a participant in this conversation.")
        message = request.data.get('message', '').strip()
        if not message:
            raise ValidationError("Message cannot be empty.")
        reply_obj = Reply.objects.create(viewing_request=viewing, author=user, message=message)
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


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def dashboard_stats(request):
    """Get seller dashboard statistics."""
    user = request.user
    properties = Property.objects.filter(owner=user)
    total_views = PropertyView.objects.filter(property__owner=user).count()
    total_enquiries = Enquiry.objects.filter(property__owner=user).count()
    unread_enquiries = Enquiry.objects.filter(property__owner=user, is_read=False).count()
    total_saves = SavedProperty.objects.filter(property__owner=user).count()

    pending_viewings = ViewingRequest.objects.filter(property__owner=user, status='pending').count()

    data = {
        'total_listings': properties.count(),
        'active_listings': properties.filter(status='active').count(),
        'total_views': total_views,
        'total_enquiries': total_enquiries,
        'unread_enquiries': unread_enquiries,
        'pending_viewings': pending_viewings,
        'total_saves': total_saves,
    }
    return Response(data)


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def notification_counts(request):
    """Lightweight endpoint for nav bell badge — returns unread/pending counts."""
    user = request.user
    unread = Enquiry.objects.filter(property__owner=user, is_read=False).count()
    pending = ViewingRequest.objects.filter(property__owner=user, status='pending').count()
    return Response({'unread_enquiries': unread, 'pending_viewings': pending, 'total': unread + pending})


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
        """Use multipart for create/update (file uploads), JSON for other actions."""
        if self.action in ['create', 'update', 'partial_update']:
            return [MultiPartParser(), FormParser()]
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

        # Tier-priority ordering: Pro > Growth > Free for public listings
        if self.action == 'list' and not self.request.query_params.get('mine'):
            from django.db.models import Case, When, Value, IntegerField, Subquery, OuterRef
            tier_slug = Subquery(
                ServiceProviderSubscription.objects.filter(
                    provider=OuterRef('pk'), status='active',
                ).order_by('-started_at').values('tier__slug')[:1]
            )
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
        # Auto-assign free tier subscription
        free_tier = SubscriptionTier.objects.filter(slug='free', is_active=True).first()
        if free_tier:
            ServiceProviderSubscription.objects.create(
                provider=provider, tier=free_tier,
                billing_cycle='monthly', status='active',
            )

    def perform_update(self, serializer):
        instance = serializer.instance
        tier = instance.current_tier

        # Enforce category limit
        new_categories = serializer.validated_data.get('categories')
        if new_categories is not None and tier:
            max_cats = tier.max_service_categories
            if max_cats != -1 and len(new_categories) > max_cats:
                raise ValidationError(
                    f"Your {tier.name} plan allows a maximum of {max_cats} "
                    f"categor{'y' if max_cats == 1 else 'ies'}. Upgrade your plan for more."
                )

        # Enforce logo restriction
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

    # Tier-priority ordering
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
            'locations_used': 1,  # Simple count — expand as location model grows
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

    # Get or create Stripe customer
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
    """Create a Stripe Billing Portal session so the provider can manage billing."""
    import stripe
    stripe.api_key = settings.STRIPE_SECRET_KEY

    try:
        provider = ServiceProvider.objects.get(owner=request.user)
    except ServiceProvider.DoesNotExist:
        return Response({'detail': 'No service provider profile found.'}, status=status.HTTP_404_NOT_FOUND)

    if not provider.stripe_customer_id:
        return Response({'detail': 'No billing account found. Subscribe to a plan first.'}, status=status.HTTP_400_BAD_REQUEST)

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
    from django.utils import timezone
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

    # Retrieve Stripe subscription for period dates
    stripe.api_key = settings.STRIPE_SECRET_KEY
    stripe_sub = stripe.Subscription.retrieve(stripe_sub_id)

    # Cancel existing active subscriptions (except free)
    provider.subscriptions.filter(status='active').exclude(tier__slug='free').update(
        status='cancelled', cancelled_at=timezone.now()
    )
    # Also deactivate any free tier subscription
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

    # Ensure provider has customer ID saved
    if customer_id and not provider.stripe_customer_id:
        provider.stripe_customer_id = customer_id
        provider.save(update_fields=['stripe_customer_id'])

    logger.info('Subscription created: provider=%s tier=%s', provider.id, tier.slug)


def _handle_subscription_updated(sub_data):
    """Handle Stripe subscription updated event."""
    from django.utils import timezone

    stripe_sub_id = sub_data.get('id')
    try:
        sub = ServiceProviderSubscription.objects.get(stripe_subscription_id=stripe_sub_id)
    except ServiceProviderSubscription.DoesNotExist:
        logger.warning('Subscription not found for update: %s', stripe_sub_id)
        return

    # Update status
    stripe_status = sub_data.get('status')
    status_map = {
        'active': 'active',
        'past_due': 'past_due',
        'canceled': 'cancelled',
        'unpaid': 'past_due',
    }
    sub.status = status_map.get(stripe_status, sub.status)
    sub.cancel_at_period_end = sub_data.get('cancel_at_period_end', False)

    # Update period dates
    if sub_data.get('current_period_start'):
        sub.current_period_start = timezone.datetime.fromtimestamp(
            sub_data['current_period_start'], tz=timezone.utc
        )
    if sub_data.get('current_period_end'):
        sub.current_period_end = timezone.datetime.fromtimestamp(
            sub_data['current_period_end'], tz=timezone.utc
        )

    # Check if tier changed (plan change)
    items = sub_data.get('items', {}).get('data', [])
    if items:
        price_id = items[0].get('price', {}).get('id', '')
        new_tier = SubscriptionTier.objects.filter(
            Q(stripe_monthly_price_id=price_id) | Q(stripe_annual_price_id=price_id)
        ).first()
        if new_tier and new_tier != sub.tier:
            sub.tier = new_tier
            # Update billing cycle
            interval = items[0].get('price', {}).get('recurring', {}).get('interval', '')
            sub.billing_cycle = 'annual' if interval == 'year' else 'monthly'

    sub.save()
    logger.info('Subscription updated: %s status=%s', stripe_sub_id, sub.status)


def _handle_subscription_deleted(sub_data):
    """Handle Stripe subscription cancelled/deleted."""
    from django.utils import timezone

    stripe_sub_id = sub_data.get('id')
    try:
        sub = ServiceProviderSubscription.objects.get(stripe_subscription_id=stripe_sub_id)
    except ServiceProviderSubscription.DoesNotExist:
        return

    sub.status = 'cancelled'
    sub.cancelled_at = timezone.now()
    sub.save(update_fields=['status', 'cancelled_at'])

    # Auto-assign free tier
    provider = sub.provider
    free_tier = SubscriptionTier.objects.filter(slug='free', is_active=True).first()
    if free_tier and not provider.subscriptions.filter(status='active').exists():
        ServiceProviderSubscription.objects.create(
            provider=provider, tier=free_tier,
            billing_cycle='monthly', status='active',
        )

    logger.info('Subscription cancelled, free tier assigned: provider=%s', provider.id)


def _handle_payment_failed(invoice_data):
    """Handle failed payment — set subscription to past_due."""
    stripe_sub_id = invoice_data.get('subscription')
    if not stripe_sub_id:
        return
    ServiceProviderSubscription.objects.filter(
        stripe_subscription_id=stripe_sub_id
    ).update(status='past_due')
    logger.warning('Payment failed for subscription: %s', stripe_sub_id)


def _handle_invoice_paid(invoice_data):
    """Handle successful invoice payment — reactivate subscription."""
    from django.utils import timezone

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
    """Proxy Land Registry Price Paid Data API to avoid browser CORS/fetch issues."""
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
