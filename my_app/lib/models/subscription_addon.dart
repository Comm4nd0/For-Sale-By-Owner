class SubscriptionAddOn {
  final int id;
  final String name;
  final String slug;
  final String description;
  final double monthlyPrice;
  final List<String> compatibleTierSlugs;

  SubscriptionAddOn({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.monthlyPrice,
    required this.compatibleTierSlugs,
  });

  factory SubscriptionAddOn.fromJson(Map<String, dynamic> json) {
    return SubscriptionAddOn(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'] ?? '',
      monthlyPrice:
          double.tryParse(json['monthly_price']?.toString() ?? '0') ?? 0,
      compatibleTierSlugs: List<String>.from(
        json['compatible_tier_slugs'] ?? [],
      ),
    );
  }
}
