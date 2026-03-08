class PropertyImage {
  final int id;
  final String imageUrl;
  final int order;
  final bool isPrimary;
  final String caption;

  PropertyImage({
    required this.id,
    required this.imageUrl,
    required this.order,
    required this.isPrimary,
    required this.caption,
  });

  factory PropertyImage.fromJson(Map<String, dynamic> json) {
    return PropertyImage(
      id: json['id'],
      imageUrl: json['image'] ?? '',
      order: json['order'] ?? 0,
      isPrimary: json['is_primary'] ?? false,
      caption: json['caption'] ?? '',
    );
  }
}
