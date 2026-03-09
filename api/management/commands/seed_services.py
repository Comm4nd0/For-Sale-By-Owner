from django.core.management.base import BaseCommand
from api.models import ServiceCategory


class Command(BaseCommand):
    help = 'Seed service categories for the service provider marketplace'

    def handle(self, *args, **options):
        categories = [
            {'name': 'EPC Inspections', 'icon': 'bolt', 'description': 'Energy Performance Certificate assessments for your property', 'order': 1},
            {'name': 'Gas Safety Certificates', 'icon': 'local_fire_department', 'description': 'Gas safety checks and CP12 certificates', 'order': 2},
            {'name': 'Conveyancing / Solicitors', 'icon': 'gavel', 'description': 'Legal services for buying and selling property', 'order': 3},
            {'name': 'Property Photography', 'icon': 'photo_camera', 'description': 'Professional photography to showcase your property', 'order': 4},
            {'name': 'Cleaning Services', 'icon': 'cleaning_services', 'description': 'Deep cleaning and end-of-tenancy cleaning', 'order': 5},
            {'name': 'Removals / Moving', 'icon': 'local_shipping', 'description': 'House removals and moving services', 'order': 6},
            {'name': 'Mortgage Brokers', 'icon': 'account_balance', 'description': 'Independent mortgage advice and broker services', 'order': 7},
            {'name': 'Home Surveys', 'icon': 'search', 'description': 'Building surveys and structural engineer reports', 'order': 8},
            {'name': 'Electricians', 'icon': 'electrical_services', 'description': 'Electrical inspections, rewiring and repairs', 'order': 9},
            {'name': 'Plumbers', 'icon': 'plumbing', 'description': 'Plumbing repairs, installations and boiler services', 'order': 10},
            {'name': 'Locksmiths', 'icon': 'lock', 'description': 'Lock changes, security upgrades and emergency access', 'order': 11},
            {'name': 'Garden / Landscaping', 'icon': 'yard', 'description': 'Garden maintenance, landscaping and design', 'order': 12},
            {'name': 'Interior Design / Staging', 'icon': 'design_services', 'description': 'Home staging and interior design to maximise sale price', 'order': 13},
            {'name': 'Storage', 'icon': 'warehouse', 'description': 'Short and long-term storage solutions', 'order': 14},
        ]

        created = 0
        for cat_data in categories:
            _, was_created = ServiceCategory.objects.get_or_create(
                name=cat_data['name'],
                defaults=cat_data,
            )
            if was_created:
                created += 1

        self.stdout.write(self.style.SUCCESS(
            f'Seeded {created} new service categories ({len(categories) - created} already existed)'
        ))
