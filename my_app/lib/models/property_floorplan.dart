class PropertyFloorplan {
  final int id;
  final String fileUrl;
  final String title;
  final int order;
  final String uploadedAt;

  PropertyFloorplan({
    required this.id,
    required this.fileUrl,
    required this.title,
    required this.order,
    required this.uploadedAt,
  });

  factory PropertyFloorplan.fromJson(Map<String, dynamic> json) {
    return PropertyFloorplan(
      id: json['id'],
      fileUrl: json['file'] ?? '',
      title: json['title'] ?? 'Floorplan',
      order: json['order'] ?? 0,
      uploadedAt: json['uploaded_at'] ?? '',
    );
  }
}
