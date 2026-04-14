"""
Management command to create a demo sale with all seed data.
Useful for development and testing.

Usage:
    USE_SQLITE=True python manage.py seed_sale_tracker
"""

from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from sale_tracker.models import Sale
from sale_tracker.seed import seed_sale

User = get_user_model()


class Command(BaseCommand):
    help = 'Create a demo sale with all seed data (stages, tasks, documents)'

    def add_arguments(self, parser):
        parser.add_argument(
            '--email',
            default='demo@example.com',
            help='Email for the demo seller (created if not exists)',
        )
        parser.add_argument(
            '--tenure',
            default='freehold',
            choices=['freehold', 'leasehold', 'share_of_freehold'],
            help='Tenure type for the demo sale',
        )

    def handle(self, *args, **options):
        email = options['email']
        tenure = options['tenure']

        user, created = User.objects.get_or_create(
            email=email,
            defaults={
                'first_name': 'Demo',
                'last_name': 'Seller',
            },
        )
        if created:
            user.set_password('demo1234')
            user.save()
            self.stdout.write(self.style.SUCCESS(
                f'Created demo user: {email} (password: demo1234)'
            ))

        sale = Sale.objects.create(
            seller=user,
            property_address='42 Acacia Avenue, London, SW1A 1AA',
            asking_price=450000,
            agreed_price=440000,
            tenure=tenure,
            buyer_name='Jane Buyer',
            buyer_contact='jane@example.com',
            agent_name='Smith & Partners',
            agent_contact='agent@example.com',
            seller_conveyancer_name='Williams Law',
            seller_conveyancer_contact='williams@law.com',
            buyer_conveyancer_name='Jones Solicitors',
            buyer_conveyancer_contact='jones@solicitors.com',
            buyer_position='mortgage',
            chain_length=2,
        )
        seed_sale(sale)

        task_count = sum(
            stage.tasks.count() for stage in sale.stages.all()
        )
        doc_count = sale.documents.count()

        self.stdout.write(self.style.SUCCESS(
            f'Created demo sale: {sale.property_address}\n'
            f'  Tenure: {tenure}\n'
            f'  Stages: {sale.stages.count()}\n'
            f'  Tasks: {task_count}\n'
            f'  Documents: {doc_count}'
        ))
