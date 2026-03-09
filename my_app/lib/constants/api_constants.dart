import 'dart:io' show Platform;

class ApiConstants {
  static const bool _useProduction = false;

  // Android emulator uses 10.0.2.2 to reach host; iOS simulator uses localhost
  static const String _androidLocalUrl = 'http://10.0.2.2:8000';
  static const String _iosLocalUrl = 'http://localhost:8000';
  static const String _prodUrl = 'http://178.104.29.66:8002';

  static String get _localUrl =>
      Platform.isIOS ? _iosLocalUrl : _androidLocalUrl;

  static String get baseUrl => _useProduction ? _prodUrl : _localUrl;
  static String get apiUrl => '$baseUrl/api';
  static String get authUrl => '$baseUrl/auth';

  // Properties
  static String get properties => '$apiUrl/properties/';
  static String propertyImages(int propertyId) =>
      '$apiUrl/properties/$propertyId/images/';
  static String propertyImage(int propertyId, int imageId) =>
      '$apiUrl/properties/$propertyId/images/$imageId/';

  // Auth
  static String get login => '$authUrl/token/login/';
  static String get logout => '$authUrl/token/logout/';
  static String get register => '$authUrl/users/';
  static String get userMe => '$authUrl/users/me/';
}
