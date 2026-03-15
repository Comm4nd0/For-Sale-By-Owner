import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/conveyancing_case.dart';
import '../widgets/branded_app_bar.dart';

class ConveyancingScreen extends StatefulWidget {
  const ConveyancingScreen({super.key});

  @override
  State<ConveyancingScreen> createState() => _ConveyancingScreenState();
}

class _ConveyancingScreenState extends State<ConveyancingScreen> {
  static const Color _primary = Color(0xFF115E66);
  static const Color _accent = Color(0xFF19747E);

  List<ConveyancingCase> _cases = [];
  bool _loading = true;
  String? _error;
  final Set<int> _expandedCaseIds = {};

  @override
  void initState() {
    super.initState();
    _loadCases();
  }

  Future<void> _loadCases() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = context.read<ApiService>();
      final data = await api.getConveyancingCases();
      if (mounted) {
        setState(() {
          _cases = data
              .map((json) =>
                  ConveyancingCase.fromJson(json as Map<String, dynamic>))
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _updateStepStatus(
      ConveyancingCase caseItem, ConveyancingStep step, String newStatus) async {
    String? notes;

    if (newStatus == 'blocked') {
      notes = await _showNotesDialog('Reason for blocking');
      if (notes == null) return;
    }

    try {
      final api = context.read<ApiService>();
      await api.updateConveyancingStep(caseItem.id, step.id, newStatus,
          notes: notes);
      await _loadCases();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Step "${step.stepTypeDisplay}" updated to ${_statusLabel(newStatus)}'),
            backgroundColor: _primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update step: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _showNotesDialog(String title) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter notes...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primary),
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'Completed';
      case 'in_progress':
        return 'In Progress';
      case 'blocked':
        return 'Blocked';
      case 'pending':
      default:
        return 'Pending';
    }
  }

  Icon _statusIcon(String status) {
    switch (status) {
      case 'completed':
        return const Icon(Icons.check_circle, color: Colors.green, size: 22);
      case 'in_progress':
        return const Icon(Icons.radio_button_checked,
            color: Colors.amber, size: 22);
      case 'blocked':
        return const Icon(Icons.cancel, color: Colors.red, size: 22);
      case 'pending':
      default:
        return const Icon(Icons.radio_button_unchecked,
            color: Colors.grey, size: 22);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.amber;
      case 'blocked':
        return Colors.red;
      case 'pending':
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Not set';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar.build(
        context: context,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadCases,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 56, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Failed to load cases',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadCases,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(backgroundColor: _primary),
              ),
            ],
          ),
        ),
      );
    }

    if (_cases.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.gavel_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No Conveyancing Cases',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'When you accept an offer on a property or have an offer accepted, '
                'your conveyancing progress will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: _primary,
      onRefresh: _loadCases,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        itemCount: _cases.length,
        itemBuilder: (context, index) => _buildCaseCard(_cases[index]),
      ),
    );
  }

  Widget _buildCaseCard(ConveyancingCase caseItem) {
    final isExpanded = _expandedCaseIds.contains(caseItem.id);
    final sortedSteps = List<ConveyancingStep>.from(caseItem.steps)
      ..sort((a, b) => a.order.compareTo(b.order));
    final progress = caseItem.progressPercentage / 100.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_primary, _accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(12),
                bottom: isExpanded ? Radius.zero : const Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        caseItem.propertyTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(51),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        caseItem.status.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        color: Colors.white70, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Buyer: ${caseItem.buyerName}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.person, color: Colors.white70, size: 16),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Seller: ${caseItem.sellerName}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: Colors.white.withAlpha(51),
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${caseItem.progressPercentage}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        color: Colors.white70, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Target: ${_formatDate(caseItem.targetCompletionDate)}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () {
                        setState(() {
                          if (isExpanded) {
                            _expandedCaseIds.remove(caseItem.id);
                          } else {
                            _expandedCaseIds.add(caseItem.id);
                          }
                        });
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isExpanded ? 'Hide Steps' : 'Show Steps',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                          ),
                          Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isExpanded) ...[
            _buildSolicitorSection(caseItem),
            if (caseItem.notes.isNotEmpty) _buildNotesSection(caseItem),
            _buildStepsList(caseItem, sortedSteps),
          ],
        ],
      ),
    );
  }

  Widget _buildSolicitorSection(ConveyancingCase caseItem) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Solicitor Details',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: _primary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildSolicitorItem(
                  label: 'Buyer\'s Solicitor',
                  value: caseItem.buyerSolicitor.isNotEmpty
                      ? caseItem.buyerSolicitor
                      : 'Not assigned',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSolicitorItem(
                  label: 'Seller\'s Solicitor',
                  value: caseItem.sellerSolicitor.isNotEmpty
                      ? caseItem.sellerSolicitor
                      : 'Not assigned',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSolicitorItem({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildNotesSection(ConveyancingCase caseItem) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.note_outlined, size: 18, color: Colors.amber[800]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notes',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.amber[900],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  caseItem.notes,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsList(
      ConveyancingCase caseItem, List<ConveyancingStep> sortedSteps) {
    if (sortedSteps.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No steps defined for this case.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedSteps.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200]),
      itemBuilder: (context, index) {
        final step = sortedSteps[index];
        return _buildStepTile(caseItem, step);
      },
    );
  }

  Widget _buildStepTile(ConveyancingCase caseItem, ConveyancingStep step) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _statusIcon(step.status),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.stepTypeDisplay,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    decoration: step.status == 'completed'
                        ? TextDecoration.lineThrough
                        : null,
                    color: step.status == 'completed'
                        ? Colors.grey
                        : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  step.statusDisplay,
                  style: TextStyle(
                    fontSize: 12,
                    color: _statusColor(step.status),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (step.notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    step.notes,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (step.completedAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Completed: ${_formatDate(step.completedAt)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
                const SizedBox(height: 6),
                _buildStepActions(caseItem, step),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepActions(ConveyancingCase caseItem, ConveyancingStep step) {
    final List<Widget> buttons = [];

    if (step.status == 'pending') {
      buttons.add(
        _buildActionButton(
          label: 'Start',
          icon: Icons.play_arrow,
          color: _accent,
          onPressed: () =>
              _updateStepStatus(caseItem, step, 'in_progress'),
        ),
      );
    }

    if (step.status == 'in_progress') {
      buttons.add(
        _buildActionButton(
          label: 'Complete',
          icon: Icons.check,
          color: Colors.green,
          onPressed: () =>
              _updateStepStatus(caseItem, step, 'completed'),
        ),
      );
    }

    if (step.status == 'pending' || step.status == 'in_progress') {
      buttons.add(
        _buildActionButton(
          label: 'Blocked',
          icon: Icons.block,
          color: Colors.red,
          onPressed: () =>
              _updateStepStatus(caseItem, step, 'blocked'),
        ),
      );
    }

    if (step.status == 'blocked') {
      buttons.add(
        _buildActionButton(
          label: 'Resume',
          icon: Icons.refresh,
          color: _accent,
          onPressed: () =>
              _updateStepStatus(caseItem, step, 'in_progress'),
        ),
      );
    }

    if (buttons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: buttons,
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 30,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withAlpha(128)),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }
}
