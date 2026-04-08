import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../constants/api_constants.dart';
import '../models/paginated_response.dart';
import '../models/property.dart';
import '../models/property_image.dart';
import '../models/property_feature.dart';
import '../models/property_floorplan.dart';
import '../models/saved_property.dart';
import '../models/viewing_request.dart';
import '../models/reply.dart';
import '../models/saved_search.dart';
import '../models/dashboard_stats.dart';
import '../models/notification_counts.dart';
import '../models/user_profile.dart';
import '../models/service_category.dart';
import '../models/service_provider.dart';
import '../models/service_provider_review.dart';
import '../models/chat_room.dart';
import '../models/chat_message.dart';
import '../models/offer.dart';
import '../models/property_document.dart';
import '../models/property_flag.dart';
import '../models/viewing_slot.dart';
import '../models/mortgage_calculation.dart';
import '../models/neighbourhood_info.dart';

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

  static const _timeout = Duration(seconds: 15);

  String _extractError(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map) {
        if (body.containsKey('detail')) return body['detail'].toString();
        // Collect field-level errors (e.g. {"business_name": ["This field is required."]})
        final messages = <String>[];
        body.forEach((key, value) {
          if (value is List) {
            messages.add('$key: ${value.join(', ')}');
          } else {
            messages.add('$key: $value');
          }
        });
        if (messages.isNotEmpty) return messages.join('; ');
      }
    } catch (_) {}
    return 'Request failed (${response.statusCode})';
  }

  Map<String, String> get _authHeaders {
    final headers = <String, String>{};
    final token = _getToken();
    if (token != null) {
      headers['Authorization'] = 'Token $token';
    }
    return headers;
  }

  Map<String, String> get _authJsonHeaders {
    final headers = {'Content-Type': 'application/json'};
    final token = _getToken();
    if (token != null) {
      headers['Authorization'] = 'Token $token';
    }
    return headers;
  }

  // ── Properties ──────────────────────────────────────────────────────

  Future<PaginatedResponse<Property>> getProperties({
    String? location,
    String? propertyType,
    double? minPrice,
    double? maxPrice,
    int? minBedrooms,
    int? minBathrooms,
    String? epcRating,
    bool? mine,
    double? lat,
    double? lon,
    double? radius,
    int page = 1,
  }) async {
    final params = <String, String>{'page': page.toString()};
    if (location != null && location.isNotEmpty) params['location'] = location;
    if (propertyType != null && propertyType.isNotEmpty) {
      params['property_type'] = propertyType;
    }
    if (minPrice != null) params['min_price'] = minPrice.toStringAsFixed(0);
    if (maxPrice != null) params['max_price'] = maxPrice.toStringAsFixed(0);
    if (minBedrooms != null) params['min_bedrooms'] = minBedrooms.toString();
    if (minBathrooms != null) params['min_bathrooms'] = minBathrooms.toString();
    if (epcRating != null && epcRating.isNotEmpty) {
      params['epc_rating'] = epcRating;
    }
    if (mine == true) params['mine'] = 'true';
    if (lat != null) params['lat'] = lat.toString();
    if (lon != null) params['lon'] = lon.toString();
    if (radius != null) params['radius'] = radius.toString();

    final uri =
        Uri.parse(ApiConstants.properties).replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      return PaginatedResponse.fromJson(
        jsonDecode(response.body),
        (json) => Property.fromJson(json),
      );
    }
    throw Exception('Failed to load properties');
  }

  Future<Property> getProperty(int id) async {
    final response = await http.get(
      Uri.parse(ApiConstants.propertyDetail(id)),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return Property.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load property');
  }

  Future<Property> createProperty(Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse(ApiConstants.properties),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (response.statusCode == 201) {
      return Property.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to create property');
  }

  Future<Property> updateProperty(int id, Map<String, dynamic> body) async {
    final response = await http.patch(
      Uri.parse(ApiConstants.propertyDetail(id)),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) {
      return Property.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to update property');
  }

  Future<void> deleteProperty(int id) async {
    final response = await http.delete(
      Uri.parse(ApiConstants.propertyDetail(id)),
      headers: _headers,
    );
    if (response.statusCode != 204) {
      throw Exception('Failed to delete property');
    }
  }

  Future<List<Property>> getSimilarProperties(int id) async {
    final response = await http.get(
      Uri.parse(ApiConstants.propertySimilar(id)),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data.map((json) => Property.fromJson(json)).toList();
    }
    throw Exception('Failed to load similar properties');
  }

  // ── Features ────────────────────────────────────────────────────────

  Future<List<PropertyFeature>> getFeatures() async {
    final response = await http.get(
      Uri.parse(ApiConstants.features),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data.map((json) => PropertyFeature.fromJson(json)).toList();
    }
    throw Exception('Failed to load features');
  }

  // ── Property Images ─────────────────────────────────────────────────

  Future<PropertyImage> uploadPropertyImage(
      int propertyId, XFile imageFile) async {
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

  Future<void> reorderImages(int propertyId, List<int> order) async {
    final response = await http.post(
      Uri.parse(ApiConstants.propertyImagesReorder(propertyId)),
      headers: _headers,
      body: jsonEncode({'order': order}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to reorder images');
    }
  }

  // ── Floorplans ──────────────────────────────────────────────────────

  Future<PropertyFloorplan> uploadFloorplan(
      int propertyId, XFile file, String? title) async {
    final uri = Uri.parse(ApiConstants.propertyFloorplans(propertyId));
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_authHeaders)
      ..files.add(await http.MultipartFile.fromPath('file', file.path));
    if (title != null && title.isNotEmpty) {
      request.fields['title'] = title;
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201) {
      return PropertyFloorplan.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to upload floorplan');
  }

  Future<void> deleteFloorplan(int propertyId, int floorplanId) async {
    final response = await http.delete(
      Uri.parse(ApiConstants.propertyFloorplan(propertyId, floorplanId)),
      headers: _authHeaders,
    );
    if (response.statusCode != 204) {
      throw Exception('Failed to delete floorplan');
    }
  }

  // ── Save / Unsave Property ─────────────────────────────────────────

  Future<bool> toggleSaveProperty(int propertyId, {required bool save}) async {
    final uri = Uri.parse(ApiConstants.propertySave(propertyId));
    final response = save
        ? await http.post(uri, headers: _headers)
        : await http.delete(uri, headers: _headers);

    if (response.statusCode == 200 || response.statusCode == 201) {
      if (response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        return data['saved'] ?? save;
      }
      return save;
    }
    throw Exception('Failed to toggle save');
  }

  Future<PaginatedResponse<SavedProperty>> getSavedProperties(
      {int page = 1}) async {
    final uri = Uri.parse(ApiConstants.savedProperties)
        .replace(queryParameters: {'page': page.toString()});
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      return PaginatedResponse.fromJson(
        jsonDecode(response.body),
        (json) => SavedProperty.fromJson(json),
      );
    }
    throw Exception('Failed to load saved properties');
  }

  Future<void> removeSavedProperty(int id) async {
    final response = await http.delete(
      Uri.parse(ApiConstants.savedProperty(id)),
      headers: _headers,
    );
    if (response.statusCode != 204) {
      throw Exception('Failed to remove saved property');
    }
  }

  // ── Viewing Requests ────────────────────────────────────────────────

  Future<PaginatedResponse<ViewingRequest>> getReceivedViewings(
      {int page = 1}) async {
    final uri = Uri.parse(ApiConstants.receivedViewings)
        .replace(queryParameters: {'page': page.toString()});
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      return PaginatedResponse.fromJson(
        jsonDecode(response.body),
        (json) => ViewingRequest.fromJson(json),
      );
    }
    throw Exception('Failed to load viewing requests');
  }

  Future<ViewingRequest> createViewing({
    required int propertyId,
    String? phone,
    required String preferredDate,
    required String preferredTime,
    String? alternativeDate,
    String? alternativeTime,
    String? message,
  }) async {
    final body = <String, dynamic>{
      'property': propertyId,
      'phone': phone ?? '',
      'preferred_date': preferredDate,
      'preferred_time': preferredTime,
    };
    if (alternativeDate != null && alternativeDate.isNotEmpty) {
      body['alternative_date'] = alternativeDate;
    }
    if (alternativeTime != null && alternativeTime.isNotEmpty) {
      body['alternative_time'] = alternativeTime;
    }
    if (message != null && message.isNotEmpty) body['message'] = message;

    final response = await http.post(
      Uri.parse(ApiConstants.viewings),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (response.statusCode == 201) {
      return ViewingRequest.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to request viewing');
  }

  Future<void> updateViewingStatus(int id, String status,
      {String? sellerNotes}) async {
    final body = <String, dynamic>{'status': status};
    if (sellerNotes != null) body['seller_notes'] = sellerNotes;

    final response = await http.patch(
      Uri.parse(ApiConstants.viewingUpdateStatus(id)),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update viewing status');
    }
  }

  Future<Reply> replyToViewing(int id, String message) async {
    final response = await http.post(
      Uri.parse(ApiConstants.viewingReply(id)),
      headers: _headers,
      body: jsonEncode({'message': message}),
    );
    if (response.statusCode == 201) {
      return Reply.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to send reply');
  }

  // ── Saved Searches ──────────────────────────────────────────────────

  Future<List<SavedSearch>> getSavedSearches() async {
    final response = await http.get(
      Uri.parse(ApiConstants.savedSearches),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final results = data['results'] as List? ?? data as List;
      return results.map((json) => SavedSearch.fromJson(json)).toList();
    }
    throw Exception('Failed to load saved searches');
  }

  Future<SavedSearch> createSavedSearch(Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse(ApiConstants.savedSearches),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (response.statusCode == 201) {
      return SavedSearch.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to save search');
  }

  Future<void> deleteSavedSearch(int id) async {
    final response = await http.delete(
      Uri.parse(ApiConstants.savedSearch(id)),
      headers: _headers,
    );
    if (response.statusCode != 204) {
      throw Exception('Failed to delete saved search');
    }
  }

  Future<void> toggleSearchAlerts(int id, bool enabled) async {
    final response = await http.patch(
      Uri.parse(ApiConstants.savedSearch(id)),
      headers: _headers,
      body: jsonEncode({'email_alerts': enabled}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update search alerts');
    }
  }

  // ── Dashboard & Notifications ───────────────────────────────────────

  Future<DashboardStats> getDashboardStats() async {
    final response = await http.get(
      Uri.parse(ApiConstants.dashboardStats),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return DashboardStats.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load dashboard stats');
  }

  Future<NotificationCounts> getNotificationCounts() async {
    final response = await http.get(
      Uri.parse(ApiConstants.notificationCounts),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return NotificationCounts.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load notification counts');
  }

  // ── Profile ─────────────────────────────────────────────────────────

  Future<UserProfile> getProfile() async {
    final response = await http.get(
      Uri.parse(ApiConstants.profile),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return UserProfile.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load profile');
  }

  Future<UserProfile> updateProfile(Map<String, dynamic> body) async {
    final response = await http.patch(
      Uri.parse(ApiConstants.profile),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) {
      return UserProfile.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to update profile');
  }

  Future<bool> changePassword(
      String currentPassword, String newPassword, String reNewPassword) async {
    final response = await http.post(
      Uri.parse(ApiConstants.changePassword),
      headers: _headers,
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
        're_new_password': reNewPassword,
      }),
    );
    return response.statusCode == 204;
  }

  // ── Service Providers ────────────────────────────────────────────────

  Future<List<ServiceCategory>> getServiceCategories() async {
    final response = await http.get(
      Uri.parse(ApiConstants.serviceCategories),
      headers: _headers,
    ).timeout(_timeout);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data.map((json) => ServiceCategory.fromJson(json)).toList();
    }
    throw Exception('Failed to load service categories');
  }

  Future<PaginatedResponse<ServiceProvider>> getServiceProviders({
    String? category,
    String? location,
    bool? mine,
    int page = 1,
  }) async {
    final params = <String, String>{'page': page.toString()};
    if (category != null && category.isNotEmpty) params['category'] = category;
    if (location != null && location.isNotEmpty) params['location'] = location;
    if (mine == true) params['mine'] = 'true';

    final uri = Uri.parse(ApiConstants.serviceProviders)
        .replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers).timeout(_timeout);

    if (response.statusCode == 200) {
      return PaginatedResponse.fromJson(
        jsonDecode(response.body),
        (json) => ServiceProvider.fromJson(json),
      );
    }
    throw Exception('Failed to load service providers');
  }

  Future<ServiceProvider> getServiceProvider(dynamic idOrSlug) async {
    final response = await http.get(
      Uri.parse(ApiConstants.serviceProviderDetail(idOrSlug)),
      headers: _headers,
    ).timeout(_timeout);
    if (response.statusCode == 200) {
      return ServiceProvider.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load service provider');
  }

  Future<ServiceProvider> createServiceProvider(
      Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse(ApiConstants.serviceProviders),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (response.statusCode == 201) {
      return ServiceProvider.fromJson(jsonDecode(response.body));
    }
    final detail = _extractError(response);
    throw Exception(detail);
  }

  Future<ServiceProvider> updateServiceProvider(
      int id, Map<String, dynamic> body) async {
    final response = await http.patch(
      Uri.parse(ApiConstants.serviceProviderDetail(id)),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) {
      return ServiceProvider.fromJson(jsonDecode(response.body));
    }
    final detail = _extractError(response);
    throw Exception(detail);
  }

  Future<List<ServiceProviderReview>> getServiceProviderReviews(
      int providerId) async {
    final response = await http.get(
      Uri.parse(ApiConstants.serviceProviderReviews(providerId)),
      headers: _headers,
    ).timeout(_timeout);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data
          .map((json) => ServiceProviderReview.fromJson(json))
          .toList();
    }
    throw Exception('Failed to load reviews');
  }

  Future<ServiceProviderReview> createReview(
      int providerId, int rating, String comment) async {
    final response = await http.post(
      Uri.parse(ApiConstants.serviceProviderReviews(providerId)),
      headers: _headers,
      body: jsonEncode({'rating': rating, 'comment': comment}),
    );
    if (response.statusCode == 201) {
      return ServiceProviderReview.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to submit review');
  }

  Future<void> deleteReview(int providerId, int reviewId) async {
    final response = await http.delete(
      Uri.parse(ApiConstants.serviceProviderReview(providerId, reviewId)),
      headers: _headers,
    );
    if (response.statusCode != 204) {
      throw Exception('Failed to delete review');
    }
  }

  Future<List<ServiceProvider>> getPropertyServices(int propertyId) async {
    final response = await http.get(
      Uri.parse(ApiConstants.propertyServices(propertyId)),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data.map((json) => ServiceProvider.fromJson(json)).toList();
    }
    throw Exception('Failed to load property services');
  }

  // ── Staff Service Management ────────────────────────────────────────

  Future<Map<String, dynamic>> getServiceProviderStats() async {
    final response = await http.get(
      Uri.parse(ApiConstants.staffServiceStats),
      headers: _headers,
    ).timeout(_timeout);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load service provider stats');
  }

  Future<int> bulkProviderAction(List<int> providerIds, String action) async {
    final response = await http.post(
      Uri.parse(ApiConstants.staffServiceActions),
      headers: _headers,
      body: jsonEncode({'provider_ids': providerIds, 'action': action}),
    ).timeout(_timeout);
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['updated'];
    }
    throw Exception('Failed to perform action');
  }

  Future<ServiceProvider> validateServiceProvider(
      int providerId, {String? status, bool? isVerified}) async {
    final body = <String, dynamic>{};
    if (status != null) body['status'] = status;
    if (isVerified != null) body['is_verified'] = isVerified;
    final response = await http.post(
      Uri.parse(ApiConstants.serviceProviderValidate(providerId)),
      headers: _headers,
      body: jsonEncode(body),
    ).timeout(_timeout);
    if (response.statusCode == 200) {
      return ServiceProvider.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to validate provider');
  }

  // ── Subscriptions / Pricing ─────────────────────────────────────────

  Future<Map<String, dynamic>> getPricing() async {
    final response = await http.get(
      Uri.parse(ApiConstants.pricing),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load pricing');
  }

  Future<Map<String, dynamic>> getMySubscription() async {
    final response = await http.get(
      Uri.parse(ApiConstants.mySubscription),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load subscription');
  }

  Future<String> createCheckout(String tierSlug, String billingCycle) async {
    final response = await http.post(
      Uri.parse(ApiConstants.createCheckout),
      headers: _headers,
      body: jsonEncode({
        'tier_slug': tierSlug,
        'billing_cycle': billingCycle,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['checkout_url'] as String;
    }
    final data = jsonDecode(response.body);
    throw Exception(data['detail'] ?? 'Failed to create checkout');
  }

  Future<String> createPortal() async {
    final response = await http.post(
      Uri.parse(ApiConstants.createPortal),
      headers: _headers,
      body: jsonEncode({}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['portal_url'] as String;
    }
    final data = jsonDecode(response.body);
    throw Exception(data['detail'] ?? 'Failed to create billing portal');
  }

  // ── Chat Rooms ──────────────────────────────────────────────────────

  Future<List<ChatRoom>> getChatRooms() async {
    final response = await http.get(
      Uri.parse(ApiConstants.chatRooms),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final results = data is List ? data : (data['results'] as List? ?? []);
      return results.map((json) => ChatRoom.fromJson(json)).toList();
    }
    throw Exception('Failed to load chat rooms');
  }

  Future<ChatRoom> getOrCreateChatRoom(int propertyId) async {
    return createChatRoom(propertyId: propertyId);
  }

  Future<ChatRoom> createChatRoom({required int propertyId, String? message}) async {
    final body = <String, dynamic>{'property': propertyId};
    if (message != null && message.isNotEmpty) {
      body['message'] = message;
    }
    final response = await http.post(
      Uri.parse(ApiConstants.chatRooms),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return ChatRoom.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to create chat room');
  }

  Future<List<ChatMessage>> getChatMessages(int roomId) async {
    final response = await http.get(
      Uri.parse(ApiConstants.chatMessages(roomId)),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data.map((json) => ChatMessage.fromJson(json)).toList();
    }
    throw Exception('Failed to load messages');
  }

  Future<ChatMessage> sendChatMessage(int roomId, String content) async {
    final response = await http.post(
      Uri.parse(ApiConstants.chatMessages(roomId)),
      headers: _headers,
      body: jsonEncode({'message': content}),
    );
    if (response.statusCode == 201) {
      return ChatMessage.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to send message');
  }

  Future<void> markMessagesRead(int roomId) async {
    await http.post(
      Uri.parse(ApiConstants.chatMarkRead(roomId)),
      headers: _headers,
    );
  }

  // ── Offers ──────────────────────────────────────────────────────────

  Future<List<Offer>> getOffers({bool? received}) async {
    final url = received == true
        ? ApiConstants.offersReceived
        : ApiConstants.offers;
    final response = await http.get(Uri.parse(url), headers: _headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final results = data is List ? data : (data['results'] as List? ?? []);
      return results.map((json) => Offer.fromJson(json)).toList();
    }
    throw Exception('Failed to load offers');
  }

  Future<Offer> createOffer({
    required int propertyId,
    required double amount,
    String? message,
    bool isCashBuyer = false,
    bool isChainFree = false,
    bool mortgageAgreed = false,
  }) async {
    final response = await http.post(
      Uri.parse(ApiConstants.offers),
      headers: _headers,
      body: jsonEncode({
        'property': propertyId,
        'amount': amount.toString(),
        'message': message ?? '',
        'is_cash_buyer': isCashBuyer,
        'is_chain_free': isChainFree,
        'mortgage_agreed': mortgageAgreed,
      }),
    );
    if (response.statusCode == 201) {
      return Offer.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to submit offer');
  }

  Future<Offer> respondToOffer(int id, String status, {double? counterAmount, String? sellerNotes}) async {
    final body = <String, dynamic>{'status': status};
    if (counterAmount != null) body['counter_amount'] = counterAmount.toString();
    if (sellerNotes != null) body['seller_notes'] = sellerNotes;

    final response = await http.patch(
      Uri.parse(ApiConstants.offerRespond(id)),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) {
      return Offer.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to respond to offer');
  }

  Future<Offer> updateOffer(int id, {
    double? amount,
    String? message,
    bool? isCashBuyer,
    bool? isChainFree,
    bool? mortgageAgreed,
  }) async {
    final body = <String, dynamic>{};
    if (amount != null) body['amount'] = amount.toString();
    if (message != null) body['message'] = message;
    if (isCashBuyer != null) body['is_cash_buyer'] = isCashBuyer;
    if (isChainFree != null) body['is_chain_free'] = isChainFree;
    if (mortgageAgreed != null) body['mortgage_agreed'] = mortgageAgreed;

    final response = await http.patch(
      Uri.parse(ApiConstants.offerDetail(id)),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) {
      return Offer.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to update offer');
  }

  Future<void> withdrawOffer(int id) async {
    final response = await http.patch(
      Uri.parse(ApiConstants.offerWithdraw(id)),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to withdraw offer');
    }
  }

  // ── Property Documents ─────────────────────────────────────────────

  Future<List<PropertyDocument>> getPropertyDocuments(int propertyId) async {
    final response = await http.get(
      Uri.parse(ApiConstants.propertyDocuments(propertyId)),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data.map((json) => PropertyDocument.fromJson(json)).toList();
    }
    throw Exception('Failed to load documents');
  }

  Future<PropertyDocument> uploadPropertyDocument(
    int propertyId,
    XFile file, {
    required String documentType,
    String? title,
    bool isPublic = false,
  }) async {
    final uri = Uri.parse(ApiConstants.propertyDocuments(propertyId));
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_authHeaders)
      ..files.add(await http.MultipartFile.fromPath('file', file.path))
      ..fields['document_type'] = documentType
      ..fields['is_public'] = isPublic.toString();
    if (title != null && title.isNotEmpty) {
      request.fields['title'] = title;
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201) {
      return PropertyDocument.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to upload document');
  }

  Future<void> deletePropertyDocument(int propertyId, int docId) async {
    final response = await http.delete(
      Uri.parse(ApiConstants.propertyDocument(propertyId, docId)),
      headers: _headers,
    );
    if (response.statusCode != 204) {
      throw Exception('Failed to delete document');
    }
  }

  // ── Property Flagging ──────────────────────────────────────────────

  Future<PropertyFlag> flagProperty(int propertyId, String reason, {String? description}) async {
    final body = <String, dynamic>{'reason': reason};
    if (description != null) body['description'] = description;

    final response = await http.post(
      Uri.parse(ApiConstants.propertyFlag(propertyId)),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (response.statusCode == 201) {
      return PropertyFlag.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to flag property');
  }

  // ── Neighbourhood Info ─────────────────────────────────────────────

  Future<NeighbourhoodInfo> getNeighbourhoodInfo(int propertyId) async {
    final response = await http.get(
      Uri.parse(ApiConstants.propertyNeighbourhood(propertyId)),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return NeighbourhoodInfo.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load neighbourhood info');
  }

  // ── Viewing Slots ─────────────────────────────────────────────────

  Future<List<ViewingSlot>> getViewingSlots(int propertyId) async {
    final response = await http.get(
      Uri.parse(ApiConstants.viewingSlots(propertyId)),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data.map((json) => ViewingSlot.fromJson(json)).toList();
    }
    throw Exception('Failed to load viewing slots');
  }

  Future<ViewingSlot> createViewingSlot(int propertyId, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse(ApiConstants.viewingSlots(propertyId)),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (response.statusCode == 201) {
      return ViewingSlot.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to create viewing slot');
  }

  Future<void> deleteViewingSlot(int propertyId, int slotId) async {
    final response = await http.delete(
      Uri.parse(ApiConstants.viewingSlot(propertyId, slotId)),
      headers: _headers,
    );
    if (response.statusCode != 204) {
      throw Exception('Failed to delete viewing slot');
    }
  }

  Future<void> bookViewingSlot(int propertyId, int slotId, {
    required String name,
    required String email,
    String? phone,
    String? message,
  }) async {
    final response = await http.post(
      Uri.parse(ApiConstants.bookViewingSlot(propertyId, slotId)),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'email': email,
        'phone': phone ?? '',
        'message': message ?? '',
      }),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to book viewing slot');
    }
  }

  // ── Mortgage Calculator ───────────────────────────────────────────

  Future<MortgageCalculation> calculateMortgage({
    required double propertyPrice,
    required double depositPercent,
    required double interestRate,
    required int termYears,
  }) async {
    final uri = Uri.parse(ApiConstants.mortgageCalculator).replace(
      queryParameters: {
        'price': propertyPrice.toString(),
        'deposit_pct': depositPercent.toString(),
        'interest_rate': interestRate.toString(),
        'term_years': termYears.toString(),
      },
    );
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return MortgageCalculation.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to calculate mortgage');
  }

  // ── Bulk Import/Export ────────────────────────────────────────────

  Future<Map<String, dynamic>> bulkImportProperties(List<Map<String, dynamic>> properties) async {
    final response = await http.post(
      Uri.parse(ApiConstants.bulkImport),
      headers: _headers,
      body: jsonEncode({'properties': properties}),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to import properties');
  }

  Future<List<Map<String, dynamic>>> exportProperties() async {
    final response = await http.get(
      Uri.parse(ApiConstants.exportProperties),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['properties'] as List).cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to export properties');
  }

  // ── Push Notifications ────────────────────────────────────────────

  Future<void> registerPushDevice(String token, {String platform = 'android'}) async {
    final response = await http.post(
      Uri.parse(ApiConstants.pushRegister),
      headers: _headers,
      body: jsonEncode({'token': token, 'platform': platform}),
    );
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('Failed to register push device');
    }
  }

  // ── House Prices ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> getHousePrices(String postcode) async {
    final uri = Uri.parse(ApiConstants.housePrices)
        .replace(queryParameters: {'postcode': postcode});
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load house prices');
  }

  // ── Health Check ──────────────────────────────────────────────────

  Future<bool> healthCheck() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConstants.healthCheck),
      ).timeout(_timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // NEW FEATURES (#28-#45)
  // ══════════════════════════════════════════════════════════════════

  // ── #28 Listing Quality Score ─────────────────────────────────────

  Future<Map<String, dynamic>> getListingQualityScore(int propertyId) async {
    final response = await http.get(
      Uri.parse(ApiConstants.propertyQualityScore(propertyId)),
      headers: _authHeaders,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load quality score');
  }

  // ── #29 Price Comparison ──────────────────────────────────────────

  Future<Map<String, dynamic>> getPriceComparison(String postcode) async {
    final uri = Uri.parse(ApiConstants.priceComparison)
        .replace(queryParameters: {'postcode': postcode});
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load price comparison');
  }

  // ── #30 Buyer Verification ────────────────────────────────────────

  Future<List<dynamic>> getBuyerVerifications() async {
    final response = await http.get(
      Uri.parse(ApiConstants.buyerVerifications),
      headers: _authHeaders,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data is List ? data : (data['results'] ?? []);
    }
    throw Exception('Failed to load verifications');
  }

  Future<Map<String, dynamic>> createBuyerVerification(
      String type, String filePath) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(ApiConstants.buyerVerifications),
    );
    request.headers.addAll(_authHeaders);
    request.fields['verification_type'] = type;
    request.files.add(await http.MultipartFile.fromPath('document', filePath));
    final streamResponse = await request.send();
    final response = await http.Response.fromStream(streamResponse);
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to create verification');
  }

  Future<Map<String, dynamic>> getBuyerVerificationStatus(int userId) async {
    final response = await http.get(
      Uri.parse(ApiConstants.buyerVerificationStatus(userId)),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load verification status');
  }

  // ── #31 Conveyancing Tracker ──────────────────────────────────────

  Future<List<dynamic>> getConveyancingCases() async {
    final response = await http.get(
      Uri.parse(ApiConstants.conveyancingCases),
      headers: _authHeaders,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data is List ? data : (data['results'] ?? []);
    }
    throw Exception('Failed to load conveyancing cases');
  }

  Future<Map<String, dynamic>> createConveyancingCase(int offerId) async {
    final response = await http.post(
      Uri.parse(ApiConstants.conveyancingCases),
      headers: _authJsonHeaders,
      body: jsonEncode({'offer': offerId}),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to create conveyancing case');
  }

  Future<Map<String, dynamic>> updateConveyancingStep(
      int caseId, int stepId, String status, {String? notes}) async {
    final body = <String, dynamic>{'status': status};
    if (notes != null) body['notes'] = notes;
    final response = await http.patch(
      Uri.parse(ApiConstants.conveyancingStepUpdate(caseId, stepId)),
      headers: _authJsonHeaders,
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to update step');
  }

  // ── #32 AI Description Generator ──────────────────────────────────

  Future<Map<String, dynamic>> generateDescription(
      Map<String, dynamic> details) async {
    final response = await http.post(
      Uri.parse(ApiConstants.generateDescription),
      headers: _authJsonHeaders,
      body: jsonEncode(details),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to generate description');
  }

  // ── #35 Stamp Duty Calculator ─────────────────────────────────────

  Future<Map<String, dynamic>> calculateStampDuty({
    required double price,
    String country = 'england',
    bool firstTimeBuyer = false,
    bool additionalProperty = false,
  }) async {
    final uri = Uri.parse(ApiConstants.stampDutyCalculator).replace(
      queryParameters: {
        'price': price.toString(),
        'country': country,
        'first_time_buyer': firstTimeBuyer.toString(),
        'additional_property': additionalProperty.toString(),
      },
    );
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to calculate stamp duty');
  }

  // ── #36 Property History ──────────────────────────────────────────

  Future<Map<String, dynamic>> getPropertyHistory(int propertyId) async {
    final response = await http.get(
      Uri.parse(ApiConstants.propertyHistory(propertyId)),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load property history');
  }

  // ── #37 Open House Events ─────────────────────────────────────────

  Future<List<dynamic>> getOpenHouseEvents({int? propertyId}) async {
    final url = propertyId != null
        ? ApiConstants.openHouseEvents(propertyId)
        : ApiConstants.openHouseUpcoming;
    final response = await http.get(Uri.parse(url), headers: _headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data is List ? data : (data['results'] ?? []);
    }
    throw Exception('Failed to load open house events');
  }

  Future<Map<String, dynamic>> createOpenHouseEvent(
      int propertyId, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse(ApiConstants.openHouseEvents(propertyId)),
      headers: _authJsonHeaders,
      body: jsonEncode(data),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to create open house event');
  }

  Future<void> deleteOpenHouseEvent(int propertyId, int eventId) async {
    final response = await http.delete(
      Uri.parse(ApiConstants.openHouseEventDetail(propertyId, eventId)),
      headers: _authHeaders,
    );
    if (response.statusCode != 204) {
      throw Exception('Failed to delete open house event');
    }
  }

  Future<Map<String, dynamic>> rsvpOpenHouse(int eventId,
      {int attendees = 1, String message = ''}) async {
    final response = await http.post(
      Uri.parse(ApiConstants.openHouseRsvp(eventId)),
      headers: _authJsonHeaders,
      body: jsonEncode({'attendees': attendees, 'message': message}),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to RSVP');
  }

  Future<void> cancelRsvp(int eventId) async {
    final response = await http.delete(
      Uri.parse(ApiConstants.openHouseRsvpCancel(eventId)),
      headers: _authHeaders,
    );
    if (response.statusCode != 204) {
      throw Exception('Failed to cancel RSVP');
    }
  }

  // ── #38 QR Code Flyers ────────────────────────────────────────────

  Future<Map<String, dynamic>> generatePropertyFlyer(int propertyId) async {
    final response = await http.get(
      Uri.parse(ApiConstants.propertyFlyer(propertyId)),
      headers: _authHeaders,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to generate flyer');
  }

  // ── #39 Solicitor/Conveyancer Matching ────────────────────────────

  Future<List<dynamic>> getQuoteRequests() async {
    final response = await http.get(
      Uri.parse(ApiConstants.quoteRequests),
      headers: _authHeaders,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data is List ? data : (data['results'] ?? []);
    }
    throw Exception('Failed to load quote requests');
  }

  Future<Map<String, dynamic>> createQuoteRequest(
      int propertyId, String transactionType,
      {String additionalInfo = ''}) async {
    final response = await http.post(
      Uri.parse(ApiConstants.quoteRequests),
      headers: _authJsonHeaders,
      body: jsonEncode({
        'property': propertyId,
        'transaction_type': transactionType,
        'additional_info': additionalInfo,
      }),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to create quote request');
  }

  Future<Map<String, dynamic>> submitConveyancerQuote(
      Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse(ApiConstants.conveyancerQuotes),
      headers: _authJsonHeaders,
      body: jsonEncode(data),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to submit quote');
  }

  Future<Map<String, dynamic>> acceptQuote(int quoteId) async {
    final response = await http.post(
      Uri.parse(ApiConstants.acceptQuote(quoteId)),
      headers: _authHeaders,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to accept quote');
  }

  // ── #40 Neighbourhood Reviews ─────────────────────────────────────

  Future<List<dynamic>> getNeighbourhoodReviews(
      {String? postcodeArea}) async {
    var url = ApiConstants.neighbourhoodReviews;
    if (postcodeArea != null) {
      url += '?postcode_area=$postcodeArea';
    }
    final response = await http.get(Uri.parse(url), headers: _headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data is List ? data : (data['results'] ?? []);
    }
    throw Exception('Failed to load neighbourhood reviews');
  }

  Future<Map<String, dynamic>> createNeighbourhoodReview(
      Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse(ApiConstants.neighbourhoodReviews),
      headers: _authJsonHeaders,
      body: jsonEncode(data),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to create review');
  }

  Future<Map<String, dynamic>> getNeighbourhoodSummary(
      String postcodeArea) async {
    final response = await http.get(
      Uri.parse(ApiConstants.neighbourhoodSummary(postcodeArea)),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load neighbourhood summary');
  }

  // ── #41 Board Orders ──────────────────────────────────────────────

  Future<List<dynamic>> getBoardOrders() async {
    final response = await http.get(
      Uri.parse(ApiConstants.boardOrders),
      headers: _authHeaders,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data is List ? data : (data['results'] ?? []);
    }
    throw Exception('Failed to load board orders');
  }

  Future<Map<String, dynamic>> createBoardOrder(
      int propertyId, String boardType, String deliveryAddress) async {
    final response = await http.post(
      Uri.parse(ApiConstants.boardOrders),
      headers: _authJsonHeaders,
      body: jsonEncode({
        'property': propertyId,
        'board_type': boardType,
        'delivery_address': deliveryAddress,
      }),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to create board order');
  }

  Future<Map<String, dynamic>> getBoardPricing() async {
    final response = await http.get(
      Uri.parse(ApiConstants.boardPricing),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load board pricing');
  }

  // ── #42 EPC Suggestions ───────────────────────────────────────────

  Future<Map<String, dynamic>> getEpcSuggestions(int propertyId) async {
    final response = await http.get(
      Uri.parse(ApiConstants.epcSuggestions(propertyId)),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load EPC suggestions');
  }

  // ── #43 Buyer Profile ─────────────────────────────────────────────

  Future<Map<String, dynamic>> getBuyerProfile() async {
    final response = await http.get(
      Uri.parse(ApiConstants.buyerProfile),
      headers: _authHeaders,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load buyer profile');
  }

  Future<Map<String, dynamic>> updateBuyerProfile(
      Map<String, dynamic> data) async {
    final response = await http.patch(
      Uri.parse(ApiConstants.buyerProfile),
      headers: _authJsonHeaders,
      body: jsonEncode(data),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to update buyer profile');
  }

  Future<List<dynamic>> getAffordableProperties() async {
    final response = await http.get(
      Uri.parse(ApiConstants.affordableProperties),
      headers: _authHeaders,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data is List ? data : (data['results'] ?? []);
    }
    throw Exception('Failed to load affordable properties');
  }

  // ── #44 Two-Factor Authentication ─────────────────────────────────

  Future<Map<String, dynamic>> setup2FA() async {
    final response = await http.post(
      Uri.parse(ApiConstants.twoFaSetup),
      headers: _authHeaders,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception(
        jsonDecode(response.body)['error'] ?? 'Failed to set up 2FA');
  }

  Future<Map<String, dynamic>> confirm2FA(String code) async {
    final response = await http.post(
      Uri.parse(ApiConstants.twoFaConfirm),
      headers: _authJsonHeaders,
      body: jsonEncode({'code': code}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception(
        jsonDecode(response.body)['error'] ?? 'Invalid code');
  }

  Future<Map<String, dynamic>> disable2FA(String code) async {
    final response = await http.post(
      Uri.parse(ApiConstants.twoFaDisable),
      headers: _authJsonHeaders,
      body: jsonEncode({'code': code}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception(
        jsonDecode(response.body)['error'] ?? 'Failed to disable 2FA');
  }

  Future<Map<String, dynamic>> verify2FA(String email, String code) async {
    final response = await http.post(
      Uri.parse(ApiConstants.twoFaVerify),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception(
        jsonDecode(response.body)['error'] ?? 'Verification failed');
  }

  // ── #45 Community Forum ───────────────────────────────────────────

  Future<List<dynamic>> getForumCategories() async {
    final response = await http.get(
      Uri.parse(ApiConstants.forumCategories),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data is List ? data : (data['results'] ?? []);
    }
    throw Exception('Failed to load forum categories');
  }

  Future<List<dynamic>> getForumTopics(
      {String? category, String? search}) async {
    var url = ApiConstants.forumTopics;
    final params = <String, String>{};
    if (category != null) params['category'] = category;
    if (search != null) params['search'] = search;
    if (params.isNotEmpty) {
      url += '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    }
    final response = await http.get(Uri.parse(url), headers: _headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data is List ? data : (data['results'] ?? []);
    }
    throw Exception('Failed to load forum topics');
  }

  Future<Map<String, dynamic>> getForumTopic(int id) async {
    final response = await http.get(
      Uri.parse(ApiConstants.forumTopicDetail(id)),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load forum topic');
  }

  Future<Map<String, dynamic>> createForumTopic(
      int categoryId, String title, String content) async {
    final response = await http.post(
      Uri.parse(ApiConstants.forumTopics),
      headers: _authJsonHeaders,
      body: jsonEncode({
        'category': categoryId,
        'title': title,
        'content': content,
      }),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to create topic');
  }

  Future<Map<String, dynamic>> createForumPost(
      int topicId, String content) async {
    final response = await http.post(
      Uri.parse(ApiConstants.forumTopicPosts(topicId)),
      headers: _authJsonHeaders,
      body: jsonEncode({'content': content}),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to create post');
  }

  Future<Map<String, dynamic>> markForumSolution(int postId) async {
    final response = await http.post(
      Uri.parse(ApiConstants.forumMarkSolution(postId)),
      headers: _authHeaders,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to mark solution');
  }

  // ── Enquiry stubs (backend API not yet implemented) ──────────────

  Future<void> markEnquiryRead(int enquiryId) async {
    // TODO: implement when backend enquiry endpoints are added
  }

  Future<Reply> replyToEnquiry(int enquiryId, String message) async {
    // TODO: implement when backend enquiry endpoints are added
    throw UnimplementedError('Enquiry replies not yet supported');
  }
}
