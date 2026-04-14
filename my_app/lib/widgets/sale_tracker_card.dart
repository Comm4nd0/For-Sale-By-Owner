import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../constants/app_theme.dart';
import '../models/sale.dart';

class SaleTrackerCard extends StatelessWidget {
  final Sale sale;
  final VoidCallback? onTap;

  const SaleTrackerCard({
    super.key,
    required this.sale,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    PhosphorIconsDuotone.chartLine,
                    color: AppTheme.forestMid,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Sale Tracker',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.charcoal,
                    ),
                  ),
                  const Spacer(),
                  if (sale.yourTurnCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.forestMid,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${sale.yourTurnCount} action${sale.yourTurnCount == 1 ? '' : 's'} needed',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                sale.propertyAddress,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.slate,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: sale.progressPercent,
                  backgroundColor: AppTheme.pebble,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.forestMid),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    sale.currentStageName ?? 'Pre-Instruction',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.forestDeep,
                    ),
                  ),
                  Text(
                    '${sale.completedTasks}/${sale.totalTasks} tasks',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.slate,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
