import 'property_image.dart';

class Property {
  final int id;
  final int ownerId;
  final String title;
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
  final List<PropertyImage> images;
  final String? primaryImageUrl;
  final String ownerName;

  Property({
    required this.id,
    required this.ownerId,
    required this.title,
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
    required this.images,
    this.primaryImageUrl,
    required this.ownerName,
  });

  factory Property.fromJson(Map<String, dynamic> json) {
    return Property(
      id: json['id'],
      ownerId: json['owner'] ?? 0,
      title: json['title'] ?? '',
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
      images: (json['images'] as List? ?? [])
          .map((img) => PropertyImage.fromJson(img))
          .toList(),
      primaryImageUrl: json['primary_image'],
      ownerName: json['owner_name'] ?? '',
    );
  }

  String get formattedPrice {
    return '\u00A3${price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
  }
}
