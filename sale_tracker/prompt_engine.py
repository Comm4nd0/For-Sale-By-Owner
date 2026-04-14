"""
Prompt engine for drafting messages to counterparties.

Generates factual, clear messages using templates with variable
substitution. Never auto-sends — the seller copies and sends manually.
"""

from django.utils import timezone
from .models import Task, PromptDraft
from .seed import PROMPT_TEMPLATES


def _get_counterparty_name(sale, counterparty_type):
    """Look up the counterparty name from the sale's contact fields."""
    mapping = {
        'seller_conveyancer': sale.seller_conveyancer_name,
        'buyer_conveyancer': sale.buyer_conveyancer_name,
        'estate_agent': sale.agent_name,
        'buyer': sale.buyer_name,
        'lender': '',
        'freeholder_or_managing_agent': '',
        'surveyor': '',
        'local_authority_or_search_provider': '',
    }
    return mapping.get(counterparty_type, '') or counterparty_type.replace('_', ' ').title()


def _format_items_list(tasks):
    """Format a list of tasks as a bulleted list for the message body."""
    if not tasks:
        return '(No specific items listed)'

    lines = []
    for task in tasks:
        days = task.days_awaiting
        line = f"\u2022 {task.title}"
        if days:
            line += f" ({days} days)"
        lines.append(line)
    return '\n'.join(lines)


def _get_oldest_days(tasks):
    """Return the number of days since the oldest awaiting_since."""
    dates = [t.awaiting_since for t in tasks if t.awaiting_since]
    if not dates:
        return 0
    oldest = min(dates)
    return (timezone.now().date() - oldest).days


def generate_prompt(sale, counterparty_type, level, tasks=None):
    """
    Generate a prompt draft for a specific counterparty and level.

    Args:
        sale: The Sale instance
        counterparty_type: One of OWNER_CHOICES values
        level: '1', '2', or 'escalation'
        tasks: Optional queryset/list of tasks to include. If None,
               finds all open tasks owned by counterparty_type.

    Returns:
        A saved PromptDraft instance.
    """
    template_key = (counterparty_type, level)
    template = PROMPT_TEMPLATES.get(template_key)

    if not template:
        # Fallback: generic template
        template = {
            'subject': f'Update request \u2014 {sale.property_address}',
            'body': (
                '{counterparty_name},\n\n'
                'Could you provide an update on the following items:\n\n'
                '{items_list}\n\n'
                'Target completion is {target_completion}.\n\n'
                '{seller_name}'
            ),
        }

    # Get tasks for this counterparty if not provided
    if tasks is None:
        tasks = Task.objects.filter(
            stage__sale=sale,
            current_owner=counterparty_type,
        ).exclude(status__in=('done', 'n_a'))

    if hasattr(tasks, '__iter__') and not hasattr(tasks, 'count'):
        tasks = list(tasks)

    # Build template variables
    seller_name = sale.seller.get_full_name() or sale.seller.email
    variables = {
        'property_address': sale.property_address,
        'target_completion': (
            sale.target_completion_date.strftime('%d %B %Y')
            if sale.target_completion_date else 'not yet agreed'
        ),
        'counterparty_name': _get_counterparty_name(sale, counterparty_type),
        'seller_name': seller_name,
        'items_list': _format_items_list(tasks),
        'oldest_days': str(_get_oldest_days(tasks)),
    }

    subject = template['subject'].format(**variables)
    body = template['body'].format(**variables)

    draft = PromptDraft.objects.create(
        sale=sale,
        recipient_owner=counterparty_type,
        level=level,
        template_key=f"{counterparty_type}_{level}",
        subject=subject,
        body_text=body,
    )

    return draft
