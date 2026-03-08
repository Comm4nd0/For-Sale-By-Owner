from django.contrib.auth import get_user_model
from rest_framework import serializers
from .models import Property, PropertyImage

User = get_user_model()


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'email', 'first_name', 'last_name']
        read_only_fields = ['id']


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


class PropertySerializer(serializers.ModelSerializer):
    owner_name = serializers.SerializerMethodField()
    property_type_display = serializers.CharField(
        source='get_property_type_display', read_only=True
    )
    status_display = serializers.CharField(
        source='get_status_display', read_only=True
    )
    images = PropertyImageSerializer(many=True, read_only=True)
    primary_image = serializers.SerializerMethodField()

    class Meta:
        model = Property
        fields = [
            'id', 'owner', 'owner_name', 'title', 'description',
            'property_type', 'property_type_display',
            'status', 'status_display', 'price',
            'address_line_1', 'address_line_2', 'city', 'county', 'postcode',
            'bedrooms', 'bathrooms', 'reception_rooms', 'square_feet',
            'images', 'primary_image', 'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'owner', 'created_at', 'updated_at']

    def get_owner_name(self, obj):
        return obj.owner.get_full_name() or obj.owner.email

    def get_primary_image(self, obj):
        primary = obj.images.filter(is_primary=True).first()
        if primary:
            return primary.image.url
        return None
