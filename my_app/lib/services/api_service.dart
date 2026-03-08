import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../constants/api_constants.dart';
import '../models/property.dart';
import '../models/property_image.dart';

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

  Map<String, String> get _authHeaders {
    final headers = <String, String>{};
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

  Future<PropertyImage> uploadPropertyImage(int propertyId, XFile imageFile) async {
    final uri = Uri.parse(ApiConstants.propertyImages(propertyId));
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_authHeaders)
      ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201) {
      return PropertyImage.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to upload image');
  }

  Future<void> deletePropertyImage(int propertyId, int imageId) async {
    final response = await http.delete(
      Uri.parse(ApiConstants.propertyImage(propertyId, imageId)),
      headers: _authHeaders,
    );
    if (response.statusCode != 204) {
      throw Exception('Failed to delete image');
    }
  }

  Future<void> updatePropertyImage(
    int propertyId,
    int imageId, {
    int? order,
    bool? isPrimary,
    String? caption,
  }) async {
    final body = <String, dynamic>{};
    if (order != null) body['order'] = order;
    if (isPrimary != null) body['is_primary'] = isPrimary;
    if (caption != null) body['caption'] = caption;

    final response = await http.patch(
      Uri.parse(ApiConstants.propertyImage(propertyId, imageId)),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update image');
    }
  }
}
