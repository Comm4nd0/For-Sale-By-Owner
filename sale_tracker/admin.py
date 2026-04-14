from django.contrib import admin
from django.utils.html import format_html
from .models import (
    Sale, Stage, Task, TaskOwnershipHistory, Document,
    DocumentDelivery, DocumentAccessLog, ContactLog, Enquiry,
    PromptDraft, StageGateOverride,
)


# ── Inlines ────────────────────────────────────────────────────

class StageInline(admin.TabularInline):
    model = Stage
    extra = 0
    readonly_fields = ('stage_number', 'name', 'status', 'started_at', 'completed_at')
    can_delete = False


class TaskOwnershipHistoryInline(admin.TabularInline):
    model = TaskOwnershipHistory
    extra = 0
    readonly_fields = ('from_owner', 'to_owner', 'transferred_at', 'reason')
    can_delete = False


class DocumentAccessLogInline(admin.TabularInline):
    model = DocumentAccessLog
    extra = 0
    readonly_fields = ('accessed_by', 'accessed_at', 'action')
    can_delete = False


class StageGateOverrideInline(admin.TabularInline):
    model = StageGateOverride
    extra = 0
    readonly_fields = ('overridden_at', 'reason')
    can_delete = False


# ── Sale ───────────────────────────────────────────────────────

@admin.register(Sale)
class SaleAdmin(admin.ModelAdmin):
    list_display = (
        'property_address', 'seller', 'status_badge', 'tenure',
        'buyer_name', 'instructed_at', 'created_at',
    )
    list_filter = ('status', 'tenure')
    search_fields = ('property_address', 'seller__email', 'buyer_name')
    readonly_fields = ('created_at', 'updated_at')
    inlines = [StageInline, StageGateOverrideInline]

    fieldsets = (
        (None, {
            'fields': (
                'seller', 'property_address', 'status', 'tenure',
                'asking_price', 'agreed_price',
            ),
        }),
        ('Parties', {
            'fields': (
                'buyer_name', 'buyer_contact', 'buyer_position', 'chain_length',
                'agent_name', 'agent_contact',
                'seller_conveyancer_name', 'seller_conveyancer_contact',
                'buyer_conveyancer_name', 'buyer_conveyancer_contact',
            ),
        }),
        ('Timeline', {
            'fields': (
                'target_exchange_date', 'target_completion_date',
                'instructed_at', 'notification_frequency',
            ),
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',),
        }),
    )

    def status_badge(self, obj):
        colours = {
            'active': '#28a745',
            'completed': '#6c757d',
            'cancelled': '#dc3545',
        }
        colour = colours.get(obj.status, '#6c757d')
        return format_html(
            '<span style="background:{}; color:#fff; padding:3px 8px; '
            'border-radius:4px; font-size:11px;">{}</span>',
            colour, obj.get_status_display(),
        )
    status_badge.short_description = 'Status'


# ── Stage ──────────────────────────────────────────────────────

@admin.register(Stage)
class StageAdmin(admin.ModelAdmin):
    list_display = ('sale', 'stage_number', 'name', 'status')
    list_filter = ('status',)
    readonly_fields = ('started_at', 'completed_at')


# ── Task ───────────────────────────────────────────────────────

@admin.register(Task)
class TaskAdmin(admin.ModelAdmin):
    list_display = ('title', 'stage', 'current_owner', 'status', 'awaiting_since', 'days_awaiting')
    list_filter = ('current_owner', 'status', 'is_seed')
    search_fields = ('title',)
    readonly_fields = ('completed_at',)
    inlines = [TaskOwnershipHistoryInline]

    def days_awaiting(self, obj):
        return obj.days_awaiting
    days_awaiting.short_description = 'Days'


# ── Document ───────────────────────────────────────────────────

@admin.register(Document)
class DocumentAdmin(admin.ModelAdmin):
    list_display = ('title', 'sale', 'category', 'required_tier', 'status', 'uploaded_at')
    list_filter = ('category', 'required_tier', 'status')
    search_fields = ('title',)
    inlines = [DocumentAccessLogInline]


# ── Contact Log ────────────────────────────────────────────────

@admin.register(ContactLog)
class ContactLogAdmin(admin.ModelAdmin):
    list_display = ('sale', 'channel', 'counterparty', 'date', 'follow_up_date')
    list_filter = ('channel',)
    search_fields = ('counterparty', 'summary')


# ── Enquiry ────────────────────────────────────────────────────

@admin.register(Enquiry)
class EnquiryAdmin(admin.ModelAdmin):
    list_display = ('sale', 'raised_by', 'current_owner', 'status', 'raised_date')
    list_filter = ('status', 'current_owner')
    search_fields = ('question',)


# ── Prompt Draft ───────────────────────────────────────────────

@admin.register(PromptDraft)
class PromptDraftAdmin(admin.ModelAdmin):
    list_display = ('sale', 'recipient_owner', 'level', 'sent_marker', 'generated_at')
    list_filter = ('recipient_owner', 'level', 'sent_marker')
    readonly_fields = ('generated_at',)


# ── Read-only audit models ─────────────────────────────────────

@admin.register(TaskOwnershipHistory)
class TaskOwnershipHistoryAdmin(admin.ModelAdmin):
    list_display = ('task', 'from_owner', 'to_owner', 'transferred_at')
    readonly_fields = ('task', 'from_owner', 'to_owner', 'transferred_at', 'reason')

    def has_add_permission(self, request):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


@admin.register(DocumentAccessLog)
class DocumentAccessLogAdmin(admin.ModelAdmin):
    list_display = ('document', 'accessed_by', 'action', 'accessed_at')
    readonly_fields = ('document', 'accessed_by', 'accessed_at', 'action')

    def has_add_permission(self, request):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


@admin.register(StageGateOverride)
class StageGateOverrideAdmin(admin.ModelAdmin):
    list_display = ('sale', 'overridden_at', 'reason')
    readonly_fields = ('sale', 'overridden_at', 'reason')

    def has_add_permission(self, request):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


@admin.register(DocumentDelivery)
class DocumentDeliveryAdmin(admin.ModelAdmin):
    list_display = ('document', 'recipient_type', 'delivery_method', 'delivered_at')
    readonly_fields = ('delivered_at',)
