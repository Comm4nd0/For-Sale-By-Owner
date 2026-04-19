"""Formal offers on properties."""
from decimal import Decimal

from django.db import transaction
from django.db.models import Q
from django.shortcuts import get_object_or_404

from rest_framework import viewsets, permissions
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.response import Response

from ..models import Offer
from ..serializers import OfferSerializer


class OfferViewSet(viewsets.ModelViewSet):
    """Manage offers on properties."""
    serializer_class = OfferSerializer
    permission_classes = [permissions.IsAuthenticated]
    http_method_names = ['get', 'post', 'patch']

    def get_queryset(self):
        user = self.request.user
        return Offer.objects.filter(
            Q(buyer=user) | Q(property__owner=user)
        ).select_related('property', 'buyer')

    def perform_create(self, serializer):
        prop = serializer.validated_data['property']
        if prop.owner == self.request.user:
            raise ValidationError("You cannot make an offer on your own property.")
        offer = serializer.save(buyer=self.request.user, status='submitted')
        try:
            from ..tasks import send_offer_notification
            send_offer_notification.delay(offer.id, 'new')
        except Exception:
            pass

    @action(detail=False, methods=['get'])
    def received(self, request):
        """Get offers received on the user's properties."""
        qs = Offer.objects.filter(
            property__owner=request.user
        ).select_related('property', 'buyer').order_by('-created_at')
        page = self.paginate_queryset(qs)
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)
        return Response(self.get_serializer(qs, many=True).data)

    @action(detail=True, methods=['patch'])
    def respond(self, request, pk=None):
        """Seller responds to an offer (accept, reject, counter)."""
        new_status = request.data.get('status')
        if new_status not in ['accepted', 'rejected', 'countered']:
            raise ValidationError("Status must be 'accepted', 'rejected', or 'countered'.")

        counter = request.data.get('counter_amount')
        if new_status == 'countered' and not counter:
            raise ValidationError("counter_amount is required for counter offers.")

        with transaction.atomic():
            offer = get_object_or_404(
                Offer.objects.select_for_update().select_related('property'),
                pk=pk,
            )
            if offer.property.owner != request.user:
                raise PermissionDenied()
            if offer.status in ('accepted', 'rejected', 'withdrawn'):
                raise ValidationError("This offer has already been resolved.")

            offer.status = new_status
            if 'seller_notes' in request.data:
                offer.seller_notes = request.data['seller_notes']
            if new_status == 'countered':
                offer.counter_amount = Decimal(str(counter))
            offer.save()

        try:
            from ..tasks import send_offer_notification
            send_offer_notification.delay(offer.id, 'status_update')
        except Exception:
            pass

        return Response(OfferSerializer(offer).data)

    @action(detail=True, methods=['patch'])
    def withdraw(self, request, pk=None):
        """Buyer withdraws their offer."""
        with transaction.atomic():
            offer = get_object_or_404(Offer.objects.select_for_update(), pk=pk)
            if offer.buyer != request.user:
                raise PermissionDenied()
            if offer.status not in ['submitted', 'under_review', 'countered']:
                raise ValidationError("Cannot withdraw this offer.")
            offer.status = 'withdrawn'
            offer.save(update_fields=['status', 'updated_at'])
        return Response(OfferSerializer(offer).data)
