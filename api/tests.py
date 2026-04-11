from datetime import date, time
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from rest_framework import status
from rest_framework.test import APIClient

from .models import (
    Property, PropertyImage, PropertyFloorplan, PropertyFeature,
    PriceHistory, SavedProperty, PropertyView,
    ViewingRequest, SavedSearch, PushNotificationDevice,
    ChatRoom, ChatMessage,
)

User = get_user_model()

# Common test overrides
TEST_STORAGES = {
    'default': {'BACKEND': 'django.core.files.storage.InMemoryStorage'},
    'staticfiles': {'BACKEND': 'django.contrib.staticfiles.storage.StaticFilesStorage'},
}

TEST_REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': ['rest_framework.authentication.TokenAuthentication'],
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 20,
    'DEFAULT_THROTTLE_CLASSES': [],
    'DEFAULT_THROTTLE_RATES': {},
}


# ─── Helpers ──────────────────────────────────────────────────────────────────

def make_user(email='buyer@test.com', password='testpass123', **kw):
    return User.objects.create_user(email=email, password=password, **kw)


def make_property(owner, **kw):
    defaults = dict(
        title='Test House', property_type='detached', status='active',
        price=Decimal('250000'), address_line_1='1 Test St',
        city='London', postcode='SW1A 1AA', bedrooms=3, bathrooms=2,
    )
    defaults.update(kw)
    return Property.objects.create(owner=owner, **defaults)


def auth_client(user):
    """Return an APIClient authenticated via token."""
    from rest_framework.authtoken.models import Token
    token, _ = Token.objects.get_or_create(user=user)
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION='Token ' + token.key)
    return client


# ─── Model Tests ──────────────────────────────────────────────────────────────

class UserModelTest(TestCase):
    def test_create_user(self):
        user = make_user()
        self.assertEqual(user.email, 'buyer@test.com')
        self.assertTrue(user.check_password('testpass123'))
        self.assertFalse(user.is_staff)

    def test_create_superuser(self):
        su = User.objects.create_superuser(email='admin@test.com', password='admin123')
        self.assertTrue(su.is_staff)
        self.assertTrue(su.is_superuser)

    def test_email_required(self):
        with self.assertRaises(ValueError):
            User.objects.create_user(email='', password='x')

    def test_str(self):
        user = make_user()
        self.assertEqual(str(user), 'buyer@test.com')


class PropertyModelTest(TestCase):
    def setUp(self):
        self.owner = make_user(email='owner@test.com')

    def test_slug_auto_generated(self):
        prop = make_property(self.owner, title='Lovely Cottage')
        self.assertTrue(prop.slug)
        self.assertIn('lovely-cottage', prop.slug)

    def test_slug_unique(self):
        p1 = make_property(self.owner, title='Same Title')
        p2 = make_property(self.owner, title='Same Title')
        self.assertNotEqual(p1.slug, p2.slug)

    def test_str(self):
        prop = make_property(self.owner, title='My House')
        self.assertIn('My House', str(prop))

    def test_ordering(self):
        p1 = make_property(self.owner, title='First')
        p2 = make_property(self.owner, title='Second')
        props = list(Property.objects.all())
        self.assertEqual(props[0], p2)  # newest first


@override_settings(STORAGES=TEST_STORAGES)
class PropertyImageModelTest(TestCase):
    def setUp(self):
        self.owner = make_user(email='owner@test.com')
        self.prop = make_property(self.owner)

    def test_first_image_auto_primary(self):
        from django.core.files.uploadedfile import SimpleUploadedFile
        img = PropertyImage.objects.create(
            property=self.prop,
            image=SimpleUploadedFile('test.jpg', b'\xff\xd8\xff\xe0', content_type='image/jpeg'),
        )
        self.assertTrue(img.is_primary)


class PriceHistoryModelTest(TestCase):
    def test_str(self):
        owner = make_user(email='owner@test.com')
        prop = make_property(owner)
        ph = PriceHistory.objects.create(property=prop, price=Decimal('300000'))
        self.assertIn('300000', str(ph))


class PropertyFeatureModelTest(TestCase):
    def test_str(self):
        f = PropertyFeature.objects.create(name='Garden', icon='🌿')
        self.assertEqual(str(f), 'Garden')

    def test_ordering(self):
        PropertyFeature.objects.create(name='Zzz')
        PropertyFeature.objects.create(name='Aaa')
        first = PropertyFeature.objects.first()
        self.assertEqual(first.name, 'Aaa')


class SavedPropertyModelTest(TestCase):
    def test_unique_together(self):
        owner = make_user(email='owner@test.com')
        buyer = make_user(email='buyer@test.com')
        prop = make_property(owner)
        SavedProperty.objects.create(user=buyer, property=prop)
        from django.db import IntegrityError
        with self.assertRaises(IntegrityError):
            SavedProperty.objects.create(user=buyer, property=prop)


class ViewingRequestModelTest(TestCase):
    def test_str_and_defaults(self):
        owner = make_user(email='owner@test.com')
        buyer = make_user(email='buyer@test.com')
        prop = make_property(owner)
        v = ViewingRequest.objects.create(
            property=prop, requester=buyer, preferred_date=date(2026, 4, 1),
            preferred_time=time(10, 0), name='Alice', email='alice@x.com',
        )
        self.assertEqual(v.status, 'pending')
        self.assertIn('Alice', str(v))


class SavedSearchModelTest(TestCase):
    def test_str_with_name(self):
        user = make_user()
        ss = SavedSearch.objects.create(user=user, name='London search')
        self.assertEqual(str(ss), 'London search')

    def test_str_without_name(self):
        user = make_user()
        ss = SavedSearch.objects.create(user=user, location='Manchester', min_bedrooms=2)
        self.assertIn('Manchester', str(ss))
        self.assertIn('2+ bed', str(ss))


# ─── API Tests ────────────────────────────────────────────────────────────────

@override_settings(REST_FRAMEWORK=TEST_REST_FRAMEWORK, STORAGES=TEST_STORAGES)
class PropertyAPITest(TestCase):
    def setUp(self):
        self.owner = make_user(email='owner@test.com')
        self.buyer = make_user(email='buyer@test.com')
        self.prop = make_property(self.owner)
        self.owner_client = auth_client(self.owner)
        self.buyer_client = auth_client(self.buyer)
        self.anon_client = APIClient()

    # ── Property CRUD ────────────────────────────────────────────────────

    def test_list_properties_anon(self):
        res = self.anon_client.get('/api/properties/')
        self.assertEqual(res.status_code, 200)

    def test_list_properties_only_active_for_anon(self):
        make_property(self.owner, title='Draft', status='draft')
        res = self.anon_client.get('/api/properties/')
        titles = [p['title'] for p in res.data['results']]
        self.assertNotIn('Draft', titles)

    def test_mine_filter_only_shows_own_properties(self):
        """mine=true should only show the current user's properties, not all."""
        make_property(self.buyer, title='Buyer Property')
        res = self.buyer_client.get('/api/properties/?mine=true')
        self.assertEqual(res.status_code, 200)
        titles = [p['title'] for p in res.data['results']]
        self.assertIn('Buyer Property', titles)
        self.assertNotIn('Test House', titles)  # owner's property

    def test_create_property_requires_auth(self):
        res = self.anon_client.post('/api/properties/', {})
        self.assertEqual(res.status_code, 401)

    def test_create_property(self):
        data = {
            'title': 'New Build', 'property_type': 'flat', 'price': '180000',
            'address_line_1': '5 New St', 'city': 'Leeds', 'postcode': 'LS1 1AA',
            'bedrooms': 2, 'bathrooms': 1, 'reception_rooms': 1,
        }
        res = self.owner_client.post('/api/properties/', data, format='json')
        self.assertEqual(res.status_code, 201)
        self.assertTrue(res.data['slug'])
        # Initial price history recorded
        prop = Property.objects.get(pk=res.data['id'])
        self.assertEqual(prop.price_history.count(), 1)

    def test_create_property_phase1_minimum(self):
        """Phase 1 should publish with only title, type, price, postcode, bedrooms."""
        data = {
            'title': 'Phase 1 House', 'property_type': 'detached', 'price': '350000',
            'postcode': 'BS1 1AA', 'bedrooms': 3,
        }
        res = self.owner_client.post('/api/properties/', data, format='json')
        self.assertEqual(res.status_code, 201, res.data)
        prop = Property.objects.get(pk=res.data['id'])
        # No address_line_1 / city required yet
        self.assertEqual(prop.address_line_1, '')
        self.assertEqual(prop.city, '')
        self.assertEqual(prop.bedrooms, 3)

    def test_retrieve_property(self):
        res = self.anon_client.get(f'/api/properties/{self.prop.id}/')
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data['title'], 'Test House')

    def test_retrieve_creates_view(self):
        count_before = PropertyView.objects.count()
        self.anon_client.get(f'/api/properties/{self.prop.id}/')
        self.assertEqual(PropertyView.objects.count(), count_before + 1)

    def test_update_property_owner_only(self):
        res = self.buyer_client.patch(
            f'/api/properties/{self.prop.id}/', {'title': 'Hacked'}, format='json'
        )
        self.assertEqual(res.status_code, 403)

    def test_update_property(self):
        res = self.owner_client.patch(
            f'/api/properties/{self.prop.id}/', {'title': 'Updated'}, format='json'
        )
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data['title'], 'Updated')

    def test_price_change_tracking(self):
        # Set initial price history
        PriceHistory.objects.create(property=self.prop, price=self.prop.price)
        res = self.owner_client.patch(
            f'/api/properties/{self.prop.id}/', {'price': '275000'}, format='json'
        )
        self.assertEqual(res.status_code, 200)
        self.assertEqual(self.prop.price_history.count(), 2)

    def test_price_no_change_no_history(self):
        PriceHistory.objects.create(property=self.prop, price=self.prop.price)
        count = self.prop.price_history.count()
        self.owner_client.patch(
            f'/api/properties/{self.prop.id}/', {'title': 'Same price'}, format='json'
        )
        self.assertEqual(self.prop.price_history.count(), count)

    def test_delete_property(self):
        res = self.owner_client.delete(f'/api/properties/{self.prop.id}/')
        self.assertEqual(res.status_code, 204)

    # ── Search/Filter ────────────────────────────────────────────────────

    def test_filter_by_city(self):
        make_property(self.owner, title='Manchester house', city='Manchester')
        res = self.anon_client.get('/api/properties/?city=Manchester')
        self.assertEqual(len(res.data['results']), 1)
        self.assertEqual(res.data['results'][0]['city'], 'Manchester')

    def test_filter_by_location(self):
        res = self.anon_client.get('/api/properties/?location=London')
        self.assertEqual(len(res.data['results']), 1)

    def test_filter_by_price_range(self):
        res = self.anon_client.get('/api/properties/?min_price=200000&max_price=300000')
        self.assertEqual(len(res.data['results']), 1)

    def test_filter_by_bedrooms(self):
        res = self.anon_client.get('/api/properties/?min_bedrooms=5')
        self.assertEqual(len(res.data['results']), 0)

    def test_filter_by_property_type(self):
        res = self.anon_client.get('/api/properties/?property_type=flat')
        self.assertEqual(len(res.data['results']), 0)

    # ── Similar ──────────────────────────────────────────────────────────

    def test_similar_properties(self):
        make_property(self.owner, title='Similar', city='London', price=Decimal('260000'))
        res = self.buyer_client.get(f'/api/properties/{self.prop.id}/similar/')
        self.assertEqual(res.status_code, 200)
        self.assertTrue(len(res.data) >= 1)

    # ── Features ─────────────────────────────────────────────────────────

    def test_features_list(self):
        PropertyFeature.objects.create(name='Garden')
        PropertyFeature.objects.create(name='Parking')
        res = self.anon_client.get('/api/features/')
        self.assertEqual(res.status_code, 200)
        self.assertEqual(len(res.data), 2)

    def test_create_property_with_features(self):
        f1 = PropertyFeature.objects.create(name='Garden')
        f2 = PropertyFeature.objects.create(name='Parking')
        data = {
            'title': 'Featured House', 'property_type': 'detached', 'price': '300000',
            'address_line_1': '1 X St', 'city': 'York', 'postcode': 'YO1 1AA',
            'bedrooms': 4, 'bathrooms': 2, 'reception_rooms': 2,
            'features': [f1.id, f2.id],
        }
        res = self.owner_client.post('/api/properties/', data, format='json')
        self.assertEqual(res.status_code, 201)
        prop = Property.objects.get(pk=res.data['id'])
        self.assertEqual(prop.features.count(), 2)

    # ── Phase 2 field patching ──────────────────────────────────────────

    def test_patch_property_phase2_fields(self):
        """PATCH should accept Phase 2 fields like tenure, flood_risk, garden_size_sqm."""
        res = self.owner_client.patch(
            f'/api/properties/{self.prop.id}/',
            {
                'tenure': 'freehold',
                'flood_risk': 'none',
                'garden_size_sqm': '120.5',
                'garden_orientation': 's',
                'council_tax_band': 'D',
                'chain_status': 'no_chain',
                'heating_type': 'gas_central',
            },
            format='json',
        )
        self.assertEqual(res.status_code, 200, res.data)
        self.prop.refresh_from_db()
        self.assertEqual(self.prop.tenure, 'freehold')
        self.assertEqual(self.prop.flood_risk, 'none')
        self.assertEqual(str(self.prop.garden_size_sqm), '120.50')
        self.assertEqual(self.prop.council_tax_band, 'D')
        self.assertEqual(self.prop.chain_status, 'no_chain')

    def test_patch_property_extras_booleans(self):
        res = self.owner_client.patch(
            f'/api/properties/{self.prop.id}/',
            {'ev_charging': True, 'smart_home': True, 'home_office': True},
            format='json',
        )
        self.assertEqual(res.status_code, 200)
        self.prop.refresh_from_db()
        self.assertTrue(self.prop.ev_charging)
        self.assertTrue(self.prop.smart_home)
        self.assertTrue(self.prop.home_office)

    # ── What3Words validation ───────────────────────────────────────────

    def test_validate_what3words_accepts_valid(self):
        res = self.owner_client.patch(
            f'/api/properties/{self.prop.id}/',
            {'what3words': 'index.home.raft'},
            format='json',
        )
        self.assertEqual(res.status_code, 200, res.data)
        self.prop.refresh_from_db()
        self.assertEqual(self.prop.what3words, 'index.home.raft')

    def test_validate_what3words_normalises_case(self):
        res = self.owner_client.patch(
            f'/api/properties/{self.prop.id}/',
            {'what3words': 'Index.Home.Raft'},
            format='json',
        )
        self.assertEqual(res.status_code, 200, res.data)
        self.prop.refresh_from_db()
        self.assertEqual(self.prop.what3words, 'index.home.raft')

    def test_validate_what3words_rejects_invalid(self):
        res = self.owner_client.patch(
            f'/api/properties/{self.prop.id}/',
            {'what3words': 'not a valid w3w value 123'},
            format='json',
        )
        self.assertEqual(res.status_code, 400)
        self.assertIn('what3words', res.data)

    # ── Listing quality score uses new fields ──────────────────────────

    def test_listing_quality_score_rewards_new_fields(self):
        score_before = self.prop.listing_quality_score()['score']
        self.prop.tenure = 'freehold'
        self.prop.flood_risk = 'none'
        self.prop.council_tax_band = 'D'
        self.prop.heating_type = 'gas_central'
        self.prop.chain_status = 'no_chain'
        self.prop.save()
        score_after = self.prop.listing_quality_score()['score']
        self.assertGreater(score_after, score_before)

    # ── Postcode lookup ─────────────────────────────────────────────────

    def test_postcode_lookup_ok(self):
        from unittest.mock import patch
        fake_payload = {
            'status': 200,
            'result': {
                'postcode': 'SW1A 1AA',
                'latitude': 51.501009,
                'longitude': -0.141588,
                'admin_district': 'Westminster',
                'admin_county': None,
                'region': 'London',
                'country': 'England',
            },
        }

        class FakeResponse:
            status_code = 200

            def json(self_inner):
                return fake_payload

        with patch('api.views.requests.get', return_value=FakeResponse()):
            res = self.anon_client.get('/api/postcode-lookup/SW1A1AA/')
        self.assertEqual(res.status_code, 200, res.data)
        self.assertEqual(res.data['postcode'], 'SW1A 1AA')
        self.assertAlmostEqual(res.data['latitude'], 51.501009, places=4)
        self.assertEqual(res.data['admin_district'], 'Westminster')

    def test_postcode_lookup_not_found(self):
        from unittest.mock import patch

        class FakeResponse:
            status_code = 404

            def json(self_inner):
                return {'status': 404, 'error': 'Postcode not found'}

        with patch('api.views.requests.get', return_value=FakeResponse()):
            res = self.anon_client.get('/api/postcode-lookup/ZZ1ZZ1/')
        self.assertEqual(res.status_code, 404)

    def test_postcode_lookup_service_down(self):
        from unittest.mock import patch
        import requests as real_requests

        with patch('api.views.requests.get', side_effect=real_requests.ConnectionError('boom')):
            res = self.anon_client.get('/api/postcode-lookup/SW1A1AA/')
        self.assertEqual(res.status_code, 503)

    # ── Brief description mode ──────────────────────────────────────────

    def test_generate_description_brief_mode(self):
        res = self.owner_client.post(
            '/api/generate-description/',
            {
                'brief': True,
                'property_type': 'detached',
                'bedrooms': 4,
                'location': 'Bristol',
                'features': ['Garden', 'Garage', 'Solar panels'],
            },
            format='json',
        )
        self.assertEqual(res.status_code, 200, res.data)
        text = res.data['description']
        self.assertTrue(res.data.get('brief'))
        self.assertLessEqual(len(text), 300)
        self.assertIn('4 bedroom', text.lower())
        self.assertIn('bristol', text.lower())

    def test_generate_description_professional_still_works(self):
        """Long-form path should be unchanged."""
        res = self.owner_client.post(
            '/api/generate-description/',
            {
                'property_type': 'detached', 'bedrooms': 3, 'bathrooms': 2,
                'reception_rooms': 2, 'square_feet': 1500,
                'features': ['Garden'], 'location': 'Bath',
                'epc_rating': 'C', 'tone': 'professional',
            },
            format='json',
        )
        self.assertEqual(res.status_code, 200, res.data)
        self.assertFalse(res.data.get('brief'))
        self.assertGreater(len(res.data['description']), 150)


@override_settings(REST_FRAMEWORK=TEST_REST_FRAMEWORK, STORAGES=TEST_STORAGES)
class SavedPropertyAPITest(TestCase):
    def setUp(self):
        self.owner = make_user(email='owner@test.com')
        self.buyer = make_user(email='buyer@test.com')
        self.prop = make_property(self.owner)
        self.client = auth_client(self.buyer)

    def test_toggle_save(self):
        res = self.client.post(f'/api/properties/{self.prop.id}/save/')
        self.assertEqual(res.status_code, 201)
        self.assertTrue(res.data['saved'])

    def test_toggle_unsave(self):
        SavedProperty.objects.create(user=self.buyer, property=self.prop)
        res = self.client.delete(f'/api/properties/{self.prop.id}/save/')
        self.assertEqual(res.status_code, 200)
        self.assertFalse(res.data['saved'])

    def test_save_not_found(self):
        res = self.client.post('/api/properties/99999/save/')
        self.assertEqual(res.status_code, 404)

    def test_list_saved(self):
        SavedProperty.objects.create(user=self.buyer, property=self.prop)
        res = self.client.get('/api/saved/')
        self.assertEqual(res.status_code, 200)
        results = res.data['results'] if 'results' in res.data else res.data
        self.assertEqual(len(results), 1)

    def test_save_requires_auth(self):
        res = APIClient().post(f'/api/properties/{self.prop.id}/save/')
        self.assertEqual(res.status_code, 401)


@override_settings(
    REST_FRAMEWORK=TEST_REST_FRAMEWORK,
    STORAGES=TEST_STORAGES,
    EMAIL_BACKEND='django.core.mail.backends.locmem.EmailBackend',
)
class ViewingRequestAPITest(TestCase):
    def setUp(self):
        self.owner = make_user(email='owner@test.com')
        self.buyer = make_user(email='buyer@test.com')
        self.prop = make_property(self.owner)
        self.buyer_client = auth_client(self.buyer)
        self.owner_client = auth_client(self.owner)

    def test_create_viewing_request(self):
        data = {
            'property': self.prop.id, 'name': 'Bob', 'email': 'bob@x.com',
            'preferred_date': '2026-04-15', 'preferred_time': '10:00',
        }
        res = self.buyer_client.post('/api/viewings/', data, format='json')
        self.assertEqual(res.status_code, 201)
        self.assertEqual(res.data['status'], 'pending')

    def test_cannot_view_own_property(self):
        data = {
            'property': self.prop.id, 'name': 'Self', 'email': 'x@x.com',
            'preferred_date': '2026-04-15', 'preferred_time': '10:00',
        }
        res = self.owner_client.post('/api/viewings/', data, format='json')
        self.assertEqual(res.status_code, 400)

    def test_owner_confirm_viewing(self):
        v = ViewingRequest.objects.create(
            property=self.prop, requester=self.buyer,
            preferred_date=date(2026, 4, 15), preferred_time=time(10, 0),
            name='Bob', email='bob@x.com',
        )
        res = self.owner_client.patch(
            f'/api/viewings/{v.id}/update_status/',
            {'status': 'confirmed', 'seller_notes': 'See you then!'},
            format='json',
        )
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data['status'], 'confirmed')
        self.assertEqual(res.data['seller_notes'], 'See you then!')

    def test_owner_decline_viewing(self):
        v = ViewingRequest.objects.create(
            property=self.prop, requester=self.buyer,
            preferred_date=date(2026, 4, 15), preferred_time=time(10, 0),
            name='Bob', email='bob@x.com',
        )
        res = self.owner_client.patch(
            f'/api/viewings/{v.id}/update_status/', {'status': 'declined'}, format='json',
        )
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data['status'], 'declined')

    def test_non_owner_cannot_update_status(self):
        v = ViewingRequest.objects.create(
            property=self.prop, requester=self.buyer,
            preferred_date=date(2026, 4, 15), preferred_time=time(10, 0),
            name='Bob', email='bob@x.com',
        )
        res = self.buyer_client.patch(
            f'/api/viewings/{v.id}/update_status/', {'status': 'confirmed'}, format='json',
        )
        self.assertEqual(res.status_code, 403)

    def test_invalid_status(self):
        v = ViewingRequest.objects.create(
            property=self.prop, requester=self.buyer,
            preferred_date=date(2026, 4, 15), preferred_time=time(10, 0),
            name='Bob', email='bob@x.com',
        )
        res = self.owner_client.patch(
            f'/api/viewings/{v.id}/update_status/', {'status': 'invalid'}, format='json',
        )
        self.assertEqual(res.status_code, 400)

    def test_received_viewings(self):
        ViewingRequest.objects.create(
            property=self.prop, requester=self.buyer,
            preferred_date=date(2026, 4, 15), preferred_time=time(10, 0),
            name='Bob', email='bob@x.com',
        )
        res = self.owner_client.get('/api/viewings/received/')
        self.assertEqual(res.status_code, 200)
        results = res.data['results'] if 'results' in res.data else res.data
        self.assertEqual(len(results), 1)


@override_settings(REST_FRAMEWORK=TEST_REST_FRAMEWORK, STORAGES=TEST_STORAGES)
class SavedSearchAPITest(TestCase):
    def setUp(self):
        self.user = make_user()
        self.client = auth_client(self.user)

    def test_create_saved_search(self):
        data = {
            'name': 'London 3 bed', 'location': 'London',
            'min_bedrooms': 3, 'email_alerts': True,
        }
        res = self.client.post('/api/saved-searches/', data, format='json')
        self.assertEqual(res.status_code, 201)
        self.assertEqual(res.data['name'], 'London 3 bed')

    def test_list_saved_searches(self):
        SavedSearch.objects.create(user=self.user, name='Test', location='York')
        res = self.client.get('/api/saved-searches/')
        self.assertEqual(res.status_code, 200)
        results = res.data['results'] if 'results' in res.data else res.data
        self.assertEqual(len(results), 1)

    def test_delete_saved_search(self):
        ss = SavedSearch.objects.create(user=self.user, name='Del')
        res = self.client.delete(f'/api/saved-searches/{ss.id}/')
        self.assertEqual(res.status_code, 204)
        self.assertFalse(SavedSearch.objects.filter(pk=ss.id).exists())

    def test_cannot_see_others_searches(self):
        other = make_user(email='other@test.com')
        SavedSearch.objects.create(user=other, name='Other search')
        res = self.client.get('/api/saved-searches/')
        results = res.data['results'] if 'results' in res.data else res.data
        self.assertEqual(len(results), 0)


@override_settings(REST_FRAMEWORK=TEST_REST_FRAMEWORK, STORAGES=TEST_STORAGES)
class DashboardStatsAPITest(TestCase):
    def setUp(self):
        self.owner = make_user(email='owner@test.com')
        self.buyer = make_user(email='buyer@test.com')
        self.prop = make_property(self.owner)
        self.owner_client = auth_client(self.owner)

    def test_dashboard_stats(self):
        # Create some data
        room = ChatRoom.objects.create(
            property=self.prop, buyer=self.buyer, seller=self.owner,
        )
        ChatMessage.objects.create(room=room, sender=self.buyer, message='Hi')
        PropertyView.objects.create(property=self.prop, viewer_ip='127.0.0.1')
        SavedProperty.objects.create(user=self.buyer, property=self.prop)

        res = self.owner_client.get('/api/dashboard/stats/')
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data['total_listings'], 1)
        self.assertEqual(res.data['active_listings'], 1)
        self.assertEqual(res.data['total_views'], 1)
        self.assertEqual(res.data['total_messages'], 1)
        self.assertEqual(res.data['unread_messages'], 1)
        self.assertEqual(res.data['total_saves'], 1)

    def test_dashboard_requires_auth(self):
        res = APIClient().get('/api/dashboard/stats/')
        self.assertEqual(res.status_code, 401)


@override_settings(REST_FRAMEWORK=TEST_REST_FRAMEWORK, STORAGES=TEST_STORAGES)
class UserProfileAPITest(TestCase):
    def setUp(self):
        self.user = make_user(first_name='Jane', last_name='Doe')
        self.client = auth_client(self.user)

    def test_get_profile(self):
        res = self.client.get('/api/profile/')
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data['first_name'], 'Jane')
        self.assertEqual(res.data['email'], 'buyer@test.com')

    def test_update_profile(self):
        res = self.client.patch(
            '/api/profile/', {'first_name': 'Janet', 'phone': '07700 000000'}, format='json'
        )
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data['first_name'], 'Janet')
        self.assertEqual(res.data['phone'], '07700 000000')

    def test_cannot_change_email(self):
        res = self.client.patch(
            '/api/profile/', {'email': 'hacked@x.com'}, format='json'
        )
        self.assertEqual(res.status_code, 200)
        self.user.refresh_from_db()
        self.assertEqual(self.user.email, 'buyer@test.com')  # unchanged

    def test_profile_requires_auth(self):
        res = APIClient().get('/api/profile/')
        self.assertEqual(res.status_code, 401)


@override_settings(REST_FRAMEWORK=TEST_REST_FRAMEWORK, STORAGES=TEST_STORAGES)
class PushDeviceAPITest(TestCase):
    def setUp(self):
        self.user = make_user()
        self.client = auth_client(self.user)

    def test_register_device(self):
        res = self.client.post('/api/push/register/', {'token': 'abc123', 'platform': 'web'}, format='json')
        self.assertEqual(res.status_code, 200)
        self.assertTrue(res.data['registered'])
        self.assertTrue(res.data['created'])

    def test_register_duplicate(self):
        self.client.post('/api/push/register/', {'token': 'abc123'}, format='json')
        res = self.client.post('/api/push/register/', {'token': 'abc123'}, format='json')
        self.assertEqual(res.status_code, 200)
        self.assertFalse(res.data['created'])

    def test_register_no_token(self):
        res = self.client.post('/api/push/register/', {}, format='json')
        self.assertEqual(res.status_code, 400)


# ─── Page Tests ───────────────────────────────────────────────────────────────

@override_settings(STORAGES=TEST_STORAGES)
class PageTests(TestCase):
    """Smoke tests for all HTML page routes (200 status)."""

    def test_home(self):
        self.assertEqual(self.client.get('/').status_code, 200)

    def test_search(self):
        self.assertEqual(self.client.get('/search/').status_code, 200)

    def test_login(self):
        self.assertEqual(self.client.get('/login/').status_code, 200)

    def test_register(self):
        self.assertEqual(self.client.get('/register/').status_code, 200)

    def test_property_create(self):
        self.assertEqual(self.client.get('/properties/new/').status_code, 200)

    def test_terms(self):
        self.assertEqual(self.client.get('/terms/').status_code, 200)

    def test_privacy(self):
        self.assertEqual(self.client.get('/privacy/').status_code, 200)

    def test_cookies(self):
        self.assertEqual(self.client.get('/cookies/').status_code, 200)

    def test_profile(self):
        self.assertEqual(self.client.get('/profile/').status_code, 200)

    def test_forgot_password(self):
        self.assertEqual(self.client.get('/forgot-password/').status_code, 200)

    def test_password_reset_confirm(self):
        self.assertEqual(self.client.get('/password-reset/abc/def/').status_code, 200)

    def test_dashboard(self):
        self.assertEqual(self.client.get('/dashboard/').status_code, 200)

    def test_saved(self):
        self.assertEqual(self.client.get('/saved/').status_code, 200)

    def test_my_listings(self):
        self.assertEqual(self.client.get('/my-listings/').status_code, 200)

    def test_property_detail(self):
        owner = make_user(email='owner@test.com')
        prop = make_property(owner)
        self.assertEqual(self.client.get(f'/properties/{prop.id}/').status_code, 200)

    def test_property_detail_slug(self):
        owner = make_user(email='owner@test.com')
        prop = make_property(owner)
        self.assertEqual(self.client.get(f'/properties/{prop.slug}/').status_code, 200)

    def test_property_edit(self):
        owner = make_user(email='owner@test.com')
        prop = make_property(owner)
        self.assertEqual(self.client.get(f'/properties/{prop.id}/edit/').status_code, 200)
