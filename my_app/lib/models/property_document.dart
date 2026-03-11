class PropertyDocument {
  final int id;
  final int propertyId;
  final String documentType;
  final String documentTypeDisplay;
  final String title;
  final String fileUrl;
  final bool isPublic;
  final String uploadedAt;

  PropertyDocument({
    required this.id,
    required this.propertyId,
    required this.documentType,
    required this.documentTypeDisplay,
    required this.title,
    required this.fileUrl,
    required this.isPublic,
    required this.uploadedAt,
  });

  factory PropertyDocument.fromJson(Map<String, dynamic> json) {
    return PropertyDocument(
      id: json['id'],
      propertyId: json['property'] ?? 0,
      documentType: json['document_type'] ?? '',
      documentTypeDisplay: json['document_type_display'] ?? '',
      title: json['title'] ?? '',
      fileUrl: json['file'] ?? '',
      isPublic: json['is_public'] ?? false,
      uploadedAt: json['uploaded_at'] ?? '',
    );
  }
}
