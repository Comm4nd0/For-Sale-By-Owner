"""TOTP-based two-factor authentication setup, verification and login gate."""
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


def _totp_matches(secret, submitted_code):
    """Constant-time comparison of a submitted TOTP code against the expected value."""
    import hmac
    if not secret or not submitted_code:
        return False
    expected = _generate_totp(secret)
    return hmac.compare_digest(str(submitted_code), expected)


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def confirm_2fa(request):
    """Confirm 2FA setup with a TOTP code."""
    user = request.user
    code = request.data.get('code', '')

    if not user.two_fa_secret:
        return Response({'error': 'Please set up 2FA first via /api/2fa/setup/'}, status=400)

    if not _totp_matches(user.two_fa_secret, code):
        return Response({'error': 'Invalid code. Please try again.'}, status=400)

    user.two_fa_enabled = True
    user.save(update_fields=['two_fa_enabled'])

    return Response({'message': '2FA has been successfully enabled.'})


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def disable_2fa(request):
    """Disable 2FA for the current user.

    Requires the user's current password in addition to a valid TOTP
    code so a stolen session token alone cannot turn 2FA off.
    """
    user = request.user
    code = request.data.get('code', '')
    password = request.data.get('password', '')

    if not user.two_fa_enabled:
        return Response({'error': '2FA is not enabled.'}, status=400)

    if not password or not user.check_password(password):
        return Response({'error': 'Password is required to disable 2FA.'}, status=400)

    if not _totp_matches(user.two_fa_secret, code):
        return Response({'error': 'Invalid code.'}, status=400)

    user.two_fa_enabled = False
    user.two_fa_secret = ''
    user.save(update_fields=['two_fa_enabled', 'two_fa_secret'])

    return Response({'message': '2FA has been disabled.'})


def _create_2fa_challenge(user):
    """Create a fresh 2FA challenge for ``user`` and return it."""
    import secrets as _secrets
    from datetime import timedelta
    from ..models import TwoFactorChallenge

    challenge = TwoFactorChallenge.objects.create(
        user=user,
        challenge_id=_secrets.token_urlsafe(32),
        expires_at=timezone.now() + timedelta(
            seconds=TwoFactorChallenge.LIFETIME_SECONDS
        ),
    )
    # Opportunistically purge stale challenges so the table doesn't grow
    # without bound.
    TwoFactorChallenge.objects.filter(
        user=user, expires_at__lt=timezone.now()
    ).delete()
    return challenge


@api_view(['POST'])
@permission_classes([permissions.AllowAny])
@throttle_classes([TwoFactorVerifyThrottle])
def verify_2fa(request):
    """Exchange a 2FA challenge_id + TOTP code for an auth token.

    Requires a challenge_id issued by a prior successful password login;
    email alone is no longer accepted. The challenge is deleted on
    success, expiry, or exhaustion of the attempt budget.
    """
    from rest_framework.authtoken.models import Token
    from ..models import TwoFactorChallenge

    challenge_id = request.data.get('challenge_id', '')
    code = request.data.get('code', '')

    if not challenge_id or not code:
        return Response(
            {'error': 'challenge_id and code are required.'},
            status=400,
        )

    try:
        challenge = TwoFactorChallenge.objects.select_related('user').get(
            challenge_id=challenge_id
        )
    except TwoFactorChallenge.DoesNotExist:
        return Response({'error': 'Invalid or expired challenge.'}, status=400)

    if challenge.is_expired():
        challenge.delete()
        return Response({'error': 'Invalid or expired challenge.'}, status=400)

    if challenge.is_exhausted():
        challenge.delete()
        return Response(
            {'error': 'Too many attempts. Please sign in again.'},
            status=429,
        )

    user = challenge.user
    if not user.two_fa_enabled:
        # The user disabled 2FA between the password step and the code
        # step — treat as an invalid challenge rather than bypassing.
        challenge.delete()
        return Response({'error': 'Invalid or expired challenge.'}, status=400)

    # Record the attempt BEFORE verifying so even a timing-successful
    # guess costs an attempt slot.
    TwoFactorChallenge.objects.filter(pk=challenge.pk).update(
        attempts=F('attempts') + 1
    )

    if not _totp_matches(user.two_fa_secret, code):
        return Response({'error': 'Invalid 2FA code.'}, status=400)

    # Success — consume the challenge and issue the token.
    challenge.delete()
    token, _ = Token.objects.get_or_create(user=user)
    return Response({'auth_token': token.key})


class TwoFactorAwareTokenCreateView(DjoserTokenCreateView):
    """Djoser login wrapper that gates on 2FA.

    If the authenticated user has ``two_fa_enabled=True`` we do not
    return an auth token; instead we create a TwoFactorChallenge and
    respond with ``{requires_2fa: true, challenge_id: ...}`` so the
    client can present the second factor at /api/2fa/verify/.
    """

    def _action(self, serializer):
        user = serializer.user
        if getattr(user, 'two_fa_enabled', False) and user.two_fa_secret:
            challenge = _create_2fa_challenge(user)
            return Response(
                {
                    'requires_2fa': True,
                    'challenge_id': challenge.challenge_id,
                    'expires_in': TwoFactorChallenge.LIFETIME_SECONDS,
                },
                status=status.HTTP_202_ACCEPTED,
            )
        return super()._action(serializer)
