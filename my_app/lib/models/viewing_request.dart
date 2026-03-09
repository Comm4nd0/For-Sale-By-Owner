import 'reply.dart';

class ViewingRequest {
  final int id;
  final int propertyId;
  final String propertyTitle;
  final int? requesterId;
  final String requesterName;
  final String preferredDate;
  final String preferredTime;
  final String? alternativeDate;
  final String? alternativeTime;
  final String message;
  final String name;
  final String email;
  final String phone;
  final String status;
  final String statusDisplay;
  final String sellerNotes;
  final String createdAt;
  final String updatedAt;
  final List<Reply> replies;
  final int replyCount;

  ViewingRequest({
    required this.id,
    required this.propertyId,
    required this.propertyTitle,
    this.requesterId,
    required this.requesterName,
    required this.preferredDate,
    required this.preferredTime,
    this.alternativeDate,
    this.alternativeTime,
    required this.message,
    required this.name,
    required this.email,
    required this.phone,
    required this.status,
    required this.statusDisplay,
    required this.sellerNotes,
    required this.createdAt,
    required this.updatedAt,
    required this.replies,
    required this.replyCount,
  });

  factory ViewingRequest.fromJson(Map<String, dynamic> json) {
    return ViewingRequest(
      id: json['id'],
      propertyId: json['property'] ?? 0,
      propertyTitle: json['property_title'] ?? '',
      requesterId: json['requester'],
      requesterName: json['requester_name'] ?? '',
      preferredDate: json['preferred_date'] ?? '',
      preferredTime: json['preferred_time'] ?? '',
      alternativeDate: json['alternative_date'],
      alternativeTime: json['alternative_time'],
      message: json['message'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      status: json['status'] ?? 'pending',
      statusDisplay: json['status_display'] ?? '',
      sellerNotes: json['seller_notes'] ?? '',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      replies: (json['replies'] as List? ?? [])
          .map((r) => Reply.fromJson(r))
          .toList(),
      replyCount: json['reply_count'] ?? 0,
    );
  }
}
