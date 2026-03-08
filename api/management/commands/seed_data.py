"""Management command to create seed data for development."""
from django.core.management.base import BaseCommand
from api.models import User, Property


class Command(BaseCommand):
    help = 'Create seed users and properties for development'

    def handle(self, *args, **options):
        # Create test users
        user1, created1 = User.objects.get_or_create(
            email='alice@example.com',
            defaults={
                'first_name': 'Alice',
                'last_name': 'Johnson',
            }
        )
        if created1:
            user1.set_password('testpass123')
            user1.save()
            self.stdout.write(self.style.SUCCESS('Created user: alice@example.com'))
        else:
            self.stdout.write('User alice@example.com already exists, skipping.')

        user2, created2 = User.objects.get_or_create(
            email='bob@example.com',
            defaults={
                'first_name': 'Bob',
                'last_name': 'Smith',
            }
        )
        if created2:
            user2.set_password('testpass123')
            user2.save()
            self.stdout.write(self.style.SUCCESS('Created user: bob@example.com'))
        else:
            self.stdout.write('User bob@example.com already exists, skipping.')

        # Skip if properties already exist
        if Property.objects.exists():
            self.stdout.write('Properties already exist, skipping seed data.')
            return

        properties = [
            {
                'owner': user1,
                'title': 'Charming 3-Bed Semi in Cheltenham',
                'description': 'A beautifully presented three bedroom semi-detached house located in a popular residential area of Cheltenham. The property benefits from a modern kitchen, spacious living room, and a well-maintained south-facing garden. Recently redecorated throughout with new carpets and a new boiler installed last year.',
                'property_type': 'semi_detached',
                'status': 'active',
                'price': 325000,
                'address_line_1': '42 Leckhampton Road',
                'city': 'Cheltenham',
                'county': 'Gloucestershire',
                'postcode': 'GL53 0BE',
                'bedrooms': 3,
                'bathrooms': 1,
                'reception_rooms': 2,
                'square_feet': 1100,
            },
            {
                'owner': user1,
                'title': 'Modern 2-Bed Flat with Parking',
                'description': 'A stylish two bedroom apartment on the second floor of a modern development. Features open plan living with a fitted kitchen, en-suite to the master bedroom, and allocated parking. Walking distance to the town centre and train station.',
                'property_type': 'flat',
                'status': 'active',
                'price': 195000,
                'address_line_1': 'Flat 8, The Waterfront',
                'address_line_2': 'Quay Street',
                'city': 'Gloucester',
                'county': 'Gloucestershire',
                'postcode': 'GL1 2LG',
                'bedrooms': 2,
                'bathrooms': 2,
                'reception_rooms': 1,
                'square_feet': 750,
            },
            {
                'owner': user1,
                'title': 'Detached Family Home with Large Garden',
                'description': 'An impressive four bedroom detached house set on a generous plot. The property offers flexible living accommodation including a separate dining room, study, and conservatory. The large rear garden is mainly laid to lawn with a patio area and mature borders. Double garage and ample off-road parking.',
                'property_type': 'detached',
                'status': 'active',
                'price': 575000,
                'address_line_1': '15 Oakwood Drive',
                'city': 'Cirencester',
                'county': 'Gloucestershire',
                'postcode': 'GL7 1QN',
                'bedrooms': 4,
                'bathrooms': 2,
                'reception_rooms': 3,
                'square_feet': 2200,
            },
            {
                'owner': user2,
                'title': 'Cosy Cotswold Cottage',
                'description': 'A delightful period cottage in the heart of a sought-after Cotswold village. Retaining many original features including exposed beams, inglenook fireplace, and flagstone floors. The cottage garden wraps around two sides of the property with views over open countryside.',
                'property_type': 'cottage',
                'status': 'active',
                'price': 425000,
                'address_line_1': '3 Church Lane',
                'city': 'Bourton-on-the-Water',
                'county': 'Gloucestershire',
                'postcode': 'GL54 2AP',
                'bedrooms': 2,
                'bathrooms': 1,
                'reception_rooms': 1,
                'square_feet': 850,
            },
            {
                'owner': user2,
                'title': 'Victorian Terraced House - Renovation Project',
                'description': 'A three bedroom Victorian mid-terrace house requiring modernisation throughout. Offers excellent potential to create a lovely family home subject to the usual consents. Original features include ceiling roses, picture rails, and a tiled hallway. Rear access to a courtyard garden.',
                'property_type': 'terraced',
                'status': 'active',
                'price': 175000,
                'address_line_1': '88 Oxford Road',
                'city': 'Gloucester',
                'county': 'Gloucestershire',
                'postcode': 'GL1 3EH',
                'bedrooms': 3,
                'bathrooms': 1,
                'reception_rooms': 2,
            },
            {
                'owner': user2,
                'title': 'Luxury Penthouse Apartment',
                'description': 'A stunning top floor penthouse apartment with panoramic views. The open plan living space is flooded with natural light from floor to ceiling windows and a private roof terrace. Specification includes underfloor heating, integrated Sonos system, and a bespoke kitchen by a local craftsman.',
                'property_type': 'flat',
                'status': 'under_offer',
                'price': 450000,
                'address_line_1': 'Penthouse, Imperial Square',
                'city': 'Cheltenham',
                'county': 'Gloucestershire',
                'postcode': 'GL50 1QA',
                'bedrooms': 3,
                'bathrooms': 2,
                'reception_rooms': 1,
                'square_feet': 1650,
            },
            {
                'owner': user1,
                'title': 'Building Plot with Planning Permission',
                'description': 'A rare opportunity to acquire a building plot with full planning permission for a detached four bedroom dwelling. The plot extends to approximately 0.3 acres and is located in a desirable village setting. Services are available at the boundary. Detailed plans available from the vendor.',
                'property_type': 'land',
                'status': 'active',
                'price': 200000,
                'address_line_1': 'Land Adjacent to The Old Rectory',
                'address_line_2': 'High Street',
                'city': 'Painswick',
                'county': 'Gloucestershire',
                'postcode': 'GL6 6QA',
                'bedrooms': 0,
                'bathrooms': 0,
                'reception_rooms': 0,
            },
            {
                'owner': user2,
                'title': 'Spacious Bungalow with Annexe',
                'description': 'A well-proportioned detached bungalow with a self-contained annexe, ideal for multi-generational living. The main property offers three bedrooms, a modern bathroom, and a large kitchen-diner. The annexe has its own entrance with a bedroom, shower room, and kitchenette. Set in mature gardens of approximately a third of an acre.',
                'property_type': 'bungalow',
                'status': 'active',
                'price': 395000,
                'address_line_1': 'Meadow View',
                'address_line_2': 'Station Road',
                'city': 'Moreton-in-Marsh',
                'county': 'Gloucestershire',
                'postcode': 'GL56 0BW',
                'bedrooms': 3,
                'bathrooms': 2,
                'reception_rooms': 2,
                'square_feet': 1400,
            },
            {
                'owner': user1,
                'title': '4-Bed Detached - Sold STC',
                'description': 'A superb four bedroom detached family home in a cul-de-sac location. SOLD SUBJECT TO CONTRACT.',
                'property_type': 'detached',
                'status': 'sold_stc',
                'price': 485000,
                'address_line_1': '7 Willow Close',
                'city': 'Tewkesbury',
                'county': 'Gloucestershire',
                'postcode': 'GL20 5TJ',
                'bedrooms': 4,
                'bathrooms': 2,
                'reception_rooms': 2,
                'square_feet': 1800,
            },
            {
                'owner': user2,
                'title': 'Studio Flat - Draft Listing',
                'description': 'Compact studio flat in city centre. Work in progress listing.',
                'property_type': 'flat',
                'status': 'draft',
                'price': 95000,
                'address_line_1': 'Unit 3, Kings Square',
                'city': 'Gloucester',
                'county': 'Gloucestershire',
                'postcode': 'GL1 1RR',
                'bedrooms': 0,
                'bathrooms': 1,
                'reception_rooms': 0,
                'square_feet': 320,
            },
        ]

        for prop_data in properties:
            Property.objects.create(**prop_data)

        self.stdout.write(self.style.SUCCESS(f'Created {len(properties)} seed properties.'))
