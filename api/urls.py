from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

router = DefaultRouter()
router.register(r'properties', views.PropertyViewSet, basename='property')
router.register(r'saved', views.SavedPropertyViewSet, basename='saved-property')
router.register(r'viewings', views.ViewingRequestViewSet, basename='viewing-request')
router.register(r'saved-searches', views.SavedSearchViewSet, basename='saved-search')
router.register(r'features', views.PropertyFeatureViewSet, basename='property-feature')
router.register(r'service-categories', views.ServiceCategoryViewSet, basename='service-category')
router.register(r'service-providers', views.ServiceProviderViewSet, basename='service-provider')
router.register(r'chat-rooms', views.ChatRoomViewSet, basename='chat-room')
router.register(r'offers', views.OfferViewSet, basename='offer')
# New feature routers
router.register(r'buyer-verifications', views.BuyerVerificationViewSet, basename='buyer-verification')
router.register(r'quote-requests', views.ConveyancerQuoteRequestViewSet, basename='quote-request')
router.register(r'conveyancer-quotes', views.ConveyancerQuoteViewSet, basename='conveyancer-quote')
router.register(r'neighbourhood-reviews', views.NeighbourhoodReviewViewSet, basename='neighbourhood-review')
router.register(r'board-orders', views.BoardOrderViewSet, basename='board-order')

urlpatterns = [
    path('', include(router.urls)),
    # Property images
    path(
        'properties/<int:property_pk>/images/',
        views.PropertyImageViewSet.as_view({'get': 'list', 'post': 'create'}),
        name='property-images-list',
    ),
    path(
        'properties/<int:property_pk>/images/<int:pk>/',
        views.PropertyImageViewSet.as_view({
            'get': 'retrieve', 'patch': 'partial_update', 'delete': 'destroy'
        }),
        name='property-images-detail',
    ),
    path(
        'properties/<int:property_pk>/images/reorder/',
        views.reorder_images,
        name='property-images-reorder',
    ),
    # Property floorplans
    path(
        'properties/<int:property_pk>/floorplans/',
        views.PropertyFloorplanViewSet.as_view({'get': 'list', 'post': 'create'}),
        name='property-floorplans-list',
    ),
    path(
        'properties/<int:property_pk>/floorplans/<int:pk>/',
        views.PropertyFloorplanViewSet.as_view({
            'get': 'retrieve', 'patch': 'partial_update', 'delete': 'destroy'
        }),
        name='property-floorplans-detail',
    ),
    # Property save toggle
    path(
        'properties/<int:property_pk>/save/',
        views.toggle_saved,
        name='property-save-toggle',
    ),
    # Property documents
    path(
        'properties/<int:property_pk>/documents/',
        views.PropertyDocumentViewSet.as_view({'get': 'list', 'post': 'create'}),
        name='property-documents-list',
    ),
    path(
        'properties/<int:property_pk>/documents/<int:pk>/',
        views.PropertyDocumentViewSet.as_view({
            'get': 'retrieve', 'patch': 'partial_update', 'delete': 'destroy'
        }),
        name='property-documents-detail',
    ),
    # Property flagging
    path(
        'properties/<int:property_pk>/flag/',
        views.flag_property,
        name='property-flag',
    ),
    # Property neighbourhood info
    path(
        'properties/<int:property_pk>/neighbourhood/',
        views.neighbourhood_info,
        name='property-neighbourhood',
    ),
    # Viewing slots
    path(
        'properties/<int:property_pk>/viewing-slots/',
        views.ViewingSlotViewSet.as_view({'get': 'list', 'post': 'create'}),
        name='viewing-slots-list',
    ),
    path(
        'properties/<int:property_pk>/viewing-slots/<int:pk>/',
        views.ViewingSlotViewSet.as_view({
            'get': 'retrieve', 'patch': 'partial_update', 'delete': 'destroy'
        }),
        name='viewing-slots-detail',
    ),
    path(
        'properties/<int:property_pk>/viewing-slots/bulk-create/',
        views.bulk_create_viewing_slots,
        name='viewing-slots-bulk-create',
    ),
    path(
        'properties/<int:property_pk>/viewing-slots/<int:slot_pk>/book/',
        views.book_viewing_slot,
        name='viewing-slot-book',
    ),
    # Dashboard & profile
    path('dashboard/stats/', views.dashboard_stats, name='dashboard-stats'),
    path('notifications/counts/', views.notification_counts, name='notification-counts'),
    path('profile/', views.user_profile, name='user-profile'),
    path('push/register/', views.register_push_device, name='push-register'),
    # Chat messages (nested)
    path(
        'chat-rooms/<int:room_pk>/messages/',
        views.ChatMessageViewSet.as_view({'get': 'list', 'post': 'create'}),
        name='chat-messages-list',
    ),
    path(
        'chat-rooms/<int:room_pk>/messages/mark_read/',
        views.ChatMessageViewSet.as_view({'post': 'mark_read'}),
        name='chat-messages-mark-read',
    ),
    # Service provider reviews (nested)
    path(
        'service-providers/<int:provider_pk>/reviews/',
        views.ServiceProviderReviewViewSet.as_view({'get': 'list', 'post': 'create'}),
        name='service-provider-reviews-list',
    ),
    path(
        'service-providers/<int:provider_pk>/reviews/<int:pk>/',
        views.ServiceProviderReviewViewSet.as_view({'get': 'retrieve', 'delete': 'destroy'}),
        name='service-provider-reviews-detail',
    ),
    # Property-scoped service providers
    path(
        'properties/<int:property_pk>/services/',
        views.property_services,
        name='property-services',
    ),
    # Subscription / Stripe
    path('pricing/', views.pricing_page, name='pricing-api'),
    path('my-subscription/', views.my_subscription, name='my-subscription'),
    path('subscriptions/create-checkout/', views.create_checkout, name='create-checkout'),
    path('subscriptions/create-portal/', views.create_portal, name='create-portal'),
    path('stripe/webhook/', views.stripe_webhook, name='stripe-webhook'),
    path('house-prices/', views.house_price_lookup, name='house-price-lookup'),
    # Service provider photos (nested)
    path(
        'service-providers/<int:provider_pk>/photos/',
        views.ServiceProviderPhotoViewSet.as_view({'get': 'list', 'post': 'create'}),
        name='service-provider-photos-list',
    ),
    path(
        'service-providers/<int:provider_pk>/photos/<int:pk>/',
        views.ServiceProviderPhotoViewSet.as_view({
            'get': 'retrieve', 'patch': 'partial_update', 'delete': 'destroy'
        }),
        name='service-provider-photos-detail',
    ),
    # Mortgage calculator
    path('mortgage-calculator/', views.mortgage_calculator, name='mortgage-calculator'),
    # Bulk import/export
    path('properties/bulk-import/', views.bulk_import_properties, name='bulk-import'),
    path('properties/export/', views.export_properties, name='export-properties'),
    # Staff service management
    path('staff/service-stats/', views.service_provider_stats, name='service-provider-stats'),
    path('staff/service-actions/', views.bulk_provider_action, name='service-provider-actions'),
    # Health check
    path('health/', views.health_check, name='health-check'),

    # ── New Feature Routes (#28-#45) ─────────────────────────────

    # #28 Listing quality score
    path(
        'properties/<int:property_pk>/quality-score/',
        views.listing_quality_score,
        name='listing-quality-score',
    ),

    # #29 Price comparison & valuation
    path('price-comparison/', views.price_comparison, name='api-price-comparison'),

    # #30 Buyer verification status
    path('buyers/<int:user_pk>/verification/', views.buyer_verification_status, name='buyer-verification-status'),

    # #32 AI listing description generator
    path('generate-description/', views.generate_listing_description, name='generate-description'),

    # Postcode lookup (postcodes.io proxy)
    path('postcode-lookup/<str:postcode>/', views.postcode_lookup, name='postcode-lookup'),

    # #33 Similar properties
    path('properties/<int:property_pk>/similar/', views.similar_properties, name='similar-properties'),

    # #35 Stamp duty calculator
    path('stamp-duty-calculator/', views.stamp_duty_calculator, name='api-stamp-duty-calculator'),

    # #36 Property history
    path('properties/<int:property_pk>/history/', views.property_history, name='property-history'),

    # #37 Open house events
    path(
        'properties/<int:property_pk>/open-house/',
        views.OpenHouseEventViewSet.as_view({'get': 'list', 'post': 'create'}),
        name='open-house-list',
    ),
    path(
        'properties/<int:property_pk>/open-house/<int:pk>/',
        views.OpenHouseEventViewSet.as_view({
            'get': 'retrieve', 'patch': 'partial_update', 'delete': 'destroy'
        }),
        name='open-house-detail',
    ),
    path('open-house/<int:event_pk>/rsvp/', views.rsvp_open_house, name='open-house-rsvp'),
    path('open-house/<int:event_pk>/rsvp/cancel/', views.cancel_rsvp, name='open-house-rsvp-cancel'),

    # #38 QR code property flyers
    path('properties/<int:property_pk>/flyer/', views.generate_property_flyer, name='property-flyer'),

    # #39 Conveyancer matching
    path('quotes/<int:quote_pk>/accept/', views.accept_conveyancer_quote, name='accept-quote'),

    # #40 Neighbourhood summary
    path('neighbourhood/<str:postcode_area>/summary/', views.neighbourhood_summary, name='neighbourhood-summary'),

    # #41 Board pricing
    path('board-pricing/', views.board_pricing, name='board-pricing'),

    # #42 EPC improvement suggestions
    path(
        'properties/<int:property_pk>/epc-suggestions/',
        views.epc_improvement_suggestions,
        name='epc-suggestions',
    ),

    # #43 Buyer profile & affordable properties
    path('buyer-profile/', views.buyer_profile_view, name='buyer-profile'),
    path('affordable-properties/', views.affordable_properties, name='affordable-properties'),

    # #44 Two-factor authentication
    path('2fa/setup/', views.setup_2fa, name='2fa-setup'),
    path('2fa/confirm/', views.confirm_2fa, name='2fa-confirm'),
    path('2fa/disable/', views.disable_2fa, name='2fa-disable'),
    path('2fa/verify/', views.verify_2fa, name='2fa-verify'),
]
