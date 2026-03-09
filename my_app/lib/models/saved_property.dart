import 'property.dart';

class SavedProperty {
  final int id;
  final int propertyId;
  final Property? propertyDetail;
  final String createdAt;

  SavedProperty({
    required this.id,
    required this.propertyId,
    this.propertyDetail,
    required this.createdAt,
  });

  factory SavedProperty.fromJson(Map<String, dynamic> json) {
    return SavedProperty(
      id: json['id'],
      propertyId: json['property'] ?? 0,
      propertyDetail: json['property_detail'] != null
          ? Property.fromJson(json['property_detail'])
          : null,
      createdAt: json['created_at'] ?? '',
    );
  }
}
