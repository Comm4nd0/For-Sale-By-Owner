"""Management command to create ~1000 realistic seed properties across the UK."""
import random
import urllib.request
import ssl
from io import BytesIO

from django.core.files.base import ContentFile
from django.core.management.base import BaseCommand
from django.utils.text import slugify
from api.models import User, Property, PropertyImage


# ---------------------------------------------------------------------------
# Image pool — a curated set of Unsplash photos grouped by category.
# Each image is downloaded ONCE then reused across many properties.
# ---------------------------------------------------------------------------
IMAGE_POOL = {
    'exterior': [
        'https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=800&h=600&fit=crop',
        'https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=800&h=600&fit=crop',
        'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=800&h=600&fit=crop',
        'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800&h=600&fit=crop',
        'https://images.unsplash.com/photo-1600047509807-ba8f99d2cdde?w=800&h=600&fit=crop',
        'https://images.unsplash.com/photo-1582268611958-ebfd161ef9cf?w=800&h=600&fit=crop',
        'https://images.unsplash.com/photo-1598228723793-52759bba239c?w=800&h=600&fit=crop',
        'https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=800&h=600&fit=crop',
        'https://images.unsplash.com/photo-1510627489930-0c1b0bfb6785?w=800&h=600&fit=crop',
        'https://images.unsplash.com/photo-1605276374104-dee2a0ed3cd6?w=800&h=600&fit=crop',
    ],
    'living_room': [
        'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800&h=600&fit=crop',
        'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800&h=600&fit=crop',
        'https://images.unsplash.com/photo-1567767292278-a4f21aa2d36e?w=800&h=600&fit=crop',
        'https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?w=800&h=600&fit=crop',
        'https://images.unsplash.com/photo-1560448075-bb485b067938?w=800&h=600&fit=crop',
    ],
    'kitchen': [
        'https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=800&h=600&fit=crop',
        'https://images.unsplash.com/photo-1556909172-54557c7e4fb7?w=800&h=600&fit=crop',
        'https://images.unsplash.com/photo-1600585154526-990dced4db0d?w=800&h=600&fit=crop',
        'https://images.unsplash.com/photo-1556185781-a47769abb7ee?w=800&h=600&fit=crop',
    ],
    'bedroom': [
        'https://images.unsplash.com/photo-1540518614846-7eded433c457?w=800&h=600&fit=crop',
        'https://images.unsplash.com/photo-1560185893-a55cbc8c57e8?w=800&h=600&fit=crop',
        'https://images.unsplash.com/photo-1616594039964-ae9021a400a0?w=800&h=600&fit=crop',
        'https://images.unsplash.com/photo-1618221195710-dd6b41faaea6?w=800&h=600&fit=crop',
    ],
    'bathroom': [
        'https://images.unsplash.com/photo-1552321554-5fefe8c9ef14?w=800&h=600&fit=crop',
        'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?w=800&h=600&fit=crop',
        'https://images.unsplash.com/photo-1600566753086-00f18fb6b3ea?w=800&h=600&fit=crop',
    ],
    'garden': [
        'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=800&h=600&fit=crop',
        'https://images.unsplash.com/photo-1585320806297-9794b3e4eeae?w=800&h=600&fit=crop',
        'https://images.unsplash.com/photo-1600573472592-401b489a3cdc?w=800&h=600&fit=crop',
        'https://images.unsplash.com/photo-1600566753190-17f0baa2a6c3?w=800&h=600&fit=crop',
    ],
}

# ---------------------------------------------------------------------------
# UK locations — city, county, postcode prefix, and regional price multiplier
# (1.0 = national average ~£285k)
# ---------------------------------------------------------------------------
LOCATIONS = [
    # London
    {'city': 'London', 'county': 'Greater London', 'prefix': 'SW', 'area_codes': ['1', '3', '4', '6', '7', '8', '9', '10', '11', '12', '15', '16', '17', '18', '19', '20'], 'multiplier': 2.2},
    {'city': 'London', 'county': 'Greater London', 'prefix': 'SE', 'area_codes': ['1', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15', '16', '17', '18', '19', '20', '21', '22', '23', '24', '25', '26', '27', '28'], 'multiplier': 1.9},
    {'city': 'London', 'county': 'Greater London', 'prefix': 'N', 'area_codes': ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15', '16', '17', '18', '19', '20', '21', '22'], 'multiplier': 2.0},
    {'city': 'London', 'county': 'Greater London', 'prefix': 'E', 'area_codes': ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15', '16', '17', '18'], 'multiplier': 1.8},
    {'city': 'London', 'county': 'Greater London', 'prefix': 'W', 'area_codes': ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14'], 'multiplier': 2.5},
    {'city': 'London', 'county': 'Greater London', 'prefix': 'NW', 'area_codes': ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11'], 'multiplier': 2.1},
    # South East
    {'city': 'Brighton', 'county': 'East Sussex', 'prefix': 'BN', 'area_codes': ['1', '2', '3'], 'multiplier': 1.5},
    {'city': 'Guildford', 'county': 'Surrey', 'prefix': 'GU', 'area_codes': ['1', '2', '3', '4'], 'multiplier': 1.7},
    {'city': 'Reading', 'county': 'Berkshire', 'prefix': 'RG', 'area_codes': ['1', '2', '4', '6', '30', '31'], 'multiplier': 1.4},
    {'city': 'Oxford', 'county': 'Oxfordshire', 'prefix': 'OX', 'area_codes': ['1', '2', '3', '4'], 'multiplier': 1.6},
    {'city': 'Canterbury', 'county': 'Kent', 'prefix': 'CT', 'area_codes': ['1', '2', '3'], 'multiplier': 1.2},
    {'city': 'Southampton', 'county': 'Hampshire', 'prefix': 'SO', 'area_codes': ['14', '15', '16', '17', '18', '19'], 'multiplier': 1.1},
    {'city': 'Portsmouth', 'county': 'Hampshire', 'prefix': 'PO', 'area_codes': ['1', '2', '3', '4', '5', '6'], 'multiplier': 1.0},
    {'city': 'Milton Keynes', 'county': 'Buckinghamshire', 'prefix': 'MK', 'area_codes': ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14'], 'multiplier': 1.2},
    {'city': 'Tunbridge Wells', 'county': 'Kent', 'prefix': 'TN', 'area_codes': ['1', '2', '3', '4'], 'multiplier': 1.5},
    {'city': 'Maidstone', 'county': 'Kent', 'prefix': 'ME', 'area_codes': ['14', '15', '16'], 'multiplier': 1.1},
    {'city': 'Chichester', 'county': 'West Sussex', 'prefix': 'PO', 'area_codes': ['18', '19', '20'], 'multiplier': 1.3},
    # South West
    {'city': 'Bristol', 'county': 'Bristol', 'prefix': 'BS', 'area_codes': ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '13', '14', '15', '16'], 'multiplier': 1.3},
    {'city': 'Bath', 'county': 'Somerset', 'prefix': 'BA', 'area_codes': ['1', '2'], 'multiplier': 1.5},
    {'city': 'Exeter', 'county': 'Devon', 'prefix': 'EX', 'area_codes': ['1', '2', '3', '4'], 'multiplier': 1.1},
    {'city': 'Plymouth', 'county': 'Devon', 'prefix': 'PL', 'area_codes': ['1', '2', '3', '4', '5', '6'], 'multiplier': 0.8},
    {'city': 'Cheltenham', 'county': 'Gloucestershire', 'prefix': 'GL', 'area_codes': ['50', '51', '52', '53'], 'multiplier': 1.2},
    {'city': 'Gloucester', 'county': 'Gloucestershire', 'prefix': 'GL', 'area_codes': ['1', '2', '3', '4'], 'multiplier': 0.9},
    {'city': 'Swindon', 'county': 'Wiltshire', 'prefix': 'SN', 'area_codes': ['1', '2', '3', '4', '5', '25'], 'multiplier': 0.9},
    {'city': 'Bournemouth', 'county': 'Dorset', 'prefix': 'BH', 'area_codes': ['1', '2', '3', '4', '5', '6', '7', '8', '9'], 'multiplier': 1.1},
    {'city': 'Truro', 'county': 'Cornwall', 'prefix': 'TR', 'area_codes': ['1', '2', '3', '4'], 'multiplier': 1.0},
    {'city': 'Salisbury', 'county': 'Wiltshire', 'prefix': 'SP', 'area_codes': ['1', '2'], 'multiplier': 1.2},
    {'city': 'Taunton', 'county': 'Somerset', 'prefix': 'TA', 'area_codes': ['1', '2', '3'], 'multiplier': 0.9},
    # East of England
    {'city': 'Cambridge', 'county': 'Cambridgeshire', 'prefix': 'CB', 'area_codes': ['1', '2', '3', '4', '5'], 'multiplier': 1.6},
    {'city': 'Norwich', 'county': 'Norfolk', 'prefix': 'NR', 'area_codes': ['1', '2', '3', '4', '5', '6'], 'multiplier': 0.9},
    {'city': 'Ipswich', 'county': 'Suffolk', 'prefix': 'IP', 'area_codes': ['1', '2', '3', '4'], 'multiplier': 0.8},
    {'city': 'Colchester', 'county': 'Essex', 'prefix': 'CO', 'area_codes': ['1', '2', '3', '4'], 'multiplier': 1.0},
    {'city': 'Peterborough', 'county': 'Cambridgeshire', 'prefix': 'PE', 'area_codes': ['1', '2', '3', '4'], 'multiplier': 0.8},
    {'city': 'Chelmsford', 'county': 'Essex', 'prefix': 'CM', 'area_codes': ['1', '2', '3'], 'multiplier': 1.2},
    {'city': 'St Albans', 'county': 'Hertfordshire', 'prefix': 'AL', 'area_codes': ['1', '2', '3', '4'], 'multiplier': 1.7},
    {'city': 'Luton', 'county': 'Bedfordshire', 'prefix': 'LU', 'area_codes': ['1', '2', '3', '4'], 'multiplier': 0.9},
    # Midlands
    {'city': 'Birmingham', 'county': 'West Midlands', 'prefix': 'B', 'area_codes': ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15', '16', '17', '18', '19', '20', '21', '23', '24', '25', '26', '27', '28', '29', '30', '31', '32', '33', '34', '35', '36', '37', '38'], 'multiplier': 0.8},
    {'city': 'Coventry', 'county': 'West Midlands', 'prefix': 'CV', 'area_codes': ['1', '2', '3', '4', '5', '6'], 'multiplier': 0.8},
    {'city': 'Nottingham', 'county': 'Nottinghamshire', 'prefix': 'NG', 'area_codes': ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15', '16'], 'multiplier': 0.7},
    {'city': 'Leicester', 'county': 'Leicestershire', 'prefix': 'LE', 'area_codes': ['1', '2', '3', '4', '5'], 'multiplier': 0.7},
    {'city': 'Derby', 'county': 'Derbyshire', 'prefix': 'DE', 'area_codes': ['1', '2', '3', '21', '22', '23', '24'], 'multiplier': 0.7},
    {'city': 'Stoke-on-Trent', 'county': 'Staffordshire', 'prefix': 'ST', 'area_codes': ['1', '2', '3', '4', '5', '6'], 'multiplier': 0.5},
    {'city': 'Worcester', 'county': 'Worcestershire', 'prefix': 'WR', 'area_codes': ['1', '2', '3', '4', '5'], 'multiplier': 0.9},
    {'city': 'Wolverhampton', 'county': 'West Midlands', 'prefix': 'WV', 'area_codes': ['1', '2', '3', '4', '6', '10', '11'], 'multiplier': 0.6},
    {'city': 'Lincoln', 'county': 'Lincolnshire', 'prefix': 'LN', 'area_codes': ['1', '2', '3', '4', '5', '6'], 'multiplier': 0.6},
    {'city': 'Shrewsbury', 'county': 'Shropshire', 'prefix': 'SY', 'area_codes': ['1', '2', '3'], 'multiplier': 0.8},
    {'city': 'Northampton', 'county': 'Northamptonshire', 'prefix': 'NN', 'area_codes': ['1', '2', '3', '4', '5'], 'multiplier': 0.8},
    # North West
    {'city': 'Manchester', 'county': 'Greater Manchester', 'prefix': 'M', 'area_codes': ['1', '2', '3', '4', '5', '6', '7', '8', '9', '11', '12', '13', '14', '15', '16', '19', '20', '21', '22', '23', '24', '25'], 'multiplier': 0.9},
    {'city': 'Liverpool', 'county': 'Merseyside', 'prefix': 'L', 'area_codes': ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15', '16', '17', '18', '19', '20', '21', '22', '23', '24', '25'], 'multiplier': 0.6},
    {'city': 'Chester', 'county': 'Cheshire', 'prefix': 'CH', 'area_codes': ['1', '2', '3', '4'], 'multiplier': 1.1},
    {'city': 'Preston', 'county': 'Lancashire', 'prefix': 'PR', 'area_codes': ['1', '2', '3', '4', '5'], 'multiplier': 0.6},
    {'city': 'Lancaster', 'county': 'Lancashire', 'prefix': 'LA', 'area_codes': ['1', '2', '3', '4'], 'multiplier': 0.7},
    {'city': 'Blackpool', 'county': 'Lancashire', 'prefix': 'FY', 'area_codes': ['1', '2', '3', '4'], 'multiplier': 0.4},
    {'city': 'Bolton', 'county': 'Greater Manchester', 'prefix': 'BL', 'area_codes': ['1', '2', '3', '4', '5', '6', '7'], 'multiplier': 0.5},
    {'city': 'Warrington', 'county': 'Cheshire', 'prefix': 'WA', 'area_codes': ['1', '2', '3', '4', '5'], 'multiplier': 0.8},
    # Yorkshire & Humber
    {'city': 'Leeds', 'county': 'West Yorkshire', 'prefix': 'LS', 'area_codes': ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15', '16', '17', '18', '19', '20', '21', '22', '23', '24', '25', '26', '27', '28'], 'multiplier': 0.8},
    {'city': 'Sheffield', 'county': 'South Yorkshire', 'prefix': 'S', 'area_codes': ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '17', '20', '21', '25', '26', '35', '36'], 'multiplier': 0.7},
    {'city': 'York', 'county': 'North Yorkshire', 'prefix': 'YO', 'area_codes': ['1', '10', '23', '24', '26', '30', '31', '32'], 'multiplier': 1.1},
    {'city': 'Harrogate', 'county': 'North Yorkshire', 'prefix': 'HG', 'area_codes': ['1', '2', '3'], 'multiplier': 1.2},
    {'city': 'Hull', 'county': 'East Yorkshire', 'prefix': 'HU', 'area_codes': ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10'], 'multiplier': 0.4},
    {'city': 'Bradford', 'county': 'West Yorkshire', 'prefix': 'BD', 'area_codes': ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15', '16', '17', '18'], 'multiplier': 0.5},
    {'city': 'Huddersfield', 'county': 'West Yorkshire', 'prefix': 'HD', 'area_codes': ['1', '2', '3', '4', '5', '6', '7', '8'], 'multiplier': 0.6},
    {'city': 'Doncaster', 'county': 'South Yorkshire', 'prefix': 'DN', 'area_codes': ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'], 'multiplier': 0.5},
    # North East
    {'city': 'Newcastle upon Tyne', 'county': 'Tyne and Wear', 'prefix': 'NE', 'area_codes': ['1', '2', '3', '4', '5', '6', '7', '12', '13', '15', '16', '20', '21', '23', '24', '25', '26', '27', '28', '29', '30'], 'multiplier': 0.6},
    {'city': 'Durham', 'county': 'County Durham', 'prefix': 'DH', 'area_codes': ['1', '2', '3', '4', '5', '6', '7', '8', '9'], 'multiplier': 0.5},
    {'city': 'Sunderland', 'county': 'Tyne and Wear', 'prefix': 'SR', 'area_codes': ['1', '2', '3', '4', '5', '6', '7'], 'multiplier': 0.4},
    {'city': 'Middlesbrough', 'county': 'North Yorkshire', 'prefix': 'TS', 'area_codes': ['1', '2', '3', '4', '5', '6'], 'multiplier': 0.4},
    {'city': 'Darlington', 'county': 'County Durham', 'prefix': 'DL', 'area_codes': ['1', '2', '3'], 'multiplier': 0.5},
    # Scotland
    {'city': 'Edinburgh', 'county': 'City of Edinburgh', 'prefix': 'EH', 'area_codes': ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15', '16', '17'], 'multiplier': 1.1},
    {'city': 'Glasgow', 'county': 'City of Glasgow', 'prefix': 'G', 'area_codes': ['1', '2', '3', '4', '5', '11', '12', '13', '14', '15', '20', '21', '22', '23', '31', '32', '33', '34', '40', '41', '42', '43', '44', '45', '46', '51', '52', '53', '61', '62', '64', '69', '71', '72', '73', '74', '76', '77', '78'], 'multiplier': 0.6},
    {'city': 'Aberdeen', 'county': 'Aberdeenshire', 'prefix': 'AB', 'area_codes': ['10', '11', '12', '15', '16', '21', '22', '23', '24', '25'], 'multiplier': 0.6},
    {'city': 'Dundee', 'county': 'City of Dundee', 'prefix': 'DD', 'area_codes': ['1', '2', '3', '4', '5'], 'multiplier': 0.5},
    {'city': 'Inverness', 'county': 'Highland', 'prefix': 'IV', 'area_codes': ['1', '2', '3'], 'multiplier': 0.6},
    {'city': 'Stirling', 'county': 'Stirling', 'prefix': 'FK', 'area_codes': ['7', '8', '9'], 'multiplier': 0.7},
    {'city': 'Perth', 'county': 'Perth and Kinross', 'prefix': 'PH', 'area_codes': ['1', '2'], 'multiplier': 0.7},
    # Wales
    {'city': 'Cardiff', 'county': 'South Glamorgan', 'prefix': 'CF', 'area_codes': ['10', '11', '14', '15', '23', '24', '3', '5'], 'multiplier': 0.8},
    {'city': 'Swansea', 'county': 'West Glamorgan', 'prefix': 'SA', 'area_codes': ['1', '2', '3', '4', '5', '6'], 'multiplier': 0.6},
    {'city': 'Newport', 'county': 'Gwent', 'prefix': 'NP', 'area_codes': ['10', '18', '19', '20'], 'multiplier': 0.6},
    {'city': 'Wrexham', 'county': 'Clwyd', 'prefix': 'LL', 'area_codes': ['11', '12', '13', '14'], 'multiplier': 0.5},
    {'city': 'Aberystwyth', 'county': 'Ceredigion', 'prefix': 'SY', 'area_codes': ['23'], 'multiplier': 0.6},
    # Northern Ireland
    {'city': 'Belfast', 'county': 'County Antrim', 'prefix': 'BT', 'area_codes': ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15'], 'multiplier': 0.5},
    {'city': 'Lisburn', 'county': 'County Antrim', 'prefix': 'BT', 'area_codes': ['27', '28'], 'multiplier': 0.5},
    {'city': 'Derry', 'county': 'County Londonderry', 'prefix': 'BT', 'area_codes': ['47', '48'], 'multiplier': 0.4},
]

# Street name components
STREET_PREFIXES = [
    'High', 'Church', 'Station', 'London', 'Park', 'Victoria', 'Green',
    'Manor', 'Queen', 'King', 'New', 'Mill', 'Castle', 'Bridge', 'Market',
    'West', 'North', 'South', 'East', 'School', 'Chapel', 'Spring',
    'Meadow', 'Orchard', 'Brook', 'Hill', 'Oak', 'Elm', 'Ash', 'Birch',
    'Willow', 'Cherry', 'Beech', 'Maple', 'Cedar', 'Pine', 'Ivy',
    'Rose', 'Primrose', 'Hawthorn', 'Holme', 'Field', 'Dale', 'Valley',
    'Ridge', 'Heath', 'Moor', 'Common', 'Woodlands', 'Riverside',
    'Lakeside', 'Waterside', 'Clifton', 'Windsor', 'Kingsway',
    'Albert', 'George', 'William', 'Charles', 'James', 'Edward',
    'Alexandra', 'Elizabeth', 'Mary', 'Catherine', 'Margaret',
    'Grange', 'Lodge', 'Abbots', 'Priory', 'Rectory',
]

STREET_SUFFIXES = [
    'Street', 'Road', 'Lane', 'Drive', 'Close', 'Avenue', 'Way',
    'Place', 'Crescent', 'Terrace', 'Gardens', 'Court', 'Mews',
    'Rise', 'Hill', 'View', 'Walk', 'Grove', 'Park', 'Row',
    'Square', 'Parade', 'Circus', 'Green', 'Croft', 'End',
]

# Property type templates with typical bedroom/bathroom counts and sqft ranges
PROPERTY_TEMPLATES = {
    'detached': {
        'bedrooms': [(3, 0.15), (4, 0.45), (5, 0.30), (6, 0.10)],
        'bathrooms': [(2, 0.50), (3, 0.35), (4, 0.15)],
        'receptions': [(2, 0.40), (3, 0.45), (4, 0.15)],
        'sqft_range': (1400, 3500),
        'base_price': 350000,
    },
    'semi_detached': {
        'bedrooms': [(2, 0.10), (3, 0.60), (4, 0.25), (5, 0.05)],
        'bathrooms': [(1, 0.40), (2, 0.50), (3, 0.10)],
        'receptions': [(1, 0.20), (2, 0.65), (3, 0.15)],
        'sqft_range': (850, 1800),
        'base_price': 250000,
    },
    'terraced': {
        'bedrooms': [(2, 0.30), (3, 0.55), (4, 0.15)],
        'bathrooms': [(1, 0.60), (2, 0.35), (3, 0.05)],
        'receptions': [(1, 0.35), (2, 0.55), (3, 0.10)],
        'sqft_range': (700, 1400),
        'base_price': 200000,
    },
    'flat': {
        'bedrooms': [(1, 0.30), (2, 0.50), (3, 0.18), (4, 0.02)],
        'bathrooms': [(1, 0.65), (2, 0.30), (3, 0.05)],
        'receptions': [(1, 0.90), (2, 0.10)],
        'sqft_range': (400, 1200),
        'base_price': 180000,
    },
    'bungalow': {
        'bedrooms': [(2, 0.35), (3, 0.45), (4, 0.15), (5, 0.05)],
        'bathrooms': [(1, 0.40), (2, 0.45), (3, 0.15)],
        'receptions': [(1, 0.25), (2, 0.55), (3, 0.20)],
        'sqft_range': (800, 1800),
        'base_price': 280000,
    },
    'cottage': {
        'bedrooms': [(1, 0.15), (2, 0.40), (3, 0.35), (4, 0.10)],
        'bathrooms': [(1, 0.55), (2, 0.40), (3, 0.05)],
        'receptions': [(1, 0.45), (2, 0.45), (3, 0.10)],
        'sqft_range': (600, 1400),
        'base_price': 300000,
    },
    'land': {
        'bedrooms': [(0, 1.0)],
        'bathrooms': [(0, 1.0)],
        'receptions': [(0, 1.0)],
        'sqft_range': (None, None),
        'base_price': 150000,
    },
}

# Title templates by property type
TITLE_TEMPLATES = {
    'detached': [
        '{beds}-Bed Detached Family Home in {city}',
        'Spacious {beds}-Bedroom Detached House',
        'Impressive Detached Home with Garden',
        'Executive {beds}-Bed Detached Property',
        '{beds}-Bedroom Detached House in {area}',
        'Substantial Detached Home with Garage',
        'Well-Presented Detached Property',
        'Modern {beds}-Bed Detached Home',
    ],
    'semi_detached': [
        'Charming {beds}-Bed Semi in {city}',
        '{beds}-Bedroom Semi-Detached House',
        'Well-Maintained Semi-Detached Home',
        'Extended {beds}-Bed Semi-Detached',
        'Modern Semi with Garden in {city}',
        'Family {beds}-Bed Semi-Detached',
        'Renovated Semi-Detached Property',
    ],
    'terraced': [
        '{beds}-Bed Terraced House in {city}',
        'Victorian Terraced Home in {area}',
        'Period {beds}-Bedroom Terrace',
        'Well-Presented Terraced Property',
        'Charming {beds}-Bed Terrace with Garden',
        'Mid-Terraced Family Home',
        'End-of-Terrace {beds}-Bed House',
    ],
    'flat': [
        'Modern {beds}-Bed Apartment in {city}',
        '{beds}-Bedroom Flat with Parking',
        'Stylish {beds}-Bed Apartment',
        'Top Floor {beds}-Bed Flat with Views',
        'Ground Floor Apartment with Garden',
        'Contemporary {beds}-Bed City Flat',
        'Penthouse Apartment in {city}',
        'Spacious {beds}-Bed Flat',
    ],
    'bungalow': [
        'Spacious {beds}-Bed Bungalow',
        'Detached Bungalow with Gardens',
        '{beds}-Bedroom Bungalow in {city}',
        'Extended Bungalow with Annexe Potential',
        'Modern {beds}-Bed Bungalow',
        'Character Bungalow in {area}',
    ],
    'cottage': [
        'Charming {beds}-Bed Cottage in {city}',
        'Period Cottage with Character',
        'Cosy {beds}-Bedroom Country Cottage',
        'Stone-Built Cottage in {area}',
        'Delightful Cottage with Garden',
        'Thatched Cottage in Village Setting',
    ],
    'land': [
        'Building Plot with Planning Permission',
        'Development Site in {city}',
        'Residential Building Plot',
        'Land with Outline Planning',
        'Plot for Sale in {area}',
    ],
}

# Description fragments for building realistic descriptions
DESC_OPENERS = {
    'detached': [
        'An impressive {beds} bedroom detached house',
        'A beautifully presented detached family home',
        'This substantial detached property offers',
        'A well-proportioned {beds} bedroom detached house',
        'An attractive detached home',
    ],
    'semi_detached': [
        'A well-presented {beds} bedroom semi-detached house',
        'This charming semi-detached home',
        'An extended {beds} bedroom semi-detached property',
        'A beautifully maintained semi-detached house',
    ],
    'terraced': [
        'A {beds} bedroom terraced house',
        'This characterful period terrace',
        'A well-maintained {beds} bedroom mid-terrace',
        'An attractive terraced property',
    ],
    'flat': [
        'A stylish {beds} bedroom apartment',
        'This modern {beds} bedroom flat',
        'A bright and spacious {beds} bedroom apartment',
        'A well-appointed {beds} bedroom flat',
    ],
    'bungalow': [
        'A spacious {beds} bedroom detached bungalow',
        'This well-maintained bungalow',
        'An attractive {beds} bedroom bungalow',
        'A delightful detached bungalow',
    ],
    'cottage': [
        'A charming {beds} bedroom period cottage',
        'This delightful cottage',
        'A characterful {beds} bedroom cottage',
        'An idyllic period cottage',
    ],
    'land': [
        'An exciting opportunity to acquire a building plot',
        'A residential development site',
        'A level building plot',
    ],
}

DESC_LOCATION = [
    'located in the popular {area} area of {city}',
    'situated in a sought-after residential area of {city}',
    'in a quiet cul-de-sac in {city}',
    'on a tree-lined street in {city}',
    'within walking distance of {city} town centre',
    'in a desirable location close to local amenities in {city}',
    'in the heart of {city}',
    'benefiting from a convenient location in {city}',
    'in a popular residential street in {city}',
    'enjoying a peaceful setting in {city}',
]

DESC_FEATURES = [
    'The property benefits from {feature1} and {feature2}.',
    'Key features include {feature1}, {feature2}, and {feature3}.',
    'The accommodation comprises {feature1}, {feature2}, and {feature3}.',
    'Highlights include {feature1} and {feature2}.',
]

FEATURES_POOL = [
    'a modern fitted kitchen',
    'a spacious living room',
    'a recently refurbished bathroom',
    'double glazing throughout',
    'gas central heating',
    'off-road parking',
    'a well-maintained garden',
    'a south-facing rear garden',
    'a single garage',
    'a double garage',
    'an en-suite to the master bedroom',
    'a separate dining room',
    'a conservatory',
    'a utility room',
    'underfloor heating',
    'a newly installed boiler',
    'an open plan kitchen-diner',
    'original period features',
    'exposed beams',
    'a log burner in the sitting room',
    'a recently landscaped garden',
    'a driveway providing ample parking',
    'a patio area ideal for entertaining',
    'far-reaching countryside views',
    'a downstairs WC',
    'a fitted home office',
    'bi-fold doors to the garden',
    'a feature fireplace',
    'a walk-in wardrobe to the master bedroom',
    'solar panels',
    'ample storage throughout',
    'a recently fitted kitchen',
]

DESC_CLOSERS = [
    'Viewing is highly recommended to appreciate all this property has to offer.',
    'Early viewing is strongly advised.',
    'An internal inspection is essential to appreciate the accommodation on offer.',
    'This property must be viewed to be fully appreciated.',
    'Contact us today to arrange a viewing.',
    'Viewings are strictly by appointment only.',
    'A rare opportunity not to be missed.',
    'We anticipate a high level of interest in this property.',
]

# EPC rating distribution (weighted)
EPC_WEIGHTS = [('A', 0.02), ('B', 0.12), ('C', 0.30), ('D', 0.30), ('E', 0.15), ('F', 0.08), ('G', 0.03)]

# Status distribution
STATUS_WEIGHTS = [
    ('active', 0.70),
    ('under_offer', 0.12),
    ('sold_stc', 0.10),
    ('sold', 0.05),
    ('withdrawn', 0.03),
]

# Property type distribution
TYPE_WEIGHTS = [
    ('detached', 0.20),
    ('semi_detached', 0.22),
    ('terraced', 0.22),
    ('flat', 0.22),
    ('bungalow', 0.07),
    ('cottage', 0.05),
    ('land', 0.02),
]


def weighted_choice(options):
    """Pick from list of (value, weight) tuples."""
    values, weights = zip(*options)
    return random.choices(values, weights=weights, k=1)[0]


def generate_postcode(location):
    """Generate a realistic-looking UK postcode."""
    prefix = location['prefix']
    area_code = random.choice(location['area_codes'])
    number = random.randint(1, 9)
    letters = ''.join(random.choices('ABDEFGHJKLMNPQRSTUWXYZ', k=2))
    return f"{prefix}{area_code} {number}{letters}"


def generate_address(location):
    """Generate a realistic UK street address."""
    num = random.randint(1, 150)
    prefix = random.choice(STREET_PREFIXES)
    suffix = random.choice(STREET_SUFFIXES)
    # Avoid silly combos like "Hill Hill"
    while prefix == suffix:
        suffix = random.choice(STREET_SUFFIXES)
    return f"{num} {prefix} {suffix}"


def generate_flat_address(location):
    """Generate a flat-style address."""
    flat_num = random.randint(1, 30)
    building_names = [
        'The Waterfront', 'Riverside Court', 'Park View', 'Centenary House',
        'Victoria Mansions', 'The Exchange', 'Regency Court', 'Harbour Point',
        'Imperial House', 'St James Place', 'The Maltings', 'Cathedral Court',
        'Merchants Quarter', 'Wellington House', 'Queens Gate', 'Berkeley Square',
        'Cranbourne House', 'Kensington Court', 'Albany House', 'Clarendon Place',
        'Elmwood Court', 'Ashford House', 'Richmond Terrace', 'Portland Place',
    ]
    building = random.choice(building_names)
    return f"Flat {flat_num}, {building}", f"{random.choice(STREET_PREFIXES)} {random.choice(['Street', 'Road', 'Lane'])}"


def generate_description(prop_type, beds, city, area):
    """Build a realistic property description."""
    opener = random.choice(DESC_OPENERS.get(prop_type, DESC_OPENERS['detached']))
    opener = opener.format(beds=beds)

    location = random.choice(DESC_LOCATION).format(area=area, city=city)

    features = random.sample(FEATURES_POOL, min(random.randint(3, 6), len(FEATURES_POOL)))
    feat_template = random.choice(DESC_FEATURES)
    feat_text = feat_template.format(
        feature1=features[0],
        feature2=features[1],
        feature3=features[2] if len(features) > 2 else features[0],
    )

    closer = random.choice(DESC_CLOSERS)

    return f"{opener} {location}. {feat_text} {closer}"


def download_image(url):
    """Download an image from a URL and return bytes."""
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    req = urllib.request.Request(url, headers={
        'User-Agent': 'Mozilla/5.0 (compatible; FSBO-Seed/1.0)'
    })
    with urllib.request.urlopen(req, context=ctx, timeout=30) as response:
        return response.read()


class Command(BaseCommand):
    help = 'Create ~1000 realistic seed properties across the UK'

    def add_arguments(self, parser):
        parser.add_argument(
            '--count', type=int, default=1000,
            help='Number of properties to create (default: 1000)',
        )
        parser.add_argument(
            '--no-images', action='store_true',
            help='Skip downloading images (much faster)',
        )
        parser.add_argument(
            '--images-per-property', type=int, default=3,
            help='Images per property (default: 3, max: 5)',
        )

    def handle(self, *args, **options):
        count = options['count']
        skip_images = options['no_images']
        images_per_prop = min(options['images_per_property'], 5)

        random.seed(42)  # Reproducible

        # Create seed users spread across the UK
        seed_users = []
        user_data = [
            ('alice@example.com', 'Alice', 'Johnson'),
            ('bob@example.com', 'Bob', 'Smith'),
            ('claire@example.com', 'Claire', 'Williams'),
            ('david@example.com', 'David', 'Brown'),
            ('emma@example.com', 'Emma', 'Taylor'),
            ('frank@example.com', 'Frank', 'Davies'),
            ('grace@example.com', 'Grace', 'Evans'),
            ('henry@example.com', 'Henry', 'Wilson'),
            ('isla@example.com', 'Isla', 'Thomas'),
            ('jack@example.com', 'Jack', 'Roberts'),
            ('kate@example.com', 'Kate', 'Walker'),
            ('liam@example.com', 'Liam', 'Wright'),
            ('mia@example.com', 'Mia', 'Robinson'),
            ('noah@example.com', 'Noah', 'Thompson'),
            ('olivia@example.com', 'Olivia', 'White'),
            ('peter@example.com', 'Peter', 'Hughes'),
            ('rachel@example.com', 'Rachel', 'Edwards'),
            ('sam@example.com', 'Sam', 'Green'),
            ('tara@example.com', 'Tara', 'Hall'),
            ('will@example.com', 'Will', 'Clark'),
        ]

        for email, first, last in user_data:
            user, created = User.objects.get_or_create(
                email=email,
                defaults={'first_name': first, 'last_name': last}
            )
            if created:
                user.set_password('testpass123')
                user.save()
                self.stdout.write(f'  Created user: {email}')
            seed_users.append(user)

        self.stdout.write(self.style.SUCCESS(f'Ready with {len(seed_users)} seed users.'))

        # Check existing property count
        existing = Property.objects.count()
        if existing >= count:
            self.stdout.write(f'Already have {existing} properties (target: {count}). Skipping.')
            return

        to_create = count - existing
        self.stdout.write(f'Creating {to_create} properties (existing: {existing}, target: {count})...')

        # Pre-download image pool if needed
        image_cache = {}
        if not skip_images:
            self.stdout.write('Pre-downloading image pool...')
            all_urls = []
            for category, urls in IMAGE_POOL.items():
                for url in urls:
                    all_urls.append((category, url))

            for category, url in all_urls:
                try:
                    self.stdout.write(f'  Downloading {category} image...')
                    image_cache[url] = download_image(url)
                except Exception as e:
                    self.stdout.write(self.style.WARNING(f'  Failed: {e}'))

            self.stdout.write(self.style.SUCCESS(
                f'Downloaded {len(image_cache)} / {len(all_urls)} pool images.'
            ))

        # Generate properties
        created_count = 0
        image_count = 0
        batch = []

        for i in range(to_create):
            location = random.choice(LOCATIONS)
            prop_type = weighted_choice(TYPE_WEIGHTS)
            template = PROPERTY_TEMPLATES[prop_type]

            beds = weighted_choice(template['bedrooms'])
            baths = weighted_choice(template['bathrooms'])
            receptions = weighted_choice(template['receptions'])

            if template['sqft_range'][0]:
                sqft = random.randint(*template['sqft_range'])
                # Bigger for more bedrooms
                sqft = int(sqft * (1 + (beds - 2) * 0.12))
            else:
                sqft = None

            # Price: base × location multiplier × bedroom adjustment × random variance
            base_price = template['base_price']
            price = base_price * location['multiplier']
            price *= (1 + (beds - 3) * 0.15)  # More beds = higher price
            price *= random.uniform(0.75, 1.30)  # Natural variance
            price = round(price / 5000) * 5000  # Round to nearest £5k
            price = max(price, 50000)  # Floor

            status = weighted_choice(STATUS_WEIGHTS)
            epc = weighted_choice(EPC_WEIGHTS) if prop_type != 'land' else ''

            city = location['city']
            county = location['county']
            area = random.choice(STREET_PREFIXES)

            # Address
            if prop_type == 'flat':
                addr1, addr2 = generate_flat_address(location)
            elif prop_type == 'land':
                addr1 = f"Land Adjacent to {random.randint(1, 50)} {random.choice(STREET_PREFIXES)} {random.choice(['Road', 'Lane', 'Street'])}"
                addr2 = ''
            else:
                addr1 = generate_address(location)
                addr2 = ''

            postcode = generate_postcode(location)

            # Title
            title_templates = TITLE_TEMPLATES.get(prop_type, TITLE_TEMPLATES['detached'])
            title = random.choice(title_templates).format(beds=beds, city=city, area=area)

            # Description
            description = generate_description(prop_type, beds, city, area)

            prop = Property(
                owner=random.choice(seed_users),
                title=title,
                description=description,
                property_type=prop_type,
                status=status,
                price=price,
                address_line_1=addr1,
                address_line_2=addr2,
                city=city,
                county=county,
                postcode=postcode,
                bedrooms=beds,
                bathrooms=baths,
                reception_rooms=receptions,
                square_feet=sqft,
                epc_rating=epc,
            )
            batch.append(prop)

            if len(batch) >= 100:
                Property.objects.bulk_create(batch)
                created_count += len(batch)
                self.stdout.write(f'  Created {created_count}/{to_create} properties...')
                batch = []

        # Final batch
        if batch:
            Property.objects.bulk_create(batch)
            created_count += len(batch)

        self.stdout.write(self.style.SUCCESS(f'Created {created_count} properties.'))

        # Attach images
        if skip_images or not image_cache:
            if skip_images:
                self.stdout.write('Skipping images (--no-images flag).')
            return

        self.stdout.write(f'Attaching images to properties ({images_per_prop} per property)...')

        # Get all newly created properties
        all_properties = list(Property.objects.order_by('-id')[:created_count])
        image_objects = []

        exterior_urls = [u for u in IMAGE_POOL['exterior'] if u in image_cache]
        interior_categories = ['living_room', 'kitchen', 'bedroom', 'bathroom', 'garden']
        interior_urls = []
        for cat in interior_categories:
            interior_urls.extend([(u, cat) for u in IMAGE_POOL[cat] if u in image_cache])

        if not exterior_urls:
            self.stdout.write(self.style.WARNING('No exterior images available, skipping.'))
            return

        for idx, prop in enumerate(all_properties):
            # Primary image: exterior
            ext_url = random.choice(exterior_urls)
            image_objects.append(PropertyImage(
                property=prop,
                image=ContentFile(image_cache[ext_url], name=f'bulk_{prop.id}_0.jpg'),
                order=0,
                is_primary=True,
                caption='Front of property',
            ))

            # Additional images
            if interior_urls:
                extras = random.sample(
                    interior_urls,
                    min(images_per_prop - 1, len(interior_urls))
                )
                for order, (url, cat) in enumerate(extras, start=1):
                    caption_map = {
                        'living_room': 'Living room',
                        'kitchen': 'Kitchen',
                        'bedroom': 'Bedroom',
                        'bathroom': 'Bathroom',
                        'garden': 'Garden',
                    }
                    image_objects.append(PropertyImage(
                        property=prop,
                        image=ContentFile(image_cache[url], name=f'bulk_{prop.id}_{order}.jpg'),
                        order=order,
                        is_primary=False,
                        caption=caption_map.get(cat, ''),
                    ))

            # Save in batches to avoid memory issues
            if len(image_objects) >= 200:
                PropertyImage.objects.bulk_create(image_objects)
                image_count += len(image_objects)
                image_objects = []
                self.stdout.write(f'  Attached {image_count} images...')

        if image_objects:
            PropertyImage.objects.bulk_create(image_objects)
            image_count += len(image_objects)

        self.stdout.write(self.style.SUCCESS(
            f'Done! Attached {image_count} images across {created_count} properties.'
        ))
