class ApiConstants {
  static const bool _useProduction = false;

  static const String _localUrl = 'http://10.0.2.2:8000'; // Android emulator -> host
  static const String _prodUrl = 'http://178.104.29.66:8002';

  static String get baseUrl => _useProduction ? _prodUrl : _localUrl;
  static String get apiUrl => '$baseUrl/api';
  static String get authUrl => '$baseUrl/auth';

  // Properties
  static String get properties => '$apiUrl/properties/';

  // Auth
  static String get login => '$authUrl/token/login/';
  static String get logout => '$authUrl/token/logout/';
  static String get register => '$authUrl/users/';
  static String get userMe => '$authUrl/users/me/';
}
