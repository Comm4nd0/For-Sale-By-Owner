"""
Celery tasks for the Sale Tracker.

Nightly threshold scans, notification dispatching,
and document cleanup.
"""

import logging
from celery import shared_task
from django.utils import timezone

logger = logging.getLogger(__name__)


@shared_task
def nightly_sale_tracker_scan():
    """
    Nightly scan of all active sales.

    For each open task, checks how many days it has been with its
    current owner and emits notification events when thresholds
    are crossed (Day 5, Day 10, Day 14+).

    This task should be scheduled via django_celery_beat
    (e.g. daily at 02:00).
    """
    from .models import Sale, Task

    active_sales = Sale.objects.filter(
        status='active',
        instructed_at__isnull=False,
    )

    today = timezone.now().date()
    notifications_sent = 0

    for sale in active_sales:
        tasks = Task.objects.filter(
            stage__sale=sale,
            awaiting_since__isnull=False,
        ).exclude(
            status__in=('done', 'n_a'),
        ).exclude(
            current_owner='seller',
        )

        for task in tasks:
            days = (today - task.awaiting_since).days

            if days >= 14:
                send_sale_tracker_notification.delay(
                    sale.id,
                    'threshold_14',
                    {
                        'task_id': task.id,
                        'task_title': task.title,
                        'current_owner': task.current_owner,
                        'days': days,
                    },
                )
                notifications_sent += 1

            elif days >= 10:
                send_sale_tracker_notification.delay(
                    sale.id,
                    'threshold_10',
                    {
                        'task_id': task.id,
                        'task_title': task.title,
                        'current_owner': task.current_owner,
                        'days': days,
                    },
                )
                notifications_sent += 1

            elif days >= 5:
                send_sale_tracker_notification.delay(
                    sale.id,
                    'threshold_5',
                    {
                        'task_id': task.id,
                        'task_title': task.title,
                        'current_owner': task.current_owner,
                        'days': days,
                    },
                )
                notifications_sent += 1

    logger.info(
        "Sale tracker nightly scan complete. "
        "Sales scanned: %d, notifications: %d",
        active_sales.count(), notifications_sent,
    )
    return notifications_sent


@shared_task
def send_sale_tracker_notification(sale_id, event_type, data=None):
    """
    Dispatch a sale tracker notification event via the existing
    platform notification layer.

    Event types:
    - threshold_5: Item with owner for 5+ days
    - threshold_10: Item with owner for 10+ days
    - threshold_14: Item with owner for 14+ days
    - task_completed: A task was completed
    - document_uploaded: A document was uploaded
    - stage_advanced: A stage was completed
    """
    from .models import Sale

    try:
        sale = Sale.objects.select_related('seller').get(pk=sale_id)
    except Sale.DoesNotExist:
        logger.warning("Sale %d not found for notification", sale_id)
        return

    user = sale.seller
    data = data or {}

    # Build notification content based on event type
    titles = {
        'threshold_5': 'Sale Tracker: Item awaiting action',
        'threshold_10': 'Sale Tracker: Follow-up suggested',
        'threshold_14': 'Sale Tracker: Consider following up',
        'task_completed': 'Sale Tracker: Task completed',
        'document_uploaded': 'Sale Tracker: Document uploaded',
        'stage_advanced': 'Sale Tracker: Stage completed',
    }

    bodies = {
        'threshold_5': (
            f"{data.get('task_title', 'An item')} has been with "
            f"{data.get('current_owner', 'another party').replace('_', ' ')} "
            f"for {data.get('days', 5)} days."
        ),
        'threshold_10': (
            f"{data.get('task_title', 'An item')} has been with "
            f"{data.get('current_owner', 'another party').replace('_', ' ')} "
            f"for {data.get('days', 10)} days. A follow-up draft is available."
        ),
        'threshold_14': (
            f"{data.get('task_title', 'An item')} has been outstanding for "
            f"{data.get('days', 14)} days. You may wish to follow up."
        ),
        'task_completed': f"Task completed: {data.get('task_title', '')}",
        'document_uploaded': f"Document uploaded: {data.get('title', '')}",
        'stage_advanced': f"Stage completed: {data.get('stage_name', '')}",
    }

    title = titles.get(event_type, 'Sale Tracker Update')
    body = bodies.get(event_type, 'You have a sale tracker update.')

    # Use existing platform push notification
    try:
        from api.tasks import send_push_notification
        send_push_notification.delay(
            user.id, title, body,
            {'type': 'sale_tracker', 'sale_id': sale_id, 'event': event_type},
        )
    except ImportError:
        logger.info("Push notifications not available")

    # Use existing email task if notification preference allows
    if sale.notification_frequency == 'realtime':
        try:
            from api.tasks import send_email_task
            send_email_task.delay(
                subject=title,
                message=body,
                recipient_list=[user.email],
            )
        except ImportError:
            logger.info("Email task not available")


@shared_task
def cleanup_expired_sale_documents():
    """
    Weekly cleanup of document files for completed/cancelled sales
    past the 90-day retention period.

    Should be scheduled via django_celery_beat (e.g. weekly on Sunday).
    """
    from .gdpr import cleanup_expired_sales

    cleanup_expired_sales()
    logger.info("Expired sale document cleanup complete.")
