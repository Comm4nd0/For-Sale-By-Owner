class PropertyFlag {
  final int id;
  final int propertyId;
  final String reason;
  final String reasonDisplay;
  final String? description;
  final String status;
  final String createdAt;

  PropertyFlag({
    required this.id,
    required this.propertyId,
    required this.reason,
    required this.reasonDisplay,
    this.description,
    required this.status,
    required this.createdAt,
  });

  factory PropertyFlag.fromJson(Map<String, dynamic> json) {
    return PropertyFlag(
      id: json['id'],
      propertyId: json['property'] ?? 0,
      reason: json['reason'] ?? '',
      reasonDisplay: json['reason_display'] ?? '',
      description: json['description'],
      status: json['status'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}
