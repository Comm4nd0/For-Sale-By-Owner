import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import '../models/sale_stage.dart';

class StageProgressBar extends StatelessWidget {
  final List<SaleStage> stages;
  final int? currentStageNumber;
  final void Function(int stageNumber)? onStageTap;

  const StageProgressBar({
    super.key,
    required this.stages,
    this.currentStageNumber,
    this.onStageTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(stages.length, (index) {
          final stage = stages[index];
          final isCompleted = stage.isDone;
          final isCurrent = stage.stageNumber == currentStageNumber;

          return Row(
            children: [
              if (index > 0)
                Container(
                  width: 20,
                  height: 2,
                  color: isCompleted
                      ? AppTheme.forestDeep
                      : AppTheme.pebble,
                ),
              GestureDetector(
                onTap: onStageTap != null
                    ? () => onStageTap!(stage.stageNumber)
                    : null,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? AppTheme.forestDeep
                            : isCurrent
                                ? AppTheme.forestMid
                                : Colors.white,
                        border: Border.all(
                          color: isCompleted
                              ? AppTheme.forestDeep
                              : isCurrent
                                  ? AppTheme.forestMid
                                  : AppTheme.stone,
                          width: isCurrent ? 2.5 : 1.5,
                        ),
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : Text(
                                '${stage.stageNumber}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isCurrent
                                      ? Colors.white
                                      : AppTheme.slate,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 60,
                      child: Text(
                        stage.name,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isCurrent
                              ? AppTheme.forestDeep
                              : AppTheme.slate,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
