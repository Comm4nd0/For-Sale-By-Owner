"""Viewing requests, viewing slots, open-house events and related replies/RSVPs."""
from django.conf import settings
from django.db.models import Q
from django.shortcuts import get_object_or_404
from django.utils import timezone

from rest_framework import viewsets, permissions, status
from rest_framework.decorators import api_view, permission_classes, action
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.response import Response

from ..models import (
    Property,
    Reply,
    ViewingRequest,
    ViewingSlot,
    ViewingSlotBooking,
    OpenHouseEvent,
    OpenHouseRSVP,
)
from ..serializers import (
    ReplySerializer,
    ViewingRequestSerializer,
    ViewingSlotSerializer,
    OpenHouseEventSerializer,
    OpenHouseRSVPSerializer,
)


class ViewingRequestViewSet(viewsets.ModelViewSet):
    serializer_class = ViewingRequestSerializer
    permission_classes = [permissions.IsAuthenticated]
    http_method_names = ['get', 'post', 'patch']

    def get_queryset(self):
        user = self.request.user
        return ViewingRequest.objects.filter(
            Q(requester=user) | Q(property__owner=user)
        ).select_related('property', 'requester').prefetch_related('replies__author')

    def perform_create(self, serializer):
        prop = serializer.validated_data['property']
        if prop.owner == self.request.user:
            raise ValidationError("You cannot request a viewing for your own property.")
        user = self.request.user
        name = serializer.validated_data.get('name') or user.get_full_name()
        email = serializer.validated_data.get('email') or user.email
        viewing = serializer.save(requester=user, name=name, email=email)
        try:
            from ..tasks import send_viewing_notification
            send_viewing_notification.delay(viewing.id)
        except Exception:
            from ..notifications import notify_viewing_request
            notify_viewing_request(viewing)

    def perform_update(self, serializer):
        instance = serializer.instance
        if instance.property.owner != self.request.user:
            raise PermissionDenied("Only the property owner can update viewing requests.")
        serializer.save()

    @action(detail=False, methods=['get'])
    def received(self, request):
        """Get viewing requests received for the user's properties."""
        qs = ViewingRequest.objects.filter(
            property__owner=request.user
        ).select_related('property', 'requester').prefetch_related('replies__author').order_by('-created_at')
        page = self.paginate_queryset(qs)
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)
        serializer = self.get_serializer(qs, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['get'])
    def sent(self, request):
        """Get viewing requests sent by the current user (buyer view)."""
        qs = ViewingRequest.objects.filter(
            requester=request.user
        ).select_related('property', 'requester').prefetch_related('replies__author').order_by('-created_at')
        page = self.paginate_queryset(qs)
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)
        serializer = self.get_serializer(qs, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def reply(self, request, pk=None):
        """Post a reply to a viewing request."""
        viewing = self.get_object()
        user = request.user
        if user != viewing.requester and user != viewing.property.owner:
            raise PermissionDenied("You are not a participant in this conversation.")
        message = request.data.get('message', '').strip()
        if not message:
            raise ValidationError("Message cannot be empty.")
        reply_obj = Reply.objects.create(viewing_request=viewing, author=user, message=message)
        try:
            from ..tasks import send_reply_notification
            send_reply_notification.delay(reply_obj.id)
        except Exception:
            from ..notifications import notify_reply
            notify_reply(reply_obj)
        return Response(ReplySerializer(reply_obj).data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['patch'])
    def update_status(self, request, pk=None):
        """Property owner can confirm/decline, or requester can cancel."""
        viewing = self.get_object()
        new_status = request.data.get('status')
        # Allow requester to cancel their own request
        if viewing.requester == request.user:
            if new_status != 'cancelled':
                raise PermissionDenied("You can only cancel your own viewing request.")
        elif viewing.property.owner != request.user:
            raise PermissionDenied()
        elif new_status not in ['confirmed', 'declined', 'completed']:
            raise ValidationError("Invalid status.")
        viewing.status = new_status
        if 'seller_notes' in request.data:
            viewing.seller_notes = request.data['seller_notes']
        viewing.save(update_fields=['status', 'seller_notes', 'updated_at'])
        try:
            from ..tasks import send_viewing_status_notification
            send_viewing_status_notification.delay(viewing.id)
        except Exception:
            pass
        return Response(ViewingRequestSerializer(viewing).data)


class ViewingSlotViewSet(viewsets.ModelViewSet):
    """Manage viewing availability slots."""
    serializer_class = ViewingSlotSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = None

    def get_permissions(self):
        if self.action in ['list', 'retrieve']:
            return [permissions.AllowAny()]
        return [permissions.IsAuthenticated()]

    def get_queryset(self):
        return ViewingSlot.objects.filter(
            property_id=self.kwargs['property_pk']
        )

    def perform_create(self, serializer):
        prop = get_object_or_404(Property, pk=self.kwargs['property_pk'])
        if prop.owner != self.request.user:
            raise PermissionDenied("Only the property owner can manage viewing slots.")
        serializer.save(property=prop)

    def perform_update(self, serializer):
        if serializer.instance.property.owner != self.request.user:
            raise PermissionDenied()
        serializer.save()

    def perform_destroy(self, instance):
        if instance.property.owner != self.request.user:
            raise PermissionDenied()
        instance.delete()


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def bulk_create_viewing_slots(request, property_pk):
    """Bulk-create recurring weekly viewing slots for multiple days of the week.

    Accepts two payload formats:

    1. Shared time (legacy): { days: [0,1,2], start_time, end_time, max_bookings }
       All days get the same time.

    2. Per-day schedule: { schedule: [{ day: 0, start_time: "10:00", end_time: "11:00" }, ...], max_bookings }
       Each day gets its own time.
    """
    prop = get_object_or_404(Property, pk=property_pk)
    if prop.owner != request.user:
        raise PermissionDenied("Only the property owner can manage viewing slots.")

    schedule = request.data.get('schedule')
    max_bookings = request.data.get('max_bookings', 1)

    try:
        max_bookings = int(max_bookings)
        if max_bookings < 1:
            raise ValueError
    except (TypeError, ValueError):
        return Response({'detail': 'max_bookings must be a positive integer.'}, status=status.HTTP_400_BAD_REQUEST)

    # Per-day schedule format
    if schedule:
        if not isinstance(schedule, list) or len(schedule) == 0:
            return Response({'detail': 'schedule must be a non-empty list.'}, status=status.HTTP_400_BAD_REQUEST)

        created = []
        for entry in schedule:
            day = entry.get('day')
            st = entry.get('start_time')
            et = entry.get('end_time')
            if day is None or not st or not et:
                return Response({'detail': 'Each schedule entry needs day, start_time and end_time.'}, status=status.HTTP_400_BAD_REQUEST)
            try:
                day = int(day)
                if not (0 <= day <= 6):
                    raise ValueError
            except (TypeError, ValueError):
                return Response({'detail': 'day must be an integer between 0 (Monday) and 6 (Sunday).'}, status=status.HTTP_400_BAD_REQUEST)

            slot = ViewingSlot.objects.create(
                property=prop,
                day_of_week=day,
                start_time=st,
                end_time=et,
                max_bookings=entry.get('max_bookings', max_bookings),
            )
            created.append(slot)

        return Response(ViewingSlotSerializer(created, many=True).data, status=status.HTTP_201_CREATED)

    # Legacy shared-time format
    days = request.data.get('days', [])
    start_time = request.data.get('start_time')
    end_time = request.data.get('end_time')

    if not days:
        return Response({'detail': 'At least one day must be selected.'}, status=status.HTTP_400_BAD_REQUEST)
    if not start_time or not end_time:
        return Response({'detail': 'start_time and end_time are required.'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        days = [int(d) for d in days]
        if not all(0 <= d <= 6 for d in days):
            raise ValueError
    except (TypeError, ValueError):
        return Response({'detail': 'days must be integers between 0 (Monday) and 6 (Sunday).'}, status=status.HTTP_400_BAD_REQUEST)

    created = []
    for day in days:
        slot = ViewingSlot.objects.create(
            property=prop,
            day_of_week=day,
            start_time=start_time,
            end_time=end_time,
            max_bookings=max_bookings,
        )
        created.append(slot)

    return Response(ViewingSlotSerializer(created, many=True).data, status=status.HTTP_201_CREATED)


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def book_viewing_slot(request, property_pk, slot_pk):
    """Book a viewing slot (creates a ViewingRequest tied to the slot)."""
    prop = get_object_or_404(Property, pk=property_pk)
    slot = get_object_or_404(ViewingSlot, pk=slot_pk, property=prop)

    if prop.owner == request.user:
        return Response({'detail': 'Cannot book a viewing for your own property.'}, status=status.HTTP_400_BAD_REQUEST)
    if not slot.get_is_available():
        return Response({'detail': 'This slot is no longer available.'}, status=status.HTTP_400_BAD_REQUEST)

    viewing = ViewingRequest.objects.create(
        property=prop,
        requester=request.user,
        preferred_date=slot.date or timezone.now().date(),
        preferred_time=slot.start_time,
        name=request.data.get('name', request.user.get_full_name()),
        email=request.data.get('email', request.user.email),
        phone=request.data.get('phone', ''),
        message=request.data.get('message', ''),
    )
    ViewingSlotBooking.objects.create(slot=slot, viewing_request=viewing)

    try:
        from ..tasks import send_viewing_notification
        send_viewing_notification.delay(viewing.id)
    except Exception:
        pass

    return Response(ViewingRequestSerializer(viewing).data, status=status.HTTP_201_CREATED)


class OpenHouseEventViewSet(viewsets.ModelViewSet):
    """CRUD for open house events."""
    serializer_class = OpenHouseEventSerializer

    def get_permissions(self):
        if self.action in ['list', 'retrieve']:
            return [permissions.AllowAny()]
        return [permissions.IsAuthenticated()]

    def get_queryset(self):
        property_pk = self.kwargs.get('property_pk')
        if property_pk:
            return OpenHouseEvent.objects.filter(property_id=property_pk)
        if self.request.user.is_authenticated:
            return OpenHouseEvent.objects.filter(property__owner=self.request.user)
        return OpenHouseEvent.objects.none()

    def perform_create(self, serializer):
        property_pk = self.kwargs.get('property_pk')
        prop = get_object_or_404(Property, pk=property_pk)
        if prop.owner != self.request.user:
            raise PermissionDenied('Only the property owner can create open house events.')
        serializer.save(property=prop)

    def perform_update(self, serializer):
        if serializer.instance.property.owner != self.request.user:
            raise PermissionDenied()
        serializer.save()

    def perform_destroy(self, instance):
        if instance.property.owner != self.request.user:
            raise PermissionDenied()
        instance.delete()


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def rsvp_open_house(request, event_pk):
    """RSVP to an open house event."""
    event = get_object_or_404(OpenHouseEvent, pk=event_pk, is_active=True)

    if not event.has_capacity:
        return Response({'error': 'This event is at full capacity.'}, status=400)

    if event.property.owner == request.user:
        return Response({'error': 'You cannot RSVP to your own open house.'}, status=400)

    rsvp, created = OpenHouseRSVP.objects.get_or_create(
        event=event,
        user=request.user,
        defaults={
            'attendees': request.data.get('attendees', 1),
            'message': request.data.get('message', ''),
        }
    )

    if not created:
        return Response({'error': 'You have already RSVPd to this event.'}, status=400)

    # Notify the seller
    try:
        from ..tasks import send_email_task
        send_email_task.delay(
            f'New RSVP for {event.title}',
            f'Hi {event.property.owner.first_name or event.property.owner.email},\n\n'
            f'{request.user.get_full_name() or request.user.email} has RSVPd to your '
            f'open house event for "{event.property.title}" on {event.date}.\n\n'
            f'— For Sale By Owner',
            settings.DEFAULT_FROM_EMAIL,
            [event.property.owner.email],
        )
    except Exception:
        pass

    return Response(OpenHouseRSVPSerializer(rsvp).data, status=201)


@api_view(['DELETE'])
@permission_classes([permissions.IsAuthenticated])
def cancel_rsvp(request, event_pk):
    """Cancel an RSVP to an open house event."""
    rsvp = get_object_or_404(OpenHouseRSVP, event_id=event_pk, user=request.user)
    rsvp.delete()
    return Response(status=204)
