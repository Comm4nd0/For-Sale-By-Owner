class ViewingSlot {
  final int id;
  final int propertyId;
  final String? date;
  final int? dayOfWeek;
  final String startTime;
  final String endTime;
  final int maxBookings;
  final int currentBookings;
  final bool isAvailable;

  ViewingSlot({
    required this.id,
    required this.propertyId,
    this.date,
    this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.maxBookings,
    required this.currentBookings,
    required this.isAvailable,
  });

  factory ViewingSlot.fromJson(Map<String, dynamic> json) {
    return ViewingSlot(
      id: json['id'],
      propertyId: json['property'] ?? 0,
      date: json['date'],
      dayOfWeek: json['day_of_week'],
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
      maxBookings: json['max_bookings'] ?? 1,
      currentBookings: json['current_bookings'] ?? 0,
      isAvailable: json['is_available'] ?? true,
    );
  }

  String get dayOfWeekDisplay {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];
    if (dayOfWeek != null && dayOfWeek! >= 0 && dayOfWeek! < 7) {
      return days[dayOfWeek!];
    }
    return '';
  }

  String get displayDate {
    if (date != null && date!.isNotEmpty) return date!;
    return dayOfWeekDisplay;
  }
}
