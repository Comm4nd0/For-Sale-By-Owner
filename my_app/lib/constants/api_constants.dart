import 'dart:io' show Platform;

class ApiConstants {
  static const bool _useProduction = true;

  // Android emulator uses 10.0.2.2 to reach host; iOS simulator uses localhost
  static const String _androidLocalUrl = 'http://10.0.2.2:8000';
  static const String _iosLocalUrl = 'http://localhost:8000';
  static const String _prodUrl = 'http://178.104.29.66:8002';

  static String get _localUrl =>
      Platform.isIOS ? _iosLocalUrl : _androidLocalUrl;

  static String get baseUrl => _useProduction ? _prodUrl : _localUrl;
  static String get apiUrl => '$baseUrl/api';
  static String get authUrl => '$baseUrl/auth';

  /// Prepend baseUrl to relative image/file URLs from the API.
  static String fullUrl(String relativeUrl) {
    if (relativeUrl.startsWith('http')) return relativeUrl;
    return '$baseUrl$relativeUrl';
  }

  // Properties
  static String get properties => '$apiUrl/properties/';
  static String propertyDetail(int id) => '$apiUrl/properties/$id/';
  static String propertySimilar(int id) => '$apiUrl/properties/$id/similar/';
  static String propertyImages(int propertyId) =>
      '$apiUrl/properties/$propertyId/images/';
  static String propertyImage(int propertyId, int imageId) =>
      '$apiUrl/properties/$propertyId/images/$imageId/';
  static String propertyImagesReorder(int propertyId) =>
      '$apiUrl/properties/$propertyId/images/reorder/';

  // Floorplans
  static String propertyFloorplans(int propertyId) =>
      '$apiUrl/properties/$propertyId/floorplans/';
  static String propertyFloorplan(int propertyId, int floorplanId) =>
      '$apiUrl/properties/$propertyId/floorplans/$floorplanId/';

  // Save toggle
  static String propertySave(int propertyId) =>
      '$apiUrl/properties/$propertyId/save/';

  // Saved properties
  static String get savedProperties => '$apiUrl/saved/';
  static String savedProperty(int id) => '$apiUrl/saved/$id/';

  // Enquiries
  static String get enquiries => '$apiUrl/enquiries/';
  static String get receivedEnquiries => '$apiUrl/enquiries/received/';
  static String enquiryDetail(int id) => '$apiUrl/enquiries/$id/';
  static String enquiryReply(int id) => '$apiUrl/enquiries/$id/reply/';

  // Viewings
  static String get viewings => '$apiUrl/viewings/';
  static String get receivedViewings => '$apiUrl/viewings/received/';
  static String viewingDetail(int id) => '$apiUrl/viewings/$id/';
  static String viewingUpdateStatus(int id) =>
      '$apiUrl/viewings/$id/update_status/';
  static String viewingReply(int id) => '$apiUrl/viewings/$id/reply/';

  // Saved searches
  static String get savedSearches => '$apiUrl/saved-searches/';
  static String savedSearch(int id) => '$apiUrl/saved-searches/$id/';

  // Features
  static String get features => '$apiUrl/features/';

  // Dashboard & notifications
  static String get dashboardStats => '$apiUrl/dashboard/stats/';
  static String get notificationCounts => '$apiUrl/notifications/counts/';

  // Profile
  static String get profile => '$apiUrl/profile/';

  // Services
  static String get serviceCategories => '$apiUrl/service-categories/';
  static String get serviceProviders => '$apiUrl/service-providers/';
  static String serviceProviderDetail(dynamic idOrSlug) =>
      '$apiUrl/service-providers/$idOrSlug/';
  static String serviceProviderReviews(int providerId) =>
      '$apiUrl/service-providers/$providerId/reviews/';
  static String serviceProviderReview(int providerId, int reviewId) =>
      '$apiUrl/service-providers/$providerId/reviews/$reviewId/';
  static String propertyServices(int propertyId) =>
      '$apiUrl/properties/$propertyId/services/';

  // Auth
  static String get login => '$authUrl/token/login/';
  static String get logout => '$authUrl/token/logout/';
  static String get register => '$authUrl/users/';
  static String get userMe => '$authUrl/users/me/';
  static String get changePassword => '$authUrl/users/set_password/';
}
