class SavedSearch {
  final int id;
  final String name;
  final String location;
  final String propertyType;
  final double? minPrice;
  final double? maxPrice;
  final int? minBedrooms;
  final int? minBathrooms;
  final String epcRating;
  final bool emailAlerts;
  final String alertFrequency;
  final String createdAt;

  SavedSearch({
    required this.id,
    required this.name,
    required this.location,
    required this.propertyType,
    this.minPrice,
    this.maxPrice,
    this.minBedrooms,
    this.minBathrooms,
    required this.epcRating,
    required this.emailAlerts,
    required this.alertFrequency,
    required this.createdAt,
  });

  factory SavedSearch.fromJson(Map<String, dynamic> json) {
    return SavedSearch(
      id: json['id'],
      name: json['name'] ?? '',
      location: json['location'] ?? '',
      propertyType: json['property_type'] ?? '',
      minPrice: json['min_price'] != null
          ? double.tryParse(json['min_price'].toString())
          : null,
      maxPrice: json['max_price'] != null
          ? double.tryParse(json['max_price'].toString())
          : null,
      minBedrooms: json['min_bedrooms'],
      minBathrooms: json['min_bathrooms'],
      epcRating: json['epc_rating'] ?? '',
      emailAlerts: json['email_alerts'] ?? true,
      alertFrequency: json['alert_frequency'] ?? 'instant',
      createdAt: json['created_at'] ?? '',
    );
  }
}
