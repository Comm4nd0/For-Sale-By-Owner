class PropertyFeature {
  final int id;
  final String name;
  final String icon;

  PropertyFeature({required this.id, required this.name, required this.icon});

  factory PropertyFeature.fromJson(Map<String, dynamic> json) {
    return PropertyFeature(
      id: json['id'],
      name: json['name'] ?? '',
      icon: json['icon'] ?? '',
    );
  }
}
