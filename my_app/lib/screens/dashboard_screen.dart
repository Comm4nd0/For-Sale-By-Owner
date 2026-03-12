import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../widgets/branded_app_bar.dart';
import '../widgets/skeleton_loading.dart';
import '../models/dashboard_stats.dart';
import '../models/notification_counts.dart';
import '../models/enquiry.dart';
import '../models/viewing_request.dart';
import '../models/offer.dart';
import '../models/chat_room.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'enquiry_detail_screen.dart';
import 'viewing_detail_screen.dart';
import 'offers_screen.dart';
import 'edit_offer_screen.dart';
import 'chat_screen.dart';
import '../widgets/scroll_to_top_button.dart';

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
  NotificationCounts? _counts;

  late Future<List<Enquiry>> _enquiriesFuture;
  late Future<List<ViewingRequest>> _viewingsFuture;
  late Future<List<Offer>> _offersFuture;
  late Future<List<ChatRoom>> _messagesFuture;
  late TabController _tabController;
  final ScrollController _enquiriesScrollController = ScrollController();
  final ScrollController _viewingsScrollController = ScrollController();
  final ScrollController _offersScrollController = ScrollController();
  final ScrollController _messagesScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    final authService = context.read<AuthService>();
    if (authService.isAuthenticated) {
      _loadStats();
      _loadCounts();
      _loadEnquiries();
      _loadViewings();
      _loadOffers();
      _loadMessages();
    } else {
      _statsLoading = false;
      _enquiriesFuture = Future.value([]);
      _viewingsFuture = Future.value([]);
      _offersFuture = Future.value([]);
      _messagesFuture = Future.value([]);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _enquiriesScrollController.dispose();
    _viewingsScrollController.dispose();
    _offersScrollController.dispose();
    _messagesScrollController.dispose();
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

  Future<void> _loadCounts() async {
    try {
      final apiService = context.read<ApiService>();
      final counts = await apiService.getNotificationCounts();
      if (mounted) setState(() => _counts = counts);
    } catch (_) {}
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

  void _loadOffers() {
    final apiService = context.read<ApiService>();
    final userId = context.read<AuthService>().userId;
    // Load both received offers (as seller) and sent offers (as buyer)
    _offersFuture = Future.wait([
      apiService.getOffers(received: true),
      apiService.getOffers(),
    ]).then((results) {
      final received = results[0];
      final all = results[1];
      final sent = all.where((o) => o.buyerId == userId).toList();
      // Combine: received first, then sent (avoiding duplicates)
      final receivedIds = received.map((o) => o.id).toSet();
      final combined = <Offer>[...received];
      for (final o in sent) {
        if (!receivedIds.contains(o.id)) combined.add(o);
      }
      return combined;
    });
  }

  void _loadMessages() {
    final apiService = context.read<ApiService>();
    _messagesFuture = apiService.getChatRooms();
  }

  Future<void> _refreshAll() async {
    await _loadStats();
    _loadCounts();
    setState(() {
      _loadEnquiries();
      _loadViewings();
      _loadOffers();
      _loadMessages();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    if (!authService.isAuthenticated) {
      return Scaffold(
        appBar: BrandedAppBar.build(context: context),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppTheme.forestMist,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.login, size: 44, color: AppTheme.forestMid),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Login Required',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.charcoal,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please log in to view your dashboard.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.slate, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      floatingActionButton: ScrollToTopButton(
        scrollController: [
          _enquiriesScrollController,
          _viewingsScrollController,
          _offersScrollController,
          _messagesScrollController,
        ][_tabController.index],
      ),
      appBar: BrandedAppBar.build(
        context: context,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            _buildTabLabel('Enquiries', _counts?.unreadEnquiries ?? 0),
            _buildTabLabel('Viewings', _counts?.pendingViewings ?? 0),
            _buildTabLabel('Offers', _counts?.pendingOffers ?? 0),
            _buildTabLabel('Messages', _counts?.unreadChats ?? 0),
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
                _buildOffersTab(),
                _buildMessagesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabLabel(String label, int count) {
    return Tab(
      child: count > 0
          ? Badge(
              label: Text(
                '$count',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
              backgroundColor: AppTheme.goldEmber,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(label),
              ),
            )
          : Text(label),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          _buildStatChip(Icons.home, 'Listings', stats.activeListings, null),
          _buildStatChip(Icons.visibility, 'Views', stats.totalViews, null),
          _buildStatChip(
            Icons.mail,
            'Enquiries',
            stats.totalEnquiries,
            stats.unreadEnquiries > 0 ? AppTheme.goldEmber : null,
          ),
          _buildStatChip(Icons.favorite, 'Saved', stats.totalSaves, null),
          _buildStatChip(
            Icons.calendar_today,
            'Viewings',
            stats.pendingViewings,
            null,
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(
      IconData icon, String label, int count, Color? highlight) {
    return Expanded(
      child: Semantics(
        label: '$label: $count',
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.pebble),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: highlight ?? AppTheme.forestMid),
              const SizedBox(height: 2),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: highlight ?? AppTheme.charcoal,
                ),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 10, color: AppTheme.slate),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
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
                      child: Icon(Icons.error_outline, size: 32, color: Colors.red[300]),
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
            controller: _enquiriesScrollController,
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
                      child: Icon(Icons.error_outline, size: 32, color: Colors.red[300]),
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
            controller: _viewingsScrollController,
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

  Widget _buildOffersTab() {
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: FutureBuilder<List<Offer>>(
        future: _offersFuture,
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
                      child: Icon(Icons.error_outline, size: 32, color: Colors.red[300]),
                    ),
                    const SizedBox(height: 16),
                    const Text('Failed to load offers'),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _loadOffers()),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final offers = snapshot.data ?? [];

          if (offers.isEmpty) {
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
                      child: const Icon(Icons.gavel, size: 36, color: AppTheme.forestMid),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No Offers Yet',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your received and sent offers will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.slate, height: 1.5),
                    ),
                  ],
                ),
              ),
            );
          }

          final userId = context.read<AuthService>().userId;

          return ListView.builder(
            controller: _offersScrollController,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: offers.length + 1,
            itemBuilder: (context, index) {
              if (index == offers.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: OutlinedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const OffersScreen(received: true)),
                    ),
                    child: const Text('View All Offers'),
                  ),
                );
              }

              final offer = offers[index];
              final isSentByMe = offer.buyerId == userId;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              offer.propertyTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          _buildOfferStatusBadge(offer.status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isSentByMe ? 'Your offer' : 'From: ${offer.buyerName}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isSentByMe ? AppTheme.forestMid : AppTheme.slate,
                          fontWeight: isSentByMe ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            offer.formattedAmount,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.charcoal,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (offer.isCashBuyer) _buildOfferTag('Cash'),
                          if (offer.isChainFree) _buildOfferTag('Chain Free'),
                        ],
                      ),
                      if (offer.counterAmount != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Counter: \u00A3${offer.counterAmount!.toStringAsFixed(0)}',
                          style: const TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                      // Received offer actions (seller view)
                      if (!isSentByMe && offer.status == 'submitted') ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _respondToOffer(offer.id, 'accepted'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                child: const Text('Accept', style: TextStyle(fontSize: 13)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _respondToOffer(offer.id, 'rejected'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                child: const Text('Reject', style: TextStyle(fontSize: 13)),
                              ),
                            ),
                          ],
                        ),
                      ],
                      // Sent offer actions (buyer view)
                      if (isSentByMe && (offer.status == 'submitted' || offer.status == 'under_review' || offer.status == 'countered')) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (offer.status == 'submitted')
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => EditOfferScreen(offer: offer),
                                      ),
                                    );
                                    if (result == true) setState(() => _loadOffers());
                                  },
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  child: const Text('Edit', style: TextStyle(fontSize: 13)),
                                ),
                              ),
                            if (offer.status == 'submitted') const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _withdrawDashOffer(offer),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                child: const Text('Withdraw', style: TextStyle(fontSize: 13)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMessagesTab() {
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: FutureBuilder<List<ChatRoom>>(
        future: _messagesFuture,
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
                      child: Icon(Icons.error_outline, size: 32, color: Colors.red[300]),
                    ),
                    const SizedBox(height: 16),
                    const Text('Failed to load messages'),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _loadMessages()),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final rooms = snapshot.data ?? [];

          if (rooms.isEmpty) {
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
                      child: const Icon(Icons.chat_bubble_outline, size: 36, color: AppTheme.forestMid),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No Messages Yet',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Start a conversation by messaging a seller from a property listing.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.slate, height: 1.5),
                    ),
                  ],
                ),
              ),
            );
          }

          final userId = context.read<AuthService>().userId;

          return ListView.builder(
            controller: _messagesScrollController,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final room = rooms[index];
              final otherName = room.buyerId == userId
                  ? room.sellerName
                  : room.buyerName;
              final initial = otherName.isNotEmpty
                  ? otherName[0].toUpperCase()
                  : '?';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.forestMist,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.forestMid,
                      ),
                    ),
                  ),
                  title: Text(
                    otherName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: room.unreadCount > 0
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Re: ${room.propertyTitle}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: AppTheme.forestMid),
                      ),
                      if (room.lastMessage != null)
                        Text(
                          room.lastMessage!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (room.lastMessageAt != null)
                        Text(
                          _formatMessageTime(room.lastMessageAt!),
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      if (room.unreadCount > 0) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.forestMid,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${room.unreadCount}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(room: room),
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

  Future<void> _respondToOffer(int offerId, String status) async {
    try {
      final apiService = context.read<ApiService>();
      await apiService.respondToOffer(offerId, status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Offer $status successfully'),
            backgroundColor: status == 'accepted' ? Colors.green : Colors.orange,
          ),
        );
        setState(() => _loadOffers());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to respond to offer'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _withdrawDashOffer(Offer offer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw Offer'),
        content: Text('Are you sure you want to withdraw your ${offer.formattedAmount} offer on ${offer.propertyTitle}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final apiService = context.read<ApiService>();
      await apiService.withdrawOffer(offer.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offer withdrawn'), backgroundColor: Colors.green),
        );
        setState(() => _loadOffers());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to withdraw offer'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildOfferStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'submitted':
        color = Colors.blue;
        break;
      case 'under_review':
        color = Colors.orange;
        break;
      case 'accepted':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      case 'countered':
        color = Colors.amber[700]!;
        break;
      case 'withdrawn':
      case 'expired':
        color = Colors.grey;
        break;
      default:
        color = Colors.grey;
    }

    return Semantics(
      label: 'Status: $status',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          status.replaceAll('_', ' '),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildOfferTag(String label) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: Colors.green[700], fontWeight: FontWeight.w600),
      ),
    );
  }

  String _formatMessageTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'now';
      if (diff.inHours < 1) return '${diff.inMinutes}m';
      if (diff.inDays < 1) return '${diff.inHours}h';
      if (diff.inDays < 7) {
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return days[date.weekday - 1];
      }
      return '${date.day}/${date.month}';
    } catch (_) {
      return '';
    }
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
