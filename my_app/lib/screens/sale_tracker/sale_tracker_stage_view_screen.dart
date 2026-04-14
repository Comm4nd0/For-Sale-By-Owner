import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../../constants/app_theme.dart';
import '../../models/sale.dart';
import '../../models/sale_stage.dart';
import '../../models/sale_task.dart';
import '../../services/api_service.dart';
import '../../widgets/branded_app_bar.dart';
import '../../widgets/ownership_badge.dart';
import '../../widgets/stage_progress_bar.dart';
import 'sale_tracker_task_detail_screen.dart';

class SaleTrackerStageViewScreen extends StatefulWidget {
  final int saleId;
  const SaleTrackerStageViewScreen({super.key, required this.saleId});

  @override
  State<SaleTrackerStageViewScreen> createState() =>
      _SaleTrackerStageViewScreenState();
}

class _SaleTrackerStageViewScreenState
    extends State<SaleTrackerStageViewScreen> {
  Sale? _sale;
  bool _loading = true;
  int? _selectedStageNumber;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final api = context.read<ApiService>();
      final json = await api.getSaleDetail(widget.saleId);
      if (mounted) {
        final sale = Sale.fromJson(json);
        setState(() {
          _sale = sale;
          _selectedStageNumber ??= sale.currentStageNumber ??
              (sale.stages.isNotEmpty ? sale.stages.first.stageNumber : null);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load stages: $e')),
        );
      }
    }
  }

  SaleStage? get _selectedStage {
    if (_sale == null || _selectedStageNumber == null) return null;
    try {
      return _sale!.stages
          .firstWhere((s) => s.stageNumber == _selectedStageNumber);
    } catch (_) {
      return null;
    }
  }

  Color _statusColour(String status) {
    switch (status) {
      case 'done':
        return AppTheme.forestDeep;
      case 'in_progress':
        return AppTheme.warning;
      case 'blocked':
        return AppTheme.error;
      default:
        return AppTheme.stone;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar.build(context: context),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sale == null
              ? const Center(child: Text('Sale not found'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text(
                        'Stage View',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.charcoal,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Stage progress bar
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: StageProgressBar(
                            stages: _sale!.stages,
                            currentStageNumber: _selectedStageNumber,
                            onStageTap: (num) {
                              setState(
                                  () => _selectedStageNumber = num);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Selected stage info
                      if (_selectedStage != null) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selectedStage!.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.charcoal,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _statusColour(
                                        _selectedStage!.status)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _statusColour(
                                          _selectedStage!.status)
                                      .withOpacity(0.4),
                                ),
                              ),
                              child: Text(
                                _selectedStage!.statusDisplay,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _statusColour(
                                      _selectedStage!.status),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_selectedStage!.completedTaskCount}/'
                          '${_selectedStage!.taskCount} tasks completed',
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.slate),
                        ),
                        const SizedBox(height: 16),

                        // Tasks for this stage
                        if (_selectedStage!.tasks.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                'No tasks in this stage',
                                style: TextStyle(
                                    color: AppTheme.slate, fontSize: 14),
                              ),
                            ),
                          )
                        else
                          ..._selectedStage!.tasks
                              .map(_buildTaskCard),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildTaskCard(SaleTask task) {
    return Card(
      child: ListTile(
        leading: OwnershipBadge(
          ownerType: task.currentOwner,
          compact: true,
        ),
        title: Text(
          task.title,
          style:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _statusColour(task.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                task.statusDisplay,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _statusColour(task.status),
                ),
              ),
            ),
            if (task.daysAwaiting > 0) ...[
              const SizedBox(width: 8),
              Text(
                '${task.daysAwaiting}d',
                style:
                    const TextStyle(fontSize: 11, color: AppTheme.slate),
              ),
            ],
          ],
        ),
        trailing: Icon(
          PhosphorIconsDuotone.caretRight,
          size: 18,
          color: AppTheme.stone,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SaleTrackerTaskDetailScreen(
                saleId: widget.saleId,
                taskId: task.id,
              ),
            ),
          ).then((_) => _loadData());
        },
      ),
    );
  }
}
