class NeighbourhoodInfo {
  final String postcode;
  final Map<String, dynamic>? crimeData;
  final Map<String, dynamic>? postcodeData;
  final List<NearbyAmenity> nearbyAmenities;

  NeighbourhoodInfo({
    required this.postcode,
    this.crimeData,
    this.postcodeData,
    required this.nearbyAmenities,
  });

  factory NeighbourhoodInfo.fromJson(Map<String, dynamic> json) {
    return NeighbourhoodInfo(
      postcode: json['postcode'] ?? '',
      crimeData: json['crime_data'] as Map<String, dynamic>?,
      postcodeData: json['postcode_data'] as Map<String, dynamic>?,
      nearbyAmenities: (json['nearby_amenities'] as List? ?? [])
          .map((a) => NearbyAmenity.fromJson(a))
          .toList(),
    );
  }
}

class NearbyAmenity {
  final String name;
  final String type;
  final double? distance;

  NearbyAmenity({
    required this.name,
    required this.type,
    this.distance,
  });

  factory NearbyAmenity.fromJson(Map<String, dynamic> json) {
    return NearbyAmenity(
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      distance: json['distance'] != null
          ? double.tryParse(json['distance'].toString())
          : null,
    );
  }
}
