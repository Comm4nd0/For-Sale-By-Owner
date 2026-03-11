class MortgageCalculation {
  final double propertyPrice;
  final double deposit;
  final double loanAmount;
  final double interestRate;
  final int termYears;
  final double monthlyPayment;
  final double totalRepayment;
  final double totalInterest;
  final double stampDuty;

  MortgageCalculation({
    required this.propertyPrice,
    required this.deposit,
    required this.loanAmount,
    required this.interestRate,
    required this.termYears,
    required this.monthlyPayment,
    required this.totalRepayment,
    required this.totalInterest,
    required this.stampDuty,
  });

  factory MortgageCalculation.fromJson(Map<String, dynamic> json) {
    return MortgageCalculation(
      propertyPrice: _toDouble(json['property_price']),
      deposit: _toDouble(json['deposit']),
      loanAmount: _toDouble(json['loan_amount']),
      interestRate: _toDouble(json['interest_rate']),
      termYears: json['term_years'] ?? 25,
      monthlyPayment: _toDouble(json['monthly_payment']),
      totalRepayment: _toDouble(json['total_repayment']),
      totalInterest: _toDouble(json['total_interest']),
      stampDuty: _toDouble(json['stamp_duty']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}
