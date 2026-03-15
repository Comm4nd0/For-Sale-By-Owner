class NotificationCounts {
  final int pendingViewings;
  final int unreadMessages;
  final int pendingOffers;

  NotificationCounts({
    required this.pendingViewings,
    required this.unreadMessages,
    required this.pendingOffers,
  });

  int get total => pendingViewings + unreadMessages + pendingOffers;

  factory NotificationCounts.fromJson(Map<String, dynamic> json) {
    return NotificationCounts(
      pendingViewings: json['pending_viewings'] ?? 0,
      unreadMessages: json['unread_messages'] ?? 0,
      pendingOffers: json['pending_offers'] ?? 0,
    );
  }
}
