import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_theme.dart';
import '../models/dashboard_stats.dart';

/// Bar chart of property views over the last 30 days for the seller
/// dashboard. Renders nothing when there are no views in the window.
class ViewsBarChart extends StatelessWidget {
  final List<ViewsByDay> viewsByDay;

  const ViewsBarChart({super.key, required this.viewsByDay});

  List<int> _dailyCounts() {
    final counts = <String, int>{};
    for (final v in viewsByDay) {
      counts[v.date] = v.count;
    }
    final today = DateTime.now();
    return List.generate(30, (i) {
      final day = today.subtract(Duration(days: 29 - i));
      final key = DateFormat('yyyy-MM-dd').format(day);
      return counts[key] ?? 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final counts = _dailyCounts();
    final total = counts.fold<int>(0, (sum, c) => sum + c);
    if (total == 0) return const SizedBox.shrink();

    final today = DateTime.now();
    final startLabel =
        DateFormat('d MMM').format(today.subtract(const Duration(days: 29)));
    final endLabel = DateFormat('d MMM').format(today);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Views — last 30 days',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                Text(
                  '$total total',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              width: double.infinity,
              child: CustomPaint(
                painter: _BarChartPainter(counts, AppTheme.forestMid),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(startLabel,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                Text(endLabel,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<int> counts;
  final Color barColor;

  _BarChartPainter(this.counts, this.barColor);

  @override
  void paint(Canvas canvas, Size size) {
    if (counts.isEmpty) return;
    final max = counts.reduce((a, b) => a > b ? a : b);
    if (max == 0) return;

    final paint = Paint()..color = barColor;
    final barWidth = size.width / counts.length;

    for (var i = 0; i < counts.length; i++) {
      if (counts[i] == 0) continue;
      final barHeight =
          (counts[i] / max * (size.height - 4)).clamp(3.0, size.height);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          i * barWidth + 1,
          size.height - barHeight,
          barWidth - 2,
          barHeight,
        ),
        const Radius.circular(1.5),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) =>
      oldDelegate.counts != counts || oldDelegate.barColor != barColor;
}
