class NotificationCounts {
  final int unreadEnquiries;
  final int pendingViewings;
  final int unreadChats;
  final int pendingOffers;

  NotificationCounts({
    required this.unreadEnquiries,
    required this.pendingViewings,
    required this.unreadChats,
    required this.pendingOffers,
  });

  int get total => unreadEnquiries + pendingViewings + unreadChats + pendingOffers;

  factory NotificationCounts.fromJson(Map<String, dynamic> json) {
    return NotificationCounts(
      unreadEnquiries: json['unread_enquiries'] ?? 0,
      pendingViewings: json['pending_viewings'] ?? 0,
      unreadChats: json['unread_chats'] ?? 0,
      pendingOffers: json['pending_offers'] ?? 0,
    );
  }
}
