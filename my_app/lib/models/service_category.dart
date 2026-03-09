class ServiceCategory {
  final int id;
  final String name;
  final String slug;
  final String icon;
  final String description;
  final int? providerCount;

  ServiceCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.icon,
    required this.description,
    this.providerCount,
  });

  factory ServiceCategory.fromJson(Map<String, dynamic> json) {
    return ServiceCategory(
      id: json['id'],
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      icon: json['icon'] ?? '',
      description: json['description'] ?? '',
      providerCount: json['provider_count'],
    );
  }
}
