class NotificationCounts {
  final int unreadEnquiries;
  final int pendingViewings;

  NotificationCounts({
    required this.unreadEnquiries,
    required this.pendingViewings,
  });

  int get total => unreadEnquiries + pendingViewings;

  factory NotificationCounts.fromJson(Map<String, dynamic> json) {
    return NotificationCounts(
      unreadEnquiries: json['unread_enquiries'] ?? 0,
      pendingViewings: json['pending_viewings'] ?? 0,
    );
  }
}
