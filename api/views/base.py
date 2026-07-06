"""Shared permission classes, throttles and helpers used across the views package."""
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


class IsOwnerOrReadOnly(permissions.BasePermission):
    """Allow read access to anyone, write access only to the property owner."""

    def has_object_permission(self, request, view, obj):
        if request.method in permissions.SAFE_METHODS:
            return True
        return obj.owner == request.user


def count_subquery(queryset, group_by):
    """Annotation expression counting related rows without join fan-out.

    ``queryset`` must already filter on ``OuterRef``; ``group_by`` is the
    field linking back to the outer row. Unlike ``Count('relation')``
    annotations, combining several of these never multiplies rows.
    """
    from django.db.models import Count, IntegerField, Subquery
    from django.db.models.functions import Coalesce
    return Coalesce(
        Subquery(
            queryset.order_by().values(group_by).annotate(_c=Count('pk')).values('_c'),
            output_field=IntegerField(),
        ),
        0,
    )


def haversine_distance(lat1, lon1, lat2, lon2):
    """Calculate distance in miles between two lat/lon points."""
    R = 3959  # Earth radius in miles
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (math.sin(dlat / 2) ** 2 +
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
         math.sin(dlon / 2) ** 2)
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def _calculate_stamp_duty(price, buyer_type='standard'):
    """Calculate stamp duty based on buyer type (England/NI rates from April 2025)."""
    # First-time buyer relief: nil to £300k, 5% to £500k, none above £500k
    if buyer_type == 'first_time':
        if price <= 500000:
            if price <= 300000:
                return 0
            return (price - 300000) * 0.05
        # Falls through to standard rates if price > £500k

    # Standard bands
    duty = 0
    bands = [
        (125000, 0),
        (250000, 0.02),
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


class IsServiceProviderOwnerOrReadOnly(permissions.BasePermission):
    def has_object_permission(self, request, view, obj):
        if request.method in permissions.SAFE_METHODS:
            return True
        if request.user.is_staff:
            return True
        return obj.owner == request.user


class ExternalLookupThrottle(UserRateThrottle):
    """Throttle for endpoints that proxy external APIs (Land Registry etc.).

    Those endpoints are AllowAny and each request can trigger a slow
    outbound HTTP call, so they need a tighter, dedicated rate than the
    generic user/anon limits. Keyed by user when authenticated, IP
    otherwise.
    """
    scope = 'external_lookup'

    def get_cache_key(self, request, view):
        if request.user and request.user.is_authenticated:
            ident = str(request.user.pk)
        else:
            ident = self.get_ident(request)
        return self.cache_format % {'scope': self.scope, 'ident': ident}


class TwoFactorVerifyThrottle(UserRateThrottle):
    """Tight per-IP throttle on the 2FA verify endpoint to resist brute force.

    Uses a dedicated scope so the rate is independent of the generic
    ``user``/``anon`` throttle rates. Keyed by challenge_id when present
    so attackers can't circumvent by cycling IPs faster than the global
    anon limit would allow.
    """
    scope = 'two_factor_verify'

    def get_cache_key(self, request, view):
        challenge_id = request.data.get('challenge_id') if hasattr(request, 'data') else None
        if challenge_id:
            return self.cache_format % {
                'scope': self.scope,
                'ident': f'chal:{challenge_id}',
            }
        return super().get_cache_key(request, view)
