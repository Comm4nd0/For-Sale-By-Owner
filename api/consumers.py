"""WebSocket consumers for real-time chat."""
import json
import logging
from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncJsonWebSocketConsumer

logger = logging.getLogger(__name__)


class ChatConsumer(AsyncJsonWebSocketConsumer):
    """WebSocket consumer for property chat rooms."""

    async def connect(self):
        self.room_id = self.scope['url_route']['kwargs']['room_id']
        self.room_group = f'chat_{self.room_id}'
        user = self.scope.get('user')

        if not user or user.is_anonymous:
            await self.close()
            return

        # Verify user is a participant
        is_participant = await self.check_participant(user.id, self.room_id)
        if not is_participant:
            await self.close()
            return

        await self.channel_layer.group_add(self.room_group, self.channel_name)
        await self.accept()

        # Send recent messages
        messages = await self.get_recent_messages(self.room_id)
        await self.send_json({'type': 'history', 'messages': messages})

    async def disconnect(self, close_code):
        if hasattr(self, 'room_group'):
            await self.channel_layer.group_discard(self.room_group, self.channel_name)

    async def receive_json(self, content):
        message_type = content.get('type', 'message')
        user = self.scope['user']

        if message_type == 'message':
            text = content.get('message', '').strip()
            if not text:
                return

            msg_data = await self.save_message(user.id, self.room_id, text)

            await self.channel_layer.group_send(
                self.room_group,
                {
                    'type': 'chat.message',
                    'message': msg_data,
                }
            )

        elif message_type == 'read':
            await self.mark_messages_read(user.id, self.room_id)
            await self.channel_layer.group_send(
                self.room_group,
                {'type': 'chat.read', 'user_id': user.id}
            )

        elif message_type == 'typing':
            await self.channel_layer.group_send(
                self.room_group,
                {
                    'type': 'chat.typing',
                    'user_id': user.id,
                    'is_typing': content.get('is_typing', False),
                }
            )

    async def chat_message(self, event):
        await self.send_json({'type': 'message', 'message': event['message']})

    async def chat_read(self, event):
        await self.send_json({'type': 'read', 'user_id': event['user_id']})

    async def chat_typing(self, event):
        await self.send_json({
            'type': 'typing',
            'user_id': event['user_id'],
            'is_typing': event['is_typing'],
        })

    @database_sync_to_async
    def check_participant(self, user_id, room_id):
        from .models import ChatRoom
        return ChatRoom.objects.filter(
            pk=room_id
        ).filter(
            models.Q(buyer_id=user_id) | models.Q(seller_id=user_id)
        ).exists()

    @database_sync_to_async
    def get_recent_messages(self, room_id, limit=50):
        from .models import ChatMessage
        messages = ChatMessage.objects.filter(
            room_id=room_id
        ).select_related('sender').order_by('-created_at')[:limit]
        return [
            {
                'id': m.id,
                'sender_id': m.sender_id,
                'sender_name': m.sender.get_full_name() or m.sender.email,
                'message': m.message,
                'is_read': m.is_read,
                'created_at': m.created_at.isoformat(),
            }
            for m in reversed(messages)
        ]

    @database_sync_to_async
    def save_message(self, user_id, room_id, text):
        from .models import ChatMessage, ChatRoom
        room = ChatRoom.objects.get(pk=room_id)
        msg = ChatMessage.objects.create(
            room=room, sender_id=user_id, message=text,
        )
        # Update room timestamp
        room.save(update_fields=['updated_at'])
        return {
            'id': msg.id,
            'sender_id': msg.sender_id,
            'sender_name': msg.sender.get_full_name() or msg.sender.email,
            'message': msg.message,
            'is_read': msg.is_read,
            'created_at': msg.created_at.isoformat(),
        }

    @database_sync_to_async
    def mark_messages_read(self, user_id, room_id):
        from .models import ChatMessage
        ChatMessage.objects.filter(
            room_id=room_id, is_read=False
        ).exclude(sender_id=user_id).update(is_read=True)


# Fix import for check_participant
import django.db.models as models
