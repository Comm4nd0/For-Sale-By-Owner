class BoardOrder {
  final int id;
  final int property;
  final String propertyTitle;
  final int user;
  final String boardType;
  final String boardTypeDisplay;
  final String status;
  final String statusDisplay;
  final String deliveryAddress;
  final double price;
  final String trackingNumber;
  final String notes;
  final String createdAt;

  BoardOrder({
    required this.id,
    required this.property,
    required this.propertyTitle,
    required this.user,
    required this.boardType,
    required this.boardTypeDisplay,
    required this.status,
    required this.statusDisplay,
    required this.deliveryAddress,
    required this.price,
    required this.trackingNumber,
    required this.notes,
    required this.createdAt,
  });

  factory BoardOrder.fromJson(Map<String, dynamic> json) {
    return BoardOrder(
      id: json['id'],
      property: json['property'] ?? 0,
      propertyTitle: json['property_title'] ?? '',
      user: json['user'] ?? 0,
      boardType: json['board_type'] ?? 'standard',
      boardTypeDisplay: json['board_type_display'] ?? '',
      status: json['status'] ?? 'pending',
      statusDisplay: json['status_display'] ?? '',
      deliveryAddress: json['delivery_address'] ?? '',
      price: double.tryParse('${json['price']}') ?? 0,
      trackingNumber: json['tracking_number'] ?? '',
      notes: json['notes'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}

class BoardPricingOption {
  final String type;
  final String name;
  final double price;
  final String description;

  BoardPricingOption({
    required this.type,
    required this.name,
    required this.price,
    required this.description,
  });

  factory BoardPricingOption.fromJson(Map<String, dynamic> json) {
    return BoardPricingOption(
      type: json['type'] ?? '',
      name: json['name'] ?? '',
      price: double.tryParse('${json['price']}') ?? 0,
      description: json['description'] ?? '',
    );
  }
}
