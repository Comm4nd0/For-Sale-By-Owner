"""DRF token authentication for Channels WebSocket connections.

The mobile app authenticates with a DRF token, not a session cookie, so
``AuthMiddlewareStack`` alone leaves ``scope['user']`` anonymous and the
chat consumer rejects the connection. This middleware resolves the user
from a ``?token=<key>`` query parameter or an ``Authorization: Token
<key>`` header, overriding whatever the session middleware resolved.
"""
from urllib.parse import parse_qs

from channels.db import database_sync_to_async


@database_sync_to_async
def _get_user_for_token(token_key):
    from django.contrib.auth.models import AnonymousUser
    from rest_framework.authtoken.models import Token
    try:
        return Token.objects.select_related('user').get(key=token_key).user
    except Token.DoesNotExist:
        return AnonymousUser()


class TokenAuthMiddleware:
    """Wrap inside AuthMiddlewareStack so a token beats session auth."""

    def __init__(self, inner):
        self.inner = inner

    async def __call__(self, scope, receive, send):
        token_key = self._extract_token(scope)
        if token_key:
            scope = dict(scope)
            scope['user'] = await _get_user_for_token(token_key)
        return await self.inner(scope, receive, send)

    @staticmethod
    def _extract_token(scope):
        query = parse_qs((scope.get('query_string') or b'').decode())
        if query.get('token'):
            return query['token'][0]
        headers = dict(scope.get('headers') or [])
        auth_header = headers.get(b'authorization', b'').decode()
        if auth_header.lower().startswith('token '):
            return auth_header.split(' ', 1)[1].strip()
        return None
