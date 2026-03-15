class ConveyancingStep {
  final int id;
  final String stepType;
  final String stepTypeDisplay;
  final String status;
  final String statusDisplay;
  final String notes;
  final String? completedAt;
  final int order;

  ConveyancingStep({
    required this.id,
    required this.stepType,
    required this.stepTypeDisplay,
    required this.status,
    required this.statusDisplay,
    required this.notes,
    this.completedAt,
    required this.order,
  });

  factory ConveyancingStep.fromJson(Map<String, dynamic> json) {
    return ConveyancingStep(
      id: json['id'],
      stepType: json['step_type'] ?? '',
      stepTypeDisplay: json['step_type_display'] ?? '',
      status: json['status'] ?? 'pending',
      statusDisplay: json['status_display'] ?? '',
      notes: json['notes'] ?? '',
      completedAt: json['completed_at'],
      order: json['order'] ?? 0,
    );
  }
}

class ConveyancingCase {
  final int id;
  final int property;
  final String propertyTitle;
  final int offer;
  final int buyer;
  final String buyerName;
  final int seller;
  final String sellerName;
  final String status;
  final String buyerSolicitor;
  final String sellerSolicitor;
  final String? targetCompletionDate;
  final String notes;
  final List<ConveyancingStep> steps;
  final int progressPercentage;
  final String createdAt;

  ConveyancingCase({
    required this.id,
    required this.property,
    required this.propertyTitle,
    required this.offer,
    required this.buyer,
    required this.buyerName,
    required this.seller,
    required this.sellerName,
    required this.status,
    required this.buyerSolicitor,
    required this.sellerSolicitor,
    this.targetCompletionDate,
    required this.notes,
    required this.steps,
    required this.progressPercentage,
    required this.createdAt,
  });

  factory ConveyancingCase.fromJson(Map<String, dynamic> json) {
    return ConveyancingCase(
      id: json['id'],
      property: json['property'] ?? 0,
      propertyTitle: json['property_title'] ?? '',
      offer: json['offer'] ?? 0,
      buyer: json['buyer'] ?? 0,
      buyerName: json['buyer_name'] ?? '',
      seller: json['seller'] ?? 0,
      sellerName: json['seller_name'] ?? '',
      status: json['status'] ?? 'active',
      buyerSolicitor: json['buyer_solicitor'] ?? '',
      sellerSolicitor: json['seller_solicitor'] ?? '',
      targetCompletionDate: json['target_completion_date'],
      notes: json['notes'] ?? '',
      steps: (json['steps'] as List? ?? [])
          .map((s) => ConveyancingStep.fromJson(s))
          .toList(),
      progressPercentage: json['progress_percentage'] ?? 0,
      createdAt: json['created_at'] ?? '',
    );
  }
}
