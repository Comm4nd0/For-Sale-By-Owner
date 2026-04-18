"""Chat rooms and messages between buyers and sellers."""
import logging

from django.db.models import Q
from django.shortcuts import get_object_or_404

from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.response import Response

from ..models import Property, ChatRoom, ChatMessage
from ..serializers import ChatRoomSerializer, ChatMessageSerializer

logger = logging.getLogger(__name__)


class ChatRoomViewSet(viewsets.ModelViewSet):
    """Manage chat rooms between buyers and sellers."""
    serializer_class = ChatRoomSerializer
    permission_classes = [permissions.IsAuthenticated]
    http_method_names = ['get', 'post']

    def get_queryset(self):
        user = self.request.user
        return ChatRoom.objects.filter(
            Q(buyer=user) | Q(seller=user)
        ).select_related('property', 'buyer', 'seller').prefetch_related('messages')

    def perform_create(self, serializer):
        prop = serializer.validated_data['property']
        if prop.owner == self.request.user:
            raise ValidationError("You cannot start a chat about your own property.")
        # Get or create the room
        room, created = ChatRoom.objects.get_or_create(
            property=prop,
            buyer=self.request.user,
            defaults={'seller': prop.owner},
        )
        if not created:
            raise ValidationError("Chat room already exists for this property.")

    def create(self, request, *args, **kwargs):
        prop_id = request.data.get('property')
        if not prop_id:
            return Response({'detail': 'property is required.'}, status=status.HTTP_400_BAD_REQUEST)
        prop = get_object_or_404(Property, pk=prop_id)
        if prop.owner == request.user:
            return Response({'detail': 'Cannot chat about your own property.'}, status=status.HTTP_400_BAD_REQUEST)
        room, created = ChatRoom.objects.get_or_create(
            property=prop,
            buyer=request.user,
            defaults={'seller': prop.owner},
        )
        # If an initial message was provided, create it
        message_text = request.data.get('message', '').strip()
        if message_text:
            ChatMessage.objects.create(room=room, sender=request.user, message=message_text)
            room.save(update_fields=['updated_at'])
        serializer = self.get_serializer(room)
        return Response(serializer.data, status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)


class ChatMessageViewSet(viewsets.ModelViewSet):
    """Messages within a chat room."""
    serializer_class = ChatMessageSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = None
    http_method_names = ['get', 'post']

    def get_queryset(self):
        room_pk = self.kwargs.get('room_pk')
        if room_pk is None:
            return ChatMessage.objects.none()
        room = get_object_or_404(ChatRoom, pk=room_pk)
        user = self.request.user
        if user != room.buyer and user != room.seller:
            raise PermissionDenied()
        qs = ChatMessage.objects.filter(room=room).select_related('sender')
        logger.info(
            'ChatMessage list: room_pk=%s, user=%s, buyer=%s, seller=%s, msg_count=%d',
            room_pk, user.pk, room.buyer_id, room.seller_id, qs.count(),
        )
        return qs

    def perform_create(self, serializer):
        room = get_object_or_404(ChatRoom, pk=self.kwargs['room_pk'])
        user = self.request.user
        if user != room.buyer and user != room.seller:
            raise PermissionDenied()
        serializer.save(room=room, sender=user)
        room.save(update_fields=['updated_at'])

    @action(detail=False, methods=['post'])
    def mark_read(self, request, room_pk=None):
        room = get_object_or_404(ChatRoom, pk=room_pk)
        user = request.user
        if user != room.buyer and user != room.seller:
            raise PermissionDenied()
        updated = ChatMessage.objects.filter(
            room=room, is_read=False
        ).exclude(sender=user).update(is_read=True)
        return Response({'marked': updated})
