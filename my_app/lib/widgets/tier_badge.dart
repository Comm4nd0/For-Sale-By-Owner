import 'package:flutter/material.dart';

class TierBadge extends StatelessWidget {
  final String tierSlug;
  final String tierName;
  final double fontSize;

  const TierBadge({
    super.key,
    required this.tierSlug,
    required this.tierName,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    if (tierSlug == 'free') return const SizedBox.shrink();

    Color bgColor;
    Color textColor;

    if (tierSlug == 'pro') {
      bgColor = const Color(0xFFC9872A);
      textColor = Colors.white;
    } else {
      bgColor = const Color(0xFFD8F3DC);
      textColor = const Color(0xFF1A3C2E);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        tierName,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
