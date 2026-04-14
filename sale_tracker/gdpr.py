"""
GDPR compliance utilities for the Sale Tracker.

Data export, anonymisation, and document cleanup.
"""

import os
from datetime import timedelta
from django.utils import timezone
from .models import (
    Sale, Stage, Task, TaskOwnershipHistory, Document,
    DocumentAccessLog, ContactLog, Enquiry, PromptDraft,
)


def export_sale_data(user):
    """
    Export all sale tracker data for a user as a JSON-serialisable dict.
    Returns metadata only — does not include file contents.
    """
    sales = Sale.objects.filter(seller=user)
    data = {'sales': []}

    for sale in sales:
        sale_data = {
            'id': sale.id,
            'property_address': sale.property_address,
            'asking_price': str(sale.asking_price) if sale.asking_price else None,
            'agreed_price': str(sale.agreed_price) if sale.agreed_price else None,
            'tenure': sale.tenure,
            'status': sale.status,
            'buyer_name': sale.buyer_name,
            'agent_name': sale.agent_name,
            'seller_conveyancer_name': sale.seller_conveyancer_name,
            'buyer_conveyancer_name': sale.buyer_conveyancer_name,
            'created_at': sale.created_at.isoformat(),
            'stages': [],
            'documents': [],
            'contact_logs': [],
            'enquiries': [],
            'prompt_drafts': [],
        }

        # Stages and tasks
        for stage in sale.stages.all():
            stage_data = {
                'stage_number': stage.stage_number,
                'name': stage.name,
                'status': stage.status,
                'tasks': [],
            }
            for task in stage.tasks.all():
                task_data = {
                    'title': task.title,
                    'current_owner': task.current_owner,
                    'status': task.status,
                    'awaiting_since': task.awaiting_since.isoformat() if task.awaiting_since else None,
                    'notes': task.notes,
                    'ownership_history': [
                        {
                            'from': h.from_owner,
                            'to': h.to_owner,
                            'at': h.transferred_at.isoformat(),
                            'reason': h.reason,
                        }
                        for h in task.ownership_history.all()
                    ],
                }
                stage_data['tasks'].append(task_data)
            sale_data['stages'].append(stage_data)

        # Documents (metadata only)
        for doc in sale.documents.all():
            sale_data['documents'].append({
                'title': doc.title,
                'category': doc.category,
                'status': doc.status,
                'uploaded_at': doc.uploaded_at.isoformat() if doc.uploaded_at else None,
                'access_logs': [
                    {
                        'action': log.action,
                        'at': log.accessed_at.isoformat(),
                    }
                    for log in doc.access_logs.all()
                ],
            })

        # Contact logs
        for log in sale.contact_logs.all():
            sale_data['contact_logs'].append({
                'date': log.date.isoformat(),
                'channel': log.channel,
                'counterparty': log.counterparty,
                'summary': log.summary,
            })

        # Enquiries
        for eq in sale.enquiries.all():
            sale_data['enquiries'].append({
                'question': eq.question,
                'current_owner': eq.current_owner,
                'status': eq.status,
                'response': eq.response,
                'raised_date': eq.raised_date.isoformat(),
            })

        # Prompt drafts
        for draft in sale.prompt_drafts.all():
            sale_data['prompt_drafts'].append({
                'subject': draft.subject,
                'level': draft.level,
                'recipient_owner': draft.recipient_owner,
                'sent': draft.sent_marker,
                'generated_at': draft.generated_at.isoformat(),
            })

        data['sales'].append(sale_data)

    return data


def delete_sale_data(user):
    """
    Anonymise and delete sale tracker data for a user.
    Removes files, anonymises personal details.
    """
    sales = Sale.objects.filter(seller=user)

    for sale in sales:
        # Delete document files
        for doc in sale.documents.all():
            if doc.file:
                try:
                    if os.path.isfile(doc.file.path):
                        os.remove(doc.file.path)
                except Exception:
                    pass
                doc.file = ''
                doc.save(update_fields=['file'])

        # Delete prompt drafts
        sale.prompt_drafts.all().delete()

        # Delete contact logs
        sale.contact_logs.all().delete()

        # Anonymise sale
        sale.buyer_name = 'Deleted'
        sale.buyer_contact = ''
        sale.agent_name = 'Deleted'
        sale.agent_contact = ''
        sale.seller_conveyancer_name = 'Deleted'
        sale.seller_conveyancer_contact = ''
        sale.buyer_conveyancer_name = 'Deleted'
        sale.buyer_conveyancer_contact = ''
        sale.status = 'cancelled'
        sale.save()


def cleanup_expired_sales():
    """
    Purge document files 90 days after a sale is completed or cancelled.
    Called by a periodic Celery task.
    """
    cutoff = timezone.now() - timedelta(days=90)

    expired_sales = Sale.objects.filter(
        status__in=('completed', 'cancelled'),
        updated_at__lt=cutoff,
    )

    for sale in expired_sales:
        for doc in sale.documents.filter(file__gt=''):
            try:
                if os.path.isfile(doc.file.path):
                    os.remove(doc.file.path)
            except Exception:
                pass
            doc.file = ''
            doc.save(update_fields=['file'])
