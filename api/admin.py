from django.contrib import admin
from django.contrib.auth import get_user_model
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.utils import timezone
from django.utils.html import format_html
from .models import (
    Property, PropertyImage, PropertyFloorplan, PropertyFeature,
    PriceHistory, SavedProperty, PropertyView,
    ViewingRequest, SavedSearch, PushNotificationDevice, Reply,
    ServiceCategory, ServiceProvider, ServiceProviderReview,
    SubscriptionTier, SubscriptionAddOn, ServiceProviderSubscription,
    ServiceProviderAddOn, ServiceProviderPhoto,
    ChatRoom, ChatMessage,
    ViewingSlot, ViewingSlotBooking,
    Offer, PropertyDocument, PropertyFlag,
    BuyerVerification, ConveyancingCase, ConveyancingStep,
    OpenHouseEvent, OpenHouseRSVP,
    ConveyancerQuoteRequest, ConveyancerQuote,
    NeighbourhoodReview, BoardOrder, BuyerProfile,
    ForumCategory, ForumTopic, ForumPost,
)
from .notifications import notify_listing_approved, notify_listing_rejected

User = get_user_model()


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    ordering = ['email']
    list_display = ['email', 'first_name', 'last_name', 'is_verified_seller', 'is_staff', 'date_joined']
    list_filter = ['is_verified_seller', 'is_staff', 'is_active', 'dark_mode']
    search_fields = ['email', 'first_name', 'last_name']
    fieldsets = (
        (None, {'fields': ('email', 'password')}),
        ('Personal info', {'fields': ('first_name', 'last_name', 'phone')}),
        ('Seller', {'fields': ('is_verified_seller',)}),
        ('Preferences', {'fields': ('dark_mode', 'notification_enquiries', 'notification_viewings', 'notification_price_drops', 'notification_saved_searches')}),
        ('Permissions', {'fields': ('is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions')}),
        ('Important dates', {'fields': ('last_login', 'date_joined')}),
    )
    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': ('email', 'first_name', 'last_name', 'password1', 'password2'),
        }),
    )
    actions = ['verify_sellers', 'unverify_sellers']

    @admin.action(description='Mark selected users as verified sellers')
    def verify_sellers(self, request, queryset):
        queryset.update(is_verified_seller=True)

    @admin.action(description='Remove verified seller status')
    def unverify_sellers(self, request, queryset):
        queryset.update(is_verified_seller=False)


class PropertyImageInline(admin.TabularInline):
    model = PropertyImage
    extra = 1
    fields = ['image', 'order', 'is_primary', 'caption']

class PropertyFloorplanInline(admin.TabularInline):
    model = PropertyFloorplan
    extra = 0
    fields = ['file', 'title', 'order']

class PropertyDocumentInline(admin.TabularInline):
    model = PropertyDocument
    extra = 0
    fields = ['document_type', 'title', 'file', 'is_public']


@admin.register(Property)
class PropertyAdmin(admin.ModelAdmin):
    list_display = ['title', 'property_type', 'status', 'status_badge', 'price_display', 'city', 'postcode', 'owner', 'view_count', 'message_count', 'flag_count', 'created_at']
    list_filter = ['status', 'property_type', 'epc_rating', 'city', 'created_at']
    list_editable = ['status']
    search_fields = ['title', 'address_line_1', 'city', 'postcode', 'owner__email', 'slug']
    readonly_fields = ['slug', 'view_count', 'message_count', 'save_count', 'flag_count', 'created_at', 'updated_at']
    inlines = [PropertyImageInline, PropertyFloorplanInline, PropertyDocumentInline]
    filter_horizontal = ['features']
    actions = ['approve_listings', 'reject_listings', 'mark_active', 'mark_withdrawn']
    fieldsets = (
        (None, {'fields': ('owner', 'title', 'slug', 'status', 'price')}),
        ('Property Details', {'fields': ('property_type', 'description', 'epc_rating', 'bedrooms', 'bathrooms', 'reception_rooms', 'square_feet', 'features')}),
        ('Address', {'fields': ('address_line_1', 'address_line_2', 'city', 'county', 'postcode')}),
        ('Geolocation', {'fields': ('latitude', 'longitude')}),
        ('Media', {'fields': ('video_url', 'video_thumbnail')}),
        ('Statistics', {'fields': ('view_count', 'message_count', 'save_count', 'flag_count')}),
        ('Dates', {'fields': ('created_at', 'updated_at')}),
    )

    def status_badge(self, obj):
        colours = {'draft': '#999', 'pending_review': '#E67E22', 'active': '#27AE60', 'under_offer': '#F39C12', 'sold_stc': '#F39C12', 'sold': '#2ECC71', 'withdrawn': '#E74C3C', 'rejected': '#C0392B'}
        colour = colours.get(obj.status, '#999')
        return format_html('<span style="background:{}; color:white; padding:3px 8px; border-radius:3px; font-size:11px;">{}</span>', colour, obj.get_status_display())
    status_badge.short_description = 'Status'

    def price_display(self, obj): return f"\u00A3{obj.price:,.0f}"
    price_display.short_description = 'Price'
    def view_count(self, obj): return obj.views.count()
    view_count.short_description = 'Views'
    def message_count(self, obj): return ChatMessage.objects.filter(room__property=obj).count()
    message_count.short_description = 'Messages'
    def save_count(self, obj): return obj.saved_by.count()
    save_count.short_description = 'Saves'
    def flag_count(self, obj): return obj.flags.filter(status='pending').count()
    flag_count.short_description = 'Flags'

    @admin.action(description='Approve selected listings')
    def approve_listings(self, request, queryset):
        for prop in queryset:
            prop.status = 'active'
            prop.save(update_fields=['status'])
            notify_listing_approved(prop)

    @admin.action(description='Reject selected listings')
    def reject_listings(self, request, queryset):
        for prop in queryset:
            prop.status = 'rejected'
            prop.save(update_fields=['status'])
            notify_listing_rejected(prop)

    @admin.action(description='Mark as Active')
    def mark_active(self, request, queryset): queryset.update(status='active')
    @admin.action(description='Mark as Withdrawn')
    def mark_withdrawn(self, request, queryset): queryset.update(status='withdrawn')


@admin.register(PropertyFeature)
class PropertyFeatureAdmin(admin.ModelAdmin):
    list_display = ['name', 'icon']
    search_fields = ['name']

@admin.register(PriceHistory)
class PriceHistoryAdmin(admin.ModelAdmin):
    list_display = ['property', 'price', 'changed_at']
    list_filter = ['changed_at']
    search_fields = ['property__title']

class ViewingReplyInline(admin.TabularInline):
    model = Reply; fk_name = 'viewing_request'; extra = 0; readonly_fields = ['author', 'message', 'created_at']

@admin.register(ViewingRequest)
class ViewingRequestAdmin(admin.ModelAdmin):
    list_display = ['property', 'name', 'preferred_date', 'preferred_time', 'status', 'created_at']
    list_filter = ['status', 'preferred_date', 'created_at']
    list_editable = ['status']
    inlines = [ViewingReplyInline]

@admin.register(Reply)
class ReplyAdmin(admin.ModelAdmin):
    list_display = ['id', 'author', 'viewing_request', 'created_at']

@admin.register(SavedSearch)
class SavedSearchAdmin(admin.ModelAdmin):
    list_display = ['user', 'name', 'location', 'property_type', 'email_alerts', 'alert_frequency', 'created_at']
    list_filter = ['email_alerts', 'alert_frequency', 'property_type']

@admin.register(SavedProperty)
class SavedPropertyAdmin(admin.ModelAdmin):
    list_display = ['user', 'property', 'created_at']

@admin.register(PropertyView)
class PropertyViewAdmin(admin.ModelAdmin):
    list_display = ['property', 'user', 'viewer_ip', 'viewed_at']
    date_hierarchy = 'viewed_at'

@admin.register(PushNotificationDevice)
class PushNotificationDeviceAdmin(admin.ModelAdmin):
    list_display = ['user', 'platform', 'is_active', 'created_at']
    list_filter = ['platform', 'is_active']

# ── New feature models ────────────────────────────────────────────

@admin.register(ChatRoom)
class ChatRoomAdmin(admin.ModelAdmin):
    list_display = ['property', 'buyer', 'seller', 'updated_at']

@admin.register(ChatMessage)
class ChatMessageAdmin(admin.ModelAdmin):
    list_display = ['room', 'sender', 'is_read', 'created_at']
    list_filter = ['is_read']

@admin.register(Offer)
class OfferAdmin(admin.ModelAdmin):
    list_display = ['property', 'buyer', 'amount', 'status', 'is_cash_buyer', 'is_chain_free', 'created_at']
    list_filter = ['status', 'is_cash_buyer', 'is_chain_free']
    actions = ['accept_offers', 'reject_offers']
    @admin.action(description='Accept offers')
    def accept_offers(self, request, qs): qs.update(status='accepted')
    @admin.action(description='Reject offers')
    def reject_offers(self, request, qs): qs.update(status='rejected')

@admin.register(ViewingSlot)
class ViewingSlotAdmin(admin.ModelAdmin):
    list_display = ['property', 'date', 'day_of_week', 'start_time', 'end_time', 'is_active']
    list_filter = ['is_active']

@admin.register(PropertyDocument)
class PropertyDocumentAdmin(admin.ModelAdmin):
    list_display = ['property', 'document_type', 'title', 'is_public', 'uploaded_at']
    list_filter = ['document_type', 'is_public']

@admin.register(PropertyFlag)
class PropertyFlagAdmin(admin.ModelAdmin):
    list_display = ['property', 'reporter', 'reason', 'status', 'created_at']
    list_filter = ['status', 'reason']
    actions = ['mark_reviewed', 'dismiss_flags']
    @admin.action(description='Mark as reviewed')
    def mark_reviewed(self, request, qs): qs.update(status='reviewed', resolved_at=timezone.now())
    @admin.action(description='Dismiss flags')
    def dismiss_flags(self, request, qs): qs.update(status='dismissed', resolved_at=timezone.now())

# ── Service Provider ──────────────────────────────────────────────

@admin.register(ServiceCategory)
class ServiceCategoryAdmin(admin.ModelAdmin):
    list_display = ['name', 'slug', 'icon', 'order']
    list_editable = ['order']
    prepopulated_fields = {'slug': ('name',)}

class ServiceProviderReviewInline(admin.TabularInline):
    model = ServiceProviderReview; extra = 0; readonly_fields = ['reviewer', 'rating', 'comment', 'created_at']
class ServiceProviderSubscriptionInline(admin.TabularInline):
    model = ServiceProviderSubscription; extra = 0
class ServiceProviderPhotoInline(admin.TabularInline):
    model = ServiceProviderPhoto; extra = 0

@admin.register(ServiceProvider)
class ServiceProviderAdmin(admin.ModelAdmin):
    list_display = ['business_name', 'owner', 'status', 'is_verified', 'created_at']
    list_filter = ['status', 'is_verified']
    list_editable = ['status', 'is_verified']
    inlines = [ServiceProviderSubscriptionInline, ServiceProviderPhotoInline, ServiceProviderReviewInline]
    actions = ['approve_providers', 'verify_providers']
    @admin.action(description='Approve providers')
    def approve_providers(self, request, qs): qs.update(status='active')
    @admin.action(description='Verify providers')
    def verify_providers(self, request, qs): qs.update(is_verified=True)

@admin.register(ServiceProviderReview)
class ServiceProviderReviewAdmin(admin.ModelAdmin):
    list_display = ['provider', 'reviewer', 'rating', 'created_at']

@admin.register(SubscriptionTier)
class SubscriptionTierAdmin(admin.ModelAdmin):
    list_display = ['name', 'monthly_price', 'annual_price', 'trial_period_days', 'display_order', 'is_active']
    list_editable = ['display_order', 'is_active', 'trial_period_days']
    prepopulated_fields = {'slug': ('name',)}

@admin.register(SubscriptionAddOn)
class SubscriptionAddOnAdmin(admin.ModelAdmin):
    list_display = ['name', 'monthly_price', 'is_active']
    prepopulated_fields = {'slug': ('name',)}

class ServiceProviderAddOnInline(admin.TabularInline):
    model = ServiceProviderAddOn; extra = 0

@admin.register(ServiceProviderSubscription)
class ServiceProviderSubscriptionAdmin(admin.ModelAdmin):
    list_display = ['provider', 'tier', 'billing_cycle', 'status', 'current_period_end']
    list_filter = ['status', 'tier']
    inlines = [ServiceProviderAddOnInline]

@admin.register(ServiceProviderPhoto)
class ServiceProviderPhotoAdmin(admin.ModelAdmin):
    list_display = ['provider', 'caption', 'order', 'uploaded_at']


# ── New Features Admin (#28-#45) ─────────────────────────────────

@admin.register(BuyerVerification)
class BuyerVerificationAdmin(admin.ModelAdmin):
    list_display = ['user', 'verification_type', 'status', 'expires_at', 'created_at']
    list_filter = ['status', 'verification_type']
    list_editable = ['status']
    actions = ['approve_verifications', 'reject_verifications']

    @admin.action(description='Approve verifications')
    def approve_verifications(self, request, qs):
        qs.update(status='verified', reviewed_at=timezone.now())

    @admin.action(description='Reject verifications')
    def reject_verifications(self, request, qs):
        qs.update(status='rejected', reviewed_at=timezone.now())


class ConveyancingStepInline(admin.TabularInline):
    model = ConveyancingStep
    extra = 0
    fields = ['step_type', 'status', 'notes', 'completed_at', 'order']


@admin.register(ConveyancingCase)
class ConveyancingCaseAdmin(admin.ModelAdmin):
    list_display = ['property', 'buyer', 'seller', 'status', 'created_at']
    list_filter = ['status']
    inlines = [ConveyancingStepInline]


@admin.register(OpenHouseEvent)
class OpenHouseEventAdmin(admin.ModelAdmin):
    list_display = ['property', 'title', 'date', 'start_time', 'end_time', 'is_active']
    list_filter = ['is_active', 'date']


@admin.register(OpenHouseRSVP)
class OpenHouseRSVPAdmin(admin.ModelAdmin):
    list_display = ['event', 'user', 'attendees', 'created_at']


@admin.register(ConveyancerQuoteRequest)
class ConveyancerQuoteRequestAdmin(admin.ModelAdmin):
    list_display = ['property', 'requester', 'transaction_type', 'status', 'created_at']
    list_filter = ['status', 'transaction_type']


@admin.register(ConveyancerQuote)
class ConveyancerQuoteAdmin(admin.ModelAdmin):
    list_display = ['request', 'provider', 'total', 'is_accepted', 'created_at']
    list_filter = ['is_accepted']


@admin.register(NeighbourhoodReview)
class NeighbourhoodReviewAdmin(admin.ModelAdmin):
    list_display = ['postcode_area', 'reviewer', 'overall_rating', 'is_current_resident', 'created_at']
    list_filter = ['overall_rating', 'is_current_resident']
    search_fields = ['postcode_area']


@admin.register(BoardOrder)
class BoardOrderAdmin(admin.ModelAdmin):
    list_display = ['property', 'user', 'board_type', 'status', 'price', 'created_at']
    list_filter = ['status', 'board_type']
    list_editable = ['status']


@admin.register(BuyerProfile)
class BuyerProfileAdmin(admin.ModelAdmin):
    list_display = ['user', 'max_budget', 'is_first_time_buyer', 'is_cash_buyer', 'mortgage_approved']
    list_filter = ['is_first_time_buyer', 'is_cash_buyer', 'mortgage_approved']


@admin.register(ForumCategory)
class ForumCategoryAdmin(admin.ModelAdmin):
    list_display = ['name', 'slug', 'icon', 'order']
    list_editable = ['order']
    prepopulated_fields = {'slug': ('name',)}


@admin.register(ForumTopic)
class ForumTopicAdmin(admin.ModelAdmin):
    list_display = ['title', 'category', 'author', 'is_pinned', 'is_locked', 'view_count', 'created_at']
    list_filter = ['category', 'is_pinned', 'is_locked']
    list_editable = ['is_pinned', 'is_locked']
    search_fields = ['title', 'content']


@admin.register(ForumPost)
class ForumPostAdmin(admin.ModelAdmin):
    list_display = ['topic', 'author', 'is_solution', 'created_at']
    list_filter = ['is_solution']
