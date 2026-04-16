"""URL configuration for fsbo_backend project."""
from django.contrib import admin
from django.contrib.sitemaps.views import sitemap
from django.urls import path, include
from django.conf import settings
from django.views.generic import TemplateView
from django.views.decorators.csrf import ensure_csrf_cookie
from django.views.static import serve as static_serve

from api.sitemaps import PropertySitemap, StaticViewSitemap
from api.views import TwoFactorAwareTokenCreateView

sitemaps = {
    'static': StaticViewSitemap,
    'properties': PropertySitemap,
}


class CSRFTemplateView(TemplateView):
    """TemplateView that always sets the CSRF cookie."""

    @classmethod
    def as_view(cls, **initkwargs):
        view = super().as_view(**initkwargs)
        return ensure_csrf_cookie(view)

admin.site.site_header = "For Sale By Owner"
admin.site.site_title = "FSBO Admin"
admin.site.index_title = "Dashboard"


_INLINE_MEDIA_EXTENSIONS = {'.png', '.jpg', '.jpeg', '.webp', '.gif', '.avif'}


def serve_media(request, path):
    """Serve user-uploaded media files.

    Non-image files are served with ``Content-Disposition: attachment`` so
    that even if a user-uploaded file sneaks past upload validation (for
    instance an .html renamed to .pdf), the browser downloads it rather
    than executing it in the site's origin.
    """
    import os as _os
    response = static_serve(request, path, document_root=settings.MEDIA_ROOT)
    ext = _os.path.splitext(path)[1].lower()
    if ext not in _INLINE_MEDIA_EXTENSIONS:
        response['Content-Disposition'] = 'attachment'
    return response


urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', include('api.urls')),
    path('api/sale-tracker/', include('sale_tracker.urls')),
    path('auth/', include('djoser.urls')),
    # Must come BEFORE djoser.urls.authtoken so this override handles
    # /auth/token/login/ — it gates on 2FA. Djoser's own logout handler
    # is still picked up from the include below.
    path('auth/token/login/', TwoFactorAwareTokenCreateView.as_view(), name='login'),
    path('auth/', include('djoser.urls.authtoken')),

    # Web pages
    path('', CSRFTemplateView.as_view(template_name='home.html'), name='home'),
    path('search/', CSRFTemplateView.as_view(template_name='search_results.html'), name='search'),
    path('login/', CSRFTemplateView.as_view(template_name='login.html'), name='login'),
    path('register/', CSRFTemplateView.as_view(template_name='register.html'), name='register'),
    path('profile/', CSRFTemplateView.as_view(template_name='profile.html'), name='profile'),
    path('forgot-password/', CSRFTemplateView.as_view(template_name='forgot_password.html'), name='forgot-password'),
    path('password-reset/<str:uid>/<str:token>/', CSRFTemplateView.as_view(template_name='password_reset_confirm.html'), name='password-reset-confirm'),
    path('properties/new/', CSRFTemplateView.as_view(template_name='property_create.html'), name='property-create'),
    path('properties/<int:id>/', CSRFTemplateView.as_view(template_name='property_detail.html'), name='property-detail'),
    path('properties/<int:id>/edit/', CSRFTemplateView.as_view(template_name='property_edit.html'), name='property-edit'),
    path('properties/<int:id>/complete/', CSRFTemplateView.as_view(template_name='property_complete.html'), name='property-complete'),
    path('my-listings/', CSRFTemplateView.as_view(template_name='my_listings.html'), name='my-listings'),
    path('dashboard/', CSRFTemplateView.as_view(template_name='dashboard.html'), name='dashboard'),
    path('saved/', CSRFTemplateView.as_view(template_name='saved_properties.html'), name='saved-properties'),

    # Staff management
    path('staff/services/', CSRFTemplateView.as_view(template_name='staff_services.html'), name='staff-services'),

    # Service providers
    path('services/', CSRFTemplateView.as_view(template_name='services.html'), name='services'),
    path('services/register/', CSRFTemplateView.as_view(template_name='service_provider_register.html'), name='service-provider-register'),
    path('my-service/', CSRFTemplateView.as_view(template_name='my_service.html'), name='my-service'),
    path('pricing/', CSRFTemplateView.as_view(template_name='pricing.html'), name='pricing'),
    path('house-prices/', CSRFTemplateView.as_view(template_name='house_prices.html'), name='house-prices'),
    path('offers/', CSRFTemplateView.as_view(template_name='offers.html'), name='offers'),
    path('messages/', CSRFTemplateView.as_view(template_name='messages.html'), name='messages'),
    path('messages/<int:room_id>/', CSRFTemplateView.as_view(template_name='messages.html'), name='message-detail'),
    path('properties/<int:id>/viewing-slots/', CSRFTemplateView.as_view(template_name='viewing_slots.html'), name='viewing-slots'),
    path('mortgage-calculator/', CSRFTemplateView.as_view(template_name='mortgage_calculator.html'), name='mortgage-calculator'),
    path('saved-searches/', CSRFTemplateView.as_view(template_name='saved_searches.html'), name='saved-searches'),
    path('services/<slug:slug>/', CSRFTemplateView.as_view(template_name='service_provider_detail.html'), name='service-provider-detail'),

    # Slug-based property URL (must come after /properties/new/ and /properties/<int:id>/)
    path('properties/<slug:slug>/', CSRFTemplateView.as_view(template_name='property_detail.html'), name='property-detail-slug'),

    # New feature pages
    path('stamp-duty-calculator/', CSRFTemplateView.as_view(template_name='stamp_duty_calculator.html'), name='stamp-duty-calculator'),
    path('conveyancing/', CSRFTemplateView.as_view(template_name='conveyancing.html'), name='conveyancing'),
    path('price-comparison/', CSRFTemplateView.as_view(template_name='price_comparison.html'), name='price-comparison'),
    path('how-it-works/', CSRFTemplateView.as_view(template_name='how_it_works.html'), name='how-it-works'),

    # Legal pages
    path('terms/', CSRFTemplateView.as_view(template_name='terms.html'), name='terms'),
    path('privacy/', CSRFTemplateView.as_view(template_name='privacy.html'), name='privacy'),
    path('cookies/', CSRFTemplateView.as_view(template_name='cookies.html'), name='cookies'),

    # SEO
    path('sitemap.xml', sitemap, {'sitemaps': sitemaps}, name='django.contrib.sitemaps.views.sitemap'),
    path('robots.txt', TemplateView.as_view(template_name='robots.txt', content_type='text/plain'), name='robots-txt'),

    # Always serve media files (user-uploaded images) regardless of DEBUG setting
    path('media/<path:path>', serve_media, name='serve-media'),
]

handler404 = 'fsbo_backend.views.custom_404'
handler500 = 'fsbo_backend.views.custom_500'
