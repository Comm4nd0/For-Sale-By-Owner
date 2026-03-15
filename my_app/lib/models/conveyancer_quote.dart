class ConveyancerQuote {
  final int id;
  final int request;
  final int provider;
  final String providerName;
  final double legalFee;
  final double disbursements;
  final double total;
  final int? estimatedWeeks;
  final String notes;
  final bool isAccepted;
  final String createdAt;

  ConveyancerQuote({
    required this.id,
    required this.request,
    required this.provider,
    required this.providerName,
    required this.legalFee,
    required this.disbursements,
    required this.total,
    this.estimatedWeeks,
    required this.notes,
    required this.isAccepted,
    required this.createdAt,
  });

  factory ConveyancerQuote.fromJson(Map<String, dynamic> json) {
    return ConveyancerQuote(
      id: json['id'],
      request: json['request'] ?? 0,
      provider: json['provider'] ?? 0,
      providerName: json['provider_name'] ?? '',
      legalFee: double.tryParse('${json['legal_fee']}') ?? 0,
      disbursements: double.tryParse('${json['disbursements']}') ?? 0,
      total: double.tryParse('${json['total']}') ?? 0,
      estimatedWeeks: json['estimated_weeks'],
      notes: json['notes'] ?? '',
      isAccepted: json['is_accepted'] ?? false,
      createdAt: json['created_at'] ?? '',
    );
  }
}

class ConveyancerQuoteRequest {
  final int id;
  final int property;
  final String propertyTitle;
  final int requester;
  final String requesterName;
  final String transactionType;
  final String status;
  final String additionalInfo;
  final List<ConveyancerQuote> quotes;
  final String createdAt;

  ConveyancerQuoteRequest({
    required this.id,
    required this.property,
    required this.propertyTitle,
    required this.requester,
    required this.requesterName,
    required this.transactionType,
    required this.status,
    required this.additionalInfo,
    required this.quotes,
    required this.createdAt,
  });

  factory ConveyancerQuoteRequest.fromJson(Map<String, dynamic> json) {
    return ConveyancerQuoteRequest(
      id: json['id'],
      property: json['property'] ?? 0,
      propertyTitle: json['property_title'] ?? '',
      requester: json['requester'] ?? 0,
      requesterName: json['requester_name'] ?? '',
      transactionType: json['transaction_type'] ?? 'buying',
      status: json['status'] ?? 'open',
      additionalInfo: json['additional_info'] ?? '',
      quotes: (json['quotes'] as List? ?? [])
          .map((q) => ConveyancerQuote.fromJson(q))
          .toList(),
      createdAt: json['created_at'] ?? '',
    );
  }
}
