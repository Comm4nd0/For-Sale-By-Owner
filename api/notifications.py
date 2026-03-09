from django.conf import settings
from django.core.mail import send_mail
from django.template.loader import render_to_string
import logging

logger = logging.getLogger(__name__)


def notify_new_enquiry(enquiry):
    """Email the property owner when a new enquiry is received."""
    owner = enquiry.property.owner
    subject = f'New enquiry about {enquiry.property.title}'
    prop_url = f'{settings.SITE_URL}/properties/{enquiry.property.slug or enquiry.property.id}/'
    message = (
        f'Hi {owner.first_name or owner.email},\n\n'
        f'You have received a new enquiry about your property "{enquiry.property.title}".\n\n'
        f'From: {enquiry.name} ({enquiry.email})\n'
        f'{f"Phone: {enquiry.phone}" if enquiry.phone else ""}\n\n'
        f'Message:\n{enquiry.message}\n\n'
        f'View your property: {prop_url}\n'
        f'Manage enquiries: {settings.SITE_URL}/dashboard/\n\n'
        f'Reply directly to the buyer at: {enquiry.email}\n\n'
        f'— For Sale By Owner'
    )
    try:
        send_mail(subject, message, settings.DEFAULT_FROM_EMAIL, [owner.email])
    except Exception as e:
        logger.error(f'Failed to send enquiry notification: {e}')


def notify_listing_approved(property_obj):
    """Email the owner when their listing is approved."""
    owner = property_obj.owner
    subject = f'Your listing "{property_obj.title}" is now live!'
    prop_url = f'{settings.SITE_URL}/properties/{property_obj.slug or property_obj.id}/'
    message = (
        f'Hi {owner.first_name or owner.email},\n\n'
        f'Great news! Your property listing "{property_obj.title}" has been '
        f'approved and is now live on For Sale By Owner.\n\n'
        f'View your listing: {prop_url}\n\n'
        f'— For Sale By Owner'
    )
    try:
        send_mail(subject, message, settings.DEFAULT_FROM_EMAIL, [owner.email])
    except Exception as e:
        logger.error(f'Failed to send approval notification: {e}')


def notify_listing_rejected(property_obj):
    """Email the owner when their listing is rejected."""
    owner = property_obj.owner
    subject = f'Update about your listing "{property_obj.title}"'
    message = (
        f'Hi {owner.first_name or owner.email},\n\n'
        f'Your property listing "{property_obj.title}" was not approved. '
        f'This may be because it does not meet our listing guidelines.\n\n'
        f'Please review your listing and resubmit, or contact us if you '
        f'believe this was in error.\n\n'
        f'Edit your listing: {settings.SITE_URL}/properties/{property_obj.id}/edit/\n\n'
        f'— For Sale By Owner'
    )
    try:
        send_mail(subject, message, settings.DEFAULT_FROM_EMAIL, [owner.email])
    except Exception as e:
        logger.error(f'Failed to send rejection notification: {e}')


def notify_viewing_request(viewing):
    """Email the property owner when a new viewing request is received."""
    owner = viewing.property.owner
    subject = f'New viewing request for {viewing.property.title}'
    message = (
        f'Hi {owner.first_name or owner.email},\n\n'
        f'You have received a new viewing request for your property "{viewing.property.title}".\n\n'
        f'From: {viewing.name} ({viewing.email})\n'
        f'{f"Phone: {viewing.phone}" if viewing.phone else ""}\n'
        f'Preferred date: {viewing.preferred_date.strftime("%A %d %B %Y")} at {viewing.preferred_time.strftime("%H:%M")}\n'
    )
    if viewing.alternative_date:
        message += f'Alternative date: {viewing.alternative_date.strftime("%A %d %B %Y")} at {viewing.alternative_time.strftime("%H:%M")}\n'
    if viewing.message:
        message += f'\nMessage:\n{viewing.message}\n'
    message += (
        f'\nManage viewing requests: {settings.SITE_URL}/dashboard/\n\n'
        f'— For Sale By Owner'
    )
    try:
        send_mail(subject, message, settings.DEFAULT_FROM_EMAIL, [owner.email])
    except Exception as e:
        logger.error(f'Failed to send viewing request notification: {e}')


def notify_viewing_status_update(viewing):
    """Email the requester when their viewing request status changes."""
    subject = f'Viewing update for {viewing.property.title}'
    status_text = viewing.get_status_display()
    message = (
        f'Hi {viewing.name},\n\n'
        f'Your viewing request for "{viewing.property.title}" has been {status_text.lower()}.\n\n'
        f'Date: {viewing.preferred_date.strftime("%A %d %B %Y")} at {viewing.preferred_time.strftime("%H:%M")}\n'
    )
    if viewing.seller_notes:
        message += f'\nNote from seller:\n{viewing.seller_notes}\n'
    message += (
        f'\nView property: {settings.SITE_URL}/properties/{viewing.property.slug or viewing.property.id}/\n\n'
        f'— For Sale By Owner'
    )
    try:
        send_mail(subject, message, settings.DEFAULT_FROM_EMAIL, [viewing.email])
    except Exception as e:
        logger.error(f'Failed to send viewing status notification: {e}')
