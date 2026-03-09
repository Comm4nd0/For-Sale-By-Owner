from django.conf import settings
from django.contrib.auth.models import AbstractUser, BaseUserManager
from django.db import models
from django.utils.text import slugify


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

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['first_name', 'last_name']

    objects = UserManager()

    def __str__(self):
        return self.email


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

    # Details
    bedrooms = models.PositiveIntegerField(default=0)
    bathrooms = models.PositiveIntegerField(default=0)
    reception_rooms = models.PositiveIntegerField(default=0)
    square_feet = models.PositiveIntegerField(null=True, blank=True)
    epc_rating = models.CharField(max_length=1, choices=EPC_RATINGS, blank=True)
    features = models.ManyToManyField(PropertyFeature, blank=True, related_name='properties')

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.title} - {self.postcode}"

    class Meta:
        verbose_name_plural = 'Properties'
        ordering = ['-created_at']

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


class PropertyImage(models.Model):
    """An image belonging to a property listing."""
    property = models.ForeignKey(
        Property, on_delete=models.CASCADE, related_name='images'
    )
    image = models.ImageField(upload_to='properties/images/')
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
    name = models.CharField(max_length=200)
    email = models.EmailField()
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
    name = models.CharField(max_length=200)
    email = models.EmailField()
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

    def __str__(self):
        return f"View of {self.property.title} at {self.viewed_at}"


class SavedSearch(models.Model):
    """A saved search with alert preferences."""
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
