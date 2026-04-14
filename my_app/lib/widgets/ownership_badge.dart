import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../constants/app_theme.dart';

class OwnershipBadge extends StatelessWidget {
  final String ownerType;
  final String? displayName;
  final bool compact;

  const OwnershipBadge({
    super.key,
    required this.ownerType,
    this.displayName,
    this.compact = false,
  });

  static const _ownerConfig = <String, _OwnerStyle>{
    'seller': _OwnerStyle(PhosphorIconsDuotone.house, Color(0xFF115E66), 'You'),
    'seller_conveyancer': _OwnerStyle(PhosphorIconsDuotone.scales, Color(0xFF2A9DA8), 'Your Conveyancer'),
    'buyer': _OwnerStyle(PhosphorIconsDuotone.user, Color(0xFF6366F1), 'Buyer'),
    'buyer_conveyancer': _OwnerStyle(PhosphorIconsDuotone.scales, Color(0xFF8B5CF6), "Buyer's Conveyancer"),
    'estate_agent': _OwnerStyle(PhosphorIconsDuotone.storefront, Color(0xFFF59E0B), 'Estate Agent'),
    'lender': _OwnerStyle(PhosphorIconsDuotone.bank, Color(0xFFEF4444), 'Lender'),
    'freeholder_or_managing_agent': _OwnerStyle(PhosphorIconsDuotone.buildings, Color(0xFF10B981), 'Freeholder / Agent'),
    'surveyor': _OwnerStyle(PhosphorIconsDuotone.ruler, Color(0xFF3B82F6), 'Surveyor'),
    'local_authority_or_search_provider': _OwnerStyle(PhosphorIconsDuotone.buildingOffice, Color(0xFF6B7280), 'Local Authority'),
    'other': _OwnerStyle(PhosphorIconsDuotone.dotsThree, Color(0xFF9CA3AF), 'Other'),
  };

  @override
  Widget build(BuildContext context) {
    final config = _ownerConfig[ownerType] ??
        _OwnerStyle(PhosphorIconsDuotone.dotsThree, AppTheme.slate, ownerType);
    final label = displayName ?? config.label;

    if (compact) {
      return Icon(config.icon, size: 18, color: config.colour);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: config.colour.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: config.colour.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: 14, color: config.colour),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: config.colour,
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerStyle {
  final IconData icon;
  final Color colour;
  final String label;
  const _OwnerStyle(this.icon, this.colour, this.label);
}
