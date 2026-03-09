class SubscriptionTier {
  final int id;
  final String name;
  final String slug;
  final String tagline;
  final String ctaText;
  final String badgeText;
  final double monthlyPrice;
  final double annualPrice;
  final String currency;
  final Map<String, dynamic> limits;
  final Map<String, bool> features;
  final int displayOrder;

  SubscriptionTier({
    required this.id,
    required this.name,
    required this.slug,
    required this.tagline,
    required this.ctaText,
    required this.badgeText,
    required this.monthlyPrice,
    required this.annualPrice,
    required this.currency,
    required this.limits,
    required this.features,
    required this.displayOrder,
  });

  factory SubscriptionTier.fromJson(Map<String, dynamic> json) {
    return SubscriptionTier(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      tagline: json['tagline'] ?? '',
      ctaText: json['cta_text'] ?? '',
      badgeText: json['badge_text'] ?? '',
      monthlyPrice:
          double.tryParse(json['monthly_price']?.toString() ?? '0') ?? 0,
      annualPrice:
          double.tryParse(json['annual_price']?.toString() ?? '0') ?? 0,
      currency: json['currency'] ?? 'GBP',
      limits: Map<String, dynamic>.from(json['limits'] ?? {}),
      features: Map<String, bool>.from(
        (json['features'] as Map? ?? {})
            .map((k, v) => MapEntry(k.toString(), v == true)),
      ),
      displayOrder: json['display_order'] ?? 0,
    );
  }

  bool get isFree => monthlyPrice == 0;

  int get maxCategories => limits['max_service_categories'] ?? 1;
  int get maxLocations => limits['max_locations'] ?? 1;
  int get maxPhotos => limits['max_photos'] ?? 0;
  bool get allowsLogo => limits['allow_logo'] ?? false;

  bool hasFeature(String key) => features[key] ?? false;
}
