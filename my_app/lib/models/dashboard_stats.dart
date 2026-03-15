class DashboardStats {
  final int totalListings;
  final int activeListings;
  final int totalViews;
  final int totalMessages;
  final int unreadMessages;
  final int totalSaves;
  final int pendingViewings;
  final int totalOffers;
  final int pendingOffers;
  final double? messageConversionRate;
  final List<ViewsByDay> viewsByDay;
  final List<PropertyStat> propertyStats;

  DashboardStats({
    required this.totalListings,
    required this.activeListings,
    required this.totalViews,
    required this.totalMessages,
    required this.unreadMessages,
    required this.totalSaves,
    required this.pendingViewings,
    required this.totalOffers,
    required this.pendingOffers,
    this.messageConversionRate,
    required this.viewsByDay,
    required this.propertyStats,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalListings: json['total_listings'] ?? 0,
      activeListings: json['active_listings'] ?? 0,
      totalViews: json['total_views'] ?? 0,
      totalMessages: json['total_messages'] ?? 0,
      unreadMessages: json['unread_messages'] ?? 0,
      totalSaves: json['total_saves'] ?? 0,
      pendingViewings: json['pending_viewings'] ?? 0,
      totalOffers: json['total_offers'] ?? 0,
      pendingOffers: json['pending_offers'] ?? 0,
      messageConversionRate: json['message_conversion_rate'] != null
          ? double.tryParse(json['message_conversion_rate'].toString())
          : null,
      viewsByDay: (json['views_by_day'] as List? ?? [])
          .map((v) => ViewsByDay.fromJson(v))
          .toList(),
      propertyStats: (json['property_stats'] as List? ?? [])
          .map((p) => PropertyStat.fromJson(p))
          .toList(),
    );
  }
}

class ViewsByDay {
  final String date;
  final int count;

  ViewsByDay({required this.date, required this.count});

  factory ViewsByDay.fromJson(Map<String, dynamic> json) {
    return ViewsByDay(
      date: json['date'] ?? '',
      count: json['count'] ?? 0,
    );
  }
}

class PropertyStat {
  final int id;
  final String title;
  final int views;
  final int messages;
  final int saves;
  final int offers;
  final List<String> tips;

  PropertyStat({
    required this.id,
    required this.title,
    required this.views,
    required this.messages,
    required this.saves,
    required this.offers,
    required this.tips,
  });

  factory PropertyStat.fromJson(Map<String, dynamic> json) {
    return PropertyStat(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      views: json['views'] ?? 0,
      messages: json['messages'] ?? 0,
      saves: json['saves'] ?? 0,
      offers: json['offers'] ?? 0,
      tips: (json['tips'] as List? ?? []).cast<String>(),
    );
  }
}
