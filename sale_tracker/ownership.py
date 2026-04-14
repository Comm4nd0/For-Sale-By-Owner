"""
Ownership engine for the Sale Tracker.

Handles task ownership transfers and dashboard grouping.
"""

from collections import defaultdict
from django.utils import timezone
from .models import Task, TaskOwnershipHistory


def transfer_ownership(task, new_owner, reason=''):
    """
    Transfer a task to a new owner. Creates an audit log entry
    and resets the awaiting_since timer.
    """
    old_owner = task.current_owner

    if old_owner == new_owner:
        return task

    TaskOwnershipHistory.objects.create(
        task=task,
        from_owner=old_owner,
        to_owner=new_owner,
        reason=reason,
    )

    task.current_owner = new_owner
    task.awaiting_since = timezone.now().date()
    task.save(update_fields=['current_owner', 'awaiting_since'])

    return task


def get_dashboard_groups(sale):
    """
    Group all open tasks and enquiries by current_owner for the
    dashboard's "Who owes what right now" view.

    Returns:
        {
            'your_turn': [task_dicts],
            'awaiting_others': {owner_type: [task_dicts]},
            'headline_numbers': {...},
        }
    """
    from .models import Enquiry

    tasks = Task.objects.filter(
        stage__sale=sale,
    ).exclude(
        status__in=('done', 'n_a'),
    ).select_related('stage')

    enquiries = Enquiry.objects.filter(
        sale=sale,
    ).exclude(
        status__in=('answered', 'closed'),
    )

    # Group tasks by owner
    your_turn = []
    awaiting_others = defaultdict(list)

    for task in tasks:
        item = {
            'id': task.id,
            'title': task.title,
            'stage_name': task.stage.name,
            'stage_number': task.stage.stage_number,
            'current_owner': task.current_owner,
            'current_owner_display': task.get_current_owner_display(),
            'status': task.status,
            'days_awaiting': task.days_awaiting,
            'awaiting_since': task.awaiting_since,
            'type': 'task',
        }

        if task.current_owner == 'seller':
            your_turn.append(item)
        else:
            awaiting_others[task.current_owner].append(item)

    # Group enquiries by owner
    for enquiry in enquiries:
        item = {
            'id': enquiry.id,
            'title': f"Enquiry: {enquiry.question[:80]}",
            'current_owner': enquiry.current_owner,
            'current_owner_display': enquiry.get_current_owner_display(),
            'status': enquiry.status,
            'raised_date': enquiry.raised_date,
            'type': 'enquiry',
        }

        if enquiry.current_owner == 'seller':
            your_turn.append(item)
        else:
            awaiting_others[enquiry.current_owner].append(item)

    # Sort: oldest first
    your_turn.sort(key=lambda x: x.get('awaiting_since') or x.get('raised_date') or timezone.now().date())

    # Sort each group by oldest awaiting_since
    for owner in awaiting_others:
        awaiting_others[owner].sort(
            key=lambda x: x.get('awaiting_since') or x.get('raised_date') or timezone.now().date()
        )

    # Headline numbers
    all_tasks = Task.objects.filter(stage__sale=sale)
    total = all_tasks.count()
    completed = all_tasks.filter(status='done').count()

    current_stage = sale.current_stage

    headline_numbers = {
        'total_tasks': total,
        'completed_tasks': completed,
        'current_stage_number': current_stage.stage_number if current_stage else None,
        'current_stage_name': current_stage.name if current_stage else None,
        'days_since_instruction': sale.days_since_instruction,
        'days_to_target_exchange': sale.days_to_target_exchange,
        'days_to_target_completion': sale.days_to_target_completion,
    }

    return {
        'your_turn': your_turn,
        'awaiting_others': dict(awaiting_others),
        'headline_numbers': headline_numbers,
    }
