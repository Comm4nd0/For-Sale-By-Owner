import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../widgets/branded_app_bar.dart';
import '../widgets/skeleton_loading.dart';
import '../models/dashboard_stats.dart';
import '../models/enquiry.dart';
import '../models/viewing_request.dart';
import '../services/api_service.dart';
import 'enquiry_detail_screen.dart';
import 'viewing_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  DashboardStats? _stats;
  bool _statsLoading = true;
  String? _statsError;

  late Future<List<Enquiry>> _enquiriesFuture;
  late Future<List<ViewingRequest>> _viewingsFuture;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStats();
    _loadEnquiries();
    _loadViewings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() {
      _statsLoading = true;
      _statsError = null;
    });

    try {
      final apiService = context.read<ApiService>();
      final stats = await apiService.getDashboardStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _statsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statsError = 'Failed to load stats';
          _statsLoading = false;
        });
      }
    }
  }

  void _loadEnquiries() {
    final apiService = context.read<ApiService>();
    _enquiriesFuture =
        apiService.getReceivedEnquiries().then((r) => r.results);
  }

  void _loadViewings() {
    final apiService = context.read<ApiService>();
    _viewingsFuture =
        apiService.getReceivedViewings().then((r) => r.results);
  }

  Future<void> _refreshAll() async {
    await _loadStats();
    setState(() {
      _loadEnquiries();
      _loadViewings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar.build(
        context: context,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Enquiries'),
            Tab(text: 'Viewings'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildStatsSection(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEnquiriesTab(),
                _buildViewingsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    if (_statsLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_statsError != null || _stats == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: TextButton(
            onPressed: _loadStats,
            child: const Text('Retry loading stats'),
          ),
        ),
      );
    }

    final stats = _stats!;

    return SizedBox(
      height: 116,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        children: [
          _buildStatCard(
            Icons.home,
            'Active Listings',
            stats.activeListings,
            null,
          ),
          _buildStatCard(
            Icons.visibility,
            'Total Views',
            stats.totalViews,
            null,
          ),
          _buildStatCard(
            Icons.mail,
            'Enquiries',
            stats.totalEnquiries,
            stats.unreadEnquiries > 0 ? AppTheme.goldEmber : null,
          ),
          _buildStatCard(
            Icons.favorite,
            'Saved',
            stats.totalSaves,
            null,
          ),
          _buildStatCard(
            Icons.calendar_today,
            'Pending Viewings',
            stats.pendingViewings,
            null,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      IconData icon, String label, int count, Color? highlight) {
    return Semantics(
      label: '$label: $count',
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.pebble),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: highlight ?? AppTheme.forestMid),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: highlight ?? AppTheme.charcoal,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: AppTheme.slate),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnquiriesTab() {
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: FutureBuilder<List<Enquiry>>(
        future: _enquiriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SkeletonList(count: 3);
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.wifi_off, size: 32, color: Colors.red[300]),
                    ),
                    const SizedBox(height: 16),
                    const Text('Failed to load enquiries'),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _loadEnquiries()),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final enquiries = snapshot.data ?? [];

          if (enquiries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppTheme.forestMist,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.mail_outline, size: 36, color: AppTheme.forestMid),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No Enquiries Yet',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'When buyers send you messages about your properties, they\'ll appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.slate, height: 1.5),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: enquiries.length,
            itemBuilder: (context, index) {
              final enquiry = enquiries[index];
              return Card(
                child: ListTile(
                  leading: !enquiry.isRead
                      ? Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        )
                      : const SizedBox(width: 10),
                  title: Text(
                    enquiry.propertyTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: enquiry.isRead
                          ? FontWeight.normal
                          : FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        enquiry.senderName.isNotEmpty
                            ? enquiry.senderName
                            : enquiry.name,
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.forestMid),
                      ),
                      Text(
                        enquiry.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  trailing: Text(
                    _formatDate(enquiry.createdAt),
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[500]),
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            EnquiryDetailScreen(enquiry: enquiry),
                      ),
                    );
                    _refreshAll();
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildViewingsTab() {
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: FutureBuilder<List<ViewingRequest>>(
        future: _viewingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SkeletonList(count: 3);
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.wifi_off, size: 32, color: Colors.red[300]),
                    ),
                    const SizedBox(height: 16),
                    const Text('Failed to load viewings'),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _loadViewings()),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final viewings = snapshot.data ?? [];

          if (viewings.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppTheme.forestMist,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.calendar_today, size: 36, color: AppTheme.forestMid),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No Viewing Requests',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'When buyers request to view your properties, they\'ll appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.slate, height: 1.5),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: viewings.length,
            itemBuilder: (context, index) {
              final viewing = viewings[index];
              return Card(
                child: ListTile(
                  title: Text(
                    viewing.propertyTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        viewing.requesterName.isNotEmpty
                            ? viewing.requesterName
                            : viewing.name,
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.forestMid),
                      ),
                      Text(
                        '${viewing.preferredDate} at ${viewing.preferredTime}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  trailing: _buildViewingStatusBadge(viewing.status),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ViewingDetailScreen(viewing: viewing),
                      ),
                    );
                    _refreshAll();
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildViewingStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'pending':
        color = Colors.orange;
        break;
      case 'confirmed':
        color = Colors.green;
        break;
      case 'declined':
        color = Colors.red;
        break;
      case 'completed':
        color = Colors.blue;
        break;
      case 'cancelled':
        color = Colors.grey;
        break;
      default:
        color = Colors.grey;
    }

    return Semantics(
      label: 'Status: $status',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          status,
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }
}
