import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import 'push_service.dart';

/// Outcome of a login attempt. The server may either return a token
/// directly (no 2FA) or respond with a pending 2FA challenge that the
/// client must complete before a token is issued.
enum LoginStatus { success, requires2FA, invalidCredentials, failure }

class LoginResult {
  LoginResult._(this.status, {this.challengeId, this.error});
  factory LoginResult.success() => LoginResult._(LoginStatus.success);
  factory LoginResult.requires2FA(String challengeId) =>
      LoginResult._(LoginStatus.requires2FA, challengeId: challengeId);
  factory LoginResult.invalidCredentials() =>
      LoginResult._(LoginStatus.invalidCredentials);
  factory LoginResult.failure(String error) =>
      LoginResult._(LoginStatus.failure, error: error);

  final LoginStatus status;
  final String? challengeId;
  final String? error;

  bool get requires2FA => status == LoginStatus.requires2FA;
  bool get isSuccess => status == LoginStatus.success;
}

class AuthService extends ChangeNotifier {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String? _token;
  int? _userId;
  String? _email;
  String? _firstName;
  String? _lastName;
  bool _isStaff = false;
  bool _isLoading = false;
  String _userType = 'Buyer';

  /// Callbacks the bootstrap wires so non-auth concerns (e.g. push
  /// notification token registration) can react to auth changes
  /// without AuthService depending on them.
  void Function()? onAuthenticatedHook;
  void Function()? onLogoutHook;

  void _fireAuthenticated() {
    try {
      onAuthenticatedHook?.call();
    } catch (e) {
      debugPrint('onAuthenticatedHook error: $e');
    }
  }

  void _fireLogout() {
    try {
      onLogoutHook?.call();
    } catch (e) {
      debugPrint('onLogoutHook error: $e');
    }
  }

  String? get token => _token;
  int? get userId => _userId;
  String? get email => _email;
  String? get firstName => _firstName;
  String? get lastName => _lastName;
  bool get isStaff => _isStaff;
  String get userType => _userType;
  bool get isAuthenticated => _token != null;
  bool get isLoading => _isLoading;

  Future<void> init() async {
    _token = await _storage.read(key: 'auth_token');
    if (_token != null) {
      await _fetchCurrentUser();
      _fireAuthenticated();
    }
    notifyListeners();
  }

  Future<void> _fetchCurrentUser() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConstants.userMe),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $_token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _userId = data['id'];
        _email = data['email'];
        _firstName = data['first_name'];
        _lastName = data['last_name'];
      }
      // Fetch profile for is_staff flag
      final profileResponse = await http.get(
        Uri.parse(ApiConstants.profile),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $_token',
        },
      );
      if (profileResponse.statusCode == 200) {
        final profileData = jsonDecode(profileResponse.body);
        _isStaff = profileData['is_staff'] ?? false;
        _userType = profileData['user_type'] ?? 'Buyer';
      }
    } catch (e) {
      debugPrint('Fetch user error: $e');
    }
  }

  /// Attempt password login. If the user has 2FA enabled the server
  /// responds with a pending challenge rather than a token; the caller
  /// should then gather a TOTP code and call [completeTwoFactorLogin]
  /// with the challenge_id.
  Future<LoginResult> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.login),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      // 202 Accepted means the password was valid but 2FA is required.
      if (response.statusCode == 202) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final challengeId = data['challenge_id'] as String?;
        _isLoading = false;
        notifyListeners();
        if (challengeId != null) {
          return LoginResult.requires2FA(challengeId);
        }
        return LoginResult.failure('Unexpected server response.');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['auth_token'];
        await _storage.write(key: 'auth_token', value: _token);
        await _fetchCurrentUser();
        _isLoading = false;
        notifyListeners();
        _fireAuthenticated();
        return LoginResult.success();
      }

      _isLoading = false;
      notifyListeners();
      if (response.statusCode == 400 || response.statusCode == 401) {
        return LoginResult.invalidCredentials();
      }
      return LoginResult.failure('Login failed (${response.statusCode}).');
    } catch (e) {
      debugPrint('Login error: $e');
      _isLoading = false;
      notifyListeners();
      return LoginResult.failure('Network error. Please try again.');
    }
  }

  /// Complete a login that returned [LoginStatus.requires2FA] by
  /// presenting the TOTP code against the stored [challengeId]. On
  /// success the auth token is stored and the listener is notified.
  Future<LoginResult> completeTwoFactorLogin({
    required String challengeId,
    required String code,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.twoFaVerify),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'challenge_id': challengeId, 'code': code}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['auth_token'];
        await _storage.write(key: 'auth_token', value: _token);
        await _fetchCurrentUser();
        _isLoading = false;
        notifyListeners();
        _fireAuthenticated();
        return LoginResult.success();
      }

      _isLoading = false;
      notifyListeners();
      String message = 'Invalid code.';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['error'] is String) message = body['error'];
      } catch (_) {}
      if (response.statusCode == 429) {
        return LoginResult.failure(
          'Too many attempts. Please sign in again.',
        );
      }
      return LoginResult.failure(message);
    } catch (e) {
      debugPrint('2FA verify error: $e');
      _isLoading = false;
      notifyListeners();
      return LoginResult.failure('Network error. Please try again.');
    }
  }

  Future<bool> register(String email, String firstName, String lastName,
      String password, String rePassword) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.register),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'first_name': firstName,
          'last_name': lastName,
          'password': password,
          're_password': rePassword,
        }),
      );

      _isLoading = false;
      notifyListeners();
      return response.statusCode == 201;
    } catch (e) {
      debugPrint('Register error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    final authToken = _token;
    // Unregister the push device BEFORE we lose the auth token, otherwise
    // the backend call can't be authenticated and the previous user keeps
    // getting notifications on this device.
    try {
      await PushService.instance.onLogout(authToken);
    } catch (e) {
      debugPrint('PushService onLogout error: $e');
    }

    if (authToken != null) {
      try {
        await http.post(
          Uri.parse(ApiConstants.logout),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Token $authToken',
          },
        );
      } catch (e) {
        debugPrint('Logout error: $e');
      }
    }

    _token = null;
    _userId = null;
    _email = null;
    _firstName = null;
    _lastName = null;
    _isStaff = false;
    await _storage.delete(key: 'auth_token');
    _fireLogout();
    notifyListeners();
  }
}
