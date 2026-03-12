class UserProfile {
  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String phone;
  final bool darkMode;
  final bool notificationEnquiries;
  final bool notificationViewings;
  final bool notificationPriceDrops;
  final bool notificationSavedSearches;

  UserProfile({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.darkMode,
    required this.notificationEnquiries,
    required this.notificationViewings,
    required this.notificationPriceDrops,
    required this.notificationSavedSearches,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      email: json['email'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      phone: json['phone'] ?? '',
      darkMode: json['dark_mode'] ?? false,
      notificationEnquiries: json['notification_enquiries'] ?? true,
      notificationViewings: json['notification_viewings'] ?? true,
      notificationPriceDrops: json['notification_price_drops'] ?? true,
      notificationSavedSearches: json['notification_saved_searches'] ?? true,
    );
  }
}
