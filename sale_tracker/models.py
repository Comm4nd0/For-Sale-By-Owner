from django.conf import settings
from django.db import models
from django.utils import timezone


# ── Ownership choices ──────────────────────────────────────────

OWNER_CHOICES = [
    ('seller', 'Seller'),
    ('seller_conveyancer', 'Seller\'s Conveyancer'),
    ('buyer', 'Buyer'),
    ('buyer_conveyancer', 'Buyer\'s Conveyancer'),
    ('estate_agent', 'Estate Agent'),
    ('lender', 'Lender'),
    ('freeholder_or_managing_agent', 'Freeholder / Managing Agent'),
    ('surveyor', 'Surveyor'),
    ('local_authority_or_search_provider', 'Local Authority / Search Provider'),
    ('other', 'Other'),
]


# ── Sale ───────────────────────────────────────────────────────

class Sale(models.Model):
    TENURE_CHOICES = [
        ('freehold', 'Freehold'),
        ('leasehold', 'Leasehold'),
        ('share_of_freehold', 'Share of Freehold'),
    ]
    BUYER_POSITION_CHOICES = [
        ('cash', 'Cash'),
        ('mortgage', 'Mortgage'),
        ('chain', 'Chain'),
    ]
    STATUS_CHOICES = [
        ('active', 'Active'),
        ('completed', 'Completed'),
        ('cancelled', 'Cancelled'),
    ]
    NOTIFICATION_FREQUENCY_CHOICES = [
        ('realtime', 'Real-time'),
        ('daily_digest', 'Daily Digest'),
        ('weekly_digest', 'Weekly Digest'),
    ]

    seller = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
        related_name='sale_tracker_sales',
    )
    property_address = models.CharField(max_length=500)
    asking_price = models.DecimalField(
        max_digits=12, decimal_places=2, null=True, blank=True,
    )
    agreed_price = models.DecimalField(
        max_digits=12, decimal_places=2, null=True, blank=True,
    )
    tenure = models.CharField(max_length=20, choices=TENURE_CHOICES)
    agent_name = models.CharField(max_length=200, blank=True)
    agent_contact = models.CharField(max_length=200, blank=True)
    seller_conveyancer_name = models.CharField(max_length=200, blank=True)
    seller_conveyancer_contact = models.CharField(max_length=200, blank=True)
    buyer_name = models.CharField(max_length=200, blank=True)
    buyer_contact = models.CharField(max_length=200, blank=True)
    buyer_conveyancer_name = models.CharField(max_length=200, blank=True)
    buyer_conveyancer_contact = models.CharField(max_length=200, blank=True)
    buyer_position = models.CharField(
        max_length=10, choices=BUYER_POSITION_CHOICES, blank=True,
    )
    chain_length = models.PositiveIntegerField(default=0)
    target_exchange_date = models.DateField(null=True, blank=True)
    target_completion_date = models.DateField(null=True, blank=True)
    status = models.CharField(
        max_length=12, choices=STATUS_CHOICES, default='active',
    )
    instructed_at = models.DateTimeField(null=True, blank=True)
    notification_frequency = models.CharField(
        max_length=15, choices=NOTIFICATION_FREQUENCY_CHOICES,
        default='daily_digest',
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Sale: {self.property_address}"

    @property
    def is_instructed(self):
        return self.instructed_at is not None

    @property
    def days_since_instruction(self):
        if not self.instructed_at:
            return None
        return (timezone.now() - self.instructed_at).days

    @property
    def days_to_target_exchange(self):
        if not self.target_exchange_date:
            return None
        return (self.target_exchange_date - timezone.now().date()).days

    @property
    def days_to_target_completion(self):
        if not self.target_completion_date:
            return None
        return (self.target_completion_date - timezone.now().date()).days

    @property
    def current_stage(self):
        return self.stages.filter(status='in_progress').first() or \
            self.stages.filter(status='not_started').order_by('stage_number').first()

    @property
    def is_leasehold(self):
        return self.tenure in ('leasehold', 'share_of_freehold')


# ── Stage ──────────────────────────────────────────────────────

class Stage(models.Model):
    STAGE_STATUS_CHOICES = [
        ('not_started', 'Not Started'),
        ('in_progress', 'In Progress'),
        ('done', 'Done'),
    ]

    sale = models.ForeignKey(
        Sale, on_delete=models.CASCADE, related_name='stages',
    )
    stage_number = models.PositiveIntegerField()
    name = models.CharField(max_length=100)
    status = models.CharField(
        max_length=12, choices=STAGE_STATUS_CHOICES, default='not_started',
    )
    started_at = models.DateTimeField(null=True, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['stage_number']
        unique_together = ['sale', 'stage_number']

    def __str__(self):
        return f"Stage {self.stage_number}: {self.name}"


# ── Task ───────────────────────────────────────────────────────

class Task(models.Model):
    TASK_STATUS_CHOICES = [
        ('not_started', 'Not Started'),
        ('in_progress', 'In Progress'),
        ('waiting_on_other', 'Waiting on Other'),
        ('done', 'Done'),
        ('n_a', 'Not Applicable'),
    ]

    stage = models.ForeignKey(
        Stage, on_delete=models.CASCADE, related_name='tasks',
    )
    title = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    current_owner = models.CharField(max_length=40, choices=OWNER_CHOICES)
    status = models.CharField(
        max_length=16, choices=TASK_STATUS_CHOICES, default='not_started',
    )
    awaiting_since = models.DateField(null=True, blank=True)
    awaiting_reason = models.CharField(max_length=300, blank=True)
    due_date = models.DateField(null=True, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    notes = models.TextField(blank=True)
    is_seed = models.BooleanField(default=True)
    order = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ['order', 'id']

    def __str__(self):
        return self.title

    @property
    def days_awaiting(self):
        if not self.awaiting_since:
            return 0
        return (timezone.now().date() - self.awaiting_since).days

    @property
    def sale(self):
        return self.stage.sale


# ── Task Ownership History ─────────────────────────────────────

class TaskOwnershipHistory(models.Model):
    task = models.ForeignKey(
        Task, on_delete=models.CASCADE, related_name='ownership_history',
    )
    from_owner = models.CharField(max_length=40, choices=OWNER_CHOICES)
    to_owner = models.CharField(max_length=40, choices=OWNER_CHOICES)
    transferred_at = models.DateTimeField(auto_now_add=True)
    reason = models.CharField(max_length=300, blank=True)

    class Meta:
        ordering = ['-transferred_at']
        verbose_name_plural = 'Task ownership history'

    def __str__(self):
        return f"{self.task.title}: {self.from_owner} → {self.to_owner}"


# ── Document ───────────────────────────────────────────────────

class Document(models.Model):
    CATEGORY_CHOICES = [
        ('identity', 'Identity'),
        ('property', 'Property'),
        ('financial', 'Financial'),
        ('form', 'Form'),
        ('certificate', 'Certificate'),
        ('guarantee', 'Guarantee'),
        ('legal', 'Legal'),
    ]
    SOURCE_CHOICES = [
        ('seller_provides', 'Seller Provides'),
        ('conveyancer_obtains', 'Conveyancer Obtains'),
        ('buyer_side_provides', 'Buyer Side Provides'),
    ]
    REQUIRED_TIER_CHOICES = [
        ('always', 'Always Required'),
        ('if_applicable', 'If Applicable'),
        ('leasehold_only', 'Leasehold Only'),
        ('situational', 'Situational'),
    ]
    DOCUMENT_STATUS_CHOICES = [
        ('have', 'Have'),
        ('missing', 'Missing'),
        ('not_applicable', 'Not Applicable'),
        ('requested', 'Requested'),
    ]

    sale = models.ForeignKey(
        Sale, on_delete=models.CASCADE, related_name='documents',
    )
    title = models.CharField(max_length=200)
    category = models.CharField(max_length=20, choices=CATEGORY_CHOICES)
    source = models.CharField(max_length=20, choices=SOURCE_CHOICES)
    required_tier = models.CharField(
        max_length=16, choices=REQUIRED_TIER_CHOICES,
    )
    status = models.CharField(
        max_length=16, choices=DOCUMENT_STATUS_CHOICES, default='missing',
    )
    file = models.FileField(
        upload_to='sale_tracker/documents/', blank=True,
    )
    uploaded_at = models.DateTimeField(null=True, blank=True)
    expiry_date = models.DateField(null=True, blank=True)
    na_reason = models.CharField(max_length=300, blank=True)
    helper_text = models.TextField(blank=True)
    is_seed = models.BooleanField(default=True)

    class Meta:
        ordering = ['category', 'title']

    def __str__(self):
        return self.title

    @property
    def is_required_and_missing(self):
        return self.required_tier == 'always' and self.status == 'missing'


# ── Document Delivery ──────────────────────────────────────────

class DocumentDelivery(models.Model):
    DELIVERY_METHOD_CHOICES = [
        ('seller_email', 'Seller Email'),
        ('platform_download', 'Platform Download'),
        ('manual', 'Manual'),
    ]

    document = models.ForeignKey(
        Document, on_delete=models.CASCADE, related_name='deliveries',
    )
    recipient_type = models.CharField(max_length=40)
    recipient_email = models.EmailField(blank=True)
    delivered_at = models.DateTimeField(auto_now_add=True)
    delivery_method = models.CharField(
        max_length=20, choices=DELIVERY_METHOD_CHOICES,
    )

    class Meta:
        ordering = ['-delivered_at']
        verbose_name_plural = 'Document deliveries'

    def __str__(self):
        return f"{self.document.title} → {self.recipient_type}"


# ── Document Access Log ────────────────────────────────────────

class DocumentAccessLog(models.Model):
    ACTION_CHOICES = [
        ('view', 'View'),
        ('download', 'Download'),
        ('delete', 'Delete'),
    ]

    document = models.ForeignKey(
        Document, on_delete=models.CASCADE, related_name='access_logs',
    )
    accessed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, related_name='+',
    )
    accessed_at = models.DateTimeField(auto_now_add=True)
    action = models.CharField(max_length=10, choices=ACTION_CHOICES)

    class Meta:
        ordering = ['-accessed_at']

    def __str__(self):
        return f"{self.action}: {self.document.title}"


# ── Contact Log ────────────────────────────────────────────────

class ContactLog(models.Model):
    CHANNEL_CHOICES = [
        ('call', 'Phone Call'),
        ('email', 'Email'),
        ('letter', 'Letter'),
        ('in_person', 'In Person'),
    ]

    sale = models.ForeignKey(
        Sale, on_delete=models.CASCADE, related_name='contact_logs',
    )
    date = models.DateTimeField(default=timezone.now)
    channel = models.CharField(max_length=12, choices=CHANNEL_CHOICES)
    counterparty = models.CharField(max_length=200)
    summary = models.TextField()
    follow_up_date = models.DateField(null=True, blank=True)
    related_task = models.ForeignKey(
        Task, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='contact_logs',
    )

    class Meta:
        ordering = ['-date']

    def __str__(self):
        return f"{self.get_channel_display()} with {self.counterparty}"


# ── Enquiry ────────────────────────────────────────────────────

class Enquiry(models.Model):
    ENQUIRY_STATUS_CHOICES = [
        ('open', 'Open'),
        ('with_seller', 'With Seller'),
        ('with_conveyancer', 'With Conveyancer'),
        ('answered', 'Answered'),
        ('closed', 'Closed'),
    ]

    sale = models.ForeignKey(
        Sale, on_delete=models.CASCADE, related_name='enquiries',
    )
    raised_date = models.DateField(auto_now_add=True)
    raised_by = models.CharField(max_length=200)
    question = models.TextField()
    current_owner = models.CharField(max_length=40, choices=OWNER_CHOICES)
    status = models.CharField(
        max_length=20, choices=ENQUIRY_STATUS_CHOICES, default='open',
    )
    response = models.TextField(blank=True)
    response_date = models.DateField(null=True, blank=True)

    class Meta:
        ordering = ['-raised_date']
        verbose_name_plural = 'Enquiries'

    def __str__(self):
        return f"Enquiry: {self.question[:50]}"


# ── Prompt Draft ───────────────────────────────────────────────

class PromptDraft(models.Model):
    LEVEL_CHOICES = [
        ('1', 'Check-in'),
        ('2', 'Follow-up'),
        ('escalation', 'Escalation'),
    ]

    sale = models.ForeignKey(
        Sale, on_delete=models.CASCADE, related_name='prompt_drafts',
    )
    generated_at = models.DateTimeField(auto_now_add=True)
    recipient_owner = models.CharField(max_length=40, choices=OWNER_CHOICES)
    level = models.CharField(max_length=12, choices=LEVEL_CHOICES)
    template_key = models.CharField(max_length=100, blank=True)
    subject = models.CharField(max_length=300)
    body_text = models.TextField()
    sent_marker = models.BooleanField(default=False)
    sent_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-generated_at']

    def __str__(self):
        return f"{self.get_level_display()} to {self.get_recipient_owner_display()}"


# ── Stage Gate Override ────────────────────────────────────────

class StageGateOverride(models.Model):
    sale = models.ForeignKey(
        Sale, on_delete=models.CASCADE, related_name='gate_overrides',
    )
    overridden_at = models.DateTimeField(auto_now_add=True)
    reason = models.TextField()

    class Meta:
        ordering = ['-overridden_at']

    def __str__(self):
        return f"Override on {self.sale} at {self.overridden_at}"
