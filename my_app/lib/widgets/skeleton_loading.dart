import 'package:flutter/material.dart';
import '../constants/app_theme.dart';

/// A shimmer-effect placeholder widget for loading states.
class ShimmerBlock extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBlock({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<ShimmerBlock> createState() => _ShimmerBlockState();
}

class _ShimmerBlockState extends State<ShimmerBlock>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value, 0),
              colors: const [
                AppTheme.pebble,
                Color(0xFFECEFF0),
                AppTheme.pebble,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton placeholder that mimics a property card layout.
class PropertyCardSkeleton extends StatelessWidget {
  const PropertyCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image placeholder
          const AspectRatio(
            aspectRatio: 16 / 9,
            child: ShimmerBlock(width: double.infinity, height: double.infinity, borderRadius: 0),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerBlock(width: 220, height: 18),
                const SizedBox(height: 8),
                const ShimmerBlock(width: 120, height: 22),
                const SizedBox(height: 8),
                const ShimmerBlock(width: 180, height: 14),
                const SizedBox(height: 4),
                const ShimmerBlock(width: 250, height: 14),
                const SizedBox(height: 10),
                Row(
                  children: const [
                    ShimmerBlock(width: 60, height: 14),
                    SizedBox(width: 16),
                    ShimmerBlock(width: 60, height: 14),
                    SizedBox(width: 16),
                    ShimmerBlock(width: 60, height: 14),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for list items (saved properties, listings).
class ListItemSkeleton extends StatelessWidget {
  const ListItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const ShimmerBlock(width: 120, height: 100, borderRadius: 8),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ShimmerBlock(width: 160, height: 16),
                  SizedBox(height: 8),
                  ShimmerBlock(width: 100, height: 16),
                  SizedBox(height: 8),
                  ShimmerBlock(width: 200, height: 12),
                  SizedBox(height: 6),
                  ShimmerBlock(width: 140, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows multiple skeleton cards for a loading list.
class SkeletonList extends StatelessWidget {
  final int count;
  final bool useCards;

  const SkeletonList({super.key, this.count = 3, this.useCards = false});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: count,
      itemBuilder: (context, index) =>
          useCards ? const PropertyCardSkeleton() : const ListItemSkeleton(),
    );
  }
}
