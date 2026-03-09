"""Seed subscription tiers and add-ons for the service provider marketplace."""
from django.core.management.base import BaseCommand
from api.models import SubscriptionTier, SubscriptionAddOn


class Command(BaseCommand):
    help = 'Seed subscription tiers and add-ons'

    def handle(self, *args, **options):
        tiers = [
            {
                'slug': 'free',
                'name': 'Free',
                'tagline': 'Get discovered. No commitment.',
                'cta_text': 'Get Listed Free',
                'badge_text': '',
                'monthly_price': 0,
                'annual_price': 0,
                'max_service_categories': 1,
                'max_locations': 1,
                'max_photos': 0,
                'allow_logo': False,
                'feature_basic_listing': True,
                'feature_local_area_visibility': True,
                'feature_contact_details': True,
                'feature_featured_placement': False,
                'feature_click_through_analytics': False,
                'feature_category_exclusivity': False,
                'feature_priority_search': False,
                'feature_lead_notifications': False,
                'feature_performance_reports': False,
                'feature_account_manager': False,
                'feature_photo_gallery': False,
                'feature_early_access': False,
                'display_order': 0,
            },
            {
                'slug': 'growth',
                'name': 'Growth',
                'tagline': 'Stand out from the crowd.',
                'cta_text': 'Start Growing',
                'badge_text': '',
                'monthly_price': 9,
                'annual_price': 86,
                'max_service_categories': 3,
                'max_locations': 1,
                'max_photos': 6,
                'allow_logo': True,
                'feature_basic_listing': True,
                'feature_local_area_visibility': True,
                'feature_contact_details': True,
                'feature_featured_placement': True,
                'feature_click_through_analytics': True,
                'feature_category_exclusivity': False,
                'feature_priority_search': False,
                'feature_lead_notifications': False,
                'feature_performance_reports': False,
                'feature_account_manager': False,
                'feature_photo_gallery': True,
                'feature_early_access': False,
                'display_order': 1,
            },
            {
                'slug': 'pro',
                'name': 'Pro',
                'tagline': 'Own your postcode.',
                'cta_text': 'Go Pro',
                'badge_text': 'Most Popular',
                'monthly_price': 25,
                'annual_price': 240,
                'max_service_categories': -1,
                'max_locations': 3,
                'max_photos': -1,
                'allow_logo': True,
                'feature_basic_listing': True,
                'feature_local_area_visibility': True,
                'feature_contact_details': True,
                'feature_featured_placement': True,
                'feature_click_through_analytics': True,
                'feature_category_exclusivity': True,
                'feature_priority_search': True,
                'feature_lead_notifications': True,
                'feature_performance_reports': True,
                'feature_account_manager': True,
                'feature_photo_gallery': True,
                'feature_early_access': True,
                'display_order': 2,
            },
        ]

        tier_created = 0
        for tier_data in tiers:
            _, was_created = SubscriptionTier.objects.update_or_create(
                slug=tier_data['slug'],
                defaults=tier_data,
            )
            if was_created:
                tier_created += 1

        # Add-ons
        addons = [
            {
                'slug': 'extra_location',
                'name': 'Additional Location',
                'description': 'Expand coverage to another postcode area',
                'monthly_price': 5,
                'display_order': 0,
                'tiers': ['growth', 'pro'],
            },
            {
                'slug': 'extra_category',
                'name': 'Additional Service Category',
                'description': 'Add another category to your listing',
                'monthly_price': 3,
                'display_order': 1,
                'tiers': ['growth'],
            },
            {
                'slug': 'premium_placement',
                'name': 'Homepage Spotlight',
                'description': 'Featured placement on the site homepage for your region',
                'monthly_price': 15,
                'display_order': 2,
                'tiers': ['growth', 'pro'],
            },
        ]

        addon_created = 0
        for addon_data in addons:
            tier_slugs = addon_data.pop('tiers')
            obj, was_created = SubscriptionAddOn.objects.update_or_create(
                slug=addon_data['slug'],
                defaults=addon_data,
            )
            obj.compatible_tiers.set(
                SubscriptionTier.objects.filter(slug__in=tier_slugs)
            )
            if was_created:
                addon_created += 1

        self.stdout.write(self.style.SUCCESS(
            f'Seeded {tier_created} tiers, {addon_created} add-ons '
            f'({len(tiers)} tiers total, {len(addons)} add-ons total)'
        ))
