from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

router = DefaultRouter()
router.register(r'properties', views.PropertyViewSet, basename='property')
router.register(r'saved', views.SavedPropertyViewSet, basename='saved-property')
router.register(r'enquiries', views.EnquiryViewSet, basename='enquiry')
router.register(r'viewings', views.ViewingRequestViewSet, basename='viewing-request')
router.register(r'saved-searches', views.SavedSearchViewSet, basename='saved-search')
router.register(r'features', views.PropertyFeatureViewSet, basename='property-feature')
router.register(r'service-categories', views.ServiceCategoryViewSet, basename='service-category')
router.register(r'service-providers', views.ServiceProviderViewSet, basename='service-provider')

urlpatterns = [
    path('', include(router.urls)),
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
    path(
        'properties/<int:property_pk>/save/',
        views.toggle_saved,
        name='property-save-toggle',
    ),
    path('dashboard/stats/', views.dashboard_stats, name='dashboard-stats'),
    path('notifications/counts/', views.notification_counts, name='notification-counts'),
    path('profile/', views.user_profile, name='user-profile'),
    path('push/register/', views.register_push_device, name='push-register'),
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
]
