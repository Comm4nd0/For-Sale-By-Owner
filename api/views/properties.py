"""Property CRUD, images, floorplans, documents, features and property-scoped tools."""
import logging
import math
from decimal import Decimal

import requests

from django.conf import settings
from django.db.models import Q
from django.shortcuts import get_object_or_404
from django.utils import timezone

from rest_framework import viewsets, permissions, status
from rest_framework.decorators import api_view, permission_classes, action
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.response import Response

from ..models import (
    Property,
    PropertyImage,
    PropertyFloorplan,
    PropertyFeature,
    PropertyDocument,
    PriceHistory,
    PropertyView,
    ServiceCategory,
    ServiceProvider,
)
from ..serializers import (
    PropertySerializer,
    PropertyListSerializer,
    PropertyImageSerializer,
    PropertyFloorplanSerializer,
    PropertyFeatureSerializer,
    PropertyDocumentSerializer,
    ServiceProviderListSerializer,
)
from .base import IsOwnerOrReadOnly

logger = logging.getLogger(__name__)


class PropertyViewSet(viewsets.ModelViewSet):
    serializer_class = PropertySerializer

    def get_serializer_class(self):
        if self.action == 'list':
            return PropertyListSerializer
        return PropertySerializer

    def get_permissions(self):
        if self.action in ['list', 'retrieve']:
            return [permissions.AllowAny()]
        return [permissions.IsAuthenticated(), IsOwnerOrReadOnly()]

    def get_object(self):
        """Support lookup by slug as well as numeric pk."""
        lookup = self.kwargs.get('pk', '')
        queryset = self.filter_queryset(self.get_queryset())
        if lookup.isdigit():
            obj = get_object_or_404(queryset, pk=lookup)
        else:
            obj = get_object_or_404(queryset, slug=lookup)
        self.check_object_permissions(self.request, obj)
        return obj

    def get_queryset(self):
        queryset = Property.objects.all().select_related('owner').prefetch_related(
            'images', 'features',
        )
        status_filter = self.request.query_params.get('status')
        property_type = self.request.query_params.get('property_type')
        city = self.request.query_params.get('city')

        if not self.request.user.is_authenticated:
            queryset = queryset.filter(status='active')
        elif self.request.query_params.get('mine') == 'true':
            queryset = queryset.filter(owner=self.request.user)
        else:
            queryset = queryset.filter(
                Q(status='active') | Q(owner=self.request.user)
            )

        if status_filter:
            queryset = queryset.filter(status=status_filter)
        if property_type:
            queryset = queryset.filter(property_type=property_type)
        if city:
            queryset = queryset.filter(city__icontains=city)

        # Search filters
        location = self.request.query_params.get('location')
        min_price = self.request.query_params.get('min_price')
        max_price = self.request.query_params.get('max_price')
        min_bedrooms = self.request.query_params.get('min_bedrooms')
        min_bathrooms = self.request.query_params.get('min_bathrooms')
        epc_rating = self.request.query_params.get('epc_rating')

        if location:
            queryset = queryset.filter(
                Q(city__icontains=location) |
                Q(county__icontains=location) |
                Q(postcode__icontains=location) |
                Q(address_line_1__icontains=location)
            )
        if min_price:
            queryset = queryset.filter(price__gte=min_price)
        if max_price:
            queryset = queryset.filter(price__lte=max_price)
        if min_bedrooms:
            queryset = queryset.filter(bedrooms__gte=min_bedrooms)
        if min_bathrooms:
            queryset = queryset.filter(bathrooms__gte=min_bathrooms)
        if epc_rating:
            queryset = queryset.filter(epc_rating=epc_rating)

        # Radius/distance search
        lat = self.request.query_params.get('lat')
        lon = self.request.query_params.get('lon')
        radius = self.request.query_params.get('radius')  # in miles
        if lat and lon and radius:
            try:
                lat, lon, radius = float(lat), float(lon), float(radius)
                # Rough bounding box filter first for efficiency
                lat_range = radius / 69.0
                lon_range = radius / (69.0 * math.cos(math.radians(lat)))
                queryset = queryset.filter(
                    latitude__isnull=False,
                    longitude__isnull=False,
                    latitude__gte=lat - lat_range,
                    latitude__lte=lat + lat_range,
                    longitude__gte=lon - lon_range,
                    longitude__lte=lon + lon_range,
                )
            except (ValueError, TypeError):
                pass

        return queryset

    def perform_create(self, serializer):
        instance = serializer.save(owner=self.request.user)
        PriceHistory.objects.create(property=instance, price=instance.price)

    def perform_update(self, serializer):
        old_price = serializer.instance.price
        instance = serializer.save()
        if instance.price != old_price:
            PriceHistory.objects.create(property=instance, price=instance.price)

    def retrieve(self, request, *args, **kwargs):
        instance = self.get_object()
        try:
            ip = request.META.get('HTTP_X_FORWARDED_FOR', request.META.get('REMOTE_ADDR', '')).split(',')[0].strip()
            PropertyView.objects.create(
                property=instance,
                viewer_ip=ip or None,
                user=request.user if request.user.is_authenticated else None,
            )
        except Exception:
            pass
        serializer = self.get_serializer(instance)
        return Response(serializer.data)

    @action(detail=True, methods=['get'])
    def similar(self, request, pk=None):
        """Return similar properties based on type, location, and price range."""
        prop = self.get_object()
        price_range = prop.price * Decimal('0.3')
        similar = Property.objects.filter(
            status='active',
        ).filter(
            Q(property_type=prop.property_type) |
            Q(city__iexact=prop.city) |
            Q(price__gte=prop.price - price_range, price__lte=prop.price + price_range)
        ).exclude(pk=prop.pk).select_related('owner').prefetch_related('images')[:6]
        serializer = PropertyListSerializer(similar, many=True, context={'request': request})
        return Response(serializer.data)


class PropertyImageViewSet(viewsets.ModelViewSet):
    serializer_class = PropertyImageSerializer
    parser_classes = [MultiPartParser, FormParser]

    def get_permissions(self):
        if self.action in ['list', 'retrieve']:
            return [permissions.AllowAny()]
        return [permissions.IsAuthenticated()]

    def get_queryset(self):
        return PropertyImage.objects.filter(
            property_id=self.kwargs['property_pk']
        )

    def _get_property(self):
        return get_object_or_404(Property, pk=self.kwargs['property_pk'])

    def create(self, request, *args, **kwargs):
        try:
            return super().create(request, *args, **kwargs)
        except (PermissionDenied, ValidationError):
            # Let DRF's exception handler turn these into 4xx responses.
            raise
        except Exception:
            logger.exception("Image upload failed")
            return Response(
                {"detail": "Upload failed. Please try again."},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

    def perform_create(self, serializer):
        property_obj = self._get_property()
        if property_obj.owner != self.request.user:
            raise PermissionDenied("You can only add images to your own properties.")
        if property_obj.images.count() >= 10:
            raise ValidationError("Maximum 10 images per property.")
        instance = serializer.save(property=property_obj)
        # Async image processing
        try:
            from ..tasks import process_property_image
            process_property_image.delay(instance.id)
        except Exception:
            pass

    def perform_update(self, serializer):
        if serializer.instance.property.owner != self.request.user:
            raise PermissionDenied()
        serializer.save()

    def perform_destroy(self, instance):
        if instance.property.owner != self.request.user:
            raise PermissionDenied()
        was_primary = instance.is_primary
        prop = instance.property
        instance.image.delete(save=False)
        if instance.thumbnail:
            instance.thumbnail.delete(save=False)
        instance.delete()
        if was_primary:
            next_img = prop.images.first()
            if next_img:
                next_img.is_primary = True
                next_img.save(update_fields=['is_primary'])


class PropertyFloorplanViewSet(viewsets.ModelViewSet):
    serializer_class = PropertyFloorplanSerializer
    parser_classes = [MultiPartParser, FormParser]

    def get_permissions(self):
        if self.action in ['list', 'retrieve']:
            return [permissions.AllowAny()]
        return [permissions.IsAuthenticated()]

    def get_queryset(self):
        return PropertyFloorplan.objects.filter(
            property_id=self.kwargs['property_pk']
        )

    def _get_property(self):
        return get_object_or_404(Property, pk=self.kwargs['property_pk'])

    def perform_create(self, serializer):
        property_obj = self._get_property()
        if property_obj.owner != self.request.user:
            raise PermissionDenied("You can only add floorplans to your own properties.")
        if property_obj.floorplans.count() >= 5:
            raise ValidationError("Maximum 5 floorplans per property.")
        serializer.save(property=property_obj)

    def perform_update(self, serializer):
        if serializer.instance.property.owner != self.request.user:
            raise PermissionDenied()
        serializer.save()

    def perform_destroy(self, instance):
        if instance.property.owner != self.request.user:
            raise PermissionDenied()
        instance.file.delete(save=False)
        instance.delete()


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def reorder_images(request, property_pk):
    """Bulk-update image ordering. Expects {"order": [id1, id2, ...]}."""
    prop = get_object_or_404(Property, pk=property_pk)
    if prop.owner != request.user:
        raise PermissionDenied()
    order = request.data.get('order', [])
    for idx, image_id in enumerate(order):
        PropertyImage.objects.filter(pk=image_id, property=prop).update(order=idx)
    return Response({'status': 'ok'})


class PropertyFeatureViewSet(viewsets.ReadOnlyModelViewSet):
    """Read-only list of available property features/tags."""
    serializer_class = PropertyFeatureSerializer
    queryset = PropertyFeature.objects.all()
    permission_classes = [permissions.AllowAny]
    pagination_class = None


class PropertyDocumentViewSet(viewsets.ModelViewSet):
    """Manage property documents (title deeds, EPC, etc.)."""
    serializer_class = PropertyDocumentSerializer
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def get_queryset(self):
        prop = get_object_or_404(Property, pk=self.kwargs['property_pk'])
        user = self.request.user
        if prop.owner == user:
            return PropertyDocument.objects.filter(property=prop)
        # Non-owners can only see public documents
        return PropertyDocument.objects.filter(property=prop, is_public=True)

    def perform_create(self, serializer):
        prop = get_object_or_404(Property, pk=self.kwargs['property_pk'])
        if prop.owner != self.request.user:
            raise PermissionDenied("Only the property owner can upload documents.")
        # Auto-fill title from the document type display name when the client omits it
        title = serializer.validated_data.get('title') or ''
        if not title:
            document_type = serializer.validated_data.get('document_type', 'other')
            title = dict(PropertyDocument.DOCUMENT_TYPES).get(
                document_type, document_type.replace('_', ' ').title()
            )
        serializer.save(property=prop, uploaded_by=self.request.user, title=title)

    def perform_update(self, serializer):
        if serializer.instance.property.owner != self.request.user:
            raise PermissionDenied()
        serializer.save()

    def perform_destroy(self, instance):
        if instance.property.owner != self.request.user:
            raise PermissionDenied()
        instance.file.delete(save=False)
        instance.delete()


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def bulk_import_properties(request):
    """Import multiple properties from JSON data."""
    properties_data = request.data.get('properties', [])
    if not properties_data or not isinstance(properties_data, list):
        return Response({'detail': 'Provide a list of properties.'}, status=status.HTTP_400_BAD_REQUEST)
    if len(properties_data) > 50:
        return Response({'detail': 'Maximum 50 properties per import.'}, status=status.HTTP_400_BAD_REQUEST)

    created = []
    errors = []
    for idx, prop_data in enumerate(properties_data):
        try:
            prop = Property.objects.create(
                owner=request.user,
                title=prop_data['title'],
                property_type=prop_data.get('property_type', 'other'),
                price=Decimal(str(prop_data['price'])),
                address_line_1=prop_data['address_line_1'],
                city=prop_data['city'],
                postcode=prop_data['postcode'],
                bedrooms=prop_data.get('bedrooms', 0),
                bathrooms=prop_data.get('bathrooms', 0),
                reception_rooms=prop_data.get('reception_rooms', 0),
                description=prop_data.get('description', ''),
                status='draft',
            )
            PriceHistory.objects.create(property=prop, price=prop.price)
            created.append({'id': prop.id, 'title': prop.title, 'slug': prop.slug})
        except Exception as e:
            errors.append({'index': idx, 'error': str(e)})

    return Response({
        'created': len(created),
        'errors': len(errors),
        'properties': created,
        'error_details': errors,
    }, status=status.HTTP_201_CREATED if created else status.HTTP_400_BAD_REQUEST)


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def export_properties(request):
    """Export the user's properties as JSON."""
    properties = Property.objects.filter(owner=request.user).prefetch_related('images', 'features')
    data = []
    for prop in properties:
        data.append({
            'title': prop.title,
            'property_type': prop.property_type,
            'status': prop.status,
            'price': str(prop.price),
            'address_line_1': prop.address_line_1,
            'address_line_2': prop.address_line_2,
            'city': prop.city,
            'county': prop.county,
            'postcode': prop.postcode,
            'bedrooms': prop.bedrooms,
            'bathrooms': prop.bathrooms,
            'reception_rooms': prop.reception_rooms,
            'square_feet': prop.square_feet,
            'epc_rating': prop.epc_rating,
            'description': prop.description,
            'features': list(prop.features.values_list('name', flat=True)),
            'created_at': prop.created_at.isoformat(),
        })
    return Response({'properties': data, 'count': len(data)})


@api_view(['GET'])
@permission_classes([permissions.AllowAny])
def property_services(request, property_pk):
    """Return active service providers that cover the property's location."""
    from django.db.models import Case, When, Value, IntegerField

    prop = get_object_or_404(Property, pk=property_pk)
    postcode_prefix = prop.postcode.split()[0] if prop.postcode else ''
    county = prop.county

    providers = ServiceProvider.objects.filter(status='active').prefetch_related(
        'categories', 'subscriptions__tier',
    )
    if postcode_prefix or county:
        providers = providers.filter(
            Q(coverage_postcodes__icontains=postcode_prefix) |
            Q(coverage_counties__icontains=county)
        ).distinct()
    else:
        providers = providers.none()

    category = request.query_params.get('category')
    if category:
        providers = providers.filter(categories__slug=category)

    providers = providers.annotate(
        tier_priority=Case(
            When(subscriptions__tier__slug='pro', subscriptions__status='active', then=Value(0)),
            When(subscriptions__tier__slug='growth', subscriptions__status='active', then=Value(1)),
            default=Value(2),
            output_field=IntegerField(),
        )
    ).order_by('tier_priority', '-created_at').distinct()

    serializer = ServiceProviderListSerializer(providers[:20], many=True, context={'request': request})
    return Response(serializer.data)


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def listing_quality_score(request, property_pk):
    """Return the listing quality score and improvement tips for a property."""
    prop = get_object_or_404(Property, pk=property_pk)
    if prop.owner != request.user:
        raise PermissionDenied('You can only view the quality score of your own listings.')
    return Response(prop.listing_quality_score())


@api_view(['GET'])
@permission_classes([permissions.AllowAny])
def similar_properties(request, property_pk):
    """Find properties similar to the given one."""
    prop = get_object_or_404(Property, pk=property_pk)

    # Match on same area, similar price (±25%), same type, similar bedrooms (±1)
    price_min = float(prop.price) * 0.75
    price_max = float(prop.price) * 1.25

    queryset = Property.objects.filter(
        status='active',
        price__gte=price_min,
        price__lte=price_max,
    ).exclude(pk=prop.pk)

    # Prefer same city/postcode area
    postcode_prefix = prop.postcode.split()[0] if ' ' in prop.postcode else prop.postcode[:3]
    same_area = queryset.filter(
        Q(city__iexact=prop.city) | Q(postcode__istartswith=postcode_prefix)
    )

    # Further filter by property type and similar bedrooms
    close_match = same_area.filter(
        property_type=prop.property_type,
        bedrooms__gte=max(0, prop.bedrooms - 1),
        bedrooms__lte=prop.bedrooms + 1,
    )

    # Fall back to broader matches if not enough results
    if close_match.count() >= 4:
        results = close_match[:8]
    elif same_area.count() >= 4:
        results = same_area[:8]
    else:
        results = queryset[:8]

    serializer = PropertyListSerializer(
        results, many=True, context={'request': request}
    )
    return Response(serializer.data)


@api_view(['GET'])
@permission_classes([permissions.AllowAny])
def property_history(request, property_pk):
    """Return property price history and days on market."""
    prop = get_object_or_404(Property, pk=property_pk)

    # Internal price history
    price_changes = PriceHistory.objects.filter(property=prop).order_by('changed_at')
    history = [
        {
            'price': float(ph.price),
            'date': ph.changed_at.isoformat(),
        }
        for ph in price_changes
    ]

    # Days on market
    days_on_market = (timezone.now() - prop.created_at).days

    # Land Registry previous sales for this postcode
    land_registry = []
    try:
        resp = requests.get(
            'https://landregistry.data.gov.uk/data/ppi/transaction-record.json',
            params={
                'propertyAddress.postcode': prop.postcode,
                'propertyAddress.paon': prop.address_line_1.split()[0] if prop.address_line_1 else '',
                '_pageSize': '10',
                '_sort': '-transactionDate',
            },
            timeout=15,
        )
        resp.raise_for_status()
        items = resp.json().get('result', {}).get('items', [])
        for item in items:
            land_registry.append({
                'price': item.get('pricePaid', 0),
                'date': item.get('transactionDate', ''),
            })
    except requests.RequestException:
        pass

    return Response({
        'property_id': prop.pk,
        'current_price': float(prop.price),
        'days_on_market': days_on_market,
        'listed_date': prop.created_at.isoformat(),
        'price_changes': history,
        'land_registry_sales': land_registry,
    })


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def generate_property_flyer(request, property_pk):
    """Generate a printable property flyer with QR code."""
    prop = get_object_or_404(Property, pk=property_pk)
    if prop.owner != request.user:
        raise PermissionDenied('Only the property owner can generate flyers.')

    property_url = f"{settings.SITE_URL}/properties/{prop.slug or prop.pk}/"

    # Generate QR code
    try:
        import qrcode
        from io import BytesIO
        import base64

        qr = qrcode.QRCode(version=1, box_size=10, border=4)
        qr.add_data(property_url)
        qr.make(fit=True)
        qr_img = qr.make_image(fill_color="black", back_color="white")
        qr_buffer = BytesIO()
        qr_img.save(qr_buffer, format='PNG')
        qr_base64 = base64.b64encode(qr_buffer.getvalue()).decode()
    except ImportError:
        qr_base64 = None

    # Get primary image
    primary_image = None
    primary = prop.images.filter(is_primary=True).first()
    if primary and primary.image:
        primary_image = primary.image.url

    # Build flyer data
    flyer_data = {
        'property': {
            'title': prop.title,
            'price': f"£{prop.price:,.0f}",
            'address': f"{prop.address_line_1}, {prop.city}, {prop.postcode}",
            'bedrooms': prop.bedrooms,
            'bathrooms': prop.bathrooms,
            'reception_rooms': prop.reception_rooms,
            'square_feet': prop.square_feet,
            'property_type': prop.get_property_type_display(),
            'epc_rating': prop.epc_rating,
            'description': prop.description[:300] + ('...' if len(prop.description) > 300 else ''),
            'primary_image': primary_image,
        },
        'qr_code': qr_base64,
        'property_url': property_url,
        'generated_at': timezone.now().isoformat(),
    }

    return Response(flyer_data)


EPC_IMPROVEMENTS = {
    'G': [
        {'improvement': 'Loft insulation (270mm)', 'estimated_cost': '£300-£500', 'annual_saving': '£150-£250', 'rating_improvement': '+5-10'},
        {'improvement': 'Cavity wall insulation', 'estimated_cost': '£500-£1,500', 'annual_saving': '£100-£200', 'rating_improvement': '+5-10'},
        {'improvement': 'Draught-proofing', 'estimated_cost': '£100-£300', 'annual_saving': '£25-£50', 'rating_improvement': '+1-3'},
        {'improvement': 'Upgrade boiler to A-rated condensing', 'estimated_cost': '£2,000-£3,500', 'annual_saving': '£200-£350', 'rating_improvement': '+10-15'},
        {'improvement': 'Double glazing', 'estimated_cost': '£3,000-£7,000', 'annual_saving': '£75-£150', 'rating_improvement': '+3-5'},
        {'improvement': 'Solar panels (4kW)', 'estimated_cost': '£5,000-£8,000', 'annual_saving': '£300-£500', 'rating_improvement': '+10-15'},
    ],
    'F': [
        {'improvement': 'Loft insulation top-up', 'estimated_cost': '£200-£400', 'annual_saving': '£100-£150', 'rating_improvement': '+3-5'},
        {'improvement': 'Cavity wall insulation', 'estimated_cost': '£500-£1,500', 'annual_saving': '£100-£200', 'rating_improvement': '+5-10'},
        {'improvement': 'Upgrade boiler to A-rated condensing', 'estimated_cost': '£2,000-£3,500', 'annual_saving': '£200-£350', 'rating_improvement': '+10-15'},
        {'improvement': 'Smart heating controls', 'estimated_cost': '£200-£400', 'annual_saving': '£75-£125', 'rating_improvement': '+2-4'},
        {'improvement': 'Solar panels (4kW)', 'estimated_cost': '£5,000-£8,000', 'annual_saving': '£300-£500', 'rating_improvement': '+10-15'},
    ],
    'E': [
        {'improvement': 'Upgrade boiler to A-rated condensing', 'estimated_cost': '£2,000-£3,500', 'annual_saving': '£150-£250', 'rating_improvement': '+8-12'},
        {'improvement': 'Smart heating controls', 'estimated_cost': '£200-£400', 'annual_saving': '£75-£125', 'rating_improvement': '+2-4'},
        {'improvement': 'Solar panels (4kW)', 'estimated_cost': '£5,000-£8,000', 'annual_saving': '£300-£500', 'rating_improvement': '+10-15'},
        {'improvement': 'External wall insulation', 'estimated_cost': '£8,000-£15,000', 'annual_saving': '£200-£400', 'rating_improvement': '+10-15'},
    ],
    'D': [
        {'improvement': 'Solar panels (4kW)', 'estimated_cost': '£5,000-£8,000', 'annual_saving': '£300-£500', 'rating_improvement': '+10-15'},
        {'improvement': 'Heat pump (air source)', 'estimated_cost': '£7,000-£14,000', 'annual_saving': '£200-£400', 'rating_improvement': '+10-20'},
        {'improvement': 'Smart heating controls', 'estimated_cost': '£200-£400', 'annual_saving': '£50-£100', 'rating_improvement': '+2-3'},
        {'improvement': 'LED lighting throughout', 'estimated_cost': '£100-£300', 'annual_saving': '£30-£60', 'rating_improvement': '+1-2'},
    ],
    'C': [
        {'improvement': 'Solar panels (4kW)', 'estimated_cost': '£5,000-£8,000', 'annual_saving': '£300-£500', 'rating_improvement': '+5-10'},
        {'improvement': 'Heat pump (air source)', 'estimated_cost': '£7,000-£14,000', 'annual_saving': '£200-£400', 'rating_improvement': '+5-10'},
        {'improvement': 'Battery storage', 'estimated_cost': '£3,000-£6,000', 'annual_saving': '£150-£300', 'rating_improvement': '+2-5'},
    ],
    'B': [
        {'improvement': 'Solar panels (if not already fitted)', 'estimated_cost': '£5,000-£8,000', 'annual_saving': '£300-£500', 'rating_improvement': '+3-5'},
        {'improvement': 'Battery storage', 'estimated_cost': '£3,000-£6,000', 'annual_saving': '£150-£300', 'rating_improvement': '+1-3'},
    ],
}


@api_view(['GET'])
@permission_classes([permissions.AllowAny])
def epc_improvement_suggestions(request, property_pk):
    """Suggest energy improvements based on EPC rating."""
    prop = get_object_or_404(Property, pk=property_pk)

    if not prop.epc_rating:
        return Response({
            'error': 'This property has no EPC rating set.',
            'suggestion': 'Add your EPC rating to receive improvement suggestions.',
        }, status=400)

    if prop.epc_rating == 'A':
        return Response({
            'epc_rating': 'A',
            'message': 'This property already has the highest EPC rating. No improvements needed.',
            'improvements': [],
        })

    improvements = EPC_IMPROVEMENTS.get(prop.epc_rating, [])

    # Find relevant service providers on the platform
    related_categories = ServiceCategory.objects.filter(
        slug__in=['epc', 'insulation', 'solar', 'boiler', 'heating', 'electrician']
    )
    postcode_prefix = prop.postcode.split()[0] if ' ' in prop.postcode else prop.postcode[:3]
    local_providers = ServiceProvider.objects.filter(
        status='active',
        categories__in=related_categories,
    ).filter(
        Q(coverage_postcodes__icontains=postcode_prefix) |
        Q(coverage_counties__icontains=prop.county)
    ).distinct()[:5]

    provider_data = [
        {
            'id': p.pk,
            'business_name': p.business_name,
            'slug': p.slug,
            'average_rating': p.average_rating,
        }
        for p in local_providers
    ]

    return Response({
        'epc_rating': prop.epc_rating,
        'improvements': improvements,
        'local_service_providers': provider_data,
    })
