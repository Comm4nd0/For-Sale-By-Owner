import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../../constants/app_theme.dart';
import '../../models/sale_task.dart';
import '../../services/api_service.dart';
import '../../widgets/branded_app_bar.dart';
import '../../widgets/ownership_badge.dart';
import 'sale_tracker_prompts_screen.dart';

class SaleTrackerTaskDetailScreen extends StatefulWidget {
  final int saleId;
  final int taskId;
  const SaleTrackerTaskDetailScreen({
    super.key,
    required this.saleId,
    required this.taskId,
  });

  @override
  State<SaleTrackerTaskDetailScreen> createState() =>
      _SaleTrackerTaskDetailScreenState();
}

class _SaleTrackerTaskDetailScreenState
    extends State<SaleTrackerTaskDetailScreen> {
  SaleTask? _task;
  bool _loading = true;
  final _notesController = TextEditingController();
  final _notesFocus = FocusNode();
  bool _notesDirty = false;

  static const _ownerChoices = {
    'seller': 'You (Seller)',
    'seller_conveyancer': 'Your Conveyancer',
    'buyer': 'Buyer',
    'buyer_conveyancer': "Buyer's Conveyancer",
    'estate_agent': 'Estate Agent',
    'lender': 'Lender',
    'freeholder_or_managing_agent': 'Freeholder / Managing Agent',
    'surveyor': 'Surveyor',
    'local_authority_or_search_provider': 'Local Authority / Search Provider',
    'other': 'Other',
  };

  @override
  void initState() {
    super.initState();
    _notesFocus.addListener(_onNotesFocusChange);
    _loadData();
  }

  @override
  void dispose() {
    _notesFocus.removeListener(_onNotesFocusChange);
    _notesFocus.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onNotesFocusChange() {
    if (!_notesFocus.hasFocus && _notesDirty) {
      _saveNotes();
    }
  }

  Future<void> _loadData() async {
    try {
      final api = context.read<ApiService>();
      final tasks = await api.getSaleTasks(widget.saleId);
      final taskJson = tasks.firstWhere(
        (t) => t['id'] == widget.taskId,
        orElse: () => <String, dynamic>{},
      );
      if (taskJson.isNotEmpty && mounted) {
        final task = SaleTask.fromJson(taskJson);
        setState(() {
          _task = task;
          _notesController.text = task.notes;
          _notesDirty = false;
          _loading = false;
        });
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load task: $e')),
        );
      }
    }
  }

  Future<void> _saveNotes() async {
    if (_task == null) return;
    try {
      final api = context.read<ApiService>();
      await api.updateTask(widget.saleId, widget.taskId, {
        'notes': _notesController.text,
      });
      _notesDirty = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notes saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save notes: $e')),
        );
      }
    }
  }

  Future<void> _markComplete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark Complete'),
        content: const Text('Mark this task as completed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final api = context.read<ApiService>();
      await api.completeTask(widget.saleId, widget.taskId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task completed')),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to complete task: $e')),
        );
      }
    }
  }

  Future<void> _showReassignSheet() async {
    final reasonController = TextEditingController();
    String? selectedOwner;

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reassign Task',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.charcoal),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'New Owner'),
                items: _ownerChoices.entries
                    .map((e) => DropdownMenuItem(
                        value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setSheetState(() => selectedOwner = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration:
                    const InputDecoration(labelText: 'Reason (optional)'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: selectedOwner != null
                      ? () => Navigator.pop(ctx, {
                            'owner': selectedOwner!,
                            'reason': reasonController.text.trim(),
                          })
                      : null,
                  child: const Text('Reassign'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    reasonController.dispose();

    if (result == null) return;

    try {
      final api = context.read<ApiService>();
      await api.reassignTask(
        widget.saleId,
        widget.taskId,
        result['owner']!,
        reason: result['reason'] ?? '',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task reassigned')),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reassign: $e')),
        );
      }
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
          : _task == null
              ? const Center(child: Text('Task not found'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Title
                      Text(
                        _task!.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.charcoal,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Stage name
                      if (_task!.stageName.isNotEmpty)
                        Text(
                          'Stage: ${_task!.stageName}',
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.slate),
                        ),
                      const SizedBox(height: 12),

                      // Description
                      if (_task!.description.isNotEmpty) ...[
                        Text(
                          _task!.description,
                          style: const TextStyle(
                              fontSize: 14, color: AppTheme.charcoal),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Owner & status row
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Text('Current Owner',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.slate)),
                                    const SizedBox(height: 4),
                                    OwnershipBadge(
                                      ownerType: _task!.currentOwner,
                                      displayName:
                                          _task!.currentOwnerDisplay,
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Text('Status',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.slate)),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _statusColour(
                                                _task!.status)
                                            .withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _task!.statusDisplay,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _statusColour(
                                              _task!.status),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Days awaiting
                      if (_task!.daysAwaiting > 0)
                        Card(
                          child: ListTile(
                            leading: Icon(PhosphorIconsDuotone.clock,
                                color: _task!.daysAwaiting > 7
                                    ? AppTheme.warning
                                    : AppTheme.slate),
                            title: Text(
                              '${_task!.daysAwaiting} day(s) awaiting action',
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: _task!.awaitingSince != null
                                ? Text('Since ${_task!.awaitingSince}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.slate))
                                : null,
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Notes
                      const Text(
                        'Notes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.charcoal,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _notesController,
                        focusNode: _notesFocus,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Add notes...',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => _notesDirty = true,
                      ),
                      const SizedBox(height: 16),

                      // Ownership history
                      if (_task!.ownershipHistory.isNotEmpty) ...[
                        const Text(
                          'Ownership History',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.charcoal,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._task!.ownershipHistory
                            .map(_buildHistoryEntry),
                      ],
                      const SizedBox(height: 24),

                      // Action buttons
                      if (!_task!.isDone)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _showReassignSheet,
                                icon: Icon(PhosphorIconsDuotone.arrowsLeftRight),
                                label: const Text('Reassign'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _markComplete,
                                icon: Icon(PhosphorIconsDuotone.check),
                                label: const Text('Complete'),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 8),
                      if (!_task!.isDone)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SaleTrackerPromptsScreen(
                                    saleId: widget.saleId,
                                  ),
                                ),
                              );
                            },
                            icon: Icon(PhosphorIconsDuotone.megaphone),
                            label: const Text('Generate Prompt'),
                          ),
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHistoryEntry(TaskOwnershipHistoryEntry entry) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.forestMid,
                ),
              ),
              Container(
                width: 2,
                height: 30,
                color: AppTheme.pebble,
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    OwnershipBadge(
                      ownerType: entry.fromOwner,
                      compact: true,
                    ),
                    const SizedBox(width: 4),
                    Icon(PhosphorIconsDuotone.arrowRight,
                        size: 14, color: AppTheme.stone),
                    const SizedBox(width: 4),
                    OwnershipBadge(
                      ownerType: entry.toOwner,
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  entry.transferredAt,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.slate),
                ),
                if (entry.reason.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.reason,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.charcoal),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
