class ChatRoom {
  final int id;
  final int propertyId;
  final String propertyTitle;
  final String? propertyImage;
  final int buyerId;
  final String buyerName;
  final int sellerId;
  final String sellerName;
  final String? lastMessage;
  final String? lastMessageAt;
  final int unreadCount;
  final String createdAt;

  ChatRoom({
    required this.id,
    required this.propertyId,
    required this.propertyTitle,
    this.propertyImage,
    required this.buyerId,
    required this.buyerName,
    required this.sellerId,
    required this.sellerName,
    this.lastMessage,
    this.lastMessageAt,
    required this.unreadCount,
    required this.createdAt,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['id'],
      propertyId: json['property'] ?? 0,
      propertyTitle: json['property_title'] ?? '',
      propertyImage: json['property_image'],
      buyerId: json['buyer'] ?? 0,
      buyerName: json['buyer_name'] ?? '',
      sellerId: json['seller'] ?? 0,
      sellerName: json['seller_name'] ?? '',
      lastMessage: json['last_message'],
      lastMessageAt: json['last_message_at'],
      unreadCount: json['unread_count'] ?? 0,
      createdAt: json['created_at'] ?? '',
    );
  }
}
