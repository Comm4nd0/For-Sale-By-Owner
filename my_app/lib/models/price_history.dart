class PriceHistory {
  final int id;
  final double price;
  final String changedAt;

  PriceHistory({
    required this.id,
    required this.price,
    required this.changedAt,
  });

  factory PriceHistory.fromJson(Map<String, dynamic> json) {
    return PriceHistory(
      id: json['id'],
      price: double.tryParse(json['price'].toString()) ?? 0,
      changedAt: json['changed_at'] ?? '',
    );
  }
}
