import 'package:flutter/material.dart';
import '../constants/app_theme.dart';

/// A floating "scroll to top" button that appears when the user scrolls
/// down past a threshold. Animates in/out with a fade + scale transition.
///
/// Usage (standalone):
///   floatingActionButton: ScrollToTopButton(scrollController: _scrollController)
///
/// Usage (alongside an existing FAB):
///   floatingActionButton: Column(
///     mainAxisSize: MainAxisSize.min,
///     crossAxisAlignment: CrossAxisAlignment.end,
///     children: [
///       ScrollToTopButton(scrollController: _scrollController),
///       const SizedBox(height: 12),
///       FloatingActionButton(heroTag: 'myAction', onPressed: ..., child: ...),
///     ],
///   ),
class ScrollToTopButton extends StatefulWidget {
  final ScrollController scrollController;
  final double showAfterPixels;

  const ScrollToTopButton({
    super.key,
    required this.scrollController,
    this.showAfterPixels = 300.0,
  });

  @override
  State<ScrollToTopButton> createState() => _ScrollToTopButtonState();
}

class _ScrollToTopButtonState extends State<ScrollToTopButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeScale;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeScale = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant ScrollToTopButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScroll);
      widget.scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    _animController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!widget.scrollController.hasClients) return;
    final shouldShow =
        widget.scrollController.offset > widget.showAfterPixels;
    if (shouldShow != _isVisible) {
      _isVisible = shouldShow;
      if (_isVisible) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    }
  }

  void _scrollToTop() {
    widget.scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeScale,
      child: ScaleTransition(
        scale: _fadeScale,
        child: FloatingActionButton.small(
          heroTag: 'scrollToTop',
          onPressed: _scrollToTop,
          backgroundColor: AppTheme.forestMid,
          foregroundColor: Colors.white,
          tooltip: 'Scroll to top',
          child: const Icon(Icons.keyboard_arrow_up),
        ),
      ),
    );
  }
}
