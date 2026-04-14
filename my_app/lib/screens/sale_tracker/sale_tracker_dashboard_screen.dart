import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../../constants/app_theme.dart';
import '../../models/sale.dart';
import '../../models/sale_dashboard.dart';
import '../../services/api_service.dart';
import '../../widgets/branded_app_bar.dart';
import '../../widgets/ownership_badge.dart';
import '../../widgets/stage_progress_bar.dart';
import 'sale_tracker_stage_view_screen.dart';
import 'sale_tracker_document_vault_screen.dart';
import 'sale_tracker_enquiries_screen.dart';
import 'sale_tracker_contact_log_screen.dart';
import 'sale_tracker_timeline_screen.dart';
import 'sale_tracker_prompts_screen.dart';
import 'sale_tracker_settings_screen.dart';
import 'sale_tracker_task_detail_screen.dart';

class SaleTrackerDashboardScreen extends StatefulWidget {
  final int saleId;
  const SaleTrackerDashboardScreen({super.key, required this.saleId});

  @override
  State<SaleTrackerDashboardScreen> createState() =>
      _SaleTrackerDashboardScreenState();
}

class _SaleTrackerDashboardScreenState
    extends State<SaleTrackerDashboardScreen> {
  Sale? _sale;
  SaleDashboard? _dashboard;
  bool _loading = true;
  final Map<String, bool> _expandedGroups = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final api = context.read<ApiService>();
      final saleJson = await api.getSaleDetail(widget.saleId);
      final dashJson = await api.getSaleDashboard(widget.saleId);
      if (mounted) {
        setState(() {
          _sale = Sale.fromJson(saleJson);
          _dashboard = SaleDashboard.fromJson(dashJson);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load dashboard: $e')),
        );
      }
    }
  }

  Future<void> _handleInstruct() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Instruct Sale'),
        content: const Text(
          'This will instruct the sale and begin the conveyancing process. '
          'Ensure all required documents are uploaded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Instruct'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final api = context.read<ApiService>();
      await api.instructSale(widget.saleId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sale instructed successfully')),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to instruct sale: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar.build(context: context, showHomeButton: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sale == null
              ? const Center(child: Text('Sale not found'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Property address
                      Text(
                        _sale!.propertyAddress,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.charcoal,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Stage progress bar
                      if (_sale!.stages.isNotEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: StageProgressBar(
                              stages: _sale!.stages,
                              currentStageNumber: _sale!.currentStageNumber,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),

                      // Readiness card (pre-instruction)
                      if (!_sale!.isInstructed &&
                          _dashboard?.readiness != null)
                        _buildReadinessCard(_dashboard!.readiness!),

                      // Headline numbers
                      if (_dashboard != null)
                        _buildHeadlineNumbers(_dashboard!.headlineNumbers),
                      const SizedBox(height: 12),

                      // Your Turn section
                      if (_dashboard != null &&
                          _dashboard!.yourTurn.isNotEmpty) ...[
                        _buildSectionHeader(
                          'Your Turn',
                          PhosphorIconsDuotone.arrowRight,
                          AppTheme.forestDeep,
                        ),
                        const SizedBox(height: 8),
                        ..._dashboard!.yourTurn.map(_buildTaskCard),
                        const SizedBox(height: 16),
                      ],

                      // Awaiting Others section
                      if (_dashboard != null &&
                          _dashboard!.awaitingOthers.isNotEmpty) ...[
                        _buildSectionHeader(
                          'Awaiting Others',
                          PhosphorIconsDuotone.clock,
                          AppTheme.slate,
                        ),
                        const SizedBox(height: 8),
                        ..._dashboard!.awaitingOthers.entries
                            .map(_buildAwaitingGroup),
                        const SizedBox(height: 16),
                      ],

                      // Expiring documents
                      if (_dashboard != null &&
                          _dashboard!.expiringDocuments.isNotEmpty) ...[
                        _buildSectionHeader(
                          'Documents Expiring Soon',
                          PhosphorIconsDuotone.warning,
                          AppTheme.warning,
                        ),
                        const SizedBox(height: 8),
                        ..._dashboard!.expiringDocuments
                            .map(_buildExpiringDocCard),
                        const SizedBox(height: 16),
                      ],

                      // Navigation buttons
                      _buildNavGrid(),
                      const SizedBox(height: 24),

                      // Disclaimer
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.cream,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.pebble),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              PhosphorIconsDuotone.info,
                              size: 18,
                              color: AppTheme.slate,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Sale Tracker organises information to help you '
                                'manage your sale. It is not legal advice. '
                                'Conveyancing should be carried out by a qualified '
                                'solicitor or licensed conveyancer.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.slate,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
    );
  }

  Widget _buildReadinessCard(ReadinessData readiness) {
    final percent = (readiness.readinessPercent * 100).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(PhosphorIconsDuotone.checkCircle,
                    color: readiness.ready
                        ? AppTheme.forestDeep
                        : AppTheme.warning,
                    size: 24),
                const SizedBox(width: 8),
                Text(
                  readiness.ready
                      ? 'Ready to Instruct'
                      : 'Preparing to Instruct',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.charcoal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: readiness.readinessPercent,
                minHeight: 8,
                backgroundColor: AppTheme.pebble,
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppTheme.forestDeep),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$percent% complete '
              '(${readiness.documentsReady}/${readiness.totalDocuments} documents)',
              style: const TextStyle(fontSize: 13, color: AppTheme.slate),
            ),
            if (readiness.missingAlways.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${readiness.missingAlways.length} required document(s) missing',
                style: const TextStyle(fontSize: 13, color: AppTheme.error),
              ),
            ],
            if (readiness.warnings.isNotEmpty)
              ...readiness.warnings.map(
                (w) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(w,
                      style:
                          const TextStyle(fontSize: 12, color: AppTheme.warning)),
                ),
              ),
            if (readiness.ready) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _handleInstruct,
                  icon: Icon(PhosphorIconsDuotone.rocketLaunch),
                  label: const Text('Instruct Sale'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeadlineNumbers(HeadlineNumbers numbers) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _buildHeadlineStat(
              '${numbers.completedTasks}/${numbers.totalTasks}',
              'Tasks Done',
              PhosphorIconsDuotone.checkSquare,
            ),
            _buildDivider(),
            _buildHeadlineStat(
              numbers.currentStageName ?? '-',
              'Current Stage',
              PhosphorIconsDuotone.flag,
            ),
            _buildDivider(),
            _buildHeadlineStat(
              numbers.daysSinceInstruction != null
                  ? '${numbers.daysSinceInstruction}'
                  : '-',
              'Days',
              PhosphorIconsDuotone.calendar,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeadlineStat(String value, String label, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppTheme.forestMid),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.charcoal,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.slate),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 40,
      color: AppTheme.pebble,
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color colour) {
    return Row(
      children: [
        Icon(icon, size: 20, color: colour),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: colour,
          ),
        ),
      ],
    );
  }

  Widget _buildTaskCard(DashboardItem item) {
    return Card(
      child: ListTile(
        leading: OwnershipBadge(ownerType: item.currentOwner, compact: true),
        title: Text(
          item.title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: item.daysAwaiting > 0
            ? Text(
                '${item.daysAwaiting} day(s) awaiting',
                style: const TextStyle(fontSize: 12, color: AppTheme.slate),
              )
            : null,
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
                taskId: item.id,
              ),
            ),
          ).then((_) => _loadData());
        },
      ),
    );
  }

  Widget _buildAwaitingGroup(MapEntry<String, List<DashboardItem>> entry) {
    final isExpanded = _expandedGroups[entry.key] ?? false;
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: OwnershipBadge(ownerType: entry.key, compact: true),
            title: Text(
              _ownerLabel(entry.key),
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.forestMist,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${entry.value.length}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.forestDeep),
                  ),
                ),
                Icon(
                  isExpanded
                      ? PhosphorIconsDuotone.caretUp
                      : PhosphorIconsDuotone.caretDown,
                  size: 18,
                  color: AppTheme.stone,
                ),
              ],
            ),
            onTap: () {
              setState(() {
                _expandedGroups[entry.key] = !isExpanded;
              });
            },
          ),
          if (isExpanded)
            ...entry.value.map(
              (item) => ListTile(
                dense: true,
                contentPadding:
                    const EdgeInsets.only(left: 56, right: 16),
                title: Text(
                  item.title,
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: item.daysAwaiting > 0
                    ? Text(
                        '${item.daysAwaiting} day(s)',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.slate),
                      )
                    : null,
                trailing: Icon(
                  PhosphorIconsDuotone.caretRight,
                  size: 16,
                  color: AppTheme.stone,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SaleTrackerTaskDetailScreen(
                        saleId: widget.saleId,
                        taskId: item.id,
                      ),
                    ),
                  ).then((_) => _loadData());
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExpiringDocCard(ExpiringDocument doc) {
    return Card(
      child: ListTile(
        leading: Icon(PhosphorIconsDuotone.warning,
            color: AppTheme.warning, size: 24),
        title: Text(doc.title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text('Expires: ${doc.expiryDate}',
            style: const TextStyle(fontSize: 12, color: AppTheme.warning)),
      ),
    );
  }

  Widget _buildNavGrid() {
    final navItems = [
      _NavItem('Stages', PhosphorIconsDuotone.steps, () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                SaleTrackerStageViewScreen(saleId: widget.saleId),
          ),
        ).then((_) => _loadData());
      }),
      _NavItem('Documents', PhosphorIconsDuotone.folderOpen, () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                SaleTrackerDocumentVaultScreen(saleId: widget.saleId),
          ),
        ).then((_) => _loadData());
      }),
      _NavItem('Enquiries', PhosphorIconsDuotone.chatCircleDots, () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                SaleTrackerEnquiriesScreen(saleId: widget.saleId),
          ),
        );
      }),
      _NavItem('Contact Log', PhosphorIconsDuotone.notebook, () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                SaleTrackerContactLogScreen(saleId: widget.saleId),
          ),
        );
      }),
      _NavItem('Timeline', PhosphorIconsDuotone.clockCounterClockwise, () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                SaleTrackerTimelineScreen(saleId: widget.saleId),
          ),
        );
      }),
      _NavItem('Prompts', PhosphorIconsDuotone.megaphone, () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                SaleTrackerPromptsScreen(saleId: widget.saleId),
          ),
        );
      }),
      _NavItem('Settings', PhosphorIconsDuotone.gear, () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                SaleTrackerSettingsScreen(saleId: widget.saleId),
          ),
        ).then((_) => _loadData());
      }),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: navItems.map((item) {
        return SizedBox(
          width: (MediaQuery.of(context).size.width - 48) / 4,
          child: InkWell(
            onTap: item.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.pebble),
              ),
              child: Column(
                children: [
                  Icon(item.icon, size: 24, color: AppTheme.forestMid),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.charcoal),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _ownerLabel(String ownerType) {
    const labels = {
      'seller': 'You',
      'seller_conveyancer': 'Your Conveyancer',
      'buyer': 'Buyer',
      'buyer_conveyancer': "Buyer's Conveyancer",
      'estate_agent': 'Estate Agent',
      'lender': 'Lender',
      'freeholder_or_managing_agent': 'Freeholder / Agent',
      'surveyor': 'Surveyor',
      'local_authority_or_search_provider': 'Local Authority',
      'other': 'Other',
    };
    return labels[ownerType] ?? ownerType;
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _NavItem(this.label, this.icon, this.onTap);
}
