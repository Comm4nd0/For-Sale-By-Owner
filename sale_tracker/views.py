from datetime import timedelta
from django.utils import timezone
from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.response import Response
from .models import (
    Sale, Stage, Task, Document, DocumentAccessLog,
    ContactLog, Enquiry, PromptDraft, StageGateOverride,
)
from .serializers import (
    SaleListSerializer, SaleDetailSerializer, SaleCreateSerializer,
    StageSerializer, TaskSerializer, TaskReassignSerializer,
    DocumentSerializer, DocumentUploadSerializer,
    DocumentChecklistItemSerializer,
    ContactLogSerializer, EnquirySerializer, EnquiryReassignSerializer,
    PromptDraftSerializer, PromptGenerateSerializer,
    InstructionReadinessSerializer, InstructionOverrideSerializer,
    DashboardSerializer,
)
from .permissions import IsSaleOwner
from .seed import seed_sale
from .ownership import transfer_ownership, get_dashboard_groups
from .prompt_engine import generate_prompt
from .gdpr import export_sale_data, delete_sale_data


# ── Helpers ────────────────────────────────────────────────────

def _get_sale_for_user(request, sale_pk):
    """Get a sale ensuring it belongs to the authenticated user."""
    return Sale.objects.get(pk=sale_pk, seller=request.user)


def _check_readiness(sale):
    """Check whether a sale is ready for instruction."""
    docs = Document.objects.filter(sale=sale)

    missing_always = []
    missing_if_applicable = []
    warnings = []

    for doc in docs:
        if doc.required_tier == 'always' and doc.status == 'missing':
            missing_always.append({
                'id': doc.id,
                'title': doc.title,
                'helper_text': doc.helper_text,
            })
        elif doc.required_tier == 'if_applicable' and doc.status == 'missing':
            missing_if_applicable.append({
                'id': doc.id,
                'title': doc.title,
                'helper_text': doc.helper_text,
            })

    # Leasehold warning
    if sale.is_leasehold:
        lpe1 = docs.filter(title__icontains='LPE1').first()
        if lpe1 and lpe1.status == 'missing':
            warnings.append(
                'LPE1 leasehold information pack is conveyancer-obtained. '
                'Expected cost \u00a3300\u2013\u00a3800, typical wait 4\u20136 weeks.'
            )

    total = docs.count()
    ready_count = docs.filter(status__in=('have', 'not_applicable')).count()
    ready = len(missing_always) == 0 and len(missing_if_applicable) == 0

    return {
        'ready': ready,
        'missing_always': missing_always,
        'missing_if_applicable': missing_if_applicable,
        'warnings': warnings,
        'total_documents': total,
        'documents_ready': ready_count,
    }


# ── Sale ViewSet ───────────────────────────────────────────────

class SaleViewSet(viewsets.ModelViewSet):
    permission_classes = [permissions.IsAuthenticated, IsSaleOwner]

    def get_queryset(self):
        return Sale.objects.filter(seller=self.request.user)

    def get_serializer_class(self):
        if self.action == 'list':
            return SaleListSerializer
        if self.action == 'create':
            return SaleCreateSerializer
        return SaleDetailSerializer

    def perform_create(self, serializer):
        sale = serializer.save(seller=self.request.user)
        seed_sale(sale)

    @action(detail=True, methods=['get'])
    def readiness(self, request, pk=None):
        sale = self.get_object()
        data = _check_readiness(sale)
        serializer = InstructionReadinessSerializer(data)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def instruct(self, request, pk=None):
        sale = self.get_object()

        if sale.instructed_at:
            return Response(
                {'detail': 'Sale has already been instructed.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        readiness = _check_readiness(sale)

        # Check for override
        override_serializer = InstructionOverrideSerializer(data=request.data)
        has_override = override_serializer.is_valid() and request.data.get('override')

        if not readiness['ready'] and not has_override:
            return Response(
                {
                    'detail': 'Cannot instruct: required documents are missing.',
                    'readiness': readiness,
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        if has_override and not readiness['ready']:
            StageGateOverride.objects.create(
                sale=sale,
                reason=override_serializer.validated_data['reason'],
            )

        sale.instructed_at = timezone.now()
        sale.save(update_fields=['instructed_at'])

        # Mark Stage 0 done, Stage 1 in_progress
        Stage.objects.filter(sale=sale, stage_number=0).update(
            status='done', completed_at=timezone.now(),
        )
        stage_1 = Stage.objects.filter(sale=sale, stage_number=1).first()
        if stage_1:
            stage_1.status = 'in_progress'
            stage_1.started_at = timezone.now()
            stage_1.save(update_fields=['status', 'started_at'])

        return Response(
            SaleDetailSerializer(sale, context={'request': request}).data,
        )

    @action(detail=True, methods=['get'])
    def dashboard(self, request, pk=None):
        sale = self.get_object()
        groups = get_dashboard_groups(sale)

        # Expiring documents (within 30 days)
        thirty_days = timezone.now().date() + timedelta(days=30)
        expiring = Document.objects.filter(
            sale=sale,
            expiry_date__isnull=False,
            expiry_date__lte=thirty_days,
            status='have',
        ).values('id', 'title', 'expiry_date', 'category')

        # Readiness (if not yet instructed)
        readiness = None
        if not sale.instructed_at:
            readiness = _check_readiness(sale)

        data = {
            'your_turn': groups['your_turn'],
            'awaiting_others': groups['awaiting_others'],
            'headline_numbers': groups['headline_numbers'],
            'expiring_documents': list(expiring),
            'readiness': readiness,
        }

        return Response(data)

    @action(detail=True, methods=['get'])
    def timeline(self, request, pk=None):
        sale = self.get_object()

        events = []

        # Stage transitions
        for stage in sale.stages.exclude(started_at=None):
            events.append({
                'type': 'stage_started',
                'date': stage.started_at.isoformat(),
                'title': f"Stage {stage.stage_number}: {stage.name} started",
            })
        for stage in sale.stages.exclude(completed_at=None):
            events.append({
                'type': 'stage_completed',
                'date': stage.completed_at.isoformat(),
                'title': f"Stage {stage.stage_number}: {stage.name} completed",
            })

        # Task completions
        for task in Task.objects.filter(
            stage__sale=sale, completed_at__isnull=False,
        ):
            events.append({
                'type': 'task_completed',
                'date': task.completed_at.isoformat(),
                'title': f"Task completed: {task.title}",
            })

        # Document uploads
        for doc in Document.objects.filter(
            sale=sale, uploaded_at__isnull=False,
        ):
            events.append({
                'type': 'document_uploaded',
                'date': doc.uploaded_at.isoformat(),
                'title': f"Document uploaded: {doc.title}",
            })

        # Contact logs
        for log in sale.contact_logs.all():
            events.append({
                'type': 'contact',
                'date': log.date.isoformat(),
                'title': f"{log.get_channel_display()} with {log.counterparty}",
            })

        # Sort by date descending
        events.sort(key=lambda e: e['date'], reverse=True)

        return Response(events)


# ── Task ViewSet (nested under sale) ───────────────────────────

class TaskViewSet(viewsets.ModelViewSet):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = TaskSerializer

    def get_queryset(self):
        sale_pk = self.kwargs['sale_pk']
        return Task.objects.filter(
            stage__sale_id=sale_pk,
            stage__sale__seller=self.request.user,
        ).select_related('stage')

    def perform_create(self, serializer):
        sale_pk = self.kwargs['sale_pk']
        sale = _get_sale_for_user(self.request, sale_pk)
        stage_id = self.request.data.get('stage_id')
        stage = Stage.objects.get(pk=stage_id, sale=sale)
        serializer.save(stage=stage, is_seed=False)

    @action(detail=True, methods=['post'])
    def reassign(self, request, sale_pk=None, pk=None):
        task = self.get_object()
        serializer = TaskReassignSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        transfer_ownership(
            task,
            serializer.validated_data['new_owner'],
            serializer.validated_data.get('reason', ''),
        )

        return Response(TaskSerializer(task).data)

    @action(detail=True, methods=['post'])
    def complete(self, request, sale_pk=None, pk=None):
        task = self.get_object()
        task.status = 'done'
        task.completed_at = timezone.now()
        task.save(update_fields=['status', 'completed_at'])

        return Response(TaskSerializer(task).data)


# ── Stage ViewSet (nested, read-only) ──────────────────────────

class StageViewSet(viewsets.ReadOnlyModelViewSet):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = StageSerializer

    def get_queryset(self):
        sale_pk = self.kwargs['sale_pk']
        return Stage.objects.filter(
            sale_id=sale_pk,
            sale__seller=self.request.user,
        ).prefetch_related('tasks')


# ── Document ViewSet (nested under sale) ───────────────────────

class DocumentViewSet(viewsets.ModelViewSet):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = DocumentSerializer

    def get_queryset(self):
        sale_pk = self.kwargs['sale_pk']
        return Document.objects.filter(
            sale_id=sale_pk,
            sale__seller=self.request.user,
        )

    def retrieve(self, request, *args, **kwargs):
        instance = self.get_object()
        # Log access
        DocumentAccessLog.objects.create(
            document=instance,
            accessed_by=request.user,
            action='view',
        )
        serializer = self.get_serializer(instance)
        return Response(serializer.data)

    def create(self, request, *args, **kwargs):
        sale_pk = self.kwargs['sale_pk']
        sale = _get_sale_for_user(request, sale_pk)

        upload_serializer = DocumentUploadSerializer(data=request.data)
        upload_serializer.is_valid(raise_exception=True)

        uploaded_file = upload_serializer.validated_data['file']
        doc_id = upload_serializer.validated_data.get('document_id')
        title = upload_serializer.validated_data.get('title', '')

        if doc_id:
            # Attach file to existing document record
            doc = Document.objects.get(pk=doc_id, sale=sale)
            doc.file = uploaded_file
            doc.status = 'have'
            doc.uploaded_at = timezone.now()
            if title:
                doc.title = title
            doc.save()
        else:
            # Create new document record
            doc = Document.objects.create(
                sale=sale,
                title=title or uploaded_file.name,
                category=request.data.get('category', 'property'),
                source='seller_provides',
                required_tier='situational',
                status='have',
                file=uploaded_file,
                uploaded_at=timezone.now(),
                is_seed=False,
            )

        # Log upload
        DocumentAccessLog.objects.create(
            document=doc,
            accessed_by=request.user,
            action='download',
        )

        serializer = DocumentSerializer(doc, context={'request': request})
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()
        # Log deletion
        DocumentAccessLog.objects.create(
            document=instance,
            accessed_by=request.user,
            action='delete',
        )
        # Soft delete: remove file but keep record
        if instance.file:
            instance.file.delete(save=False)
        instance.status = 'missing'
        instance.uploaded_at = None
        instance.save(update_fields=['file', 'status', 'uploaded_at'])

        return Response(status=status.HTTP_204_NO_CONTENT)

    @action(detail=False, methods=['get'])
    def checklist(self, request, sale_pk=None):
        sale_pk = self.kwargs['sale_pk']
        docs = Document.objects.filter(
            sale_id=sale_pk,
            sale__seller=request.user,
            is_seed=True,
        )

        items = []
        for doc in docs:
            items.append({
                'id': doc.id,
                'title': doc.title,
                'category': doc.category,
                'category_display': doc.get_category_display(),
                'required_tier': doc.required_tier,
                'required_tier_display': doc.get_required_tier_display(),
                'status': doc.status,
                'status_display': doc.get_status_display(),
                'helper_text': doc.helper_text,
                'has_file': bool(doc.file),
                'source': doc.source,
                'source_display': doc.get_source_display(),
            })

        serializer = DocumentChecklistItemSerializer(items, many=True)
        return Response(serializer.data)


# ── Contact Log ViewSet ────────────────────────────────────────

class ContactLogViewSet(viewsets.ModelViewSet):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = ContactLogSerializer

    def get_queryset(self):
        sale_pk = self.kwargs['sale_pk']
        return ContactLog.objects.filter(
            sale_id=sale_pk,
            sale__seller=self.request.user,
        )

    def perform_create(self, serializer):
        sale_pk = self.kwargs['sale_pk']
        sale = _get_sale_for_user(self.request, sale_pk)
        serializer.save(sale=sale)


# ── Enquiry ViewSet ────────────────────────────────────────────

class EnquiryViewSet(viewsets.ModelViewSet):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = EnquirySerializer

    def get_queryset(self):
        sale_pk = self.kwargs['sale_pk']
        return Enquiry.objects.filter(
            sale_id=sale_pk,
            sale__seller=self.request.user,
        )

    def perform_create(self, serializer):
        sale_pk = self.kwargs['sale_pk']
        sale = _get_sale_for_user(self.request, sale_pk)
        serializer.save(sale=sale)

    @action(detail=True, methods=['post'])
    def reassign(self, request, sale_pk=None, pk=None):
        enquiry = self.get_object()
        serializer = EnquiryReassignSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        enquiry.current_owner = serializer.validated_data['new_owner']
        enquiry.save(update_fields=['current_owner'])

        return Response(EnquirySerializer(enquiry).data)


# ── Prompt Draft ViewSet ───────────────────────────────────────

class PromptDraftViewSet(viewsets.ReadOnlyModelViewSet):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = PromptDraftSerializer

    def get_queryset(self):
        sale_pk = self.kwargs['sale_pk']
        return PromptDraft.objects.filter(
            sale_id=sale_pk,
            sale__seller=self.request.user,
        )

    def partial_update(self, request, *args, **kwargs):
        """Allow updating sent_marker and sent_at."""
        draft = self.get_object()
        if 'sent_marker' in request.data:
            draft.sent_marker = request.data['sent_marker']
            if draft.sent_marker:
                draft.sent_at = timezone.now()
            else:
                draft.sent_at = None
            draft.save(update_fields=['sent_marker', 'sent_at'])
        return Response(PromptDraftSerializer(draft).data)

    @action(detail=False, methods=['post'])
    def generate(self, request, sale_pk=None):
        sale_pk = self.kwargs['sale_pk']
        sale = _get_sale_for_user(request, sale_pk)

        serializer = PromptGenerateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        task_ids = serializer.validated_data.get('task_ids', [])
        tasks = None
        if task_ids:
            tasks = Task.objects.filter(
                pk__in=task_ids,
                stage__sale=sale,
            )

        draft = generate_prompt(
            sale=sale,
            counterparty_type=serializer.validated_data['counterparty_type'],
            level=serializer.validated_data['level'],
            tasks=tasks,
        )

        return Response(
            PromptDraftSerializer(draft).data,
            status=status.HTTP_201_CREATED,
        )


# ── GDPR endpoints ─────────────────────────────────────────────

@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def gdpr_export(request):
    data = export_sale_data(request.user)
    return Response(data)


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def gdpr_delete(request):
    delete_sale_data(request.user)
    return Response(
        {'detail': 'Your sale tracker data has been deleted.'},
        status=status.HTTP_204_NO_CONTENT,
    )
