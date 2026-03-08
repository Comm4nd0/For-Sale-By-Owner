from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

router = DefaultRouter()
router.register(r'properties', views.PropertyViewSet, basename='property')

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
]
