"""Sitemaps for public pages and active property listings."""
from django.contrib.sitemaps import Sitemap
from django.urls import reverse

from api.models import Property


class StaticViewSitemap(Sitemap):
    """Public, indexable top-level pages."""

    changefreq = 'weekly'
    priority = 0.6
    protocol = 'https'

    def items(self):
        return [
            'home',
            'search',
            'services',
            'pricing',
            'house-prices',
            'mortgage-calculator',
            'stamp-duty-calculator',
            'conveyancing',
            'price-comparison',
            'how-it-works',
            'terms',
            'privacy',
            'cookies',
        ]

    def location(self, item):
        return reverse(item)


class PropertySitemap(Sitemap):
    """Active public property listings, keyed by slug."""

    changefreq = 'daily'
    priority = 0.8
    protocol = 'https'
    limit = 5000

    def items(self):
        return (
            Property.objects
            .filter(status='active')
            .exclude(slug='')
            .only('slug', 'updated_at')
            .order_by('-updated_at')
        )

    def location(self, obj):
        return f'/properties/{obj.slug}/'

    def lastmod(self, obj):
        return obj.updated_at
