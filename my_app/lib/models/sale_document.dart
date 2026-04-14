class SaleDocument {
  final int id;
  final String title;
  final String category;
  final String categoryDisplay;
  final String source;
  final String sourceDisplay;
  final String requiredTier;
  final String requiredTierDisplay;
  final String status;
  final String statusDisplay;
  final String? fileUrl;
  final String? uploadedAt;
  final String? expiryDate;
  final String naReason;
  final String helperText;
  final bool isSeed;

  SaleDocument({
    required this.id,
    required this.title,
    required this.category,
    this.categoryDisplay = '',
    required this.source,
    this.sourceDisplay = '',
    required this.requiredTier,
    this.requiredTierDisplay = '',
    required this.status,
    this.statusDisplay = '',
    this.fileUrl,
    this.uploadedAt,
    this.expiryDate,
    this.naReason = '',
    this.helperText = '',
    this.isSeed = true,
  });

  factory SaleDocument.fromJson(Map<String, dynamic> json) {
    return SaleDocument(
      id: json['id'],
      title: json['title'] ?? '',
      category: json['category'] ?? '',
      categoryDisplay: json['category_display'] ?? '',
      source: json['source'] ?? '',
      sourceDisplay: json['source_display'] ?? '',
      requiredTier: json['required_tier'] ?? '',
      requiredTierDisplay: json['required_tier_display'] ?? '',
      status: json['status'] ?? 'missing',
      statusDisplay: json['status_display'] ?? '',
      fileUrl: json['file_url'],
      uploadedAt: json['uploaded_at'],
      expiryDate: json['expiry_date'],
      naReason: json['na_reason'] ?? '',
      helperText: json['helper_text'] ?? '',
      isSeed: json['is_seed'] ?? true,
    );
  }

  bool get hasFile => fileUrl != null && fileUrl!.isNotEmpty;
  bool get isMissing => status == 'missing';
  bool get isRequired => requiredTier == 'always';
}

class DocumentChecklistItem {
  final int id;
  final String title;
  final String category;
  final String categoryDisplay;
  final String requiredTier;
  final String requiredTierDisplay;
  final String status;
  final String statusDisplay;
  final String helperText;
  final bool hasFile;
  final String source;
  final String sourceDisplay;

  DocumentChecklistItem({
    required this.id,
    required this.title,
    required this.category,
    this.categoryDisplay = '',
    required this.requiredTier,
    this.requiredTierDisplay = '',
    required this.status,
    this.statusDisplay = '',
    this.helperText = '',
    this.hasFile = false,
    this.source = '',
    this.sourceDisplay = '',
  });

  factory DocumentChecklistItem.fromJson(Map<String, dynamic> json) {
    return DocumentChecklistItem(
      id: json['id'],
      title: json['title'] ?? '',
      category: json['category'] ?? '',
      categoryDisplay: json['category_display'] ?? '',
      requiredTier: json['required_tier'] ?? '',
      requiredTierDisplay: json['required_tier_display'] ?? '',
      status: json['status'] ?? 'missing',
      statusDisplay: json['status_display'] ?? '',
      helperText: json['helper_text'] ?? '',
      hasFile: json['has_file'] ?? false,
      source: json['source'] ?? '',
      sourceDisplay: json['source_display'] ?? '',
    );
  }
}
