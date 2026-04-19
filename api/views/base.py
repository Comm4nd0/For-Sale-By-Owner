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


class IsServiceProviderOwnerOrReadOnly(permissions.BasePermission):
    def has_object_permission(self, request, view, obj):
        if request.method in permissions.SAFE_METHODS:
            return True
        if request.user.is_staff:
            return True
        return obj.owner == request.user


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
