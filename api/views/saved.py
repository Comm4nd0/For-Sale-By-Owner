"""Saved items, searches, push-device registration and listing moderation flags."""
from django.shortcuts import get_object_or_404

from rest_framework import viewsets, permissions, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response

from ..models import (
    Property,
    SavedProperty,
    SavedSearch,
    PushNotificationDevice,
    PropertyFlag,
)
from ..serializers import (
    SavedPropertySerializer,
    SavedSearchSerializer,
    PropertyFlagSerializer,
)


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


class SavedSearchViewSet(viewsets.ModelViewSet):
    serializer_class = SavedSearchSerializer
    permission_classes = [permissions.IsAuthenticated]
    http_method_names = ['get', 'post', 'patch', 'delete']

    def get_queryset(self):
        return SavedSearch.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


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


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def unregister_push_device(request):
    """Mark an FCM token inactive so the device stops receiving pushes.

    Called from the mobile app on logout to stop the previous user's
    notifications from arriving on a shared device.
    """
    token = request.data.get('token')
    if not token:
        return Response({'detail': 'Token is required.'}, status=status.HTTP_400_BAD_REQUEST)
    # Only allow a user to unregister their own device token to avoid cross-user
    # deactivation, but be lenient if a token has rotated and is no longer ours.
    updated = PushNotificationDevice.objects.filter(
        token=token, user=request.user
    ).update(is_active=False)
    return Response({'unregistered': bool(updated)})


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def flag_property(request, property_pk):
    """Flag a property listing for moderation."""
    prop = get_object_or_404(Property, pk=property_pk)
    if prop.owner == request.user:
        return Response({'detail': 'Cannot flag your own property.'}, status=status.HTTP_400_BAD_REQUEST)
    if PropertyFlag.objects.filter(property=prop, reporter=request.user).exists():
        return Response({'detail': 'You have already flagged this property.'}, status=status.HTTP_400_BAD_REQUEST)

    reason = request.data.get('reason', '')
    if reason not in dict(PropertyFlag.REASON_CHOICES):
        return Response({'detail': 'Invalid reason.'}, status=status.HTTP_400_BAD_REQUEST)

    flag = PropertyFlag.objects.create(
        property=prop,
        reporter=request.user,
        reason=reason,
        description=request.data.get('description', ''),
    )
    return Response(PropertyFlagSerializer(flag).data, status=status.HTTP_201_CREATED)
