import 'property_image.dart';
import 'property_feature.dart';
import 'property_floorplan.dart';
import 'price_history.dart';

class Property {
  final int id;
  final int ownerId;
  final String title;
  final String slug;
  final String description;
  final String propertyType;
  final String propertyTypeDisplay;
  final String status;
  final String statusDisplay;
  final double price;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String county;
  final String postcode;
  final int bedrooms;
  final int bathrooms;
  final int receptionRooms;
  final int? squareFeet;
  final String epcRating;
  final String epcRatingDisplay;
  final List<PropertyImage> images;
  final List<PropertyFeature> features;
  final List<PropertyFloorplan> floorplans;
  final List<PriceHistory> priceHistory;
  final String? primaryImageUrl;
  final String ownerName;
  final bool ownerIsVerified;
  final bool isSaved;
  final double? latitude;
  final double? longitude;
  final String? videoUrl;
  final String? videoThumbnail;
  final int imageCount;
  final int? viewCount;
  final int? messageCount;
  final int? offerCount;
  final String createdAt;
  final String updatedAt;

  Property({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.slug,
    required this.description,
    required this.propertyType,
    required this.propertyTypeDisplay,
    required this.status,
    required this.statusDisplay,
    required this.price,
    required this.addressLine1,
    required this.addressLine2,
    required this.city,
    required this.county,
    required this.postcode,
    required this.bedrooms,
    required this.bathrooms,
    required this.receptionRooms,
    this.squareFeet,
    required this.epcRating,
    required this.epcRatingDisplay,
    required this.images,
    required this.features,
    required this.floorplans,
    required this.priceHistory,
    this.primaryImageUrl,
    required this.ownerName,
    required this.ownerIsVerified,
    required this.isSaved,
    this.latitude,
    this.longitude,
    this.videoUrl,
    this.videoThumbnail,
    required this.imageCount,
    this.viewCount,
    this.messageCount,
    this.offerCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Property.fromJson(Map<String, dynamic> json) {
    return Property(
      id: json['id'],
      ownerId: json['owner'] ?? 0,
      title: json['title'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'] ?? '',
      propertyType: json['property_type'] ?? '',
      propertyTypeDisplay: json['property_type_display'] ?? '',
      status: json['status'] ?? '',
      statusDisplay: json['status_display'] ?? '',
      price: double.tryParse(json['price'].toString()) ?? 0,
      addressLine1: json['address_line_1'] ?? '',
      addressLine2: json['address_line_2'] ?? '',
      city: json['city'] ?? '',
      county: json['county'] ?? '',
      postcode: json['postcode'] ?? '',
      bedrooms: json['bedrooms'] ?? 0,
      bathrooms: json['bathrooms'] ?? 0,
      receptionRooms: json['reception_rooms'] ?? 0,
      squareFeet: json['square_feet'],
      epcRating: json['epc_rating'] ?? '',
      epcRatingDisplay: json['epc_rating_display'] ?? '',
      images: (json['images'] as List? ?? [])
          .map((img) => PropertyImage.fromJson(img))
          .toList(),
      features: (json['feature_list'] as List? ?? [])
          .map((f) => PropertyFeature.fromJson(f))
          .toList(),
      floorplans: (json['floorplans'] as List? ?? [])
          .map((f) => PropertyFloorplan.fromJson(f))
          .toList(),
      priceHistory: (json['price_history'] as List? ?? [])
          .map((p) => PriceHistory.fromJson(p))
          .toList(),
      primaryImageUrl: json['primary_image'],
      ownerName: json['owner_name'] ?? '',
      ownerIsVerified: json['owner_is_verified'] ?? false,
      isSaved: json['is_saved'] ?? false,
      latitude: json['latitude'] != null
          ? double.tryParse(json['latitude'].toString())
          : null,
      longitude: json['longitude'] != null
          ? double.tryParse(json['longitude'].toString())
          : null,
      videoUrl: json['video_url'],
      videoThumbnail: json['video_thumbnail'],
      imageCount: json['image_count'] ?? 0,
      viewCount: json['view_count'],
      messageCount: json['message_count'],
      offerCount: json['offer_count'],
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'property_type': propertyType,
        'status': status,
        'price': price.toString(),
        'address_line_1': addressLine1,
        'address_line_2': addressLine2,
        'city': city,
        'county': county,
        'postcode': postcode,
        'bedrooms': bedrooms,
        'bathrooms': bathrooms,
        'reception_rooms': receptionRooms,
        'square_feet': squareFeet,
        'epc_rating': epcRating,
        'features': features.map((f) => f.id).toList(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (videoUrl != null) 'video_url': videoUrl,
      };

  String get formattedPrice {
    return '\u00A3${price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
  }
}
