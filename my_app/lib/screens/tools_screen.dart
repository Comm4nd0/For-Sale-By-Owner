import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import '../widgets/branded_app_bar.dart';
import 'mortgage_calculator_screen.dart';
import 'house_prices_screen.dart';
import 'price_comparison_screen.dart';
import 'stamp_duty_screen.dart';
import 'forum_screen.dart';
import 'neighbourhood_review_screen.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar.build(context: context),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Property Tools',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.charcoal,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Free tools to help you buy or sell your property.',
            style: TextStyle(color: AppTheme.slate, fontSize: 14),
          ),
          const SizedBox(height: 20),
          _ToolCard(
            icon: PhosphorIconsDuotone.calculator,
            title: 'Mortgage Calculator',
            subtitle: 'Estimate your monthly payments based on price, deposit, rate, and term.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MortgageCalculatorScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            icon: PhosphorIconsDuotone.trendUp,
            title: 'House Price Lookup',
            subtitle: 'Search sold house prices in any area by postcode.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HousePricesScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            icon: PhosphorIconsDuotone.arrowsLeftRight,
            title: 'Price Comparison',
            subtitle: 'Compare sold prices and local listings in your area.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PriceComparisonScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            icon: PhosphorIconsDuotone.bank,
            title: 'Stamp Duty Calculator',
            subtitle: 'Calculate SDLT, LBTT, or LTT for England, Scotland & Wales.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StampDutyScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            icon: PhosphorIconsDuotone.buildings,
            title: 'Neighbourhood Reviews',
            subtitle: 'Read and write reviews for any UK neighbourhood.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NeighbourhoodReviewScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            icon: PhosphorIconsDuotone.chatsCircle,
            title: 'Community Forum',
            subtitle: 'Discuss buying, selling, and property topics.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ForumScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final PhosphorIconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.forestMist,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: PhosphorIcon(icon, color: AppTheme.forestMid, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppTheme.charcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.slate,
                      ),
                    ),
                  ],
                ),
              ),
              PhosphorIcon(PhosphorIconsDuotone.caretRight, color: AppTheme.stone),
            ],
          ),
        ),
      ),
    );
  }
}
