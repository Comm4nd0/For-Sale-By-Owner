import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/api_constants.dart';
import '../constants/app_theme.dart';
import '../models/service_category.dart';
import '../models/service_provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'service_provider_detail_screen.dart';
import 'service_provider_form_screen.dart';
import 'pricing_screen.dart';
import '../widgets/tier_badge.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final TextEditingController _locationController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ServiceCategory> _categories = [];
  List<ServiceProvider> _providers = [];
  String? _selectedCategory;
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  int _totalCount = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadProviders();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _locationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _loadCategories() async {
    try {
      final apiService = context.read<ApiService>();
      final cats = await apiService.getServiceCategories();
      if (mounted) setState(() => _categories = cats);
    } catch (_) {}
  }

  Future<void> _loadProviders() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _page = 1;
      _providers = [];
      _hasMore = true;
      _error = null;
    });

    try {
      final apiService = context.read<ApiService>();
      final result = await apiService.getServiceProviders(
        category: _selectedCategory,
        location: _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : null,
        page: 1,
      );
      if (mounted) {
        setState(() {
          _providers = result.results;
          _totalCount = result.count;
          _hasMore = result.next != null;
          _page = 2;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasMore = false;
          _error = 'Unable to load service providers. Pull down to retry.';
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    try {
      final apiService = context.read<ApiService>();
      final result = await apiService.getServiceProviders(
        category: _selectedCategory,
        location: _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : null,
        page: _page,
      );
      if (mounted) {
        setState(() {
          _providers.addAll(result.results);
          _hasMore = result.next != null;
          _page++;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _selectCategory(String? slug) {
    setState(() => _selectedCategory = _selectedCategory == slug ? null : slug);
    _loadProviders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Services'),
        actions: [
          IconButton(
            icon: const Icon(Icons.monetization_on_outlined),
            tooltip: 'Pricing',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PricingScreen()),
            ),
          ),
          if (context.read<AuthService>().isAuthenticated)
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ServiceProviderFormScreen()),
              ),
              child: const Text('Register',
                  style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: AppTheme.forestDeep,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _locationController,
                    style: const TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Town, county or postcode...',
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.location_on_outlined,
                          color: AppTheme.stone),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    onSubmitted: (_) => _loadProviders(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _loadProviders,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.forestMid,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  child: const Icon(Icons.search, color: Colors.white),
                ),
              ],
            ),
          ),
          // Category chips
          if (_categories.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategory == cat.slug;
                  return FilterChip(
                    label: Text(cat.name),
                    selected: isSelected,
                    onSelected: (_) => _selectCategory(cat.slug),
                    selectedColor: AppTheme.forestMid,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.forestDeep,
                      fontSize: 12,
                    ),
                    backgroundColor: AppTheme.forestMist,
                    checkmarkColor: Colors.white,
                  );
                },
              ),
            ),
          // Results
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadProviders,
              child: _error != null && _providers.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 100),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cloud_off,
                                  size: 48, color: AppTheme.stone),
                              const SizedBox(height: 12),
                              Text(_error!,
                                  style: const TextStyle(
                                      fontSize: 14, color: AppTheme.slate),
                                  textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _loadProviders,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.forestMid,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : _providers.isEmpty && !_isLoading
                      ? ListView(
                          children: [
                            const SizedBox(height: 100),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.search_off,
                                      size: 48, color: AppTheme.stone),
                                  const SizedBox(height: 12),
                                  const Text('No service providers found',
                                      style: TextStyle(
                                          fontSize: 16, color: AppTheme.slate)),
                                  const SizedBox(height: 4),
                                  const Text(
                                      'Try a different location or category',
                                      style: TextStyle(
                                          fontSize: 14, color: AppTheme.stone)),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount:
                              _providers.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _providers.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                    child: CircularProgressIndicator()),
                              );
                            }
                            return _ProviderCard(
                                provider: _providers[index]);
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final ServiceProvider provider;

  const _ProviderCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ServiceProviderDetailScreen(providerId: provider.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: provider.logoUrl != null
                    ? Image.network(
                        ApiConstants.fullUrl(provider.logoUrl!),
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _logoPlaceholder(),
                      )
                    : _logoPlaceholder(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            provider.businessName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: AppTheme.forestDeep,
                            ),
                          ),
                        ),
                        if (provider.isPaidTier)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: TierBadge(
                              tierSlug: provider.tierSlug,
                              tierName: provider.tierName,
                            ),
                          ),
                        if (provider.isVerified)
                          const Icon(Icons.verified,
                              size: 16, color: AppTheme.forestMid),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: provider.categories.take(3).map((c) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.forestMist,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(c.name,
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.forestDeep)),
                        );
                      }).toList(),
                    ),
                    if (provider.coverageDisplay.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 14, color: AppTheme.stone),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              provider.coverageDisplay,
                              style: const TextStyle(
                                  fontSize: 12, color: AppTheme.slate),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (provider.averageRating != null) ...[
                          const Icon(Icons.star,
                              size: 14, color: AppTheme.goldEmber),
                          const SizedBox(width: 2),
                          Text(
                            provider.averageRating!.toStringAsFixed(1),
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.goldEmber),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          '${provider.reviewCount} review${provider.reviewCount == 1 ? '' : 's'}',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.stone),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logoPlaceholder() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppTheme.forestMist,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.business, color: AppTheme.stone, size: 24),
    );
  }
}
