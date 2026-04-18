"""Dashboard, profile, notifications, health check and buyer verification/profile."""
import logging
import math
import requests
from collections import defaultdict
from datetime import timedelta
from decimal import Decimal

from django.conf import settings
from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.db.models import Q, Count, Sum, Avg, F
from django.shortcuts import get_object_or_404
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt

from rest_framework import viewsets, permissions, status, generics
from rest_framework.decorators import api_view, permission_classes, action, throttle_classes
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework.response import Response
from rest_framework.throttling import UserRateThrottle

from djoser.views import TokenCreateView as DjoserTokenCreateView

from ..models import (
    Property, PropertyImage, PropertyFloorplan, PropertyFeature,
    PriceHistory, SavedProperty, PropertyView,
    ViewingRequest, SavedSearch, PushNotificationDevice, Reply,
    ServiceCategory, ServiceProvider, ServiceProviderReview,
    SubscriptionTier, SubscriptionAddOn, ServiceProviderSubscription,
    ServiceProviderPhoto,
    ChatRoom, ChatMessage,
    ViewingSlot, ViewingSlotBooking,
    Offer, PropertyDocument, PropertyFlag,
    BuyerVerification,
    OpenHouseEvent, OpenHouseRSVP,
    ConveyancerQuoteRequest, ConveyancerQuote,
    NeighbourhoodReview, BoardOrder, BuyerProfile,
    TwoFactorChallenge,
)
from ..serializers import (
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
    OpenHouseEventSerializer, OpenHouseRSVPSerializer,
    ConveyancerQuoteRequestSerializer, ConveyancerQuoteSerializer,
    NeighbourhoodReviewSerializer, BoardOrderSerializer, BuyerProfileSerializer,
)

logger = logging.getLogger(__name__)
User = get_user_model()

from .base import (
    IsOwnerOrReadOnly, IsServiceProviderOwnerOrReadOnly,
    haversine_distance, TwoFactorVerifyThrottle,
    _calculate_stamp_duty,
)

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

    # Buyer viewing requests stats
    my_viewing_requests = ViewingRequest.objects.filter(requester=user).count()
    my_pending_viewing_requests = ViewingRequest.objects.filter(requester=user, status='pending').count()

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
        'my_viewing_requests': my_viewing_requests,
        'my_pending_viewing_requests': my_pending_viewing_requests,
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


@api_view(['GET'])
@permission_classes([permissions.AllowAny])
def health_check(request):
    """Health check endpoint for monitoring and deploy scripts.

    Returns 200 only when the database and cache are both reachable.
    A non-2xx response tells deploy.sh / monitors that the container
    should not be serving traffic yet.
    """
    checks = {}
    overall_ok = True

    # Database: a minimal round-trip confirms migrations have run and
    # the connection pool is alive.
    try:
        from django.db import connection
        with connection.cursor() as cursor:
            cursor.execute('SELECT 1')
            cursor.fetchone()
        checks['database'] = 'ok'
    except Exception as exc:
        checks['database'] = f'error: {exc.__class__.__name__}'
        overall_ok = False

    # Cache: set/get a short-lived key. Covers Redis-backed cache in
    # prod and LocMemCache under USE_SQLITE so the check doesn't lie
    # in tests.
    try:
        cache.set('health-check', '1', 5)
        if cache.get('health-check') == '1':
            checks['cache'] = 'ok'
        else:
            checks['cache'] = 'error: value mismatch'
            overall_ok = False
    except Exception as exc:
        checks['cache'] = f'error: {exc.__class__.__name__}'
        overall_ok = False

    return Response(
        {'status': 'healthy' if overall_ok else 'unhealthy', 'checks': checks},
        status=status.HTTP_200_OK if overall_ok else status.HTTP_503_SERVICE_UNAVAILABLE,
    )


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
