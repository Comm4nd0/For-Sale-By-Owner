class BuyerVerification {
  final int id;
  final int user;
  final String verificationType;
  final String verificationTypeDisplay;
  final String? document;
  final String status;
  final bool isValid;
  final String? expiresAt;
  final String createdAt;
  final String? reviewedAt;

  BuyerVerification({
    required this.id,
    required this.user,
    required this.verificationType,
    required this.verificationTypeDisplay,
    this.document,
    required this.status,
    required this.isValid,
    this.expiresAt,
    required this.createdAt,
    this.reviewedAt,
  });

  factory BuyerVerification.fromJson(Map<String, dynamic> json) {
    return BuyerVerification(
      id: json['id'],
      user: json['user'],
      verificationType: json['verification_type'] ?? '',
      verificationTypeDisplay: json['verification_type_display'] ?? '',
      document: json['document'],
      status: json['status'] ?? 'pending',
      isValid: json['is_valid'] ?? false,
      expiresAt: json['expires_at'],
      createdAt: json['created_at'] ?? '',
      reviewedAt: json['reviewed_at'],
    );
  }
}
