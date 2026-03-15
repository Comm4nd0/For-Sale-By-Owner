class BuyerProfile {
  final int id;
  final int user;
  final double? maxBudget;
  final double? depositAmount;
  final bool mortgageApproved;
  final double? mortgageAmount;
  final bool isFirstTimeBuyer;
  final bool isCashBuyer;
  final bool hasPropertyToSell;
  final String preferredAreas;

  BuyerProfile({
    required this.id,
    required this.user,
    this.maxBudget,
    this.depositAmount,
    required this.mortgageApproved,
    this.mortgageAmount,
    required this.isFirstTimeBuyer,
    required this.isCashBuyer,
    required this.hasPropertyToSell,
    required this.preferredAreas,
  });

  factory BuyerProfile.fromJson(Map<String, dynamic> json) {
    return BuyerProfile(
      id: json['id'] ?? 0,
      user: json['user'] ?? 0,
      maxBudget: json['max_budget'] != null
          ? double.tryParse('${json['max_budget']}')
          : null,
      depositAmount: json['deposit_amount'] != null
          ? double.tryParse('${json['deposit_amount']}')
          : null,
      mortgageApproved: json['mortgage_approved'] ?? false,
      mortgageAmount: json['mortgage_amount'] != null
          ? double.tryParse('${json['mortgage_amount']}')
          : null,
      isFirstTimeBuyer: json['is_first_time_buyer'] ?? false,
      isCashBuyer: json['is_cash_buyer'] ?? false,
      hasPropertyToSell: json['has_property_to_sell'] ?? false,
      preferredAreas: json['preferred_areas'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'max_budget': maxBudget,
      'deposit_amount': depositAmount,
      'mortgage_approved': mortgageApproved,
      'mortgage_amount': mortgageAmount,
      'is_first_time_buyer': isFirstTimeBuyer,
      'is_cash_buyer': isCashBuyer,
      'has_property_to_sell': hasPropertyToSell,
      'preferred_areas': preferredAreas,
    };
  }
}
