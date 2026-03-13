class ViewingSlot {
  final int id;
  final int propertyId;
  final String? date;
  final int? dayOfWeek;
  final String? dayDisplay;
  final String startTime;
  final String endTime;
  final int maxBookings;
  final int currentBookings;
  final bool isAvailable;
  final bool isActive;

  ViewingSlot({
    required this.id,
    required this.propertyId,
    this.date,
    this.dayOfWeek,
    this.dayDisplay,
    required this.startTime,
    required this.endTime,
    required this.maxBookings,
    required this.currentBookings,
    required this.isAvailable,
    this.isActive = true,
  });

  bool get isRecurring => date == null && dayOfWeek != null;

  factory ViewingSlot.fromJson(Map<String, dynamic> json) {
    return ViewingSlot(
      id: json['id'],
      propertyId: json['property'] ?? 0,
      date: json['date'],
      dayOfWeek: json['day_of_week'],
      dayDisplay: json['day_display'],
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
      maxBookings: json['max_bookings'] ?? 1,
      currentBookings: json['current_bookings'] ?? 0,
      isAvailable: json['is_available'] ?? true,
      isActive: json['is_active'] ?? true,
    );
  }

  String get dayOfWeekDisplay {
    if (dayDisplay != null && dayDisplay!.isNotEmpty) return dayDisplay!;
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];
    if (dayOfWeek != null && dayOfWeek! >= 0 && dayOfWeek! < 7) {
      return days[dayOfWeek!];
    }
    return '';
  }

  String get displayTitle {
    if (isRecurring) {
      return 'Every $dayOfWeekDisplay';
    }
    if (date != null && date!.isNotEmpty) return date!;
    return dayOfWeekDisplay;
  }
}
