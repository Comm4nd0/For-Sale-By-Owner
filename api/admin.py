from django.contrib import admin
from django.contrib.auth import get_user_model
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.utils.html import format_html
from .models import (
    Property, PropertyImage, PropertyFloorplan, PropertyFeature,
    PriceHistory, SavedProperty, Enquiry, PropertyView,
    ViewingRequest, SavedSearch, PushNotificationDevice, Reply,
    ServiceCategory, ServiceProvider, ServiceProviderReview,
)
from .notifications import notify_listing_approved, notify_listing_rejected

User = get_user_model()


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    ordering = ['email']
    list_display = ['email', 'first_name', 'last_name', 'is_verified_seller', 'is_staff', 'date_joined']
    list_filter = ['is_verified_seller', 'is_staff', 'is_active']
    search_fields = ['email', 'first_name', 'last_name']
    fieldsets = (
        (None, {'fields': ('email', 'password')}),
        ('Personal info', {'fields': ('first_name', 'last_name', 'phone')}),
        ('Seller', {'fields': ('is_verified_seller',)}),
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


@admin.register(Property)
class PropertyAdmin(admin.ModelAdmin):
    list_display = ['title', 'property_type', 'status', 'status_badge', 'epc_rating', 'price_display', 'city', 'postcode', 'owner', 'view_count', 'enquiry_count', 'created_at']
    list_filter = ['status', 'property_type', 'epc_rating', 'city', 'created_at']
    list_editable = ['status']
    search_fields = ['title', 'address_line_1', 'city', 'postcode', 'owner__email', 'slug']
    readonly_fields = ['slug', 'view_count', 'enquiry_count', 'save_count', 'created_at', 'updated_at']
    inlines = [PropertyImageInline, PropertyFloorplanInline]
    filter_horizontal = ['features']
    actions = ['approve_listings', 'reject_listings', 'mark_active', 'mark_withdrawn']
    fieldsets = (
        (None, {'fields': ('owner', 'title', 'slug', 'status', 'price')}),
        ('Property Details', {'fields': ('property_type', 'description', 'epc_rating', 'bedrooms', 'bathrooms', 'reception_rooms', 'square_feet', 'features')}),
        ('Address', {'fields': ('address_line_1', 'address_line_2', 'city', 'county', 'postcode')}),
        ('Statistics', {'fields': ('view_count', 'enquiry_count', 'save_count')}),
        ('Dates', {'fields': ('created_at', 'updated_at')}),
    )

    def status_badge(self, obj):
        colours = {
            'draft': '#999',
            'pending_review': '#E67E22',
            'active': '#27AE60',
            'under_offer': '#F39C12',
            'sold_stc': '#F39C12',
            'sold': '#2ECC71',
            'withdrawn': '#E74C3C',
            'rejected': '#C0392B',
        }
        colour = colours.get(obj.status, '#999')
        return format_html(
            '<span style="background:{}; color:white; padding:3px 8px; border-radius:3px; font-size:11px;">{}</span>',
            colour, obj.get_status_display()
        )
    status_badge.short_description = 'Status'

    def price_display(self, obj):
        return f"\u00A3{obj.price:,.0f}"
    price_display.short_description = 'Price'

    def view_count(self, obj):
        return obj.views.count()
    view_count.short_description = 'Views'

    def enquiry_count(self, obj):
        return obj.enquiries.count()
    enquiry_count.short_description = 'Enquiries'

    def save_count(self, obj):
        return obj.saved_by.count()
    save_count.short_description = 'Saves'

    @admin.action(description='Approve selected listings (set Active)')
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
    def mark_active(self, request, queryset):
        queryset.update(status='active')

    @admin.action(description='Mark as Withdrawn')
    def mark_withdrawn(self, request, queryset):
        queryset.update(status='withdrawn')


@admin.register(PropertyFeature)
class PropertyFeatureAdmin(admin.ModelAdmin):
    list_display = ['name', 'icon']
    search_fields = ['name']


@admin.register(PriceHistory)
class PriceHistoryAdmin(admin.ModelAdmin):
    list_display = ['property', 'price', 'changed_at']
    list_filter = ['changed_at']
    search_fields = ['property__title']
    readonly_fields = ['changed_at']


@admin.register(PropertyFloorplan)
class PropertyFloorplanAdmin(admin.ModelAdmin):
    list_display = ['property', 'title', 'order', 'uploaded_at']
    search_fields = ['property__title', 'title']
    readonly_fields = ['uploaded_at']


class EnquiryReplyInline(admin.TabularInline):
    model = Reply
    fk_name = 'enquiry'
    extra = 0
    readonly_fields = ['author', 'message', 'created_at']


class ViewingReplyInline(admin.TabularInline):
    model = Reply
    fk_name = 'viewing_request'
    extra = 0
    readonly_fields = ['author', 'message', 'created_at']


@admin.register(Enquiry)
class EnquiryAdmin(admin.ModelAdmin):
    list_display = ['property', 'name', 'email', 'is_read', 'created_at']
    list_filter = ['is_read', 'created_at']
    search_fields = ['name', 'email', 'property__title', 'message']
    readonly_fields = ['created_at']
    inlines = [EnquiryReplyInline]
    actions = ['mark_read', 'mark_unread']

    @admin.action(description='Mark as read')
    def mark_read(self, request, queryset):
        queryset.update(is_read=True)

    @admin.action(description='Mark as unread')
    def mark_unread(self, request, queryset):
        queryset.update(is_read=False)


@admin.register(ViewingRequest)
class ViewingRequestAdmin(admin.ModelAdmin):
    list_display = ['property', 'name', 'preferred_date', 'preferred_time', 'status', 'created_at']
    list_filter = ['status', 'preferred_date', 'created_at']
    list_editable = ['status']
    search_fields = ['property__title', 'name', 'email']
    readonly_fields = ['created_at', 'updated_at']
    inlines = [ViewingReplyInline]


@admin.register(Reply)
class ReplyAdmin(admin.ModelAdmin):
    list_display = ['id', 'author', 'enquiry', 'viewing_request', 'created_at']
    list_filter = ['created_at']
    search_fields = ['author__email', 'message']
    readonly_fields = ['created_at']


@admin.register(SavedSearch)
class SavedSearchAdmin(admin.ModelAdmin):
    list_display = ['user', 'name', 'location', 'property_type', 'email_alerts', 'created_at']
    list_filter = ['email_alerts', 'property_type', 'created_at']
    search_fields = ['user__email', 'name', 'location']
    readonly_fields = ['created_at']


@admin.register(SavedProperty)
class SavedPropertyAdmin(admin.ModelAdmin):
    list_display = ['user', 'property', 'created_at']
    list_filter = ['created_at']
    search_fields = ['user__email', 'property__title']
    readonly_fields = ['created_at']


@admin.register(PropertyView)
class PropertyViewAdmin(admin.ModelAdmin):
    list_display = ['property', 'user', 'viewer_ip', 'viewed_at']
    list_filter = ['viewed_at']
    search_fields = ['property__title', 'user__email', 'viewer_ip']
    readonly_fields = ['viewed_at']
    date_hierarchy = 'viewed_at'


@admin.register(PushNotificationDevice)
class PushNotificationDeviceAdmin(admin.ModelAdmin):
    list_display = ['user', 'platform', 'is_active', 'created_at']
    list_filter = ['platform', 'is_active']
    search_fields = ['user__email', 'token']
    readonly_fields = ['created_at']


# ── Service Provider models ──────────────────────────────────────

@admin.register(ServiceCategory)
class ServiceCategoryAdmin(admin.ModelAdmin):
    list_display = ['name', 'slug', 'icon', 'order']
    list_editable = ['order']
    search_fields = ['name']
    prepopulated_fields = {'slug': ('name',)}


class ServiceProviderReviewInline(admin.TabularInline):
    model = ServiceProviderReview
    extra = 0
    readonly_fields = ['reviewer', 'rating', 'comment', 'created_at']


@admin.register(ServiceProvider)
class ServiceProviderAdmin(admin.ModelAdmin):
    list_display = ['business_name', 'owner', 'status', 'is_verified', 'review_count_display', 'created_at']
    list_filter = ['status', 'is_verified', 'categories', 'created_at']
    list_editable = ['status', 'is_verified']
    search_fields = ['business_name', 'owner__email', 'coverage_counties', 'coverage_postcodes']
    readonly_fields = ['slug', 'created_at', 'updated_at']
    filter_horizontal = ['categories']
    inlines = [ServiceProviderReviewInline]
    actions = ['approve_providers', 'verify_providers']

    def review_count_display(self, obj):
        return obj.reviews.count()
    review_count_display.short_description = 'Reviews'

    @admin.action(description='Approve selected providers (set Active)')
    def approve_providers(self, request, queryset):
        queryset.update(status='active')

    @admin.action(description='Mark as verified')
    def verify_providers(self, request, queryset):
        queryset.update(is_verified=True)


@admin.register(ServiceProviderReview)
class ServiceProviderReviewAdmin(admin.ModelAdmin):
    list_display = ['provider', 'reviewer', 'rating', 'created_at']
    list_filter = ['rating', 'created_at']
    search_fields = ['provider__business_name', 'reviewer__email', 'comment']
    readonly_fields = ['created_at']
