class SalePromptDraft {
  final int id;
  final String generatedAt;
  final String recipientOwner;
  final String recipientOwnerDisplay;
  final String level;
  final String levelDisplay;
  final String subject;
  final String bodyText;
  final bool sentMarker;
  final String? sentAt;

  SalePromptDraft({
    required this.id,
    required this.generatedAt,
    required this.recipientOwner,
    this.recipientOwnerDisplay = '',
    required this.level,
    this.levelDisplay = '',
    required this.subject,
    required this.bodyText,
    this.sentMarker = false,
    this.sentAt,
  });

  factory SalePromptDraft.fromJson(Map<String, dynamic> json) {
    return SalePromptDraft(
      id: json['id'],
      generatedAt: json['generated_at'] ?? '',
      recipientOwner: json['recipient_owner'] ?? '',
      recipientOwnerDisplay: json['recipient_owner_display'] ?? '',
      level: json['level'] ?? '',
      levelDisplay: json['level_display'] ?? '',
      subject: json['subject'] ?? '',
      bodyText: json['body_text'] ?? '',
      sentMarker: json['sent_marker'] ?? false,
      sentAt: json['sent_at'],
    );
  }
}
