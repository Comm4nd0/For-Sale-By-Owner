class NeighbourhoodReview {
  final int id;
  final int reviewer;
  final String reviewerName;
  final String postcodeArea;
  final int overallRating;
  final int? communityRating;
  final int? noiseRating;
  final int? parkingRating;
  final int? shopsRating;
  final int? safetyRating;
  final int? schoolsRating;
  final int? transportRating;
  final String comment;
  final int? yearsLived;
  final bool isCurrentResident;
  final String createdAt;

  NeighbourhoodReview({
    required this.id,
    required this.reviewer,
    required this.reviewerName,
    required this.postcodeArea,
    required this.overallRating,
    this.communityRating,
    this.noiseRating,
    this.parkingRating,
    this.shopsRating,
    this.safetyRating,
    this.schoolsRating,
    this.transportRating,
    required this.comment,
    this.yearsLived,
    required this.isCurrentResident,
    required this.createdAt,
  });

  factory NeighbourhoodReview.fromJson(Map<String, dynamic> json) {
    return NeighbourhoodReview(
      id: json['id'],
      reviewer: json['reviewer'] ?? 0,
      reviewerName: json['reviewer_name'] ?? '',
      postcodeArea: json['postcode_area'] ?? '',
      overallRating: json['overall_rating'] ?? 0,
      communityRating: json['community_rating'],
      noiseRating: json['noise_rating'],
      parkingRating: json['parking_rating'],
      shopsRating: json['shops_rating'],
      safetyRating: json['safety_rating'],
      schoolsRating: json['schools_rating'],
      transportRating: json['transport_rating'],
      comment: json['comment'] ?? '',
      yearsLived: json['years_lived'],
      isCurrentResident: json['is_current_resident'] ?? true,
      createdAt: json['created_at'] ?? '',
    );
  }
}

class NeighbourhoodSummary {
  final String postcodeArea;
  final int reviewCount;
  final Map<String, double?> ratings;

  NeighbourhoodSummary({
    required this.postcodeArea,
    required this.reviewCount,
    required this.ratings,
  });

  factory NeighbourhoodSummary.fromJson(Map<String, dynamic> json) {
    final ratingsJson = json['ratings'] as Map<String, dynamic>? ?? {};
    return NeighbourhoodSummary(
      postcodeArea: json['postcode_area'] ?? '',
      reviewCount: json['review_count'] ?? 0,
      ratings: ratingsJson.map((k, v) => MapEntry(k, v?.toDouble())),
    );
  }
}
