"""URL configuration for fsbo_backend project."""
import os
from django.contrib import admin
from django.http import FileResponse, Http404
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from django.views.generic import TemplateView
from django.views.decorators.csrf import ensure_csrf_cookie


class CSRFTemplateView(TemplateView):
    """TemplateView that always sets the CSRF cookie."""

    @classmethod
    def as_view(cls, **initkwargs):
        view = super().as_view(**initkwargs)
        return ensure_csrf_cookie(view)

admin.site.site_header = "For Sale By Owner"
admin.site.site_title = "FSBO Admin"
admin.site.index_title = "Dashboard"


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

    # Web pages
    path('', CSRFTemplateView.as_view(template_name='home.html'), name='home'),
    path('search/', CSRFTemplateView.as_view(template_name='search_results.html'), name='search'),
    path('login/', CSRFTemplateView.as_view(template_name='login.html'), name='login'),
    path('register/', CSRFTemplateView.as_view(template_name='register.html'), name='register'),
    path('properties/new/', CSRFTemplateView.as_view(template_name='property_create.html'), name='property-create'),
    path('properties/<int:id>/', CSRFTemplateView.as_view(template_name='property_detail.html'), name='property-detail'),
    path('properties/<int:id>/edit/', CSRFTemplateView.as_view(template_name='property_edit.html'), name='property-edit'),
    path('my-listings/', CSRFTemplateView.as_view(template_name='my_listings.html'), name='my-listings'),

    # Legal pages
    path('terms/', CSRFTemplateView.as_view(template_name='terms.html'), name='terms'),
    path('privacy/', CSRFTemplateView.as_view(template_name='privacy.html'), name='privacy'),
    path('cookies/', CSRFTemplateView.as_view(template_name='cookies.html'), name='cookies'),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
else:
    urlpatterns += [
        path('media/<path:path>', serve_media, name='serve-media'),
    ]
