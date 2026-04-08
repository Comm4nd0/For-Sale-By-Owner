import builtins

from django.conf import settings
from django.contrib.auth.models import AbstractUser, BaseUserManager
from django.db import models
from django.utils.text import slugify

# Alias for property decorator since some models have a 'property' FK field
# that shadows the builtin
python_property = builtins.property


class UserManager(BaseUserManager):
    """Custom manager for User model where email is the unique identifier."""

    def create_user(self, email, password=None, **extra_fields):
        if not email:
            raise ValueError('Users must have an email address')
        email = self.normalize_email(email)
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        return self.create_user(email, password, **extra_fields)


class User(AbstractUser):
    """Custom user model that uses email instead of username."""
    username = None
    email = models.EmailField('email address', unique=True)
    is_verified_seller = models.BooleanField(
        default=False,
        help_text='Indicates the seller has verified their identity.',
    )
    phone = models.CharField(max_length=20, blank=True)
    dark_mode = models.BooleanField(default=False, help_text='User prefers dark mode')
    notification_enquiries = models.BooleanField(default=True)
    notification_viewings = models.BooleanField(default=True)
    notification_price_drops = models.BooleanField(default=True)
    notification_saved_searches = models.BooleanField(default=True)

    # 2FA (#44)
    two_fa_enabled = models.BooleanField(default=False, help_text='Two-factor authentication enabled')
    two_fa_secret = models.CharField(max_length=64, blank=True, help_text='TOTP secret key')

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['first_name', 'last_name']

    objects = UserManager()

    def __str__(self):
        return self.email

    @property
    def is_verified_buyer(self):
        """Check if user has any valid buyer verification."""
        return self.verifications.filter(status='verified').exists()


class PropertyFeature(models.Model):
    """Reusable property feature tag (e.g. 'Garden', 'Parking', 'Central Heating')."""
    name = models.CharField(max_length=100, unique=True)
    icon = models.CharField(max_length=50, blank=True, help_text='Optional icon name or emoji')

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name


class Property(models.Model):
    """A property listed for sale by owner."""

    PROPERTY_TYPES = [
        ('detached', 'Detached'),
        ('semi_detached', 'Semi-Detached'),
        ('terraced', 'Terraced'),
        ('flat', 'Flat/Apartment'),
        ('bungalow', 'Bungalow'),
        ('cottage', 'Cottage'),
        ('land', 'Land'),
        ('other', 'Other'),
    ]

    STATUS_CHOICES = [
        ('draft', 'Draft'),
        ('pending_review', 'Pending Review'),
        ('active', 'Active'),
        ('under_offer', 'Under Offer'),
        ('sold_stc', 'Sold STC'),
        ('sold', 'Sold'),
        ('withdrawn', 'Withdrawn'),
        ('rejected', 'Rejected'),
    ]

    EPC_RATINGS = [
        ('A', 'A'),
        ('B', 'B'),
        ('C', 'C'),
        ('D', 'D'),
        ('E', 'E'),
        ('F', 'F'),
        ('G', 'G'),
    ]

    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='properties'
    )
    title = models.CharField(max_length=200)
    slug = models.SlugField(max_length=220, unique=True, blank=True)
    description = models.TextField(blank=True)
    property_type = models.CharField(max_length=20, choices=PROPERTY_TYPES)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='draft')
    price = models.DecimalField(max_digits=12, decimal_places=2)

    # Address
    address_line_1 = models.CharField(max_length=200)
    address_line_2 = models.CharField(max_length=200, blank=True)
    city = models.CharField(max_length=100)
    county = models.CharField(max_length=100, blank=True)
    postcode = models.CharField(max_length=10)

    # Geolocation (for distance/radius search)
    latitude = models.FloatField(null=True, blank=True, db_index=True)
    longitude = models.FloatField(null=True, blank=True, db_index=True)

    # Details
    bedrooms = models.PositiveIntegerField(default=0)
    bathrooms = models.PositiveIntegerField(default=0)
    reception_rooms = models.PositiveIntegerField(default=0)
    square_feet = models.PositiveIntegerField(null=True, blank=True)
    epc_rating = models.CharField(max_length=1, choices=EPC_RATINGS, blank=True)
    features = models.ManyToManyField(PropertyFeature, blank=True, related_name='properties')

    # Video / virtual tour
    video_url = models.URLField(blank=True, help_text='YouTube or Matterport URL for virtual tour')
    video_thumbnail = models.ImageField(upload_to='properties/video_thumbnails/', blank=True, null=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.title} - {self.postcode}"

    class Meta:
        verbose_name_plural = 'Properties'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['status', '-created_at']),
            models.Index(fields=['city']),
            models.Index(fields=['postcode']),
            models.Index(fields=['price']),
            models.Index(fields=['property_type']),
            models.Index(fields=['bedrooms']),
        ]

    def save(self, *args, **kwargs):
        if not self.slug:
            base = slugify(f"{self.title}-{self.postcode}")
            slug = base
            n = 1
            while Property.objects.filter(slug=slug).exclude(pk=self.pk).exists():
                slug = f"{base}-{n}"
                n += 1
            self.slug = slug
        super().save(*args, **kwargs)

    def listing_quality_score(self):
        """Calculate listing completeness score (0-100) with tips for improvement."""
        score = 0
        tips = []

        # Title & description (20 points)
        if self.title:
            score += 5
        if self.description:
            score += 10 if len(self.description) > 200 else 5
        else:
            tips.append('Add a detailed description — listings with descriptions get 50% more views')
        if len(self.description) <= 200 and self.description:
            tips.append('Expand your description to at least 200 characters for better engagement')

        # Images (25 points)
        image_count = self.images.count()
        if image_count >= 10:
            score += 25
        elif image_count >= 5:
            score += 15
            tips.append(f'Add {10 - image_count} more photos — listings with 10+ photos get 3x more enquiries')
        elif image_count >= 1:
            score += 5
            tips.append(f'Add more photos — you only have {image_count}')
        else:
            tips.append('Add photos — listings without images rarely receive enquiries')

        # Floorplan (10 points)
        if self.floorplans.exists():
            score += 10
        else:
            tips.append('Add a floorplan — listings with floorplans get 40% more enquiries')

        # EPC rating (10 points)
        if self.epc_rating:
            score += 10
        else:
            tips.append('Add your EPC rating — buyers expect to see energy performance')

        # Price (5 points - always set)
        if self.price:
            score += 5

        # Location details (10 points)
        if self.latitude and self.longitude:
            score += 5
        else:
            tips.append('Add map coordinates to appear in map-based searches')
        if self.county:
            score += 5

        # Property details (10 points)
        if self.bedrooms > 0:
            score += 3
        if self.bathrooms > 0:
            score += 3
        if self.square_feet:
            score += 4
        else:
            tips.append('Add the square footage — buyers use this to compare value')

        # Features (5 points)
        if self.features.exists():
            score += 5
        else:
            tips.append('Add property features (garden, parking, etc.) to improve search visibility')

        # Video tour (5 points)
        if self.video_url:
            score += 5
        else:
            tips.append('Add a video tour — virtual tours significantly increase buyer interest')

        return {'score': min(score, 100), 'tips': tips}


class PropertyImage(models.Model):
    """An image belonging to a property listing."""
    property = models.ForeignKey(
        Property, on_delete=models.CASCADE, related_name='images'
    )
    image = models.ImageField(upload_to='properties/images/')
    thumbnail = models.ImageField(upload_to='properties/thumbnails/', blank=True, null=True)
    order = models.PositiveIntegerField(default=0)
    is_primary = models.BooleanField(default=False)
    caption = models.CharField(max_length=200, blank=True)
    uploaded_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['order', 'uploaded_at']

    def __str__(self):
        return f"Image {self.order} for {self.property.title}"

    def save(self, *args, **kwargs):
        if self.is_primary:
            PropertyImage.objects.filter(
                property=self.property, is_primary=True
            ).exclude(pk=self.pk).update(is_primary=False)
        if not self.pk and not PropertyImage.objects.filter(property=self.property).exists():
            self.is_primary = True
        super().save(*args, **kwargs)


class PropertyFloorplan(models.Model):
    """A floorplan document/image belonging to a property listing."""
    property = models.ForeignKey(
        Property, on_delete=models.CASCADE, related_name='floorplans'
    )
    file = models.FileField(upload_to='properties/floorplans/')
    title = models.CharField(max_length=200, blank=True, default='Floorplan')
    order = models.PositiveIntegerField(default=0)
    uploaded_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['order', 'uploaded_at']

    def __str__(self):
        return f"Floorplan for {self.property.title}"


class PriceHistory(models.Model):
    """Tracks price changes for a property."""
    property = models.ForeignKey(
        Property, on_delete=models.CASCADE, related_name='price_history'
    )
    price = models.DecimalField(max_digits=12, decimal_places=2)
    changed_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-changed_at']
        verbose_name_plural = 'Price histories'

    def __str__(self):
        return f"{self.property.title}: £{self.price} on {self.changed_at.date()}"


class SavedProperty(models.Model):
    """A property saved/favourited by a user."""
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='saved_properties'
    )
    property = models.ForeignKey(
        Property, on_delete=models.CASCADE, related_name='saved_by'
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ['user', 'property']
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.user.email} saved {self.property.title}"


class Enquiry(models.Model):
    """An enquiry/message from a buyer to a property seller."""
    property = models.ForeignKey(
        Property, on_delete=models.CASCADE, related_name='enquiries'
    )
    sender = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='sent_enquiries'
    )
    name = models.CharField(max_length=200, blank=True)
    email = models.EmailField(blank=True)
    phone = models.CharField(max_length=20, blank=True)
    message = models.TextField()
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name_plural = 'Enquiries'
        ordering = ['-created_at']

    def __str__(self):
        return f"Enquiry from {self.name} about {self.property.title}"


class ViewingRequest(models.Model):
    """A request to view a property in person."""
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('confirmed', 'Confirmed'),
        ('declined', 'Declined'),
        ('cancelled', 'Cancelled'),
        ('completed', 'Completed'),
    ]

    property = models.ForeignKey(
        Property, on_delete=models.CASCADE, related_name='viewing_requests'
    )
    requester = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='viewing_requests'
    )
    preferred_date = models.DateField()
    preferred_time = models.TimeField()
    alternative_date = models.DateField(null=True, blank=True)
    alternative_time = models.TimeField(null=True, blank=True)
    message = models.TextField(blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    seller_notes = models.TextField(blank=True)
    name = models.CharField(max_length=200, blank=True)
    email = models.EmailField(blank=True)
    phone = models.CharField(max_length=20, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Viewing for {self.property.title} by {self.name} on {self.preferred_date}"


class Reply(models.Model):
    """A reply message in an enquiry or viewing request conversation thread."""
    enquiry = models.ForeignKey(
        Enquiry, on_delete=models.CASCADE, null=True, blank=True, related_name='replies'
    )
    viewing_request = models.ForeignKey(
        ViewingRequest, on_delete=models.CASCADE, null=True, blank=True, related_name='replies'
    )
    author = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='replies'
    )
    message = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['created_at']
        verbose_name_plural = 'Replies'
        constraints = [
            models.CheckConstraint(
                check=(
                    models.Q(enquiry__isnull=False, viewing_request__isnull=True)
                    | models.Q(enquiry__isnull=True, viewing_request__isnull=False)
                ),
                name='reply_exactly_one_parent',
            ),
        ]

    def __str__(self):
        parent = self.enquiry or self.viewing_request
        return f"Reply by {self.author.email} on {parent}"


class PropertyView(models.Model):
    """Tracks views of a property listing."""
    property = models.ForeignKey(
        Property, on_delete=models.CASCADE, related_name='views'
    )
    viewer_ip = models.GenericIPAddressField(null=True, blank=True)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='property_views'
    )
    viewed_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-viewed_at']
        indexes = [
            models.Index(fields=['property', '-viewed_at']),
        ]

    def __str__(self):
        return f"View of {self.property.title} at {self.viewed_at}"


class SavedSearch(models.Model):
    """A saved search with alert preferences."""

    ALERT_FREQUENCY_CHOICES = [
        ('instant', 'Instant'),
        ('daily', 'Daily Digest'),
        ('weekly', 'Weekly Digest'),
    ]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='saved_searches'
    )
    name = models.CharField(max_length=200, blank=True)
    # Search criteria stored as JSON-compatible fields
    location = models.CharField(max_length=200, blank=True)
    property_type = models.CharField(max_length=20, blank=True)
    min_price = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    max_price = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    min_bedrooms = models.PositiveIntegerField(null=True, blank=True)
    min_bathrooms = models.PositiveIntegerField(null=True, blank=True)
    epc_rating = models.CharField(max_length=1, blank=True)
    email_alerts = models.BooleanField(default=True)
    alert_frequency = models.CharField(
        max_length=10, choices=ALERT_FREQUENCY_CHOICES, default='instant'
    )
    last_notified = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        parts = []
        if self.location:
            parts.append(self.location)
        if self.property_type:
            parts.append(self.property_type)
        if self.min_bedrooms:
            parts.append(f"{self.min_bedrooms}+ bed")
        return self.name or ', '.join(parts) or 'Saved Search'


class PushNotificationDevice(models.Model):
    """Stores push notification tokens for mobile app users."""
    PLATFORM_CHOICES = [
        ('ios', 'iOS'),
        ('android', 'Android'),
        ('web', 'Web'),
    ]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
        related_name='push_devices'
    )
    platform = models.CharField(max_length=10, choices=PLATFORM_CHOICES)
    token = models.TextField(unique=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ['user', 'token']

    def __str__(self):
        return f"{self.user.email} - {self.platform}"


# ── Chat / Real-Time Messaging ──────────────────────────────────

class ChatRoom(models.Model):
    """A chat room between a buyer and seller for a specific property."""
    property = models.ForeignKey(
        Property, on_delete=models.CASCADE, related_name='chat_rooms'
    )
    buyer = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='buyer_chats'
    )
    seller = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='seller_chats'
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ['property', 'buyer']
        ordering = ['-updated_at']

    def __str__(self):
        return f"Chat: {self.buyer.email} <-> {self.seller.email} re: {self.property.title}"


class ChatMessage(models.Model):
    """A message in a chat room."""
    room = models.ForeignKey(
        ChatRoom, on_delete=models.CASCADE, related_name='messages'
    )
    sender = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='chat_messages'
    )
    message = models.TextField()
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['created_at']

    def __str__(self):
        return f"{self.sender.email}: {self.message[:50]}"


# ── Viewing Scheduler ───────────────────────────────────────────

class ViewingSlot(models.Model):
    """An available time slot set by a property seller for viewings."""
    DAY_CHOICES = [
        (0, 'Monday'), (1, 'Tuesday'), (2, 'Wednesday'),
        (3, 'Thursday'), (4, 'Friday'), (5, 'Saturday'), (6, 'Sunday'),
    ]

    property = models.ForeignKey(
        Property, on_delete=models.CASCADE, related_name='viewing_slots'
    )
    date = models.DateField(null=True, blank=True, help_text='Specific date, or leave blank for recurring')
    day_of_week = models.IntegerField(choices=DAY_CHOICES, null=True, blank=True)
    start_time = models.TimeField()
    end_time = models.TimeField()
    max_bookings = models.PositiveIntegerField(default=1)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ['date', 'day_of_week', 'start_time']

    def __str__(self):
        if self.date:
            return f"{self.property.title}: {self.date} {self.start_time}-{self.end_time}"
        return f"{self.property.title}: {self.get_day_of_week_display()} {self.start_time}-{self.end_time}"

    def get_bookings_count(self):
        return self.bookings.filter(
            viewing_request__status__in=['pending', 'confirmed']
        ).count()

    def get_is_available(self):
        return self.is_active and self.get_bookings_count() < self.max_bookings


class ViewingSlotBooking(models.Model):
    """Links a viewing request to a specific slot."""
    slot = models.ForeignKey(
        ViewingSlot, on_delete=models.CASCADE, related_name='bookings'
    )
    viewing_request = models.OneToOneField(
        ViewingRequest, on_delete=models.CASCADE, related_name='slot_booking'
    )
    created_at = models.DateTimeField(auto_now_add=True)


# ── Offer Management ────────────────────────────────────────────

class Offer(models.Model):
    """A formal offer from a buyer to a seller."""
    STATUS_CHOICES = [
        ('submitted', 'Submitted'),
        ('under_review', 'Under Review'),
        ('accepted', 'Accepted'),
        ('rejected', 'Rejected'),
        ('countered', 'Countered'),
        ('withdrawn', 'Withdrawn'),
        ('expired', 'Expired'),
    ]

    property = models.ForeignKey(
        Property, on_delete=models.CASCADE, related_name='offers'
    )
    buyer = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='offers_made'
    )
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    message = models.TextField(blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='submitted')
    counter_amount = models.DecimalField(
        max_digits=12, decimal_places=2, null=True, blank=True,
        help_text='Counter-offer amount from seller'
    )
    seller_notes = models.TextField(blank=True)
    is_cash_buyer = models.BooleanField(default=False)
    is_chain_free = models.BooleanField(default=False)
    mortgage_agreed = models.BooleanField(default=False)
    expires_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Offer £{self.amount:,.0f} on {self.property.title} by {self.buyer.email}"


# ── Property Documents ──────────────────────────────────────────

class PropertyDocument(models.Model):
    """Secure document attached to a property (title deeds, EPC, etc.)."""
    DOCUMENT_TYPES = [
        ('epc', 'EPC Certificate'),
        ('title_deeds', 'Title Deeds'),
        ('searches', 'Searches'),
        ('ta6', 'TA6 Property Information'),
        ('ta10', 'TA10 Fittings & Contents'),
        ('floorplan', 'Floorplan'),
        ('survey', 'Survey Report'),
        ('other', 'Other'),
    ]

    property = models.ForeignKey(
        Property, on_delete=models.CASCADE, related_name='documents'
    )
    uploaded_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='uploaded_documents'
    )
    document_type = models.CharField(max_length=20, choices=DOCUMENT_TYPES)
    title = models.CharField(max_length=200)
    file = models.FileField(upload_to='properties/documents/')
    is_public = models.BooleanField(
        default=False,
        help_text='If true, any authenticated user can view. Otherwise only owner and accepted buyers.'
    )
    uploaded_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['document_type', '-uploaded_at']

    def __str__(self):
        return f"{self.title} ({self.get_document_type_display()}) - {self.property.title}"


# ── Property Flagging / Moderation ──────────────────────────────

class PropertyFlag(models.Model):
    """A user flag/report on a property listing."""
    REASON_CHOICES = [
        ('spam', 'Spam or Scam'),
        ('inappropriate', 'Inappropriate Content'),
        ('inaccurate', 'Inaccurate Information'),
        ('duplicate', 'Duplicate Listing'),
        ('sold', 'Already Sold'),
        ('other', 'Other'),
    ]

    STATUS_CHOICES = [
        ('pending', 'Pending Review'),
        ('reviewed', 'Reviewed'),
        ('actioned', 'Actioned'),
        ('dismissed', 'Dismissed'),
    ]

    property = models.ForeignKey(
        Property, on_delete=models.CASCADE, related_name='flags'
    )
    reporter = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='property_flags'
    )
    reason = models.CharField(max_length=20, choices=REASON_CHOICES)
    description = models.TextField(blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    admin_notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    resolved_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']
        unique_together = ['property', 'reporter']

    def __str__(self):
        return f"Flag on {self.property.title} by {self.reporter.email}: {self.reason}"



# ── Service Provider Models ─────────────────────────────────────

class ServiceCategory(models.Model):
    """A predefined category of service (e.g. EPC Inspections, Conveyancing)."""
    name = models.CharField(max_length=100, unique=True)
    slug = models.SlugField(max_length=110, unique=True, blank=True)
    icon = models.CharField(max_length=50, blank=True, help_text='Optional icon name or emoji')
    description = models.TextField(blank=True)
    order = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ['order', 'name']
        verbose_name_plural = 'Service categories'

    def __str__(self):
        return self.name

    def save(self, *args, **kwargs):
        if not self.slug:
            self.slug = slugify(self.name)
        super().save(*args, **kwargs)


class ServiceProvider(models.Model):
    """A service provider listing, advertising services to property buyers/sellers."""
    STATUS_CHOICES = [
        ('draft', 'Draft'),
        ('pending_review', 'Pending Review'),
        ('active', 'Active'),
        ('suspended', 'Suspended'),
        ('withdrawn', 'Withdrawn'),
    ]

    owner = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
        related_name='service_provider'
    )
    business_name = models.CharField(max_length=200)
    slug = models.SlugField(max_length=220, unique=True, blank=True)
    description = models.TextField(blank=True)
    categories = models.ManyToManyField(ServiceCategory, related_name='providers')

    # Contact
    contact_email = models.EmailField()
    contact_phone = models.CharField(max_length=20, blank=True)
    website = models.URLField(blank=True)

    # Coverage (geographic targeting)
    coverage_counties = models.TextField(
        blank=True,
        help_text='Comma-separated county names, e.g. "Gloucestershire, Oxfordshire"'
    )
    coverage_postcodes = models.TextField(
        blank=True,
        help_text='Comma-separated postcode prefixes, e.g. "GL, OX, BS"'
    )

    # Branding
    logo = models.ImageField(upload_to='services/logos/', blank=True, null=True)

    # Business details
    pricing_info = models.TextField(blank=True, help_text='Free-text pricing or "from" prices')
    years_established = models.PositiveIntegerField(null=True, blank=True)

    # Moderation
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='draft')
    is_verified = models.BooleanField(default=False, help_text='Admin-verified business')

    # Stripe
    stripe_customer_id = models.CharField(
        max_length=100, blank=True, default='',
        help_text='Stripe Customer ID for billing'
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return self.business_name

    def save(self, *args, **kwargs):
        if not self.slug:
            base = slugify(self.business_name)
            slug = base
            n = 1
            while ServiceProvider.objects.filter(slug=slug).exclude(pk=self.pk).exists():
                slug = f"{base}-{n}"
                n += 1
            self.slug = slug
        super().save(*args, **kwargs)

    @property
    def coverage_counties_list(self):
        return [c.strip() for c in self.coverage_counties.split(',') if c.strip()]

    @property
    def coverage_postcodes_list(self):
        return [p.strip().upper() for p in self.coverage_postcodes.split(',') if p.strip()]

    @property
    def average_rating(self):
        avg = self.reviews.aggregate(models.Avg('rating'))['rating__avg']
        return round(avg, 1) if avg else None

    @property
    def review_count(self):
        return self.reviews.count()

    @property
    def active_subscription(self):
        """Return the current active subscription, or None."""
        from django.utils import timezone
        return self.subscriptions.filter(
            status='active'
        ).filter(
            models.Q(current_period_end__isnull=True) |
            models.Q(current_period_end__gt=timezone.now())
        ).select_related('tier').first()

    @property
    def current_tier(self):
        """Return the current SubscriptionTier, or None if no active subscription."""
        sub = self.active_subscription
        if sub:
            return sub.tier
        return None


class ServiceProviderReview(models.Model):
    """A rating and review left by a user for a service provider."""
    RATING_CHOICES = [(i, str(i)) for i in range(1, 6)]

    provider = models.ForeignKey(
        ServiceProvider, on_delete=models.CASCADE, related_name='reviews'
    )
    reviewer = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='service_reviews'
    )
    rating = models.PositiveIntegerField(choices=RATING_CHOICES)
    comment = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        unique_together = ['provider', 'reviewer']

    def __str__(self):
        return f"{self.reviewer.email} rated {self.provider.business_name} {self.rating}/5"


# ── Subscription / Pricing Models ────────────────────────────────


class SubscriptionTier(models.Model):
    """Admin-configurable subscription tier for service providers."""
    name = models.CharField(max_length=50)
    slug = models.SlugField(max_length=50, unique=True)
    tagline = models.CharField(max_length=200, blank=True)
    cta_text = models.CharField(max_length=100, blank=True, help_text='Call-to-action button text')
    badge_text = models.CharField(max_length=50, blank=True, help_text='e.g. "Most Popular"')

    # Pricing
    monthly_price = models.DecimalField(max_digits=8, decimal_places=2, default=0)
    annual_price = models.DecimalField(max_digits=8, decimal_places=2, default=0)
    currency = models.CharField(max_length=3, default='GBP')

    # Stripe Price IDs (set via admin after creating products in Stripe Dashboard)
    stripe_monthly_price_id = models.CharField(
        max_length=100, blank=True, default='',
        help_text='Stripe Price ID for monthly billing'
    )
    stripe_annual_price_id = models.CharField(
        max_length=100, blank=True, default='',
        help_text='Stripe Price ID for annual billing'
    )

    # Limits (-1 means unlimited)
    max_service_categories = models.IntegerField(default=1, help_text='-1 = unlimited')
    max_locations = models.IntegerField(default=1, help_text='-1 = unlimited')
    max_photos = models.IntegerField(default=0, help_text='-1 = unlimited')
    allow_logo = models.BooleanField(default=False)

    # Feature flags
    feature_basic_listing = models.BooleanField(default=True)
    feature_local_area_visibility = models.BooleanField(default=True)
    feature_contact_details = models.BooleanField(default=True)
    feature_featured_placement = models.BooleanField(default=False)
    feature_click_through_analytics = models.BooleanField(default=False)
    feature_category_exclusivity = models.BooleanField(default=False)
    feature_priority_search = models.BooleanField(default=False)
    feature_lead_notifications = models.BooleanField(default=False)
    feature_performance_reports = models.BooleanField(default=False)
    feature_account_manager = models.BooleanField(default=False)
    feature_photo_gallery = models.BooleanField(default=False)
    feature_early_access = models.BooleanField(default=False)

    # Trial
    trial_period_days = models.PositiveIntegerField(
        default=0,
        help_text='Number of days free trial for new subscribers. 0 = no trial.'
    )

    # Display
    display_order = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ['display_order', 'monthly_price']

    def __str__(self):
        return self.name


class SubscriptionAddOn(models.Model):
    """Purchasable extras for service provider subscriptions."""
    name = models.CharField(max_length=100)
    slug = models.SlugField(max_length=100, unique=True)
    description = models.TextField(blank=True)
    monthly_price = models.DecimalField(max_digits=8, decimal_places=2)
    stripe_price_id = models.CharField(
        max_length=100, blank=True, default='',
        help_text='Stripe Price ID for this add-on'
    )
    compatible_tiers = models.ManyToManyField(
        SubscriptionTier, related_name='available_addons', blank=True
    )
    is_active = models.BooleanField(default=True)
    display_order = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ['display_order']

    def __str__(self):
        return self.name


class ServiceProviderSubscription(models.Model):
    """Links a service provider to their active subscription tier."""
    BILLING_CHOICES = [
        ('monthly', 'Monthly'),
        ('annual', 'Annual'),
    ]
    STATUS_CHOICES = [
        ('active', 'Active'),
        ('cancelled', 'Cancelled'),
        ('past_due', 'Past Due'),
        ('pending', 'Pending'),
    ]

    provider = models.ForeignKey(
        ServiceProvider, on_delete=models.CASCADE, related_name='subscriptions'
    )
    tier = models.ForeignKey(
        SubscriptionTier, on_delete=models.PROTECT, related_name='subscriptions'
    )
    billing_cycle = models.CharField(max_length=10, choices=BILLING_CHOICES, default='monthly')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='active')

    # Stripe
    stripe_subscription_id = models.CharField(
        max_length=100, blank=True, default=None, unique=True, null=True,
        help_text='Stripe Subscription ID'
    )
    stripe_customer_id = models.CharField(max_length=100, blank=True, default='')

    # Period
    current_period_start = models.DateTimeField(null=True, blank=True)
    current_period_end = models.DateTimeField(null=True, blank=True)
    cancel_at_period_end = models.BooleanField(default=False)

    started_at = models.DateTimeField(auto_now_add=True)
    cancelled_at = models.DateTimeField(null=True, blank=True)
    trial_end = models.DateTimeField(
        null=True, blank=True,
        help_text='When the trial period ends (from Stripe)'
    )
    admin_notes = models.TextField(blank=True)

    class Meta:
        ordering = ['-started_at']

    def __str__(self):
        return f"{self.provider.business_name} - {self.tier.name} ({self.status})"

    @property
    def is_current(self):
        if self.status != 'active':
            return False
        if self.current_period_end is None:
            return True
        from django.utils import timezone
        return self.current_period_end > timezone.now()

    @property
    def is_on_trial(self):
        if self.trial_end is None:
            return False
        from django.utils import timezone
        return self.trial_end > timezone.now() and self.status == 'active'


class ServiceProviderAddOn(models.Model):
    """Active add-on on a service provider's subscription."""
    subscription = models.ForeignKey(
        ServiceProviderSubscription, on_delete=models.CASCADE, related_name='active_addons'
    )
    addon = models.ForeignKey(
        SubscriptionAddOn, on_delete=models.PROTECT, related_name='provider_addons'
    )
    quantity = models.PositiveIntegerField(default=1)
    stripe_subscription_item_id = models.CharField(max_length=100, blank=True, default='')
    activated_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ['subscription', 'addon']

    def __str__(self):
        return f"{self.subscription.provider.business_name} - {self.addon.name} x{self.quantity}"


class ServiceProviderPhoto(models.Model):
    """Gallery photo for a service provider (paid tiers only)."""
    provider = models.ForeignKey(
        ServiceProvider, on_delete=models.CASCADE, related_name='photos'
    )
    image = models.ImageField(upload_to='services/photos/')
    caption = models.CharField(max_length=200, blank=True)
    order = models.PositiveIntegerField(default=0)
    uploaded_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['order', 'uploaded_at']

    def __str__(self):
        return f"Photo {self.order} for {self.provider.business_name}"


# ── #30 Buyer Verification & Proof of Funds ─────────────────────

class BuyerVerification(models.Model):
    """Buyer identity and financial verification."""
    VERIFICATION_TYPES = [
        ('mortgage_aip', 'Mortgage Agreement in Principle'),
        ('proof_of_funds', 'Proof of Funds'),
        ('id_verification', 'ID Verification'),
    ]
    STATUS_CHOICES = [
        ('pending', 'Pending Review'),
        ('verified', 'Verified'),
        ('rejected', 'Rejected'),
        ('expired', 'Expired'),
    ]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
        related_name='verifications'
    )
    verification_type = models.CharField(max_length=20, choices=VERIFICATION_TYPES)
    document = models.FileField(upload_to='verifications/')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    admin_notes = models.TextField(blank=True)
    expires_at = models.DateField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    reviewed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.user.email} - {self.get_verification_type_display()} ({self.status})"

    @property
    def is_valid(self):
        from django.utils import timezone
        if self.status != 'verified':
            return False
        if self.expires_at and self.expires_at < timezone.now().date():
            return False
        return True


# ── #31 Conveyancing Progress Tracker ────────────────────────────

class ConveyancingCase(models.Model):
    """Tracks the conveyancing process after an offer is accepted."""
    STATUS_CHOICES = [
        ('active', 'Active'),
        ('completed', 'Completed'),
        ('fallen_through', 'Fallen Through'),
    ]

    property = models.ForeignKey(
        Property, on_delete=models.CASCADE, related_name='conveyancing_cases'
    )
    offer = models.OneToOneField(
        Offer, on_delete=models.CASCADE, related_name='conveyancing_case'
    )
    buyer = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
        related_name='buyer_conveyancing_cases'
    )
    seller = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
        related_name='seller_conveyancing_cases'
    )
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='active')
    buyer_solicitor = models.CharField(max_length=200, blank=True)
    seller_solicitor = models.CharField(max_length=200, blank=True)
    target_completion_date = models.DateField(null=True, blank=True)
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name_plural = 'Conveyancing cases'

    def __str__(self):
        return f"Conveyancing: {self.property.title}"


class ConveyancingStep(models.Model):
    """A step in the conveyancing process."""
    STEP_CHOICES = [
        ('offer_accepted', 'Offer Accepted'),
        ('memorandum_of_sale', 'Memorandum of Sale Issued'),
        ('solicitors_instructed', 'Solicitors Instructed'),
        ('draft_contract', 'Draft Contract Received'),
        ('searches_ordered', 'Searches Ordered'),
        ('searches_received', 'Searches Received'),
        ('survey_booked', 'Survey Booked'),
        ('survey_received', 'Survey Received'),
        ('mortgage_offer', 'Mortgage Offer Received'),
        ('enquiries_raised', 'Enquiries Raised'),
        ('enquiries_answered', 'Enquiries Answered'),
        ('ready_to_exchange', 'Ready to Exchange'),
        ('exchanged', 'Contracts Exchanged'),
        ('completion', 'Completion'),
    ]
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('in_progress', 'In Progress'),
        ('completed', 'Completed'),
        ('blocked', 'Blocked'),
        ('not_applicable', 'Not Applicable'),
    ]

    case = models.ForeignKey(
        ConveyancingCase, on_delete=models.CASCADE, related_name='steps'
    )
    step_type = models.CharField(max_length=30, choices=STEP_CHOICES)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    notes = models.TextField(blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    order = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['order']
        unique_together = ['case', 'step_type']

    def __str__(self):
        return f"{self.get_step_type_display()} - {self.get_status_display()}"


# ── #37 Open House Events ───────────────────────────────────────

class OpenHouseEvent(models.Model):
    """An open house event for a property."""
    property = models.ForeignKey(
        Property, on_delete=models.CASCADE, related_name='open_house_events'
    )
    title = models.CharField(max_length=200, default='Open House')
    date = models.DateField()
    start_time = models.TimeField()
    end_time = models.TimeField()
    description = models.TextField(blank=True)
    max_attendees = models.PositiveIntegerField(null=True, blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['date', 'start_time']

    def __str__(self):
        return f"{self.title} on {self.date}"

    def get_rsvp_count(self):
        return self.rsvps.count()

    rsvp_count = python_property(lambda self: self.get_rsvp_count())

    def get_has_capacity(self):
        if self.max_attendees is None:
            return True
        return self.get_rsvp_count() < self.max_attendees

    has_capacity = python_property(lambda self: self.get_has_capacity())


class OpenHouseRSVP(models.Model):
    """RSVP for an open house event."""
    event = models.ForeignKey(
        OpenHouseEvent, on_delete=models.CASCADE, related_name='rsvps'
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
        related_name='open_house_rsvps'
    )
    attendees = models.PositiveIntegerField(default=1)
    message = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ['event', 'user']
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.user.email} RSVP to {self.event}"


# ── #39 Solicitor / Conveyancer Matching ─────────────────────────

class ConveyancerQuoteRequest(models.Model):
    """Request for conveyancing quotes from service providers."""
    STATUS_CHOICES = [
        ('open', 'Open'),
        ('quotes_received', 'Quotes Received'),
        ('accepted', 'Accepted'),
        ('closed', 'Closed'),
    ]

    property = models.ForeignKey(
        Property, on_delete=models.CASCADE, related_name='quote_requests'
    )
    requester = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
        related_name='quote_requests'
    )
    transaction_type = models.CharField(
        max_length=20,
        choices=[('buying', 'Buying'), ('selling', 'Selling')],
        default='buying'
    )
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='open')
    additional_info = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Quote request by {self.requester.email} for {self.property.title}"


class ConveyancerQuote(models.Model):
    """A quote from a service provider for conveyancing work."""
    request = models.ForeignKey(
        ConveyancerQuoteRequest, on_delete=models.CASCADE, related_name='quotes'
    )
    provider = models.ForeignKey(
        ServiceProvider, on_delete=models.CASCADE, related_name='conveyancer_quotes'
    )
    legal_fee = models.DecimalField(max_digits=10, decimal_places=2)
    disbursements = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    total = models.DecimalField(max_digits=10, decimal_places=2)
    estimated_weeks = models.PositiveIntegerField(null=True, blank=True)
    notes = models.TextField(blank=True)
    is_accepted = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['total']
        unique_together = ['request', 'provider']

    def __str__(self):
        return f"£{self.total} quote from {self.provider.business_name}"


# ── #40 Neighbourhood Reviews ───────────────────────────────────

class NeighbourhoodReview(models.Model):
    """Review of a neighbourhood by a resident."""
    RATING_CHOICES = [(i, str(i)) for i in range(1, 6)]

    reviewer = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
        related_name='neighbourhood_reviews'
    )
    postcode_area = models.CharField(
        max_length=10,
        help_text='Postcode district e.g. "BS1", "GL50"'
    )
    overall_rating = models.PositiveIntegerField(choices=RATING_CHOICES)
    community_rating = models.PositiveIntegerField(choices=RATING_CHOICES, null=True, blank=True)
    noise_rating = models.PositiveIntegerField(choices=RATING_CHOICES, null=True, blank=True)
    parking_rating = models.PositiveIntegerField(choices=RATING_CHOICES, null=True, blank=True)
    shops_rating = models.PositiveIntegerField(choices=RATING_CHOICES, null=True, blank=True)
    safety_rating = models.PositiveIntegerField(choices=RATING_CHOICES, null=True, blank=True)
    schools_rating = models.PositiveIntegerField(choices=RATING_CHOICES, null=True, blank=True)
    transport_rating = models.PositiveIntegerField(choices=RATING_CHOICES, null=True, blank=True)
    comment = models.TextField(blank=True)
    years_lived = models.PositiveIntegerField(
        null=True, blank=True,
        help_text='How many years the reviewer has lived in the area'
    )
    is_current_resident = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        unique_together = ['reviewer', 'postcode_area']
        indexes = [
            models.Index(fields=['postcode_area']),
        ]

    def __str__(self):
        return f"{self.reviewer.email} review of {self.postcode_area}: {self.overall_rating}/5"


# ── #41 "For Sale" Board Ordering ────────────────────────────────

class BoardOrder(models.Model):
    """Order for a physical "For Sale" board."""
    STATUS_CHOICES = [
        ('pending', 'Pending Payment'),
        ('paid', 'Paid'),
        ('production', 'In Production'),
        ('shipped', 'Shipped'),
        ('delivered', 'Delivered'),
        ('cancelled', 'Cancelled'),
    ]
    BOARD_TYPES = [
        ('standard', 'Standard Board'),
        ('premium', 'Premium Board with QR Code'),
        ('solar_lit', 'Solar-Lit Board'),
    ]

    property = models.ForeignKey(
        Property, on_delete=models.CASCADE, related_name='board_orders'
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
        related_name='board_orders'
    )
    board_type = models.CharField(max_length=20, choices=BOARD_TYPES, default='standard')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    delivery_address = models.TextField()
    price = models.DecimalField(max_digits=8, decimal_places=2)
    stripe_payment_id = models.CharField(max_length=100, blank=True)
    tracking_number = models.CharField(max_length=100, blank=True)
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.get_board_type_display()} for {self.property.title} ({self.status})"


# ── #43 Buyer Affordability Profile ──────────────────────────────

class BuyerProfile(models.Model):
    """Buyer's financial profile for affordability matching."""
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
        related_name='buyer_profile'
    )
    max_budget = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    deposit_amount = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    mortgage_approved = models.BooleanField(default=False)
    mortgage_amount = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    is_first_time_buyer = models.BooleanField(default=False)
    is_cash_buyer = models.BooleanField(default=False)
    has_property_to_sell = models.BooleanField(default=False)
    preferred_areas = models.TextField(
        blank=True, help_text='Comma-separated postcodes or areas'
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        budget = f"£{self.max_budget:,.0f}" if self.max_budget else "No budget set"
        return f"{self.user.email} - {budget}"


# ── #45 Community Forum / Knowledge Base ─────────────────────────

class ForumCategory(models.Model):
    """Category for forum topics."""
    name = models.CharField(max_length=100, unique=True)
    slug = models.SlugField(max_length=110, unique=True, blank=True)
    description = models.TextField(blank=True)
    icon = models.CharField(max_length=50, blank=True)
    order = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ['order', 'name']
        verbose_name_plural = 'Forum categories'

    def __str__(self):
        return self.name

    def save(self, *args, **kwargs):
        if not self.slug:
            self.slug = slugify(self.name)
        super().save(*args, **kwargs)

    @property
    def topic_count(self):
        return self.topics.count()


class ForumTopic(models.Model):
    """A forum topic / thread."""
    category = models.ForeignKey(
        ForumCategory, on_delete=models.CASCADE, related_name='topics'
    )
    author = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
        related_name='forum_topics'
    )
    title = models.CharField(max_length=200)
    slug = models.SlugField(max_length=220, unique=True, blank=True)
    content = models.TextField()
    is_pinned = models.BooleanField(default=False)
    is_locked = models.BooleanField(default=False)
    view_count = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-is_pinned', '-created_at']
        indexes = [
            models.Index(fields=['category', '-created_at']),
        ]

    def __str__(self):
        return self.title

    def save(self, *args, **kwargs):
        if not self.slug:
            base = slugify(self.title)
            slug = base
            n = 1
            while ForumTopic.objects.filter(slug=slug).exclude(pk=self.pk).exists():
                slug = f"{base}-{n}"
                n += 1
            self.slug = slug
        super().save(*args, **kwargs)

    @property
    def reply_count(self):
        return self.posts.count()


class ForumPost(models.Model):
    """A reply/post in a forum topic."""
    topic = models.ForeignKey(
        ForumTopic, on_delete=models.CASCADE, related_name='posts'
    )
    author = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
        related_name='forum_posts'
    )
    content = models.TextField()
    is_solution = models.BooleanField(default=False, help_text='Marked as the accepted answer')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['created_at']

    def __str__(self):
        return f"Post by {self.author.email} in {self.topic.title}"
