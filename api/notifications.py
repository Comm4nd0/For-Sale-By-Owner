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
