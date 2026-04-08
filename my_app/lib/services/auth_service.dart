import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

class AuthService extends ChangeNotifier {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String? _token;
  int? _userId;
  String? _email;
  String? _firstName;
  String? _lastName;
  bool _isStaff = false;
  bool _isLoading = false;

  String? get token => _token;
  int? get userId => _userId;
  String? get email => _email;
  String? get firstName => _firstName;
  String? get lastName => _lastName;
  bool get isStaff => _isStaff;
  bool get isAuthenticated => _token != null;
  bool get isLoading => _isLoading;

  Future<void> init() async {
    _token = await _storage.read(key: 'auth_token');
    if (_token != null) {
      await _fetchCurrentUser();
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
      }
    } catch (e) {
      debugPrint('Fetch user error: $e');
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.login),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['auth_token'];
        await _storage.write(key: 'auth_token', value: _token);
        await _fetchCurrentUser();
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Login error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
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
    if (_token != null) {
      try {
        await http.post(
          Uri.parse(ApiConstants.logout),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Token $_token',
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
    notifyListeners();
  }
}
