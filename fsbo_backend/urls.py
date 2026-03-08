"""URL configuration for fsbo_backend project."""
import os
from django.contrib import admin
from django.http import FileResponse, Http404
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from django.views.generic import TemplateView


def serve_media(request, path):
    """Serve media files in production."""
    file_path = os.path.join(settings.MEDIA_ROOT, path)
    if os.path.isfile(file_path):
        return FileResponse(open(file_path, 'rb'))
    raise Http404


urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', include('api.urls')),
    path('auth/', include('djoser.urls')),
    path('auth/', include('djoser.urls.authtoken')),
    path('', TemplateView.as_view(template_name='home.html'), name='home'),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
else:
    urlpatterns += [
        path('media/<path:path>', serve_media, name='serve-media'),
    ]
