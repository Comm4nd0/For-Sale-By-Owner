"""Service providers, categories, reviews, subscriptions and conveyancer quotes."""
import logging
import math
import requests
from collections import defaultdict
from datetime import timedelta
from decimal import Decimal

from django.conf import settings
from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.db import transaction
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
        if self.action == 'validate':
            return [permissions.IsAdminUser()]
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
            elif self.request.user.is_authenticated and self.request.user.is_staff:
                pass  # Staff see all services regardless of status
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
        serializer.save(owner=self.request.user)
        # Provider must choose a paid tier — no automatic subscription created

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

    @action(detail=True, methods=['post'], url_path='validate')
    def validate(self, request, pk=None):
        """Staff-only action to update a service provider's status and verification."""
        provider = self.get_object()
        new_status = request.data.get('status')
        is_verified = request.data.get('is_verified')

        if new_status is not None:
            valid_statuses = [c[0] for c in ServiceProvider.STATUS_CHOICES]
            if new_status not in valid_statuses:
                raise ValidationError(f"Invalid status. Must be one of: {', '.join(valid_statuses)}")
            provider.status = new_status

        if is_verified is not None:
            provider.is_verified = bool(is_verified)

        provider.save()
        serializer = self.get_serializer(provider)
        return Response(serializer.data)


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

    session_params = {
        'customer': customer_id,
        'mode': 'subscription',
        'line_items': [{'price': price_id, 'quantity': 1}],
        'success_url': f'{site_url}/my-service/?subscription=success',
        'cancel_url': f'{site_url}/pricing/?cancelled=true',
        'metadata': {
            'provider_id': provider.id,
            'tier_slug': tier.slug,
            'billing_cycle': billing_cycle,
        },
    }
    if tier.trial_period_days > 0:
        session_params['subscription_data'] = {
            'trial_period_days': tier.trial_period_days,
        }
    session = stripe.checkout.Session.create(**session_params)

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


@transaction.atomic
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

    # Cancel any existing active subscriptions
    provider.subscriptions.filter(status='active').update(
        status='cancelled', cancelled_at=timezone.now()
    )

    # Build trial_end from Stripe subscription data
    trial_end_ts = getattr(stripe_sub, 'trial_end', None)
    trial_end = (
        timezone.datetime.fromtimestamp(trial_end_ts, tz=timezone.utc)
        if trial_end_ts else None
    )

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
            'trial_end': trial_end,
        },
    )

    if customer_id and not provider.stripe_customer_id:
        provider.stripe_customer_id = customer_id
        provider.save(update_fields=['stripe_customer_id'])

    logger.info('Subscription created: provider=%s tier=%s', provider.id, tier.slug)


@transaction.atomic
def _handle_subscription_updated(sub_data):
    stripe_sub_id = sub_data.get('id')
    try:
        sub = ServiceProviderSubscription.objects.select_for_update().get(
            stripe_subscription_id=stripe_sub_id
        )
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


@transaction.atomic
def _handle_subscription_deleted(sub_data):
    stripe_sub_id = sub_data.get('id')
    try:
        sub = ServiceProviderSubscription.objects.select_for_update().get(
            stripe_subscription_id=stripe_sub_id
        )
    except ServiceProviderSubscription.DoesNotExist:
        return

    sub.status = 'cancelled'
    sub.cancelled_at = timezone.now()
    sub.save(update_fields=['status', 'cancelled_at'])

    logger.info('Subscription cancelled: provider=%s', sub.provider.id)


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
            from ..tasks import send_email_task
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
    with transaction.atomic():
        quote = get_object_or_404(
            ConveyancerQuote.objects.select_for_update().select_related('request', 'provider'),
            pk=quote_pk,
        )
        if quote.request.requester != request.user:
            raise PermissionDenied('Only the requester can accept quotes.')

        quote.is_accepted = True
        quote.save(update_fields=['is_accepted'])
        quote.request.status = 'accepted'
        quote.request.save(update_fields=['status'])

        # Reject other quotes
        ConveyancerQuote.objects.filter(
            request=quote.request
        ).exclude(pk=quote.pk).update(is_accepted=False)

    # Notify accepted provider
    try:
        from ..tasks import send_email_task
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


@api_view(['GET'])
@permission_classes([permissions.IsAdminUser])
def service_provider_stats(request):
    """Return aggregate statistics for staff service management dashboard."""
    stats = ServiceProvider.objects.aggregate(
        total=Count('id'),
        draft=Count('id', filter=Q(status='draft')),
        pending_review=Count('id', filter=Q(status='pending_review')),
        active=Count('id', filter=Q(status='active')),
        suspended=Count('id', filter=Q(status='suspended')),
        withdrawn=Count('id', filter=Q(status='withdrawn')),
        verified=Count('id', filter=Q(is_verified=True)),
    )

    subscription_stats = list(
        ServiceProviderSubscription.objects.filter(status='active')
        .values('tier__name')
        .annotate(count=Count('id'))
    )

    pending_providers = (
        ServiceProvider.objects.filter(status='pending_review')
        .select_related('owner')
        .prefetch_related('categories', 'subscriptions__tier')
        .order_by('created_at')
    )

    recent_providers = (
        ServiceProvider.objects.all()
        .select_related('owner')
        .prefetch_related('categories', 'subscriptions__tier')
        .order_by('-created_at')[:20]
    )

    return Response({
        'counts': stats,
        'subscription_breakdown': subscription_stats,
        'pending_providers': ServiceProviderListSerializer(
            pending_providers, many=True, context={'request': request}
        ).data,
        'recent_providers': ServiceProviderListSerializer(
            recent_providers, many=True, context={'request': request}
        ).data,
    })


@api_view(['POST'])
@permission_classes([permissions.IsAdminUser])
def bulk_provider_action(request):
    """Bulk status update for service providers (staff-only)."""
    provider_ids = request.data.get('provider_ids', [])
    action_name = request.data.get('action')

    action_map = {
        'approve': 'active',
        'suspend': 'suspended',
        'reject': 'withdrawn',
    }
    new_status = action_map.get(action_name)
    if not new_status:
        return Response(
            {'detail': f'Invalid action. Must be one of: {", ".join(action_map.keys())}'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    if not provider_ids:
        return Response(
            {'detail': 'No provider IDs provided.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    updated = ServiceProvider.objects.filter(id__in=provider_ids).update(status=new_status)
    return Response({'updated': updated, 'new_status': new_status})
