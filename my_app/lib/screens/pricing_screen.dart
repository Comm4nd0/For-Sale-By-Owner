import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/subscription_tier.dart';
import '../models/subscription_addon.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/branded_app_bar.dart';
import '../widgets/scroll_to_top_button.dart';
import '../utils/auto_retry.dart';
import 'login_screen.dart';
import 'service_provider_form_screen.dart';

class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> with AutoRetryMixin {
  final ScrollController _scrollController = ScrollController();
  bool _isAnnual = false;
  bool _isLoading = true;
  String? _error;
  List<SubscriptionTier> _tiers = [];
  List<SubscriptionAddOn> _addons = [];

  static const _featureLabels = {
    'basic_listing': 'Basic listing',
    'local_area_visibility': 'Local area visibility',
    'contact_details': 'Contact details shown',
    'featured_placement': 'Featured placement',
    'click_through_analytics': 'Click-through analytics',
    'category_exclusivity': 'Category exclusivity',
    'priority_search': 'Priority in search',
    'lead_notifications': 'Lead notifications',
    'performance_reports': 'Performance reports',
    'account_manager': 'Account manager',
    'photo_gallery': 'Photo gallery',
    'early_access': 'Early access',
  };

  @override
  void initState() {
    super.initState();
    _loadPricing();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPricing() async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final data = await withRetry(() => api.getPricing());
      setState(() {
        _tiers = (data['tiers'] as List)
            .map((t) => SubscriptionTier.fromJson(t))
            .toList();
        _addons = (data['addons'] as List)
            .map((a) => SubscriptionAddOn.fromJson(a))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load pricing. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _subscribe(SubscriptionTier tier) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (!auth.isAuthenticated) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final url = await api.createCheckout(
        tier.slug,
        _isAnnual ? 'annual' : 'monthly',
      );
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar.build(context: context, showHomeButton: true),
      floatingActionButton: ScrollToTopButton(scrollController: _scrollController),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _error = null;
                          });
                          _loadPricing();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        children: [
          // Hero
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF115E66), Color(0xFF19747E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: Column(
              children: [
                const Text(
                  'Simple, Transparent Pricing',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Grow your business with premium features',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 15,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                // Billing toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Monthly',
                      style: TextStyle(
                        color: Colors.white
                            .withValues(alpha: _isAnnual ? 0.6 : 1.0),
                        fontWeight:
                            _isAnnual ? FontWeight.normal : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: _isAnnual,
                      onChanged: (v) => setState(() => _isAnnual = v),
                      activeColor: Colors.white,
                      activeTrackColor: Colors.white.withValues(alpha: 0.3),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Annual',
                      style: TextStyle(
                        color: Colors.white
                            .withValues(alpha: _isAnnual ? 1.0 : 0.6),
                        fontWeight:
                            _isAnnual ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF19747E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Save 20%',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tier cards
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: _tiers.map((tier) => _buildTierCard(tier)).toList(),
            ),
          ),

          // Add-ons
          if (_addons.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add-Ons',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF115E66),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Boost your listing with optional extras',
                    style: TextStyle(color: Color(0xFF4A5C62), fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  ..._addons.map((addon) => _buildAddonCard(addon)),
                ],
              ),
            ),

          // Free for buyers/sellers banner
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFD1E8E2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Text(
                  'Buying or selling a property?',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF115E66),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'For Sale By Owner is 100% free for property buyers and sellers. No fees. No commission. Ever.',
                  style: TextStyle(color: Color(0xFF4A5C62), fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTierCard(SubscriptionTier tier) {
    final isHighlighted = tier.slug == 'pro';
    if (tier.slug == 'free') return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: isHighlighted
              ? const Color(0xFF19747E)
              : const Color(0xFFE2E2E2),
          width: isHighlighted ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: const Color(0xFF19747E).withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Column(
        children: [
          if (tier.badgeText.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: const BoxDecoration(
                color: Color(0xFF19747E),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(11),
                  topRight: Radius.circular(11),
                ),
              ),
              child: Text(
                tier.badgeText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tier.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF115E66),
                  ),
                ),
                if (tier.tagline.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      tier.tagline,
                      style: const TextStyle(
                        color: Color(0xFF4A5C62),
                        fontSize: 13,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),

                // Price
                Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: _isAnnual
                          ? '\u00A3${(tier.annualPrice / 12).toStringAsFixed(0)}'
                          : '\u00A3${tier.monthlyPrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF115E66),
                      ),
                    ),
                    const TextSpan(
                      text: '/month',
                      style: TextStyle(
                        color: Color(0xFF8FA3A8),
                        fontSize: 14,
                      ),
                    ),
                  ]),
                ),
                if (_isAnnual)
                  Text(
                    'Billed \u00A3${tier.annualPrice.toStringAsFixed(0)}/year',
                    style: const TextStyle(
                      color: Color(0xFF4A5C62),
                      fontSize: 12,
                    ),
                  ),
                if (tier.hasTrial)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'First ${tier.trialPeriodDays >= 30 ? '${(tier.trialPeriodDays / 30).round()} month${(tier.trialPeriodDays / 30).round() > 1 ? 's' : ''}' : '${tier.trialPeriodDays} days'} free',
                      style: const TextStyle(
                        color: Color(0xFF19747E),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // Limits
                _buildLimit(
                    _formatLimit(tier.maxCategories, 'category', 'categories')),
                _buildLimit(
                    _formatLimit(tier.maxLocations, 'location', 'locations')),
                _buildLimit(tier.maxPhotos == 0
                    ? 'No photos'
                    : _formatLimit(tier.maxPhotos, 'photo', 'photos')),
                _buildLimit(tier.allowsLogo ? 'Logo upload' : 'No logo'),

                const Divider(height: 24),

                // Features
                ..._featureLabels.entries.map((e) {
                  final has = tier.hasFeature(e.key);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        PhosphorIcon(
                          has ? PhosphorIconsDuotone.check : PhosphorIconsDuotone.minus,
                          size: 18,
                          color: has
                              ? const Color(0xFF19747E)
                              : const Color(0xFFE2E2E2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          e.value,
                          style: TextStyle(
                            fontSize: 13,
                            color: has
                                ? const Color(0xFF1A2C33)
                                : const Color(0xFF8FA3A8),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 16),

                // CTA
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                          onPressed: () => _subscribe(tier),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF19747E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            tier.hasTrial
                                ? 'Start Free Trial'
                                : tier.ctaText.isNotEmpty
                                    ? tier.ctaText
                                    : 'Choose ${tier.name}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimit(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 6, color: Color(0xFF19747E)),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF19747E),
            ),
          ),
        ],
      ),
    );
  }

  String _formatLimit(int val, String singular, String plural) {
    if (val == -1) return 'Unlimited $plural';
    return '$val ${val == 1 ? singular : plural}';
  }

  Widget _buildAddonCard(SubscriptionAddOn addon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E2E2)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            addon.name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF115E66),
              fontSize: 15,
            ),
          ),
          if (addon.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                addon.description,
                style: const TextStyle(
                  color: Color(0xFF4A5C62),
                  fontSize: 13,
                ),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            '\u00A3${addon.monthlyPrice.toStringAsFixed(0)}/month',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF19747E),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Available on: ${addon.compatibleTierSlugs.map((s) => s[0].toUpperCase() + s.substring(1)).join(', ')}',
            style: const TextStyle(
              color: Color(0xFF8FA3A8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
