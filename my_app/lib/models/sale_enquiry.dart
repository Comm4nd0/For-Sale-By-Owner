class SaleEnquiry {
  final int id;
  final String raisedDate;
  final String raisedBy;
  final String question;
  final String currentOwner;
  final String currentOwnerDisplay;
  final String status;
  final String statusDisplay;
  final String response;
  final String? responseDate;

  SaleEnquiry({
    required this.id,
    required this.raisedDate,
    required this.raisedBy,
    required this.question,
    required this.currentOwner,
    this.currentOwnerDisplay = '',
    required this.status,
    this.statusDisplay = '',
    this.response = '',
    this.responseDate,
  });

  factory SaleEnquiry.fromJson(Map<String, dynamic> json) {
    return SaleEnquiry(
      id: json['id'],
      raisedDate: json['raised_date'] ?? '',
      raisedBy: json['raised_by'] ?? '',
      question: json['question'] ?? '',
      currentOwner: json['current_owner'] ?? '',
      currentOwnerDisplay: json['current_owner_display'] ?? '',
      status: json['status'] ?? 'open',
      statusDisplay: json['status_display'] ?? '',
      response: json['response'] ?? '',
      responseDate: json['response_date'],
    );
  }
}
