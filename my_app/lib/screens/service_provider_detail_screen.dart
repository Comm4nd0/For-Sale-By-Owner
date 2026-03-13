import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/api_constants.dart';
import '../constants/app_theme.dart';
import '../widgets/branded_app_bar.dart';
import '../widgets/scroll_to_top_button.dart';
import '../models/service_provider.dart';
import '../models/service_provider_review.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/auto_retry.dart';

class ServiceProviderDetailScreen extends StatefulWidget {
  final int providerId;

  const ServiceProviderDetailScreen({super.key, required this.providerId});

  @override
  State<ServiceProviderDetailScreen> createState() =>
      _ServiceProviderDetailScreenState();
}

class _ServiceProviderDetailScreenState
    extends State<ServiceProviderDetailScreen> with AutoRetryMixin {
  final ScrollController _scrollController = ScrollController();
  ServiceProvider? _provider;
  List<ServiceProviderReview> _reviews = [];
  bool _isLoading = true;
  String? _error;
  int _selectedRating = 0;
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final apiService = context.read<ApiService>();
      final provider = await withRetry(() => apiService.getServiceProvider(widget.providerId));
      final reviews =
          await withRetry(() => apiService.getServiceProviderReviews(widget.providerId));
      if (mounted) {
        setState(() {
          _provider = provider;
          _reviews = reviews;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load service provider';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submitReview() async {
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating')),
      );
      return;
    }
    try {
      final apiService = context.read<ApiService>();
      await apiService.createReview(
        widget.providerId,
        _selectedRating,
        _commentController.text,
      );
      _commentController.clear();
      setState(() => _selectedRating = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted!')),
      );
      _load(); // Refresh
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _deleteReview(int reviewId) async {
    try {
      final apiService = context.read<ApiService>();
      await apiService.deleteReview(widget.providerId, reviewId);
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: BrandedAppBar.build(context: context, showHomeButton: true),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _provider == null) {
      return Scaffold(
        appBar: BrandedAppBar.build(context: context, showHomeButton: true),
        body: Center(child: Text(_error ?? 'Not found')),
      );
    }

    final p = _provider!;
    final authService = context.read<AuthService>();

    return Scaffold(
      floatingActionButton: ScrollToTopButton(scrollController: _scrollController),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.home_outlined),
                tooltip: 'Home',
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: const AppBarLogo(),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.forestDeep, AppTheme.forestMid],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with logo
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: p.logoUrl != null
                            ? Image.network(
                                ApiConstants.fullUrl(p.logoUrl!),
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _logoPlaceholder(80),
                              )
                            : _logoPlaceholder(80),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (p.isVerified) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.forestMist,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.verified,
                                            size: 14,
                                            color: AppTheme.forestMid),
                                        SizedBox(width: 4),
                                        Text('Verified',
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.forestDeep)),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: p.categories.map((c) {
                                return Chip(
                                  label: Text(c.name,
                                      style: const TextStyle(fontSize: 12)),
                                  backgroundColor: AppTheme.forestMist,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 6),
                            if (p.averageRating != null)
                              Row(
                                children: [
                                  ...List.generate(5, (i) {
                                    return Icon(
                                      i < p.averageRating!.round()
                                          ? Icons.star
                                          : Icons.star_border,
                                      size: 18,
                                      color: AppTheme.goldEmber,
                                    );
                                  }),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${p.averageRating!.toStringAsFixed(1)} (${p.reviewCount})',
                                    style: const TextStyle(
                                        fontSize: 13, color: AppTheme.slate),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Description
                  if (p.description.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text('About',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.forestDeep)),
                    const SizedBox(height: 8),
                    Text(p.description,
                        style: const TextStyle(
                            height: 1.5, color: AppTheme.slate)),
                  ],

                  // Coverage
                  if (p.coverageDisplay.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text('Coverage Area',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.forestDeep)),
                    const SizedBox(height: 8),
                    if (p.coverageCounties.isNotEmpty) ...[
                      const Text('Counties:',
                          style: TextStyle(
                              fontSize: 13, color: AppTheme.slate)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: p.coverageCounties
                            .split(',')
                            .map((c) => c.trim())
                            .where((c) => c.isNotEmpty)
                            .map((c) => Chip(
                                  label: Text(c,
                                      style: const TextStyle(fontSize: 12)),
                                  backgroundColor: AppTheme.forestMist,
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ))
                            .toList(),
                      ),
                    ],
                    if (p.coveragePostcodes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('Postcode areas:',
                          style: TextStyle(
                              fontSize: 13, color: AppTheme.slate)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: p.coveragePostcodes
                            .split(',')
                            .map((c) => c.trim())
                            .where((c) => c.isNotEmpty)
                            .map((c) => Chip(
                                  label: Text(c,
                                      style: const TextStyle(fontSize: 12)),
                                  backgroundColor: AppTheme.forestMist,
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ))
                            .toList(),
                      ),
                    ],
                  ],

                  // Pricing
                  if (p.pricingInfo.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text('Pricing',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.forestDeep)),
                    const SizedBox(height: 8),
                    Text(p.pricingInfo,
                        style: const TextStyle(
                            height: 1.5, color: AppTheme.slate)),
                  ],

                  // Contact
                  const SizedBox(height: 24),
                  const Text('Contact',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.forestDeep)),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          if (p.contactEmail != null &&
                              p.contactEmail!.isNotEmpty)
                            _contactRow(
                                Icons.email_outlined, p.contactEmail!),
                          if (p.contactPhone != null &&
                              p.contactPhone!.isNotEmpty)
                            _contactRow(
                                Icons.phone_outlined, p.contactPhone!),
                          if (p.website != null && p.website!.isNotEmpty)
                            _contactRow(
                                Icons.language_outlined, p.website!),
                          if (p.yearsEstablished != null)
                            _contactRow(Icons.calendar_today_outlined,
                                '${p.yearsEstablished} years established'),
                        ],
                      ),
                    ),
                  ),

                  // Reviews
                  const SizedBox(height: 24),
                  Text('Reviews (${_reviews.length})',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.forestDeep)),
                  const SizedBox(height: 12),

                  // Review form
                  if (authService.isAuthenticated) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Leave a Review',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.forestDeep)),
                            const SizedBox(height: 8),
                            Row(
                              children: List.generate(5, (i) {
                                return GestureDetector(
                                  onTap: () => setState(
                                      () => _selectedRating = i + 1),
                                  child: Icon(
                                    i < _selectedRating
                                        ? Icons.star
                                        : Icons.star_border,
                                    size: 32,
                                    color: AppTheme.goldEmber,
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _commentController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                hintText: 'Write a comment (optional)',
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _submitReview,
                                child: const Text('Submit Review'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Review list
                  if (_reviews.isEmpty)
                    const Text('No reviews yet. Be the first!',
                        style: TextStyle(color: AppTheme.stone))
                  else
                    ..._reviews.map((r) => _ReviewCard(
                          review: r,
                          onDelete: authService.isAuthenticated
                              ? () => _deleteReview(r.id)
                              : null,
                        )),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.forestMist,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.business, color: AppTheme.stone, size: size * 0.4),
    );
  }

  Widget _contactRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.forestMid),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text,
                  style:
                      const TextStyle(fontSize: 14, color: AppTheme.slate))),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ServiceProviderReview review;
  final VoidCallback? onDelete;

  const _ReviewCard({required this.review, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(review.reviewerName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.forestDeep)),
                Text(
                  review.createdAt.length >= 10
                      ? review.createdAt.substring(0, 10)
                      : review.createdAt,
                  style:
                      const TextStyle(fontSize: 12, color: AppTheme.stone),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: List.generate(5, (i) {
                return Icon(
                  i < review.rating ? Icons.star : Icons.star_border,
                  size: 16,
                  color: AppTheme.goldEmber,
                );
              }),
            ),
            if (review.comment.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(review.comment,
                  style:
                      const TextStyle(fontSize: 13, color: AppTheme.slate)),
            ],
            if (onDelete != null) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onDelete,
                  child: const Text('Delete',
                      style: TextStyle(color: AppTheme.error, fontSize: 12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
