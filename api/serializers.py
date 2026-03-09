from django.contrib.auth import get_user_model
from rest_framework import serializers
from .models import (
    Property, PropertyImage, PropertyFloorplan, PropertyFeature,
    PriceHistory, SavedProperty, Enquiry, PropertyView,
    ViewingRequest, SavedSearch,
)

User = get_user_model()


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'email', 'first_name', 'last_name', 'is_verified_seller', 'phone']
        read_only_fields = ['id', 'is_verified_seller']


class UserProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'email', 'first_name', 'last_name', 'phone']
        read_only_fields = ['id', 'email']


class RelativeImageField(serializers.ImageField):
    """Returns relative URL path instead of absolute to avoid mixed-content issues behind proxies."""

    def to_representation(self, value):
        if not value:
            return None
        return value.url


class PropertyImageSerializer(serializers.ModelSerializer):
    image = RelativeImageField()

    class Meta:
        model = PropertyImage
        fields = ['id', 'image', 'order', 'is_primary', 'caption', 'uploaded_at']
        read_only_fields = ['id', 'uploaded_at']


class PropertyFloorplanSerializer(serializers.ModelSerializer):
    class Meta:
        model = PropertyFloorplan
        fields = ['id', 'file', 'title', 'order', 'uploaded_at']
        read_only_fields = ['id', 'uploaded_at']


class PropertyFeatureSerializer(serializers.ModelSerializer):
    class Meta:
        model = PropertyFeature
        fields = ['id', 'name', 'icon']


class PriceHistorySerializer(serializers.ModelSerializer):
    class Meta:
        model = PriceHistory
        fields = ['id', 'price', 'changed_at']
        read_only_fields = ['id', 'changed_at']


class PropertySerializer(serializers.ModelSerializer):
    owner_name = serializers.SerializerMethodField()
    owner_is_verified = serializers.BooleanField(source='owner.is_verified_seller', read_only=True)
    property_type_display = serializers.CharField(
        source='get_property_type_display', read_only=True
    )
    status_display = serializers.CharField(
        source='get_status_display', read_only=True
    )
    epc_rating_display = serializers.CharField(
        source='get_epc_rating_display', read_only=True
    )
    images = PropertyImageSerializer(many=True, read_only=True)
    floorplans = PropertyFloorplanSerializer(many=True, read_only=True)
    feature_list = PropertyFeatureSerializer(source='features', many=True, read_only=True)
    price_history = PriceHistorySerializer(many=True, read_only=True)
    primary_image = serializers.SerializerMethodField()
    is_saved = serializers.SerializerMethodField()
    view_count = serializers.SerializerMethodField()
    enquiry_count = serializers.SerializerMethodField()

    class Meta:
        model = Property
        fields = [
            'id', 'owner', 'owner_name', 'owner_is_verified',
            'title', 'slug', 'description',
            'property_type', 'property_type_display',
            'status', 'status_display', 'price',
            'address_line_1', 'address_line_2', 'city', 'county', 'postcode',
            'bedrooms', 'bathrooms', 'reception_rooms', 'square_feet',
            'epc_rating', 'epc_rating_display',
            'features', 'feature_list',
            'images', 'floorplans', 'primary_image', 'is_saved',
            'price_history', 'view_count', 'enquiry_count',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'owner', 'slug', 'created_at', 'updated_at']

    def get_owner_name(self, obj):
        return obj.owner.get_full_name() or obj.owner.email

    def get_primary_image(self, obj):
        primary = obj.images.filter(is_primary=True).first()
        if primary:
            return primary.image.url
        return None

    def get_is_saved(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return SavedProperty.objects.filter(user=request.user, property=obj).exists()
        return False

    def get_view_count(self, obj):
        return obj.views.count()

    def get_enquiry_count(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated and obj.owner == request.user:
            return obj.enquiries.count()
        return None


class PropertyListSerializer(PropertySerializer):
    """Lighter serializer for list views — omits full images array."""
    class Meta(PropertySerializer.Meta):
        fields = [
            'id', 'owner', 'owner_name', 'owner_is_verified',
            'title', 'slug',
            'property_type', 'property_type_display',
            'status', 'status_display', 'price',
            'address_line_1', 'address_line_2', 'city', 'county', 'postcode',
            'bedrooms', 'bathrooms', 'reception_rooms', 'square_feet',
            'epc_rating', 'epc_rating_display',
            'feature_list', 'primary_image', 'is_saved',
            'view_count', 'created_at', 'updated_at',
        ]


class SavedPropertySerializer(serializers.ModelSerializer):
    property_detail = PropertyListSerializer(source='property', read_only=True)

    class Meta:
        model = SavedProperty
        fields = ['id', 'property', 'property_detail', 'created_at']
        read_only_fields = ['id', 'created_at']


class EnquirySerializer(serializers.ModelSerializer):
    sender_name = serializers.CharField(source='sender.get_full_name', read_only=True)
    property_title = serializers.CharField(source='property.title', read_only=True)

    class Meta:
        model = Enquiry
        fields = [
            'id', 'property', 'property_title',
            'sender', 'sender_name',
            'name', 'email', 'phone', 'message',
            'is_read', 'created_at',
        ]
        read_only_fields = ['id', 'sender', 'created_at']


class ViewingRequestSerializer(serializers.ModelSerializer):
    requester_name = serializers.CharField(source='requester.get_full_name', read_only=True)
    property_title = serializers.CharField(source='property.title', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)

    class Meta:
        model = ViewingRequest
        fields = [
            'id', 'property', 'property_title',
            'requester', 'requester_name',
            'preferred_date', 'preferred_time',
            'alternative_date', 'alternative_time',
            'message', 'name', 'email', 'phone',
            'status', 'status_display', 'seller_notes',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'requester', 'status', 'seller_notes', 'created_at', 'updated_at']


class SavedSearchSerializer(serializers.ModelSerializer):
    class Meta:
        model = SavedSearch
        fields = [
            'id', 'name', 'location', 'property_type',
            'min_price', 'max_price', 'min_bedrooms', 'min_bathrooms',
            'epc_rating', 'email_alerts', 'created_at',
        ]
        read_only_fields = ['id', 'created_at']


class DashboardStatsSerializer(serializers.Serializer):
    total_listings = serializers.IntegerField()
    active_listings = serializers.IntegerField()
    total_views = serializers.IntegerField()
    total_enquiries = serializers.IntegerField()
    unread_enquiries = serializers.IntegerField()
    total_saves = serializers.IntegerField()
