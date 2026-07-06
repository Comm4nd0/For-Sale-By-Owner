"""ASGI config for fsbo_backend project."""
import os
from django.core.asgi import get_asgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'fsbo_backend.settings')

django_asgi_app = get_asgi_application()

from channels.auth import AuthMiddlewareStack
from channels.routing import ProtocolTypeRouter, URLRouter
from api.routing import websocket_urlpatterns
from api.ws_auth import TokenAuthMiddleware

application = ProtocolTypeRouter({
    'http': django_asgi_app,
    # Session auth resolves first (web), then TokenAuthMiddleware overrides
    # scope['user'] when the mobile app supplies a DRF token.
    'websocket': AuthMiddlewareStack(
        TokenAuthMiddleware(
            URLRouter(websocket_urlpatterns)
        )
    ),
})
