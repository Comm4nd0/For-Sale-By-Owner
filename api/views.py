from rest_framework import viewsets, permissions
from .models import Property
from .serializers import PropertySerializer


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
        queryset = Property.objects.all().select_related('owner')
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
