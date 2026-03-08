import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../models/property.dart';

class ApiService {
  final String? Function() _getToken;

  ApiService(this._getToken);

  Map<String, String> get _headers {
    final headers = {'Content-Type': 'application/json'};
    final token = _getToken();
    if (token != null) {
      headers['Authorization'] = 'Token $token';
    }
    return headers;
  }

  Future<List<Property>> getProperties() async {
    final response = await http.get(
      Uri.parse(ApiConstants.properties),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final results = data['results'] as List? ?? data as List;
      return results.map((json) => Property.fromJson(json)).toList();
    }
    throw Exception('Failed to load properties');
  }

  Future<Property> getProperty(int id) async {
    final response = await http.get(
      Uri.parse('${ApiConstants.properties}$id/'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return Property.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load property');
  }
}
