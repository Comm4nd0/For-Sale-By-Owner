class ChatMessage {
  final int id;
  final int roomId;
  final int senderId;
  final String senderName;
  final String content;
  final bool isRead;
  final String createdAt;

  ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.isRead,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? 0,
      roomId: json['room'] ?? 0,
      senderId: json['sender'] ?? 0,
      senderName: json['sender_name'] ?? '',
      content: json['message'] ?? '',
      isRead: json['is_read'] ?? false,
      createdAt: json['created_at'] ?? '',
    );
  }
}
