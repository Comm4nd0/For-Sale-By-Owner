import 'service_category.dart';
import 'service_provider_review.dart';

class ServiceProvider {
  final int id;
  final String businessName;
  final String slug;
  final String description;
  final List<ServiceCategory> categories;
  final String coverageCounties;
  final String coveragePostcodes;
  final String? logoUrl;
  final bool isVerified;
  final String pricingInfo;
  final double? averageRating;
  final int reviewCount;
  final String createdAt;

  // Detail-only fields
  final int? ownerId;
  final String? ownerName;
  final String? contactEmail;
  final String? contactPhone;
  final String? website;
  final int? yearsEstablished;
  final String? status;
  final List<ServiceProviderReview>? reviews;

  ServiceProvider({
    required this.id,
    required this.businessName,
    required this.slug,
    required this.description,
    required this.categories,
    required this.coverageCounties,
    required this.coveragePostcodes,
    this.logoUrl,
    required this.isVerified,
    required this.pricingInfo,
    this.averageRating,
    required this.reviewCount,
    required this.createdAt,
    this.ownerId,
    this.ownerName,
    this.contactEmail,
    this.contactPhone,
    this.website,
    this.yearsEstablished,
    this.status,
    this.reviews,
  });

  factory ServiceProvider.fromJson(Map<String, dynamic> json) {
    return ServiceProvider(
      id: json['id'],
      businessName: json['business_name'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'] ?? '',
      categories: (json['categories'] as List? ?? [])
          .map((c) => ServiceCategory.fromJson(c))
          .toList(),
      coverageCounties: json['coverage_counties'] ?? '',
      coveragePostcodes: json['coverage_postcodes'] ?? '',
      logoUrl: json['logo'],
      isVerified: json['is_verified'] ?? false,
      pricingInfo: json['pricing_info'] ?? '',
      averageRating: json['average_rating'] != null
          ? double.tryParse(json['average_rating'].toString())
          : null,
      reviewCount: json['review_count'] ?? 0,
      createdAt: json['created_at'] ?? '',
      ownerId: json['owner'],
      ownerName: json['owner_name'],
      contactEmail: json['contact_email'],
      contactPhone: json['contact_phone'],
      website: json['website'],
      yearsEstablished: json['years_established'],
      status: json['status'],
      reviews: json['reviews'] != null
          ? (json['reviews'] as List)
              .map((r) => ServiceProviderReview.fromJson(r))
              .toList()
          : null,
    );
  }

  String get coverageDisplay {
    final parts = <String>[];
    if (coverageCounties.isNotEmpty) parts.add(coverageCounties);
    if (coveragePostcodes.isNotEmpty) parts.add(coveragePostcodes);
    return parts.join(' | ');
  }
}
