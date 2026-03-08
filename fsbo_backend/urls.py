"""URL configuration for fsbo_backend project."""
import os
from django.contrib import admin
from django.http import FileResponse, Http404
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from django.views.generic import TemplateView

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
    path('', TemplateView.as_view(template_name='home.html'), name='home'),
    path('login/', TemplateView.as_view(template_name='login.html'), name='login'),
    path('register/', TemplateView.as_view(template_name='register.html'), name='register'),
    path('properties/new/', TemplateView.as_view(template_name='property_create.html'), name='property-create'),
    path('properties/<int:id>/', TemplateView.as_view(template_name='property_detail.html'), name='property-detail'),
    path('properties/<int:id>/edit/', TemplateView.as_view(template_name='property_edit.html'), name='property-edit'),
    path('my-listings/', TemplateView.as_view(template_name='my_listings.html'), name='my-listings'),

    # Legal pages
    path('terms/', TemplateView.as_view(template_name='terms.html'), name='terms'),
    path('privacy/', TemplateView.as_view(template_name='privacy.html'), name='privacy'),
    path('cookies/', TemplateView.as_view(template_name='cookies.html'), name='cookies'),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
else:
    urlpatterns += [
        path('media/<path:path>', serve_media, name='serve-media'),
    ]
