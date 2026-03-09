import 'package:flutter/material.dart';

class SubscriptionCard extends StatelessWidget {
  final Map<String, dynamic>? subscriptionData;
  final VoidCallback onUpgrade;
  final VoidCallback onManageBilling;

  const SubscriptionCard({
    super.key,
    required this.subscriptionData,
    required this.onUpgrade,
    required this.onManageBilling,
  });

  @override
  Widget build(BuildContext context) {
    final tier = subscriptionData?['tier'] as Map<String, dynamic>?;
    final usage = subscriptionData?['usage'] as Map<String, dynamic>? ?? {};
    final subscription =
        subscriptionData?['subscription'] as Map<String, dynamic>?;

    final tierName = tier?['name'] ?? 'Free';
    final tierSlug = tier?['slug'] ?? 'free';
    final isFree = tierSlug == 'free';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A3C2E), Color(0xFF2D6A4F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Your Plan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              _buildTierBadge(tierName, tierSlug),
            ],
          ),
          const SizedBox(height: 12),

          // Billing info
          if (!isFree && subscription != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  subscription['billing_cycle'] == 'annual'
                      ? 'Annual billing'
                      : 'Monthly billing',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
                if (subscription['current_period_end'] != null)
                  Text(
                    'Renews ${_formatDate(subscription['current_period_end'])}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
            if (subscription['cancel_at_period_end'] == true)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Cancels at end of billing period',
                  style: TextStyle(
                    color: Colors.amber.shade300,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 12),
          ],

          // Usage meters
          _buildUsageMeter(
            'Categories',
            usage['categories_used'] ?? 0,
            usage['categories_max'] ?? 1,
          ),
          const SizedBox(height: 8),
          _buildUsageMeter(
            'Locations',
            usage['locations_used'] ?? 0,
            usage['locations_max'] ?? 1,
          ),
          const SizedBox(height: 8),
          _buildUsageMeter(
            'Photos',
            usage['photos_used'] ?? 0,
            usage['photos_max'] ?? 0,
          ),
          const SizedBox(height: 16),

          // Actions
          Row(
            children: [
              if (isFree)
                Expanded(
                  child: ElevatedButton(
                    onPressed: onUpgrade,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D6A4F),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Upgrade Plan'),
                  ),
                )
              else ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: onUpgrade,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.5)),
                    ),
                    child: const Text('Change Plan'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onManageBilling,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.5)),
                    ),
                    child: const Text('Manage Billing'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTierBadge(String name, String slug) {
    Color bgColor;
    Color textColor;

    if (slug == 'pro') {
      bgColor = const Color(0xFFC9872A);
      textColor = Colors.white;
    } else if (slug == 'growth') {
      bgColor = const Color(0xFFD8F3DC);
      textColor = const Color(0xFF1A3C2E);
    } else {
      bgColor = Colors.white.withValues(alpha: 0.2);
      textColor = Colors.white;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '$name Plan',
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildUsageMeter(String label, int used, int max) {
    final isUnlimited = max == -1;
    final isNone = max == 0;
    final pct =
        isUnlimited || isNone ? 0.0 : (used / max).clamp(0.0, 1.0);
    final text = isUnlimited
        ? '$used used (unlimited)'
        : isNone
            ? 'Not available'
            : '$used / $max';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            valueColor:
                const AlwaysStoppedAnimation<Color>(Color(0xFFD8F3DC)),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return '';
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }
}
