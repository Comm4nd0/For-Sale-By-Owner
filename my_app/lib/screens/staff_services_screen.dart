import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../models/service_provider.dart';
import '../services/api_service.dart';
import '../widgets/branded_app_bar.dart';
import 'service_provider_detail_screen.dart';

class StaffServicesScreen extends StatefulWidget {
  const StaffServicesScreen({super.key});

  @override
  State<StaffServicesScreen> createState() => _StaffServicesScreenState();
}

class _StaffServicesScreenState extends State<StaffServicesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _error;

  Map<String, dynamic> _counts = {};
  List<dynamic> _subscriptionBreakdown = [];
  List<ServiceProvider> _pendingProviders = [];
  List<ServiceProvider> _recentProviders = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final apiService = context.read<ApiService>();
      final data = await apiService.getServiceProviderStats();

      final pending = (data['pending_providers'] as List? ?? [])
          .map((json) => ServiceProvider.fromJson(json))
          .toList();
      final recent = (data['recent_providers'] as List? ?? [])
          .map((json) => ServiceProvider.fromJson(json))
          .toList();

      if (mounted) {
        setState(() {
          _counts = data['counts'] ?? {};
          _subscriptionBreakdown = data['subscription_breakdown'] ?? [];
          _pendingProviders = pending;
          _recentProviders = recent;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('StaffServicesScreen load error: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load data';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _performAction(int providerId, String action) async {
    try {
      final apiService = context.read<ApiService>();
      await apiService.bulkProviderAction([providerId], action);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Provider ${action}d successfully')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action failed')),
        );
      }
    }
  }

  Future<void> _verifyProvider(int providerId) async {
    try {
      final apiService = context.read<ApiService>();
      await apiService.validateServiceProvider(providerId, isVerified: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Provider verified')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification failed')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar.build(context: context, title: 'Service Management'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: AppTheme.error)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: Column(
                    children: [
                      TabBar(
                        controller: _tabController,
                        labelColor: AppTheme.forestDeep,
                        unselectedLabelColor: AppTheme.slate,
                        indicatorColor: AppTheme.forestMid,
                        tabs: [
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Pending'),
                                if (_pendingProviders.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.warning,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${_pendingProviders.length}',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Tab(text: 'Overview'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildPendingTab(),
                            _buildOverviewTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildPendingTab() {
    if (_pendingProviders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 48, color: AppTheme.stone),
            SizedBox(height: 12),
            Text('No providers pending approval',
                style: TextStyle(color: AppTheme.slate)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _pendingProviders.length,
      itemBuilder: (context, index) =>
          _buildProviderCard(_pendingProviders[index], showActions: true),
    );
  }

  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildStatsGrid(),
        if (_subscriptionBreakdown.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Subscription Breakdown',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.forestDeep)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _subscriptionBreakdown.map((s) {
              return Chip(
                label: Text('${s['tier__name']}: ${s['count']}'),
                backgroundColor: AppTheme.forestMist,
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 20),
        const Text('Recent Providers',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.forestDeep)),
        const SizedBox(height: 8),
        ..._recentProviders
            .map((p) => _buildProviderCard(p, showActions: false)),
      ],
    );
  }

  Widget _buildStatsGrid() {
    final items = [
      _StatItem('Total', _counts['total'] ?? 0, AppTheme.forestDeep),
      _StatItem('Pending', _counts['pending_review'] ?? 0, AppTheme.warning),
      _StatItem('Active', _counts['active'] ?? 0, AppTheme.forestMid),
      _StatItem('Suspended', _counts['suspended'] ?? 0, AppTheme.error),
      _StatItem('Draft', _counts['draft'] ?? 0, AppTheme.slate),
      _StatItem('Verified', _counts['verified'] ?? 0, AppTheme.info),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.4,
      children: items.map((item) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1)),
            ],
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${item.value}',
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: item.color),
              ),
              const SizedBox(height: 2),
              Text(item.label,
                  style: const TextStyle(fontSize: 12, color: AppTheme.slate)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProviderCard(ServiceProvider provider, {required bool showActions}) {
    final statusLabel = (provider.status ?? 'draft').replaceAll('_', ' ');
    final statusColor = _statusColor(provider.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ServiceProviderDetailScreen(providerId: provider.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      provider.businessName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppTheme.charcoal),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  PhosphorIcon(PhosphorIconsDuotone.user, size: 14, color: AppTheme.slate),
                  const SizedBox(width: 4),
                  Text(provider.ownerName ?? '-',
                      style: const TextStyle(fontSize: 13, color: AppTheme.slate)),
                  const SizedBox(width: 12),
                  if (provider.isVerified)
                    Row(
                      children: [
                        PhosphorIcon(PhosphorIconsDuotone.sealCheck,
                            size: 14, color: AppTheme.forestMid),
                        const SizedBox(width: 2),
                        const Text('Verified',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.forestMid)),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                provider.categories.map((c) => c.name).join(', '),
                style: const TextStyle(fontSize: 12, color: AppTheme.stone),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (showActions) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (provider.status != 'active')
                      _actionButton('Approve', AppTheme.forestMid,
                          () => _performAction(provider.id, 'approve')),
                    if (provider.status != 'suspended') ...[
                      const SizedBox(width: 8),
                      _actionButton('Suspend', AppTheme.error,
                          () => _performAction(provider.id, 'suspend')),
                    ],
                    if (!provider.isVerified) ...[
                      const SizedBox(width: 8),
                      _actionButton('Verify', AppTheme.info,
                          () => _verifyProvider(provider.id)),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      ),
    );
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'active':
        return AppTheme.forestMid;
      case 'pending_review':
        return AppTheme.warning;
      case 'suspended':
        return AppTheme.error;
      case 'withdrawn':
        return AppTheme.slate;
      default:
        return AppTheme.stone;
    }
  }
}

class _StatItem {
  final String label;
  final int value;
  final Color color;
  const _StatItem(this.label, this.value, this.color);
}
