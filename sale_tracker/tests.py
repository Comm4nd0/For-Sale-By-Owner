"""
Comprehensive test suite for the Sale Tracker.

Covers: Stage 0 gate enforcement, ownership transfer logging,
per-user data isolation, prompt engine, document access logging,
GDPR compliance, and API endpoints.
"""

from decimal import Decimal
from datetime import timedelta
from django.test import TestCase, override_settings
from django.utils import timezone
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from rest_framework.authtoken.models import Token
from django.core.files.uploadedfile import SimpleUploadedFile

from .models import (
    Sale, Stage, Task, TaskOwnershipHistory, Document,
    DocumentAccessLog, ContactLog, Enquiry, PromptDraft,
    StageGateOverride,
)
from .seed import seed_sale
from .ownership import transfer_ownership, get_dashboard_groups
from .prompt_engine import generate_prompt
from .gdpr import export_sale_data, delete_sale_data

User = get_user_model()

TEST_REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework.authentication.TokenAuthentication',
    ],
    'DEFAULT_THROTTLE_CLASSES': [],
    'DEFAULT_THROTTLE_RATES': {},
}


# ── Helpers ────────────────────────────────────────────────────

def make_user(email='seller@test.com', password='testpass123', **kw):
    defaults = {'first_name': 'Test', 'last_name': 'User'}
    defaults.update(kw)
    return User.objects.create_user(email=email, password=password, **defaults)


def make_sale(seller, tenure='freehold', **kw):
    defaults = {
        'property_address': '1 Test Street, London, SW1A 1AA',
        'asking_price': Decimal('300000'),
        'agreed_price': Decimal('290000'),
        'tenure': tenure,
        'buyer_name': 'Test Buyer',
        'buyer_contact': 'buyer@test.com',
        'seller_conveyancer_name': 'Test Conveyancer',
        'seller_conveyancer_contact': 'conv@test.com',
        'buyer_conveyancer_name': 'Buyer Conveyancer',
        'buyer_conveyancer_contact': 'buyconv@test.com',
        'agent_name': 'Test Agent',
        'agent_contact': 'agent@test.com',
    }
    defaults.update(kw)
    sale = Sale.objects.create(seller=seller, **defaults)
    seed_sale(sale)
    return sale


def auth_client(user):
    token, _ = Token.objects.get_or_create(user=user)
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION='Token ' + token.key)
    return client


# ── Sale Model Tests ───────────────────────────────────────────

class SaleModelTests(TestCase):
    def setUp(self):
        self.user = make_user()

    def test_create_sale_with_seed_data(self):
        sale = make_sale(self.user)
        self.assertEqual(sale.stages.count(), 10)
        self.assertGreater(
            Task.objects.filter(stage__sale=sale).count(), 30,
        )
        self.assertGreater(sale.documents.count(), 20)

    def test_leasehold_sale_includes_leasehold_docs(self):
        sale = make_sale(self.user, tenure='leasehold')
        leasehold_docs = sale.documents.filter(required_tier='leasehold_only')
        self.assertGreater(leasehold_docs.count(), 0)

    def test_freehold_sale_excludes_leasehold_docs(self):
        sale = make_sale(self.user, tenure='freehold')
        leasehold_docs = sale.documents.filter(required_tier='leasehold_only')
        self.assertEqual(leasehold_docs.count(), 0)

    def test_sale_properties(self):
        sale = make_sale(self.user)
        self.assertFalse(sale.is_instructed)
        self.assertIsNone(sale.days_since_instruction)
        self.assertTrue(sale.is_leasehold is False)

    def test_stage_0_starts_in_progress(self):
        sale = make_sale(self.user)
        stage_0 = sale.stages.get(stage_number=0)
        self.assertEqual(stage_0.status, 'in_progress')
        self.assertIsNotNone(stage_0.started_at)


# ── Stage Gate Tests ───────────────────────────────────────────

@override_settings(REST_FRAMEWORK=TEST_REST_FRAMEWORK)
class StageGateTests(TestCase):
    def setUp(self):
        self.user = make_user()
        self.client = auth_client(self.user)
        self.sale = make_sale(self.user)

    def test_instruct_fails_with_missing_required_docs(self):
        """Cannot instruct when 'always' required docs are missing."""
        response = self.client.post(
            f'/api/sale-tracker/sales/{self.sale.id}/instruct/',
        )
        self.assertEqual(response.status_code, 400)
        self.assertIn('readiness', response.json())

    def test_instruct_succeeds_when_all_docs_ready(self):
        """Can instruct when all required docs are uploaded or n/a."""
        for doc in self.sale.documents.filter(required_tier='always'):
            doc.status = 'have'
            doc.save()
        for doc in self.sale.documents.filter(required_tier='if_applicable'):
            doc.status = 'not_applicable'
            doc.na_reason = 'Not applicable to this property'
            doc.save()

        response = self.client.post(
            f'/api/sale-tracker/sales/{self.sale.id}/instruct/',
        )
        self.assertEqual(response.status_code, 200)
        self.sale.refresh_from_db()
        self.assertIsNotNone(self.sale.instructed_at)

    def test_instruct_with_override(self):
        """Can override the gate with a reason."""
        response = self.client.post(
            f'/api/sale-tracker/sales/{self.sale.id}/instruct/',
            {'override': True, 'reason': 'Conveyancer advised to proceed'},
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(StageGateOverride.objects.filter(sale=self.sale).count(), 1)

    def test_instruct_already_instructed(self):
        """Cannot instruct twice."""
        self.sale.instructed_at = timezone.now()
        self.sale.save()

        response = self.client.post(
            f'/api/sale-tracker/sales/{self.sale.id}/instruct/',
        )
        self.assertEqual(response.status_code, 400)

    def test_readiness_endpoint(self):
        response = self.client.get(
            f'/api/sale-tracker/sales/{self.sale.id}/readiness/',
        )
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn('ready', data)
        self.assertIn('missing_always', data)


# ── Ownership Tests ────────────────────────────────────────────

class OwnershipTests(TestCase):
    def setUp(self):
        self.user = make_user()
        self.sale = make_sale(self.user)
        self.task = Task.objects.filter(stage__sale=self.sale).first()

    def test_transfer_creates_history(self):
        old_owner = self.task.current_owner
        transfer_ownership(self.task, 'buyer_conveyancer', 'Sent for review')

        history = TaskOwnershipHistory.objects.filter(task=self.task)
        self.assertEqual(history.count(), 1)
        self.assertEqual(history.first().from_owner, old_owner)
        self.assertEqual(history.first().to_owner, 'buyer_conveyancer')

    def test_transfer_updates_awaiting_since(self):
        transfer_ownership(self.task, 'buyer')
        self.task.refresh_from_db()
        self.assertEqual(self.task.current_owner, 'buyer')
        self.assertEqual(self.task.awaiting_since, timezone.now().date())

    def test_transfer_same_owner_noop(self):
        old_owner = self.task.current_owner
        transfer_ownership(self.task, old_owner)
        self.assertEqual(
            TaskOwnershipHistory.objects.filter(task=self.task).count(), 0,
        )

    def test_dashboard_groups(self):
        # Set one task to seller, one to buyer
        tasks = list(Task.objects.filter(stage__sale=self.sale)[:2])
        tasks[0].current_owner = 'seller'
        tasks[0].status = 'in_progress'
        tasks[0].awaiting_since = timezone.now().date()
        tasks[0].save()

        tasks[1].current_owner = 'buyer_conveyancer'
        tasks[1].status = 'waiting_on_other'
        tasks[1].awaiting_since = timezone.now().date()
        tasks[1].save()

        groups = get_dashboard_groups(self.sale)
        self.assertIn('your_turn', groups)
        self.assertIn('awaiting_others', groups)
        self.assertIn('headline_numbers', groups)


# ── Data Isolation Tests ───────────────────────────────────────

@override_settings(REST_FRAMEWORK=TEST_REST_FRAMEWORK)
class DataIsolationTests(TestCase):
    def setUp(self):
        self.user_a = make_user('a@test.com')
        self.user_b = make_user('b@test.com')
        self.sale_a = make_sale(self.user_a)
        self.sale_b = make_sale(self.user_b)
        self.client_a = auth_client(self.user_a)
        self.client_b = auth_client(self.user_b)

    def test_user_cannot_see_other_sales(self):
        response = self.client_a.get('/api/sale-tracker/sales/')
        sale_ids = [s['id'] for s in response.json()['results']]
        self.assertIn(self.sale_a.id, sale_ids)
        self.assertNotIn(self.sale_b.id, sale_ids)

    def test_user_cannot_access_other_sale_detail(self):
        response = self.client_a.get(
            f'/api/sale-tracker/sales/{self.sale_b.id}/',
        )
        self.assertEqual(response.status_code, 404)

    def test_user_cannot_access_other_sale_tasks(self):
        response = self.client_a.get(
            f'/api/sale-tracker/sales/{self.sale_b.id}/tasks/',
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.json()['results']), 0)

    def test_user_cannot_access_other_sale_documents(self):
        response = self.client_a.get(
            f'/api/sale-tracker/sales/{self.sale_b.id}/documents/',
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.json()['results']), 0)

    def test_unauthenticated_access_denied(self):
        client = APIClient()
        response = client.get('/api/sale-tracker/sales/')
        self.assertEqual(response.status_code, 401)


# ── Prompt Engine Tests ────────────────────────────────────────

class PromptEngineTests(TestCase):
    def setUp(self):
        self.user = make_user(first_name='John', last_name='Smith')
        self.sale = make_sale(self.user)

    def test_generate_prompt_level_1(self):
        draft = generate_prompt(
            self.sale, 'seller_conveyancer', '1',
        )
        self.assertIsInstance(draft, PromptDraft)
        self.assertIn('Test Conveyancer', draft.body_text)
        self.assertIn('John Smith', draft.body_text)
        self.assertIn(self.sale.property_address, draft.subject)

    def test_generate_prompt_escalation(self):
        draft = generate_prompt(
            self.sale, 'seller_conveyancer', 'escalation',
        )
        self.assertIn('SRA', draft.body_text)

    def test_all_template_keys_render(self):
        """All 18 templates should render without KeyError."""
        from .seed import PROMPT_TEMPLATES
        for (counterparty, level), _ in PROMPT_TEMPLATES.items():
            draft = generate_prompt(self.sale, counterparty, level)
            self.assertTrue(len(draft.body_text) > 0)


# ── Document Tests ─────────────────────────────────────────────

@override_settings(REST_FRAMEWORK=TEST_REST_FRAMEWORK)
class DocumentTests(TestCase):
    def setUp(self):
        self.user = make_user()
        self.client = auth_client(self.user)
        self.sale = make_sale(self.user)

    def test_upload_document(self):
        test_file = SimpleUploadedFile(
            'test.pdf', b'PDF content', content_type='application/pdf',
        )
        response = self.client.post(
            f'/api/sale-tracker/sales/{self.sale.id}/documents/',
            {'file': test_file, 'title': 'Test PDF'},
            format='multipart',
        )
        self.assertEqual(response.status_code, 201)
        doc = Document.objects.get(title='Test PDF')
        self.assertEqual(doc.status, 'have')

    def test_upload_to_existing_document(self):
        doc = self.sale.documents.filter(status='missing').first()
        test_file = SimpleUploadedFile(
            'id.jpg', b'JPEG content', content_type='image/jpeg',
        )
        response = self.client.post(
            f'/api/sale-tracker/sales/{self.sale.id}/documents/',
            {'file': test_file, 'document_id': doc.id},
            format='multipart',
        )
        self.assertEqual(response.status_code, 201)
        doc.refresh_from_db()
        self.assertEqual(doc.status, 'have')

    def test_retrieve_logs_access(self):
        doc = self.sale.documents.first()
        self.client.get(
            f'/api/sale-tracker/sales/{self.sale.id}/documents/{doc.id}/',
        )
        self.assertEqual(
            DocumentAccessLog.objects.filter(
                document=doc, action='view',
            ).count(),
            1,
        )

    def test_delete_soft_deletes(self):
        doc = self.sale.documents.first()
        doc.status = 'have'
        doc.file = SimpleUploadedFile('f.pdf', b'x')
        doc.save()

        self.client.delete(
            f'/api/sale-tracker/sales/{self.sale.id}/documents/{doc.id}/',
        )
        doc.refresh_from_db()
        self.assertEqual(doc.status, 'missing')
        self.assertFalse(bool(doc.file))

    def test_checklist_endpoint(self):
        response = self.client.get(
            f'/api/sale-tracker/sales/{self.sale.id}/documents/checklist/',
        )
        self.assertEqual(response.status_code, 200)
        self.assertGreater(len(response.json()), 0)


# ── Celery Task Tests ──────────────────────────────────────────

class CeleryTaskTests(TestCase):
    def setUp(self):
        self.user = make_user()
        self.sale = make_sale(self.user)
        self.sale.instructed_at = timezone.now()
        self.sale.save()

    def test_nightly_scan_detects_thresholds(self):
        from .tasks import nightly_sale_tracker_scan

        task = Task.objects.filter(
            stage__sale=self.sale,
        ).exclude(current_owner='seller').first()
        task.status = 'in_progress'
        task.awaiting_since = timezone.now().date() - timedelta(days=6)
        task.save()

        count = nightly_sale_tracker_scan()
        self.assertGreaterEqual(count, 1)


# ── GDPR Tests ─────────────────────────────────────────────────

class GDPRTests(TestCase):
    def setUp(self):
        self.user = make_user()
        self.sale = make_sale(self.user)

    def test_export_returns_all_data(self):
        data = export_sale_data(self.user)
        self.assertIn('sales', data)
        self.assertEqual(len(data['sales']), 1)
        sale_data = data['sales'][0]
        self.assertIn('stages', sale_data)
        self.assertIn('documents', sale_data)

    def test_delete_anonymises_data(self):
        delete_sale_data(self.user)
        self.sale.refresh_from_db()
        self.assertEqual(self.sale.buyer_name, 'Deleted')
        self.assertEqual(self.sale.status, 'cancelled')


# ── API Endpoint Tests ─────────────────────────────────────────

@override_settings(REST_FRAMEWORK=TEST_REST_FRAMEWORK)
class APIEndpointTests(TestCase):
    def setUp(self):
        self.user = make_user()
        self.client = auth_client(self.user)

    def test_create_sale(self):
        response = self.client.post('/api/sale-tracker/sales/', {
            'property_address': '99 New Street, London, E1 1AA',
            'tenure': 'freehold',
        })
        self.assertEqual(response.status_code, 201)
        sale = Sale.objects.get(property_address='99 New Street, London, E1 1AA')
        self.assertGreater(sale.stages.count(), 0)

    def test_list_sales(self):
        make_sale(self.user)
        response = self.client.get('/api/sale-tracker/sales/')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['count'], 1)

    def test_sale_detail(self):
        sale = make_sale(self.user)
        response = self.client.get(f'/api/sale-tracker/sales/{sale.id}/')
        self.assertEqual(response.status_code, 200)
        self.assertIn('stages', response.json())

    def test_dashboard_endpoint(self):
        sale = make_sale(self.user)
        response = self.client.get(f'/api/sale-tracker/sales/{sale.id}/dashboard/')
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn('your_turn', data)
        self.assertIn('awaiting_others', data)
        self.assertIn('headline_numbers', data)

    def test_timeline_endpoint(self):
        sale = make_sale(self.user)
        response = self.client.get(f'/api/sale-tracker/sales/{sale.id}/timeline/')
        self.assertEqual(response.status_code, 200)

    def test_task_reassign(self):
        sale = make_sale(self.user)
        task = Task.objects.filter(stage__sale=sale).first()
        response = self.client.post(
            f'/api/sale-tracker/sales/{sale.id}/tasks/{task.id}/reassign/',
            {'new_owner': 'buyer_conveyancer', 'reason': 'Sent for review'},
        )
        self.assertEqual(response.status_code, 200)
        task.refresh_from_db()
        self.assertEqual(task.current_owner, 'buyer_conveyancer')

    def test_task_complete(self):
        sale = make_sale(self.user)
        task = Task.objects.filter(stage__sale=sale).first()
        response = self.client.post(
            f'/api/sale-tracker/sales/{sale.id}/tasks/{task.id}/complete/',
        )
        self.assertEqual(response.status_code, 200)
        task.refresh_from_db()
        self.assertEqual(task.status, 'done')

    def test_contact_log_crud(self):
        sale = make_sale(self.user)
        response = self.client.post(
            f'/api/sale-tracker/sales/{sale.id}/contact-log/',
            {
                'channel': 'email',
                'counterparty': 'Test Conveyancer',
                'summary': 'Discussed progress',
            },
        )
        self.assertEqual(response.status_code, 201)

        response = self.client.get(
            f'/api/sale-tracker/sales/{sale.id}/contact-log/',
        )
        self.assertEqual(response.status_code, 200)

    def test_enquiry_crud(self):
        sale = make_sale(self.user)
        response = self.client.post(
            f'/api/sale-tracker/sales/{sale.id}/enquiries/',
            {
                'raised_by': 'Buyer Conveyancer',
                'question': 'Was the extension built under building regs?',
                'current_owner': 'seller',
            },
        )
        self.assertEqual(response.status_code, 201)

    def test_prompt_generate(self):
        sale = make_sale(self.user)
        response = self.client.post(
            f'/api/sale-tracker/sales/{sale.id}/prompts/generate/',
            {
                'counterparty_type': 'seller_conveyancer',
                'level': '1',
            },
        )
        self.assertEqual(response.status_code, 201)
        data = response.json()
        self.assertIn('subject', data)
        self.assertIn('body_text', data)

    def test_gdpr_export(self):
        make_sale(self.user)
        response = self.client.get('/api/sale-tracker/gdpr/export/')
        self.assertEqual(response.status_code, 200)
        self.assertIn('sales', response.json())

    def test_gdpr_delete(self):
        make_sale(self.user)
        response = self.client.post('/api/sale-tracker/gdpr/delete/')
        self.assertEqual(response.status_code, 204)
