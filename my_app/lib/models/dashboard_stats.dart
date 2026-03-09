class DashboardStats {
  final int totalListings;
  final int activeListings;
  final int totalViews;
  final int totalEnquiries;
  final int unreadEnquiries;
  final int totalSaves;
  final int pendingViewings;

  DashboardStats({
    required this.totalListings,
    required this.activeListings,
    required this.totalViews,
    required this.totalEnquiries,
    required this.unreadEnquiries,
    required this.totalSaves,
    required this.pendingViewings,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalListings: json['total_listings'] ?? 0,
      activeListings: json['active_listings'] ?? 0,
      totalViews: json['total_views'] ?? 0,
      totalEnquiries: json['total_enquiries'] ?? 0,
      unreadEnquiries: json['unread_enquiries'] ?? 0,
      totalSaves: json['total_saves'] ?? 0,
      pendingViewings: json['pending_viewings'] ?? 0,
    );
  }
}
