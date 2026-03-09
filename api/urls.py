from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

router = DefaultRouter()
router.register(r'properties', views.PropertyViewSet, basename='property')
router.register(r'saved', views.SavedPropertyViewSet, basename='saved-property')
router.register(r'enquiries', views.EnquiryViewSet, basename='enquiry')

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
        'properties/<int:property_pk>/save/',
        views.toggle_saved,
        name='property-save-toggle',
    ),
    path('dashboard/stats/', views.dashboard_stats, name='dashboard-stats'),
    path('push/register/', views.register_push_device, name='push-register'),
]
