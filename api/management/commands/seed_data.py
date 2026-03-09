"""Management command to create seed data for development."""
import urllib.request
import ssl
from io import BytesIO

from django.core.files.base import ContentFile
from django.core.management.base import BaseCommand
from api.models import User, Property, PropertyImage


# Unsplash image URLs mapped to each property (3-5 images each)
# Using Unsplash CDN which is free to use for development
PROPERTY_IMAGES = {
    0: [  # Charming 3-Bed Semi in Cheltenham
        ('https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=800&h=600&fit=crop', 'Front of house', True),
        ('https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800&h=600&fit=crop', 'Living room', False),
        ('https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=800&h=600&fit=crop', 'Kitchen', False),
        ('https://images.unsplash.com/photo-1540518614846-7eded433c457?w=800&h=600&fit=crop', 'Master bedroom', False),
        ('https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=800&h=600&fit=crop', 'South-facing rear garden', False),
    ],
    1: [  # Modern 2-Bed Flat with Parking
        ('https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=800&h=600&fit=crop', 'Building exterior', True),
        ('https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800&h=600&fit=crop', 'Open plan living', False),
        ('https://images.unsplash.com/photo-1560185893-a55cbc8c57e8?w=800&h=600&fit=crop', 'Bedroom', False),
        ('https://images.unsplash.com/photo-1552321554-5fefe8c9ef14?w=800&h=600&fit=crop', 'En-suite bathroom', False),
    ],
    2: [  # Detached Family Home with Large Garden
        ('https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=800&h=600&fit=crop', 'Front elevation', True),
        ('https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=800&h=600&fit=crop', 'Garden view', False),
        ('https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800&h=600&fit=crop', 'Rear aspect', False),
        ('https://images.unsplash.com/photo-1556909172-54557c7e4fb7?w=800&h=600&fit=crop', 'Kitchen', False),
        ('https://images.unsplash.com/photo-1567767292278-a4f21aa2d36e?w=800&h=600&fit=crop', 'Living room', False),
    ],
    3: [  # Cosy Cotswold Cottage
        ('https://images.unsplash.com/photo-1510627489930-0c1b0bfb6785?w=800&h=600&fit=crop', 'Cottage front', True),
        ('https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?w=800&h=600&fit=crop', 'Sitting room with inglenook', False),
        ('https://images.unsplash.com/photo-1585320806297-9794b3e4eeae?w=800&h=600&fit=crop', 'Cottage garden', False),
    ],
    4: [  # Victorian Terraced House - Renovation Project
        ('https://images.unsplash.com/photo-1582268611958-ebfd161ef9cf?w=800&h=600&fit=crop', 'Street view', True),
        ('https://images.unsplash.com/photo-1560185127-6ed189bf02f4?w=800&h=600&fit=crop', 'Tiled hallway', False),
        ('https://images.unsplash.com/photo-1560448075-bb485b067938?w=800&h=600&fit=crop', 'Reception room', False),
    ],
    5: [  # Luxury Penthouse Apartment
        ('https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800&h=600&fit=crop', 'Open plan living area', True),
        ('https://images.unsplash.com/photo-1618221195710-dd6b41faaea6?w=800&h=600&fit=crop', 'Master bedroom', False),
        ('https://images.unsplash.com/photo-1600566753086-00f18fb6b3ea?w=800&h=600&fit=crop', 'Bathroom', False),
        ('https://images.unsplash.com/photo-1600210492493-0946911123ea?w=800&h=600&fit=crop', 'Private roof terrace', False),
    ],
    6: [  # Building Plot with Planning Permission
        ('https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=800&h=600&fit=crop', 'Plot overview', True),
        ('https://images.unsplash.com/photo-1628624747186-a941c476b7ef?w=800&h=600&fit=crop', 'Site entrance', False),
        ('https://images.unsplash.com/photo-1501785888041-af3ef285b470?w=800&h=600&fit=crop', 'Surrounding countryside', False),
    ],
    7: [  # Spacious Bungalow with Annexe
        ('https://images.unsplash.com/photo-1598228723793-52759bba239c?w=800&h=600&fit=crop', 'Bungalow front', True),
        ('https://images.unsplash.com/photo-1600585154526-990dced4db0d?w=800&h=600&fit=crop', 'Kitchen diner', False),
        ('https://images.unsplash.com/photo-1600573472592-401b489a3cdc?w=800&h=600&fit=crop', 'Garden', False),
        ('https://images.unsplash.com/photo-1616594039964-ae9021a400a0?w=800&h=600&fit=crop', 'Bedroom', False),
    ],
    8: [  # 4-Bed Detached - Sold STC
        ('https://images.unsplash.com/photo-1600047509807-ba8f99d2cdde?w=800&h=600&fit=crop', 'Front of property', True),
        ('https://images.unsplash.com/photo-1600566753190-17f0baa2a6c3?w=800&h=600&fit=crop', 'Rear garden', False),
        ('https://images.unsplash.com/photo-1556909172-54557c7e4fb7?w=800&h=600&fit=crop', 'Kitchen', False),
    ],
    9: [  # Studio Flat - Draft Listing
        ('https://images.unsplash.com/photo-1536376072261-38c75010e6c9?w=800&h=600&fit=crop', 'Studio interior', True),
        ('https://images.unsplash.com/photo-1460317442991-0ec209397118?w=800&h=600&fit=crop', 'Building exterior', False),
        ('https://images.unsplash.com/photo-1584622650111-993a426fbf0a?w=800&h=600&fit=crop', 'Shower room', False),
    ],
}


def download_image(url):
    """Download an image from a URL and return it as bytes."""
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    req = urllib.request.Request(url, headers={
        'User-Agent': 'Mozilla/5.0 (compatible; FSBO-Seed/1.0)'
    })
    with urllib.request.urlopen(req, context=ctx, timeout=30) as response:
        return response.read()


class Command(BaseCommand):
    help = 'Create seed users and properties for development'

    def add_arguments(self, parser):
        parser.add_argument(
            '--no-images',
            action='store_true',
            help='Skip downloading images (faster, useful offline)',
        )

    def handle(self, *args, **options):
        skip_images = options.get('no_images', False)

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

        properties_data = [
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

        created_properties = []
        for prop_data in properties_data:
            prop = Property.objects.create(**prop_data)
            created_properties.append(prop)

        self.stdout.write(self.style.SUCCESS(
            f'Created {len(created_properties)} seed properties.'
        ))

        # Download and attach images
        if skip_images:
            self.stdout.write('Skipping image downloads (--no-images flag).')
            return

        self.stdout.write('Downloading property images from Unsplash...')
        total_images = 0
        failed_images = 0

        for idx, prop in enumerate(created_properties):
            images = PROPERTY_IMAGES.get(idx, [])
            for order, (url, caption, is_primary) in enumerate(images):
                try:
                    self.stdout.write(f'  Downloading image {order + 1} for: {prop.title}...')
                    image_data = download_image(url)
                    image_file = ContentFile(image_data, name=f'seed_{idx}_{order}.jpg')

                    PropertyImage.objects.create(
                        property=prop,
                        image=image_file,
                        order=order,
                        is_primary=is_primary,
                        caption=caption,
                    )
                    total_images += 1
                except Exception as e:
                    failed_images += 1
                    self.stdout.write(self.style.WARNING(
                        f'  Failed to download image for {prop.title}: {e}'
                    ))

        self.stdout.write(self.style.SUCCESS(
            f'Downloaded {total_images} images ({failed_images} failed).'
        ))
