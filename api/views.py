from django.db.models import Q, Count
from rest_framework import viewsets, permissions, status, generics
from rest_framework.decorators import api_view, permission_classes, action
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.response import Response
from .models import Property, PropertyImage, SavedProperty, Enquiry, PropertyView, PushNotificationDevice
from .serializers import (
    PropertySerializer, PropertyListSerializer, PropertyImageSerializer,
    SavedPropertySerializer, EnquirySerializer, DashboardStatsSerializer,
)
from .notifications import notify_new_enquiry


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

    def get_queryset(self):
        queryset = Property.objects.all().select_related('owner').prefetch_related('images')
        status_filter = self.request.query_params.get('status')
        property_type = self.request.query_params.get('property_type')
        city = self.request.query_params.get('city')

        if not self.request.user.is_authenticated:
            queryset = queryset.filter(status='active')
        elif self.request.query_params.get('mine') != 'true':
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
        serializer.save(owner=self.request.user)

    def retrieve(self, request, *args, **kwargs):
        instance = self.get_object()
        # Track view
        PropertyView.objects.create(
            property=instance,
            viewer_ip=request.META.get('HTTP_X_FORWARDED_FOR', request.META.get('REMOTE_ADDR', '')).split(',')[0].strip(),
            user=request.user if request.user.is_authenticated else None,
        )
        serializer = self.get_serializer(instance)
        return Response(serializer.data)

    @action(detail=True, methods=['get'])
    def similar(self, request, pk=None):
        """Return similar properties based on type, location, and price range."""
        prop = self.get_object()
        price_range = prop.price * 0.3
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
        return Property.objects.get(pk=self.kwargs['property_pk'])

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


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def reorder_images(request, property_pk):
    """Bulk-update image ordering. Expects {"order": [id1, id2, ...]}."""
    prop = Property.objects.get(pk=property_pk)
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

    def get_queryset(self):
        user = self.request.user
        # Users can see enquiries they sent or received (as property owner)
        return Enquiry.objects.filter(
            Q(sender=user) | Q(property__owner=user)
        ).select_related('property', 'sender')

    def perform_create(self, serializer):
        prop = serializer.validated_data['property']
        if prop.owner == self.request.user:
            raise ValidationError("You cannot enquire about your own property.")
        enquiry = serializer.save(sender=self.request.user)
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
        ).select_related('property', 'sender').order_by('-created_at')
        page = self.paginate_queryset(qs)
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)
        serializer = self.get_serializer(qs, many=True)
        return Response(serializer.data)


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

    data = {
        'total_listings': properties.count(),
        'active_listings': properties.filter(status='active').count(),
        'total_views': total_views,
        'total_enquiries': total_enquiries,
        'unread_enquiries': unread_enquiries,
        'total_saves': total_saves,
    }
    return Response(data)


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
