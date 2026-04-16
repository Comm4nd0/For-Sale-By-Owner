from rest_framework import serializers
from django.utils import timezone
from api.validators import validate_document_file
from .models import (
    Sale, Stage, Task, TaskOwnershipHistory, Document,
    DocumentDelivery, DocumentAccessLog, ContactLog, Enquiry,
    PromptDraft, StageGateOverride,
)


# ── Task ───────────────────────────────────────────────────────

class TaskOwnershipHistorySerializer(serializers.ModelSerializer):
    from_owner_display = serializers.CharField(
        source='get_from_owner_display', read_only=True,
    )
    to_owner_display = serializers.CharField(
        source='get_to_owner_display', read_only=True,
    )

    class Meta:
        model = TaskOwnershipHistory
        fields = [
            'id', 'from_owner', 'from_owner_display',
            'to_owner', 'to_owner_display',
            'transferred_at', 'reason',
        ]
        read_only_fields = fields


class TaskSerializer(serializers.ModelSerializer):
    current_owner_display = serializers.CharField(
        source='get_current_owner_display', read_only=True,
    )
    status_display = serializers.CharField(
        source='get_status_display', read_only=True,
    )
    days_awaiting = serializers.IntegerField(read_only=True)
    stage_name = serializers.CharField(source='stage.name', read_only=True)
    stage_number = serializers.IntegerField(source='stage.stage_number', read_only=True)
    ownership_history = TaskOwnershipHistorySerializer(
        many=True, read_only=True,
    )

    class Meta:
        model = Task
        fields = [
            'id', 'title', 'description', 'current_owner',
            'current_owner_display', 'status', 'status_display',
            'awaiting_since', 'awaiting_reason', 'due_date',
            'completed_at', 'notes', 'is_seed', 'order',
            'days_awaiting', 'stage_name', 'stage_number',
            'ownership_history',
        ]
        read_only_fields = [
            'id', 'completed_at', 'is_seed', 'days_awaiting',
            'stage_name', 'stage_number', 'ownership_history',
        ]


class TaskReassignSerializer(serializers.Serializer):
    new_owner = serializers.ChoiceField(
        choices=[c[0] for c in Task._meta.get_field('current_owner').choices],
    )
    reason = serializers.CharField(required=False, default='')


# ── Stage ──────────────────────────────────────────────────────

class StageSerializer(serializers.ModelSerializer):
    status_display = serializers.CharField(
        source='get_status_display', read_only=True,
    )
    tasks = TaskSerializer(many=True, read_only=True)
    task_count = serializers.SerializerMethodField()
    completed_task_count = serializers.SerializerMethodField()

    class Meta:
        model = Stage
        fields = [
            'id', 'stage_number', 'name', 'status', 'status_display',
            'started_at', 'completed_at', 'tasks',
            'task_count', 'completed_task_count',
        ]
        read_only_fields = fields

    def get_task_count(self, obj):
        return obj.tasks.count()

    def get_completed_task_count(self, obj):
        return obj.tasks.filter(status='done').count()


# ── Document ───────────────────────────────────────────────────

class DocumentSerializer(serializers.ModelSerializer):
    category_display = serializers.CharField(
        source='get_category_display', read_only=True,
    )
    source_display = serializers.CharField(
        source='get_source_display', read_only=True,
    )
    required_tier_display = serializers.CharField(
        source='get_required_tier_display', read_only=True,
    )
    status_display = serializers.CharField(
        source='get_status_display', read_only=True,
    )
    file_url = serializers.SerializerMethodField()

    class Meta:
        model = Document
        fields = [
            'id', 'title', 'category', 'category_display',
            'source', 'source_display',
            'required_tier', 'required_tier_display',
            'status', 'status_display',
            'file', 'file_url', 'uploaded_at', 'expiry_date',
            'na_reason', 'helper_text', 'is_seed',
        ]
        read_only_fields = [
            'id', 'uploaded_at', 'is_seed',
            'file_url', 'category_display', 'source_display',
            'required_tier_display', 'status_display',
        ]

    def get_file_url(self, obj):
        if obj.file:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.file.url)
            return obj.file.url
        return None


class DocumentUploadSerializer(serializers.Serializer):
    file = serializers.FileField()
    title = serializers.CharField(max_length=200, required=False)
    document_id = serializers.IntegerField(
        required=False,
        help_text='ID of existing document record to attach file to',
    )

    def validate_file(self, value):
        validate_document_file(value)
        return value


class DocumentChecklistItemSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    title = serializers.CharField()
    category = serializers.CharField()
    category_display = serializers.CharField()
    required_tier = serializers.CharField()
    required_tier_display = serializers.CharField()
    status = serializers.CharField()
    status_display = serializers.CharField()
    helper_text = serializers.CharField()
    has_file = serializers.BooleanField()
    source = serializers.CharField()
    source_display = serializers.CharField()


# ── Contact Log ────────────────────────────────────────────────

class ContactLogSerializer(serializers.ModelSerializer):
    channel_display = serializers.CharField(
        source='get_channel_display', read_only=True,
    )

    class Meta:
        model = ContactLog
        fields = [
            'id', 'date', 'channel', 'channel_display',
            'counterparty', 'summary', 'follow_up_date',
            'related_task',
        ]
        read_only_fields = ['id']


# ── Enquiry ────────────────────────────────────────────────────

class EnquirySerializer(serializers.ModelSerializer):
    current_owner_display = serializers.CharField(
        source='get_current_owner_display', read_only=True,
    )
    status_display = serializers.CharField(
        source='get_status_display', read_only=True,
    )

    class Meta:
        model = Enquiry
        fields = [
            'id', 'raised_date', 'raised_by', 'question',
            'current_owner', 'current_owner_display',
            'status', 'status_display',
            'response', 'response_date',
        ]
        read_only_fields = ['id', 'raised_date']


class EnquiryReassignSerializer(serializers.Serializer):
    new_owner = serializers.ChoiceField(
        choices=[c[0] for c in Enquiry._meta.get_field('current_owner').choices],
    )
    reason = serializers.CharField(required=False, default='')


# ── Prompt Draft ───────────────────────────────────────────────

class PromptDraftSerializer(serializers.ModelSerializer):
    recipient_owner_display = serializers.CharField(
        source='get_recipient_owner_display', read_only=True,
    )
    level_display = serializers.CharField(
        source='get_level_display', read_only=True,
    )

    class Meta:
        model = PromptDraft
        fields = [
            'id', 'generated_at', 'recipient_owner',
            'recipient_owner_display', 'level', 'level_display',
            'template_key', 'subject', 'body_text',
            'sent_marker', 'sent_at',
        ]
        read_only_fields = [
            'id', 'generated_at', 'template_key',
            'subject', 'body_text',
        ]


class PromptGenerateSerializer(serializers.Serializer):
    counterparty_type = serializers.ChoiceField(
        choices=[c[0] for c in PromptDraft._meta.get_field('recipient_owner').choices],
    )
    level = serializers.ChoiceField(
        choices=[c[0] for c in PromptDraft._meta.get_field('level').choices],
    )
    task_ids = serializers.ListField(
        child=serializers.IntegerField(),
        required=False,
        default=[],
    )


# ── Sale ───────────────────────────────────────────────────────

class SaleListSerializer(serializers.ModelSerializer):
    status_display = serializers.CharField(
        source='get_status_display', read_only=True,
    )
    tenure_display = serializers.CharField(
        source='get_tenure_display', read_only=True,
    )
    current_stage_name = serializers.SerializerMethodField()
    current_stage_number = serializers.SerializerMethodField()
    total_tasks = serializers.SerializerMethodField()
    completed_tasks = serializers.SerializerMethodField()
    your_turn_count = serializers.SerializerMethodField()

    class Meta:
        model = Sale
        fields = [
            'id', 'property_address', 'status', 'status_display',
            'tenure', 'tenure_display', 'buyer_name',
            'agreed_price', 'instructed_at',
            'target_completion_date',
            'current_stage_name', 'current_stage_number',
            'total_tasks', 'completed_tasks', 'your_turn_count',
            'created_at',
        ]

    def get_current_stage_name(self, obj):
        stage = obj.current_stage
        return stage.name if stage else None

    def get_current_stage_number(self, obj):
        stage = obj.current_stage
        return stage.stage_number if stage else None

    def get_total_tasks(self, obj):
        return Task.objects.filter(stage__sale=obj).count()

    def get_completed_tasks(self, obj):
        return Task.objects.filter(stage__sale=obj, status='done').count()

    def get_your_turn_count(self, obj):
        return Task.objects.filter(
            stage__sale=obj,
            current_owner='seller',
        ).exclude(status__in=('done', 'n_a')).count()


class SaleDetailSerializer(serializers.ModelSerializer):
    status_display = serializers.CharField(
        source='get_status_display', read_only=True,
    )
    tenure_display = serializers.CharField(
        source='get_tenure_display', read_only=True,
    )
    buyer_position_display = serializers.CharField(
        source='get_buyer_position_display', read_only=True,
    )
    notification_frequency_display = serializers.CharField(
        source='get_notification_frequency_display', read_only=True,
    )
    stages = StageSerializer(many=True, read_only=True)
    days_since_instruction = serializers.IntegerField(read_only=True)
    days_to_target_exchange = serializers.IntegerField(read_only=True)
    days_to_target_completion = serializers.IntegerField(read_only=True)

    class Meta:
        model = Sale
        fields = [
            'id', 'property_address', 'asking_price', 'agreed_price',
            'tenure', 'tenure_display',
            'agent_name', 'agent_contact',
            'seller_conveyancer_name', 'seller_conveyancer_contact',
            'buyer_name', 'buyer_contact',
            'buyer_conveyancer_name', 'buyer_conveyancer_contact',
            'buyer_position', 'buyer_position_display',
            'chain_length',
            'target_exchange_date', 'target_completion_date',
            'status', 'status_display',
            'instructed_at',
            'notification_frequency', 'notification_frequency_display',
            'stages',
            'days_since_instruction', 'days_to_target_exchange',
            'days_to_target_completion',
            'created_at', 'updated_at',
        ]
        read_only_fields = [
            'id', 'instructed_at', 'stages',
            'days_since_instruction', 'days_to_target_exchange',
            'days_to_target_completion',
            'created_at', 'updated_at',
        ]


class SaleCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Sale
        fields = [
            'property_address', 'asking_price', 'agreed_price',
            'tenure',
            'agent_name', 'agent_contact',
            'seller_conveyancer_name', 'seller_conveyancer_contact',
            'buyer_name', 'buyer_contact',
            'buyer_conveyancer_name', 'buyer_conveyancer_contact',
            'buyer_position', 'chain_length',
            'target_exchange_date', 'target_completion_date',
            'notification_frequency',
        ]


# ── Instruction readiness ──────────────────────────────────────

class InstructionReadinessSerializer(serializers.Serializer):
    ready = serializers.BooleanField()
    missing_always = serializers.ListField(child=serializers.DictField())
    missing_if_applicable = serializers.ListField(child=serializers.DictField())
    warnings = serializers.ListField(child=serializers.CharField())
    total_documents = serializers.IntegerField()
    documents_ready = serializers.IntegerField()


class InstructionOverrideSerializer(serializers.Serializer):
    reason = serializers.CharField(min_length=10)


# ── Dashboard ──────────────────────────────────────────────────

class DashboardSerializer(serializers.Serializer):
    your_turn = serializers.ListField()
    awaiting_others = serializers.DictField()
    headline_numbers = serializers.DictField()
    expiring_documents = serializers.ListField()
    readiness = serializers.DictField(required=False)


# ── Stage Gate Override ────────────────────────────────────────

class StageGateOverrideSerializer(serializers.ModelSerializer):
    class Meta:
        model = StageGateOverride
        fields = ['id', 'overridden_at', 'reason']
        read_only_fields = ['id', 'overridden_at']
