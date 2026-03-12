from django.contrib.auth import get_user_model
from rest_framework import serializers
from .models import (
    Property, PropertyImage, PropertyFloorplan, PropertyFeature,
    PriceHistory, SavedProperty, Enquiry, PropertyView,
    ViewingRequest, SavedSearch, Reply,
    ServiceCategory, ServiceProvider, ServiceProviderReview,
    SubscriptionTier, SubscriptionAddOn, ServiceProviderSubscription,
    ServiceProviderPhoto,
    ChatRoom, ChatMessage,
    ViewingSlot, ViewingSlotBooking,
    Offer, PropertyDocument, PropertyFlag,
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
        fields = [
            'id', 'email', 'first_name', 'last_name', 'phone',
            'dark_mode',
            'notification_enquiries', 'notification_viewings',
            'notification_price_drops', 'notification_saved_searches',
        ]
        read_only_fields = ['id', 'email']


class RelativeImageField(serializers.ImageField):
    """Returns relative URL path instead of absolute to avoid mixed-content issues behind proxies."""

    def to_representation(self, value):
        if not value:
            return None
        return value.url


class PropertyImageSerializer(serializers.ModelSerializer):
    image = RelativeImageField()
    thumbnail = RelativeImageField(read_only=True)

    class Meta:
        model = PropertyImage
        fields = ['id', 'image', 'thumbnail', 'order', 'is_primary', 'caption', 'uploaded_at']
        read_only_fields = ['id', 'thumbnail', 'uploaded_at']


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
    offer_count = serializers.SerializerMethodField()

    class Meta:
        model = Property
        fields = [
            'id', 'owner', 'owner_name', 'owner_is_verified',
            'title', 'slug', 'description',
            'property_type', 'property_type_display',
            'status', 'status_display', 'price',
            'address_line_1', 'address_line_2', 'city', 'county', 'postcode',
            'latitude', 'longitude',
            'bedrooms', 'bathrooms', 'reception_rooms', 'square_feet',
            'epc_rating', 'epc_rating_display',
            'features', 'feature_list',
            'images', 'floorplans', 'primary_image', 'is_saved',
            'price_history', 'view_count', 'enquiry_count', 'offer_count',
            'video_url', 'video_thumbnail',
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

    def get_offer_count(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated and obj.owner == request.user:
            return obj.offers.count()
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
            'latitude', 'longitude',
            'bedrooms', 'bathrooms', 'reception_rooms', 'square_feet',
            'epc_rating', 'epc_rating_display',
            'feature_list', 'primary_image', 'is_saved',
            'view_count', 'video_url',
            'created_at', 'updated_at',
        ]


class SavedPropertySerializer(serializers.ModelSerializer):
    property_detail = PropertyListSerializer(source='property', read_only=True)

    class Meta:
        model = SavedProperty
        fields = ['id', 'property', 'property_detail', 'created_at']
        read_only_fields = ['id', 'created_at']


class ReplySerializer(serializers.ModelSerializer):
    author_name = serializers.SerializerMethodField()

    class Meta:
        model = Reply
        fields = ['id', 'enquiry', 'viewing_request', 'author', 'author_name', 'message', 'created_at']
        read_only_fields = ['id', 'author', 'created_at']

    def get_author_name(self, obj):
        return obj.author.get_full_name() or 'User'


class EnquirySerializer(serializers.ModelSerializer):
    sender_name = serializers.CharField(source='sender.get_full_name', read_only=True)
    property_title = serializers.CharField(source='property.title', read_only=True)
    replies = ReplySerializer(many=True, read_only=True)
    reply_count = serializers.SerializerMethodField()

    class Meta:
        model = Enquiry
        fields = [
            'id', 'property', 'property_title',
            'sender', 'sender_name',
            'name', 'email', 'phone', 'message',
            'is_read', 'created_at',
            'replies', 'reply_count',
        ]
        read_only_fields = ['id', 'sender', 'created_at']
        extra_kwargs = {
            'email': {'write_only': True},
            'phone': {'write_only': True},
        }

    def get_reply_count(self, obj):
        return obj.replies.count()


class ViewingRequestSerializer(serializers.ModelSerializer):
    requester_name = serializers.CharField(source='requester.get_full_name', read_only=True)
    property_title = serializers.CharField(source='property.title', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    replies = ReplySerializer(many=True, read_only=True)
    reply_count = serializers.SerializerMethodField()

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
            'replies', 'reply_count',
        ]
        read_only_fields = ['id', 'requester', 'status', 'seller_notes', 'created_at', 'updated_at']
        extra_kwargs = {
            'email': {'write_only': True},
            'phone': {'write_only': True},
        }

    def get_reply_count(self, obj):
        return obj.replies.count()


class SavedSearchSerializer(serializers.ModelSerializer):
    class Meta:
        model = SavedSearch
        fields = [
            'id', 'name', 'location', 'property_type',
            'min_price', 'max_price', 'min_bedrooms', 'min_bathrooms',
            'epc_rating', 'email_alerts', 'alert_frequency', 'created_at',
        ]
        read_only_fields = ['id', 'created_at']


class DashboardStatsSerializer(serializers.Serializer):
    total_listings = serializers.IntegerField()
    active_listings = serializers.IntegerField()
    total_views = serializers.IntegerField()
    total_enquiries = serializers.IntegerField()
    unread_enquiries = serializers.IntegerField()
    total_saves = serializers.IntegerField()


# ── Chat Serializers ─────────────────────────────────────────────

class ChatMessageSerializer(serializers.ModelSerializer):
    sender_name = serializers.SerializerMethodField()

    class Meta:
        model = ChatMessage
        fields = ['id', 'room', 'sender', 'sender_name', 'message', 'is_read', 'created_at']
        read_only_fields = ['id', 'sender', 'created_at']

    def get_sender_name(self, obj):
        return obj.sender.get_full_name() or obj.sender.email


class ChatRoomSerializer(serializers.ModelSerializer):
    buyer_name = serializers.SerializerMethodField()
    seller_name = serializers.SerializerMethodField()
    property_title = serializers.CharField(source='property.title', read_only=True)
    property_slug = serializers.CharField(source='property.slug', read_only=True)
    last_message = serializers.SerializerMethodField()
    unread_count = serializers.SerializerMethodField()

    class Meta:
        model = ChatRoom
        fields = [
            'id', 'property', 'property_title', 'property_slug',
            'buyer', 'buyer_name', 'seller', 'seller_name',
            'last_message', 'unread_count',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'buyer', 'seller', 'created_at', 'updated_at']

    def get_buyer_name(self, obj):
        return obj.buyer.get_full_name() or obj.buyer.email

    def get_seller_name(self, obj):
        return obj.seller.get_full_name() or obj.seller.email

    def get_last_message(self, obj):
        msg = obj.messages.order_by('-created_at').first()
        if msg:
            return {
                'message': msg.message[:100],
                'sender_id': msg.sender_id,
                'created_at': msg.created_at.isoformat(),
            }
        return None

    def get_unread_count(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return obj.messages.filter(is_read=False).exclude(sender=request.user).count()
        return 0


# ── Viewing Slot Serializers ─────────────────────────────────────

class ViewingSlotSerializer(serializers.ModelSerializer):
    is_available = serializers.SerializerMethodField()
    current_bookings = serializers.SerializerMethodField()
    day_display = serializers.CharField(source='get_day_of_week_display', read_only=True)

    def get_is_available(self, obj):
        return obj.get_is_available()

    def get_current_bookings(self, obj):
        return obj.get_bookings_count()

    class Meta:
        model = ViewingSlot
        fields = [
            'id', 'property', 'date', 'day_of_week', 'day_display',
            'start_time', 'end_time', 'max_bookings', 'current_bookings',
            'is_available', 'is_active',
        ]
        read_only_fields = ['id', 'property']


# ── Offer Serializers ────────────────────────────────────────────

class OfferSerializer(serializers.ModelSerializer):
    buyer_name = serializers.SerializerMethodField()
    property_title = serializers.CharField(source='property.title', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)

    class Meta:
        model = Offer
        fields = [
            'id', 'property', 'property_title',
            'buyer', 'buyer_name',
            'amount', 'message', 'status', 'status_display',
            'counter_amount', 'seller_notes',
            'is_cash_buyer', 'is_chain_free', 'mortgage_agreed',
            'expires_at', 'created_at', 'updated_at',
        ]
        read_only_fields = [
            'id', 'buyer', 'status', 'counter_amount',
            'seller_notes', 'created_at', 'updated_at',
        ]

    def get_buyer_name(self, obj):
        return obj.buyer.get_full_name() or obj.buyer.email


# ── Document Serializers ─────────────────────────────────────────

class PropertyDocumentSerializer(serializers.ModelSerializer):
    uploaded_by_name = serializers.SerializerMethodField()
    document_type_display = serializers.CharField(
        source='get_document_type_display', read_only=True
    )

    class Meta:
        model = PropertyDocument
        fields = [
            'id', 'property', 'uploaded_by', 'uploaded_by_name',
            'document_type', 'document_type_display',
            'title', 'file', 'is_public', 'uploaded_at',
        ]
        read_only_fields = ['id', 'uploaded_by', 'uploaded_at']

    def get_uploaded_by_name(self, obj):
        return obj.uploaded_by.get_full_name() or obj.uploaded_by.email


# ── Flag / Moderation Serializers ────────────────────────────────

class PropertyFlagSerializer(serializers.ModelSerializer):
    reason_display = serializers.CharField(source='get_reason_display', read_only=True)

    class Meta:
        model = PropertyFlag
        fields = [
            'id', 'property', 'reporter', 'reason', 'reason_display',
            'description', 'status', 'created_at',
        ]
        read_only_fields = ['id', 'reporter', 'status', 'created_at']



# ── Service Provider serializers ─────────────────────────────────

class ServiceCategorySerializer(serializers.ModelSerializer):
    provider_count = serializers.SerializerMethodField()

    class Meta:
        model = ServiceCategory
        fields = ['id', 'name', 'slug', 'icon', 'description', 'order', 'provider_count']

    def get_provider_count(self, obj):
        return obj.providers.filter(status='active').count()


class ServiceProviderReviewSerializer(serializers.ModelSerializer):
    reviewer_name = serializers.SerializerMethodField()

    class Meta:
        model = ServiceProviderReview
        fields = ['id', 'provider', 'reviewer', 'reviewer_name', 'rating', 'comment', 'created_at']
        read_only_fields = ['id', 'reviewer', 'created_at']

    def get_reviewer_name(self, obj):
        return obj.reviewer.get_full_name() or 'User'


class ServiceProviderListSerializer(serializers.ModelSerializer):
    """Lighter serializer for list views."""
    logo = RelativeImageField()
    categories = ServiceCategorySerializer(many=True, read_only=True)
    average_rating = serializers.SerializerMethodField()
    review_count = serializers.SerializerMethodField()
    tier_name = serializers.SerializerMethodField()
    tier_slug = serializers.SerializerMethodField()
    is_featured = serializers.SerializerMethodField()

    class Meta:
        model = ServiceProvider
        fields = [
            'id', 'business_name', 'slug', 'description',
            'categories', 'coverage_counties', 'coverage_postcodes',
            'logo', 'is_verified', 'pricing_info',
            'average_rating', 'review_count',
            'tier_name', 'tier_slug', 'is_featured',
            'created_at',
        ]

    def get_average_rating(self, obj):
        return obj.average_rating

    def get_review_count(self, obj):
        return obj.review_count

    def get_tier_name(self, obj):
        tier = obj.current_tier
        return tier.name if tier else 'Free'

    def get_tier_slug(self, obj):
        tier = obj.current_tier
        return tier.slug if tier else 'free'

    def get_is_featured(self, obj):
        tier = obj.current_tier
        return tier.feature_featured_placement if tier else False


class ServiceProviderPhotoSerializer(serializers.ModelSerializer):
    image = RelativeImageField()

    class Meta:
        model = ServiceProviderPhoto
        fields = ['id', 'image', 'caption', 'order', 'uploaded_at']
        read_only_fields = ['id', 'uploaded_at']


class ServiceProviderDetailSerializer(ServiceProviderListSerializer):
    """Full serializer for detail/create/update views."""
    reviews = ServiceProviderReviewSerializer(many=True, read_only=True)
    photos = ServiceProviderPhotoSerializer(many=True, read_only=True)
    owner_name = serializers.SerializerMethodField()
    category_ids = serializers.PrimaryKeyRelatedField(
        queryset=ServiceCategory.objects.all(),
        many=True, write_only=True, required=False,
        source='categories',
    )
    subscription = serializers.SerializerMethodField()
    tier_limits = serializers.SerializerMethodField()
    tier_features = serializers.SerializerMethodField()

    class Meta(ServiceProviderListSerializer.Meta):
        fields = ServiceProviderListSerializer.Meta.fields + [
            'owner', 'owner_name',
            'contact_email', 'contact_phone', 'website',
            'years_established',
            'status', 'reviews', 'photos',
            'subscription', 'tier_limits', 'tier_features',
            'updated_at',
            'category_ids',
        ]
        read_only_fields = ['id', 'owner', 'slug', 'is_verified', 'created_at', 'updated_at']

    def get_owner_name(self, obj):
        return obj.owner.get_full_name() or obj.owner.email

    def get_subscription(self, obj):
        """Return subscription details only to the owner."""
        request = self.context.get('request')
        if not request or not request.user.is_authenticated or request.user != obj.owner:
            return None
        sub = obj.active_subscription
        if not sub:
            return None
        return ServiceProviderSubscriptionSerializer(sub).data

    def get_tier_limits(self, obj):
        tier = obj.current_tier
        if not tier:
            return {}
        return {
            'max_service_categories': tier.max_service_categories,
            'max_locations': tier.max_locations,
            'max_photos': tier.max_photos,
            'allow_logo': tier.allow_logo,
        }

    def get_tier_features(self, obj):
        tier = obj.current_tier
        if not tier:
            return {}
        return {
            'basic_listing': tier.feature_basic_listing,
            'local_area_visibility': tier.feature_local_area_visibility,
            'contact_details': tier.feature_contact_details,
            'featured_placement': tier.feature_featured_placement,
            'click_through_analytics': tier.feature_click_through_analytics,
            'category_exclusivity': tier.feature_category_exclusivity,
            'priority_search': tier.feature_priority_search,
            'lead_notifications': tier.feature_lead_notifications,
            'performance_reports': tier.feature_performance_reports,
            'account_manager': tier.feature_account_manager,
            'photo_gallery': tier.feature_photo_gallery,
            'early_access': tier.feature_early_access,
        }

    def create(self, validated_data):
        categories = validated_data.pop('categories', [])
        instance = super().create(validated_data)
        if categories:
            instance.categories.set(categories)
        return instance

    def update(self, instance, validated_data):
        categories = validated_data.pop('categories', None)
        instance = super().update(instance, validated_data)
        if categories is not None:
            instance.categories.set(categories)
        return instance


# ── Subscription serializers ─────────────────────────────────────

class SubscriptionTierSerializer(serializers.ModelSerializer):
    limits = serializers.SerializerMethodField()
    features = serializers.SerializerMethodField()

    class Meta:
        model = SubscriptionTier
        fields = [
            'id', 'name', 'slug', 'tagline', 'cta_text', 'badge_text',
            'monthly_price', 'annual_price', 'currency',
            'limits', 'features', 'display_order',
        ]

    def get_limits(self, obj):
        return {
            'max_service_categories': obj.max_service_categories,
            'max_locations': obj.max_locations,
            'max_photos': obj.max_photos,
            'allow_logo': obj.allow_logo,
        }

    def get_features(self, obj):
        return {
            'basic_listing': obj.feature_basic_listing,
            'local_area_visibility': obj.feature_local_area_visibility,
            'contact_details': obj.feature_contact_details,
            'featured_placement': obj.feature_featured_placement,
            'click_through_analytics': obj.feature_click_through_analytics,
            'category_exclusivity': obj.feature_category_exclusivity,
            'priority_search': obj.feature_priority_search,
            'lead_notifications': obj.feature_lead_notifications,
            'performance_reports': obj.feature_performance_reports,
            'account_manager': obj.feature_account_manager,
            'photo_gallery': obj.feature_photo_gallery,
            'early_access': obj.feature_early_access,
        }


class SubscriptionAddOnSerializer(serializers.ModelSerializer):
    compatible_tier_slugs = serializers.SerializerMethodField()

    class Meta:
        model = SubscriptionAddOn
        fields = [
            'id', 'name', 'slug', 'description', 'monthly_price',
            'compatible_tier_slugs',
        ]

    def get_compatible_tier_slugs(self, obj):
        return list(obj.compatible_tiers.values_list('slug', flat=True))


class ServiceProviderSubscriptionSerializer(serializers.ModelSerializer):
    tier = SubscriptionTierSerializer(read_only=True)

    class Meta:
        model = ServiceProviderSubscription
        fields = [
            'id', 'tier', 'billing_cycle', 'status',
            'current_period_start', 'current_period_end',
            'cancel_at_period_end', 'started_at',
        ]
