"""Celery tasks for asynchronous processing."""
import logging
from datetime import timedelta
from celery import shared_task
from django.conf import settings
from django.core.mail import send_mail
from django.db.models import Q, Count
from django.utils import timezone

logger = logging.getLogger(__name__)


# ── Email Notification Tasks ────────────────────────────────────

@shared_task(bind=True, max_retries=3)
def send_email_task(self, subject, message, from_email, recipient_list):
    """Generic async email sending with retry."""
    try:
        send_mail(subject, message, from_email, recipient_list)
    except Exception as exc:
        logger.error('Email send failed: %s', exc)
        self.retry(exc=exc, countdown=60 * (self.request.retries + 1))


@shared_task
def send_message_notification(message_id):
    """Send email notification for a new chat message."""
    from .models import ChatMessage
    try:
        msg = ChatMessage.objects.select_related(
            'room__property__owner', 'room__buyer', 'sender'
        ).get(pk=message_id)
    except ChatMessage.DoesNotExist:
        return

    room = msg.room
    # Notify the other party (not the sender)
    if msg.sender == room.seller:
        recipient = room.buyer
    else:
        recipient = room.seller

    sender_name = msg.sender.get_full_name() or msg.sender.email
    subject = f'New message about {room.property.title}'
    message = (
        f'Hi {recipient.first_name or recipient.email},\n\n'
        f'You have received a new message about "{room.property.title}".\n\n'
        f'From: {sender_name}\n\n'
        f'Message:\n{msg.message}\n\n'
        f'Reply on your dashboard:\n'
        f'{settings.SITE_URL}/messages/{room.id}/\n\n'
        f'— For Sale By Owner'
    )
    send_mail(subject, message, settings.DEFAULT_FROM_EMAIL, [recipient.email])

    send_push_notification.delay(
        recipient.id,
        'New Message',
        f'{sender_name} messaged about {room.property.title}',
    )


@shared_task
def send_viewing_notification(viewing_id):
    """Send email notification for a new viewing request."""
    from .models import ViewingRequest
    try:
        viewing = ViewingRequest.objects.select_related('property__owner').get(pk=viewing_id)
    except ViewingRequest.DoesNotExist:
        return

    owner = viewing.property.owner
    subject = f'New viewing request for {viewing.property.title}'
    message = (
        f'Hi {owner.first_name or owner.email},\n\n'
        f'You have received a new viewing request for your property "{viewing.property.title}".\n\n'
        f'From: {viewing.name}\n'
        f'Preferred date: {viewing.preferred_date.strftime("%A %d %B %Y")} at {viewing.preferred_time.strftime("%H:%M")}\n'
    )
    if viewing.alternative_date:
        alt_time = viewing.alternative_time.strftime("%H:%M") if viewing.alternative_time else 'TBC'
        message += f'Alternative date: {viewing.alternative_date.strftime("%A %d %B %Y")} at {alt_time}\n'
    if viewing.message:
        message += f'\nMessage:\n{viewing.message}\n'
    message += (
        f'\nManage viewing requests on your dashboard:\n'
        f'{settings.SITE_URL}/dashboard/\n\n'
        f'— For Sale By Owner'
    )
    send_mail(subject, message, settings.DEFAULT_FROM_EMAIL, [owner.email])

    send_push_notification.delay(
        owner.id,
        'New Viewing Request',
        f'{viewing.name} requested a viewing of {viewing.property.title}',
    )


@shared_task
def send_reply_notification(reply_id):
    """Send email notification for a viewing reply."""
    from .models import Reply
    try:
        reply = Reply.objects.select_related(
            'viewing_request__property__owner', 'author'
        ).get(pk=reply_id)
    except Reply.DoesNotExist:
        return

    if reply.viewing_request:
        parent = reply.viewing_request
        property_obj = parent.property
        if reply.author == property_obj.owner:
            recipient_email = parent.email
            recipient_name = parent.name
        else:
            recipient_email = property_obj.owner.email
            recipient_name = property_obj.owner.first_name or property_obj.owner.email
        subject = f'New reply about viewing for {property_obj.title}'
    else:
        return

    message = (
        f'Hi {recipient_name},\n\n'
        f'You have received a new reply regarding "{property_obj.title}".\n\n'
        f'View and reply on the site:\n'
        f'{settings.SITE_URL}/dashboard/\n\n'
        f'— For Sale By Owner'
    )
    send_mail(subject, message, settings.DEFAULT_FROM_EMAIL, [recipient_email])


@shared_task
def send_offer_notification(offer_id, notification_type='new'):
    """Send email notification for offers."""
    from .models import Offer
    try:
        offer = Offer.objects.select_related('property__owner', 'buyer').get(pk=offer_id)
    except Offer.DoesNotExist:
        return

    if notification_type == 'new':
        owner = offer.property.owner
        subject = f'New offer on {offer.property.title}'
        message = (
            f'Hi {owner.first_name or owner.email},\n\n'
            f'You have received a new offer of £{offer.amount:,.0f} on '
            f'your property "{offer.property.title}".\n\n'
            f'From: {offer.buyer.get_full_name() or offer.buyer.email}\n'
        )
        if offer.is_cash_buyer:
            message += 'Buyer type: Cash buyer\n'
        if offer.is_chain_free:
            message += 'Chain status: Chain free\n'
        message += (
            f'\nReview this offer on your dashboard:\n'
            f'{settings.SITE_URL}/dashboard/\n\n'
            f'— For Sale By Owner'
        )
        send_mail(subject, message, settings.DEFAULT_FROM_EMAIL, [owner.email])
        send_push_notification.delay(
            owner.id,
            'New Offer Received',
            f'£{offer.amount:,.0f} offer on {offer.property.title}',
        )
    elif notification_type == 'status_update':
        subject = f'Offer update on {offer.property.title}'
        message = (
            f'Hi {offer.buyer.first_name or offer.buyer.email},\n\n'
            f'Your offer of £{offer.amount:,.0f} on "{offer.property.title}" '
            f'has been {offer.get_status_display().lower()}.\n\n'
        )
        if offer.counter_amount:
            message += f'Counter offer: £{offer.counter_amount:,.0f}\n'
        if offer.seller_notes:
            message += f'\nNote from seller:\n{offer.seller_notes}\n'
        message += (
            f'\nView details on your dashboard:\n'
            f'{settings.SITE_URL}/dashboard/\n\n'
            f'— For Sale By Owner'
        )
        send_mail(subject, message, settings.DEFAULT_FROM_EMAIL, [offer.buyer.email])


@shared_task
def send_viewing_status_notification(viewing_id):
    """Send email when viewing status changes."""
    from .models import ViewingRequest
    try:
        viewing = ViewingRequest.objects.select_related('property').get(pk=viewing_id)
    except ViewingRequest.DoesNotExist:
        return

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
    send_mail(subject, message, settings.DEFAULT_FROM_EMAIL, [viewing.email])


# ── Push Notification Tasks ─────────────────────────────────────

@shared_task
def send_push_notification(user_id, title, body, data=None):
    """Send push notification to all of a user's registered devices."""
    from .models import PushNotificationDevice

    devices = PushNotificationDevice.objects.filter(user_id=user_id, is_active=True)
    if not devices.exists():
        return

    if not settings.FCM_CREDENTIALS_FILE:
        logger.debug('FCM not configured, skipping push notification')
        return

    try:
        import firebase_admin
        from firebase_admin import messaging

        if not firebase_admin._apps:
            cred = firebase_admin.credentials.Certificate(settings.FCM_CREDENTIALS_FILE)
            firebase_admin.initialize_app(cred)

        for device in devices:
            try:
                message = messaging.Message(
                    notification=messaging.Notification(title=title, body=body),
                    data=data or {},
                    token=device.token,
                )
                messaging.send(message)
            except Exception as e:
                logger.warning('Push notification failed for device %s: %s', device.id, e)
                if 'Requested entity was not found' in str(e) or 'registration-token-not-registered' in str(e):
                    device.is_active = False
                    device.save(update_fields=['is_active'])
    except ImportError:
        logger.warning('firebase-admin not installed, skipping push notifications')
    except Exception as e:
        logger.error('Push notification error: %s', e)


# ── Saved Search Alerts ─────────────────────────────────────────

@shared_task
def process_saved_search_alerts():
    """Match new properties against saved searches and send alerts."""
    from .models import SavedSearch, Property

    now = timezone.now()
    searches = SavedSearch.objects.filter(email_alerts=True).select_related('user')

    for search in searches:
        # Determine time window based on frequency
        if search.alert_frequency == 'instant':
            since = search.last_notified or (now - timezone.timedelta(hours=1))
        elif search.alert_frequency == 'daily':
            since = search.last_notified or (now - timezone.timedelta(days=1))
            if search.last_notified and (now - search.last_notified).total_seconds() < 86400:
                continue
        elif search.alert_frequency == 'weekly':
            since = search.last_notified or (now - timezone.timedelta(weeks=1))
            if search.last_notified and (now - search.last_notified).total_seconds() < 604800:
                continue
        else:
            continue

        # Build matching query
        queryset = Property.objects.filter(status='active', created_at__gte=since)

        if search.location:
            queryset = queryset.filter(
                Q(city__icontains=search.location) |
                Q(county__icontains=search.location) |
                Q(postcode__icontains=search.location)
            )
        if search.property_type:
            queryset = queryset.filter(property_type=search.property_type)
        if search.min_price:
            queryset = queryset.filter(price__gte=search.min_price)
        if search.max_price:
            queryset = queryset.filter(price__lte=search.max_price)
        if search.min_bedrooms:
            queryset = queryset.filter(bedrooms__gte=search.min_bedrooms)
        if search.min_bathrooms:
            queryset = queryset.filter(bathrooms__gte=search.min_bathrooms)
        if search.epc_rating:
            queryset = queryset.filter(epc_rating=search.epc_rating)

        matches = queryset[:10]
        if not matches:
            continue

        # Send alert email
        subject = f'New properties matching "{search}"'
        lines = [
            f'Hi {search.user.first_name or search.user.email},\n',
            f'We found {len(matches)} new propert{"y" if len(matches) == 1 else "ies"} '
            f'matching your saved search "{search}":\n',
        ]
        for prop in matches:
            lines.append(
                f'  - {prop.title} — £{prop.price:,.0f} — {prop.city}\n'
                f'    {settings.SITE_URL}/properties/{prop.slug or prop.id}/\n'
            )
        lines.append(f'\nView all results: {settings.SITE_URL}/search/\n')
        lines.append('— For Sale By Owner')

        send_mail(
            subject, '\n'.join(lines),
            settings.DEFAULT_FROM_EMAIL, [search.user.email],
        )

        search.last_notified = now
        search.save(update_fields=['last_notified'])

        # Push notification
        send_push_notification.delay(
            search.user.id,
            'New Property Matches',
            f'{len(matches)} new propert{"y" if len(matches) == 1 else "ies"} matching "{search}"',
        )


@shared_task
def send_price_drop_alerts():
    """Notify users when properties they've saved drop in price."""
    from .models import SavedProperty, PriceHistory

    recent_changes = PriceHistory.objects.filter(
        changed_at__gte=timezone.now() - timezone.timedelta(hours=24),
    ).select_related('property').order_by('property', '-changed_at')

    notified = set()
    for change in recent_changes:
        prop = change.property
        if prop.pk in notified:
            continue

        # Check if price actually dropped
        previous = PriceHistory.objects.filter(
            property=prop, changed_at__lt=change.changed_at
        ).order_by('-changed_at').first()
        if not previous or change.price >= previous.price:
            continue

        notified.add(prop.pk)
        drop_amount = previous.price - change.price

        # Notify all users who saved this property
        saved_users = SavedProperty.objects.filter(
            property=prop
        ).select_related('user')

        for saved in saved_users:
            if not saved.user.notification_price_drops:
                continue
            subject = f'Price drop on {prop.title}'
            message = (
                f'Hi {saved.user.first_name or saved.user.email},\n\n'
                f'A property you saved has dropped in price!\n\n'
                f'{prop.title}\n'
                f'Was: £{previous.price:,.0f}\n'
                f'Now: £{change.price:,.0f}\n'
                f'Saving: £{drop_amount:,.0f}\n\n'
                f'View property: {settings.SITE_URL}/properties/{prop.slug or prop.id}/\n\n'
                f'— For Sale By Owner'
            )
            send_mail(subject, message, settings.DEFAULT_FROM_EMAIL, [saved.user.email])
            send_push_notification.delay(
                saved.user.id,
                'Price Drop',
                f'{prop.title} dropped £{drop_amount:,.0f}',
            )


# ── Image Processing Tasks ──────────────────────────────────────

@shared_task
def process_property_image(image_id):
    """Resize and optimise a property image, generate thumbnail."""
    from .models import PropertyImage
    from PIL import Image as PILImage
    from io import BytesIO
    from django.core.files.base import ContentFile
    import os

    try:
        img_obj = PropertyImage.objects.get(pk=image_id)
    except PropertyImage.DoesNotExist:
        return

    try:
        with PILImage.open(img_obj.image) as img:
            # Convert to RGB if necessary
            if img.mode in ('RGBA', 'P'):
                img = img.convert('RGB')

            # Resize main image if too large
            max_w = settings.PROPERTY_IMAGE_MAX_WIDTH
            max_h = settings.PROPERTY_IMAGE_MAX_HEIGHT
            if img.width > max_w or img.height > max_h:
                img.thumbnail((max_w, max_h), PILImage.LANCZOS)

            # Save optimised main image
            buffer = BytesIO()
            img.save(buffer, format='JPEG', quality=settings.PROPERTY_IMAGE_QUALITY, optimize=True)
            buffer.seek(0)

            filename = os.path.splitext(os.path.basename(img_obj.image.name))[0]
            img_obj.image.save(f'{filename}.jpg', ContentFile(buffer.read()), save=False)

            # Generate thumbnail
            thumb_size = settings.PROPERTY_IMAGE_THUMBNAIL_SIZE
            img.thumbnail(thumb_size, PILImage.LANCZOS)
            thumb_buffer = BytesIO()
            img.save(thumb_buffer, format='JPEG', quality=80, optimize=True)
            thumb_buffer.seek(0)

            img_obj.thumbnail.save(
                f'{filename}_thumb.jpg',
                ContentFile(thumb_buffer.read()),
                save=False,
            )

            img_obj.save(update_fields=['image', 'thumbnail'])
            logger.info('Processed image %s', image_id)
    except Exception as e:
        logger.error('Image processing failed for %s: %s', image_id, e)


# ── #34 Seller Activity Reminder Tasks ─────────────────────────

@shared_task
def send_seller_activity_reminders():
    """Nudge sellers who haven't logged in recently or have stale listings."""
    from .models import Property, ChatMessage
    from django.contrib.auth import get_user_model
    User = get_user_model()

    now = timezone.now()

    # 1. Sellers with unread messages who haven't logged in for 7+ days
    inactive_sellers = User.objects.filter(
        last_login__lt=now - timedelta(days=7),
        properties__status='active',
    ).distinct()

    for seller in inactive_sellers:
        unread_count = ChatMessage.objects.filter(
            room__seller=seller,
            is_read=False,
        ).exclude(sender=seller).count()

        if unread_count > 0:
            subject = f'You have {unread_count} unread message{"s" if unread_count > 1 else ""}'
            message = (
                f'Hi {seller.first_name or seller.email},\n\n'
                f'You have {unread_count} unread message{"s" if unread_count > 1 else ""} '
                f'from interested buyers on For Sale By Owner.\n\n'
                f'Log in to respond:\n'
                f'{settings.SITE_URL}/messages/\n\n'
                f'— For Sale By Owner'
            )
            send_mail(subject, message, settings.DEFAULT_FROM_EMAIL, [seller.email])

    # 2. Stale listings (60+ days without update)
    stale_listings = Property.objects.filter(
        status='active',
        updated_at__lt=now - timedelta(days=60),
    ).select_related('owner')

    for prop in stale_listings:
        days = (now - prop.updated_at).days
        subject = f'Your listing "{prop.title}" has been active for {days} days'
        message = (
            f'Hi {prop.owner.first_name or prop.owner.email},\n\n'
            f'Your property "{prop.title}" has been listed for {days} days.\n\n'
            f'Consider:\n'
            f'- Updating your photos\n'
            f'- Adjusting your asking price\n'
            f'- Refreshing the description\n\n'
            f'Properties that are regularly updated receive more interest.\n\n'
            f'Update your listing: {settings.SITE_URL}/properties/{prop.id}/edit/\n\n'
            f'— For Sale By Owner'
        )
        send_mail(subject, message, settings.DEFAULT_FROM_EMAIL, [prop.owner.email])


@shared_task
def send_weekly_seller_digest():
    """Send weekly summary to sellers with active listings."""
    from .models import Property, PropertyView, ChatMessage, Offer, SavedProperty
    from django.contrib.auth import get_user_model
    User = get_user_model()

    now = timezone.now()
    week_ago = now - timedelta(days=7)

    sellers_with_listings = User.objects.filter(
        properties__status='active'
    ).distinct()

    for seller in sellers_with_listings:
        active_props = Property.objects.filter(owner=seller, status='active')
        if not active_props.exists():
            continue

        total_views = PropertyView.objects.filter(
            property__in=active_props,
            viewed_at__gte=week_ago,
        ).count()

        new_messages = ChatMessage.objects.filter(
            room__seller=seller,
            created_at__gte=week_ago,
        ).exclude(sender=seller).count()

        new_offers = Offer.objects.filter(
            property__in=active_props,
            created_at__gte=week_ago,
        ).count()

        new_saves = SavedProperty.objects.filter(
            property__in=active_props,
            created_at__gte=week_ago,
        ).count()

        subject = 'Your weekly listing summary'
        message = (
            f'Hi {seller.first_name or seller.email},\n\n'
            f'Here\'s your weekly summary for your {active_props.count()} active listing{"s" if active_props.count() > 1 else ""}:\n\n'
            f'  Views this week: {total_views}\n'
            f'  New messages: {new_messages}\n'
            f'  New offers: {new_offers}\n'
            f'  New saves: {new_saves}\n\n'
        )
        for prop in active_props:
            prop_views = PropertyView.objects.filter(
                property=prop, viewed_at__gte=week_ago
            ).count()
            message += f'  - {prop.title}: {prop_views} views\n'

        message += (
            f'\nView your dashboard: {settings.SITE_URL}/dashboard/\n\n'
            f'— For Sale By Owner'
        )
        send_mail(subject, message, settings.DEFAULT_FROM_EMAIL, [seller.email])


# ── #31 Conveyancing Stale Step Nudges ───────────────────────────

@shared_task
def check_conveyancing_stale_steps(case_id=None):
    """Check for stale conveyancing steps and send nudge emails."""
    from .models import ConveyancingCase, ConveyancingStep

    now = timezone.now()
    stale_threshold = now - timedelta(weeks=2)

    if case_id:
        cases = ConveyancingCase.objects.filter(pk=case_id, status='active')
    else:
        cases = ConveyancingCase.objects.filter(status='active')

    for case in cases.select_related('buyer', 'seller', 'property'):
        stale_steps = case.steps.filter(
            status='in_progress',
            updated_at__lt=stale_threshold,
        )

        for step in stale_steps:
            days_stuck = (now - step.updated_at).days
            step_name = step.get_step_type_display()

            for user in [case.buyer, case.seller]:
                subject = f'Conveyancing update: {step_name} has been pending for {days_stuck} days'
                message = (
                    f'Hi {user.first_name or user.email},\n\n'
                    f'The "{step_name}" step in the conveyancing process for '
                    f'"{case.property.title}" has been in progress for {days_stuck} days.\n\n'
                    f'Consider chasing your solicitor or checking if any action is needed from you.\n\n'
                    f'View progress: {settings.SITE_URL}/dashboard/\n\n'
                    f'— For Sale By Owner'
                )
                send_mail(subject, message, settings.DEFAULT_FROM_EMAIL, [user.email])


@shared_task
def check_all_conveyancing_cases():
    """Periodic task to check all active conveyancing cases for stale steps."""
    check_conveyancing_stale_steps(case_id=None)
