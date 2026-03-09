class ServiceProviderReview {
  final int id;
  final int providerId;
  final int reviewerId;
  final String reviewerName;
  final int rating;
  final String comment;
  final String createdAt;

  ServiceProviderReview({
    required this.id,
    required this.providerId,
    required this.reviewerId,
    required this.reviewerName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory ServiceProviderReview.fromJson(Map<String, dynamic> json) {
    return ServiceProviderReview(
      id: json['id'],
      providerId: json['provider'] ?? 0,
      reviewerId: json['reviewer'] ?? 0,
      reviewerName: json['reviewer_name'] ?? 'User',
      rating: json['rating'] ?? 0,
      comment: json['comment'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}
