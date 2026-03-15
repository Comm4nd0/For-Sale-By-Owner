class OpenHouseEvent {
  final int id;
  final int property;
  final String title;
  final String date;
  final String startTime;
  final String endTime;
  final String description;
  final int? maxAttendees;
  final bool isActive;
  final int rsvpCount;
  final bool hasCapacity;
  final bool userHasRsvpd;
  final String createdAt;

  OpenHouseEvent({
    required this.id,
    required this.property,
    required this.title,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.description,
    this.maxAttendees,
    required this.isActive,
    required this.rsvpCount,
    required this.hasCapacity,
    required this.userHasRsvpd,
    required this.createdAt,
  });

  factory OpenHouseEvent.fromJson(Map<String, dynamic> json) {
    return OpenHouseEvent(
      id: json['id'],
      property: json['property'] ?? 0,
      title: json['title'] ?? '',
      date: json['date'] ?? '',
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
      description: json['description'] ?? '',
      maxAttendees: json['max_attendees'],
      isActive: json['is_active'] ?? true,
      rsvpCount: json['rsvp_count'] ?? 0,
      hasCapacity: json['has_capacity'] ?? true,
      userHasRsvpd: json['user_has_rsvpd'] ?? false,
      createdAt: json['created_at'] ?? '',
    );
  }
}
