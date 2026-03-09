class Reply {
  final int id;
  final int? enquiryId;
  final int? viewingRequestId;
  final int authorId;
  final String authorName;
  final String message;
  final String createdAt;

  Reply({
    required this.id,
    this.enquiryId,
    this.viewingRequestId,
    required this.authorId,
    required this.authorName,
    required this.message,
    required this.createdAt,
  });

  factory Reply.fromJson(Map<String, dynamic> json) {
    return Reply(
      id: json['id'],
      enquiryId: json['enquiry'],
      viewingRequestId: json['viewing_request'],
      authorId: json['author'] ?? 0,
      authorName: json['author_name'] ?? '',
      message: json['message'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}
