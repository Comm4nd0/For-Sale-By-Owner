import 'reply.dart';

class Enquiry {
  final int id;
  final int propertyId;
  final String propertyTitle;
  final int? senderId;
  final String senderName;
  final String name;
  final String email;
  final String phone;
  final String message;
  final bool isRead;
  final String createdAt;
  final List<Reply> replies;
  final int replyCount;

  Enquiry({
    required this.id,
    required this.propertyId,
    required this.propertyTitle,
    this.senderId,
    required this.senderName,
    required this.name,
    required this.email,
    required this.phone,
    required this.message,
    required this.isRead,
    required this.createdAt,
    required this.replies,
    required this.replyCount,
  });

  factory Enquiry.fromJson(Map<String, dynamic> json) {
    return Enquiry(
      id: json['id'],
      propertyId: json['property'] ?? 0,
      propertyTitle: json['property_title'] ?? '',
      senderId: json['sender'],
      senderName: json['sender_name'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      message: json['message'] ?? '',
      isRead: json['is_read'] ?? false,
      createdAt: json['created_at'] ?? '',
      replies: (json['replies'] as List? ?? [])
          .map((r) => Reply.fromJson(r))
          .toList(),
      replyCount: json['reply_count'] ?? 0,
    );
  }
}
