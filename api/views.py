from rest_framework import viewsets, permissions
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.parsers import MultiPartParser, FormParser
from .models import Property, PropertyImage
from .serializers import PropertySerializer, PropertyImageSerializer


class IsOwnerOrReadOnly(permissions.BasePermission):
    """Allow read access to anyone, write access only to the property owner."""

    def has_object_permission(self, request, view, obj):
        if request.method in permissions.SAFE_METHODS:
            return True
        return obj.owner == request.user


class PropertyViewSet(viewsets.ModelViewSet):
    serializer_class = PropertySerializer

    def get_permissions(self):
        if self.action in ['list', 'retrieve']:
            return [permissions.AllowAny()]
        return [permissions.IsAuthenticated(), IsOwnerOrReadOnly()]

    def get_queryset(self):
        queryset = Property.objects.all().select_related('owner').prefetch_related('images')
        status = self.request.query_params.get('status')
        property_type = self.request.query_params.get('property_type')
        city = self.request.query_params.get('city')

        if not self.request.user.is_authenticated:
            queryset = queryset.filter(status='active')

        if status:
            queryset = queryset.filter(status=status)
        if property_type:
            queryset = queryset.filter(property_type=property_type)
        if city:
            queryset = queryset.filter(city__icontains=city)

        return queryset

    def perform_create(self, serializer):
        serializer.save(owner=self.request.user)


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
