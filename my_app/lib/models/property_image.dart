class PropertyImage {
  final int id;
  final String imageUrl;
  final String? thumbnailUrl;
  final int order;
  final bool isPrimary;
  final String caption;

  PropertyImage({
    required this.id,
    required this.imageUrl,
    this.thumbnailUrl,
    required this.order,
    required this.isPrimary,
    required this.caption,
  });

  factory PropertyImage.fromJson(Map<String, dynamic> json) {
    return PropertyImage(
      id: json['id'],
      imageUrl: json['image'] ?? '',
      thumbnailUrl: json['thumbnail'],
      order: json['order'] ?? 0,
      isPrimary: json['is_primary'] ?? false,
      caption: json['caption'] ?? '',
    );
  }
}
