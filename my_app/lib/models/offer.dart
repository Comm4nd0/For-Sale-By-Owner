class Offer {
  final int id;
  final int propertyId;
  final String propertyTitle;
  final int buyerId;
  final String buyerName;
  final double amount;
  final String status;
  final String statusDisplay;
  final double? counterAmount;
  final bool isCashBuyer;
  final bool isChainFree;
  final bool mortgageAgreed;
  final String? message;
  final String? sellerResponse;
  final String? expiresAt;
  final String createdAt;
  final String updatedAt;

  Offer({
    required this.id,
    required this.propertyId,
    required this.propertyTitle,
    required this.buyerId,
    required this.buyerName,
    required this.amount,
    required this.status,
    required this.statusDisplay,
    this.counterAmount,
    required this.isCashBuyer,
    required this.isChainFree,
    required this.mortgageAgreed,
    this.message,
    this.sellerResponse,
    this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Offer.fromJson(Map<String, dynamic> json) {
    return Offer(
      id: json['id'],
      propertyId: json['property'] ?? 0,
      propertyTitle: json['property_title'] ?? '',
      buyerId: json['buyer'] ?? 0,
      buyerName: json['buyer_name'] ?? '',
      amount: double.tryParse(json['amount'].toString()) ?? 0,
      status: json['status'] ?? '',
      statusDisplay: json['status_display'] ?? '',
      counterAmount: json['counter_amount'] != null
          ? double.tryParse(json['counter_amount'].toString())
          : null,
      isCashBuyer: json['is_cash_buyer'] ?? false,
      isChainFree: json['is_chain_free'] ?? false,
      mortgageAgreed: json['mortgage_agreed'] ?? false,
      message: json['message'],
      sellerResponse: json['seller_response'],
      expiresAt: json['expires_at'],
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  String get formattedAmount {
    return '\u00A3${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
  }
}
