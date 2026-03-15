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

  // Public-facing website URL for share links
  static const String websiteUrl = 'https://for-sale-by-owner.co.uk';

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

  // Service provider photos
  static String serviceProviderPhotos(int providerId) =>
      '$apiUrl/service-providers/$providerId/photos/';
  static String serviceProviderPhoto(int providerId, int photoId) =>
      '$apiUrl/service-providers/$providerId/photos/$photoId/';

  // Subscriptions / Pricing
  static String get pricing => '$apiUrl/pricing/';
  static String get mySubscription => '$apiUrl/my-subscription/';
  static String get createCheckout =>
      '$apiUrl/subscriptions/create-checkout/';
  static String get createPortal =>
      '$apiUrl/subscriptions/create-portal/';

  // House prices
  static String get housePrices => '$apiUrl/house-prices/';

  // Chat rooms
  static String get chatRooms => '$apiUrl/chat-rooms/';
  static String chatRoomDetail(int id) => '$apiUrl/chat-rooms/$id/';
  static String chatMessages(int roomId) =>
      '$apiUrl/chat-rooms/$roomId/messages/';
  static String chatMarkRead(int roomId) =>
      '$apiUrl/chat-rooms/$roomId/messages/mark_read/';

  // Offers
  static String get offers => '$apiUrl/offers/';
  static String get offersReceived => '$apiUrl/offers/received/';
  static String offerDetail(int id) => '$apiUrl/offers/$id/';
  static String offerRespond(int id) => '$apiUrl/offers/$id/respond/';
  static String offerWithdraw(int id) => '$apiUrl/offers/$id/withdraw/';

  // Property documents
  static String propertyDocuments(int propertyId) =>
      '$apiUrl/properties/$propertyId/documents/';
  static String propertyDocument(int propertyId, int docId) =>
      '$apiUrl/properties/$propertyId/documents/$docId/';

  // Property flagging
  static String propertyFlag(int propertyId) =>
      '$apiUrl/properties/$propertyId/flag/';

  // Neighbourhood info
  static String propertyNeighbourhood(int propertyId) =>
      '$apiUrl/properties/$propertyId/neighbourhood/';

  // Viewing slots
  static String viewingSlots(int propertyId) =>
      '$apiUrl/properties/$propertyId/viewing-slots/';
  static String viewingSlot(int propertyId, int slotId) =>
      '$apiUrl/properties/$propertyId/viewing-slots/$slotId/';
  static String bookViewingSlot(int propertyId, int slotId) =>
      '$apiUrl/properties/$propertyId/viewing-slots/$slotId/book/';

  // Mortgage calculator
  static String get mortgageCalculator => '$apiUrl/mortgage-calculator/';

  // Bulk import/export
  static String get bulkImport => '$apiUrl/properties/bulk-import/';
  static String get exportProperties => '$apiUrl/properties/export/';

  // Push notifications
  static String get pushRegister => '$apiUrl/push/register/';

  // Health check
  static String get healthCheck => '$apiUrl/health/';

  // ── New Features (#28-#45) ────────────────────────────────────

  // #28 Listing Quality Score
  static String propertyQualityScore(int propertyId) =>
      '$apiUrl/properties/$propertyId/quality-score/';

  // #29 Price Comparison
  static String get priceComparison => '$apiUrl/price-comparison/';

  // #30 Buyer Verification
  static String get buyerVerifications => '$apiUrl/buyer-verifications/';
  static String buyerVerificationDetail(int id) =>
      '$apiUrl/buyer-verifications/$id/';
  static String buyerVerificationStatus(int userId) =>
      '$apiUrl/buyers/$userId/verification/';

  // #31 Conveyancing Tracker
  static String get conveyancingCases => '$apiUrl/conveyancing-cases/';
  static String conveyancingCaseDetail(int id) =>
      '$apiUrl/conveyancing-cases/$id/';
  static String conveyancingStepUpdate(int caseId, int stepId) =>
      '$apiUrl/conveyancing-cases/$caseId/steps/$stepId/';

  // #32 AI Description Generator
  static String get generateDescription => '$apiUrl/generate-description/';

  // #33 Similar Properties (already exists above)

  // #35 Stamp Duty Calculator
  static String get stampDutyCalculator => '$apiUrl/stamp-duty-calculator/';

  // #36 Property History
  static String propertyHistory(int propertyId) =>
      '$apiUrl/properties/$propertyId/history/';

  // #37 Open House Events
  static String get openHouseUpcoming => '$apiUrl/open-house/';
  static String openHouseEvents(int propertyId) =>
      '$apiUrl/properties/$propertyId/open-house/';
  static String openHouseEventDetail(int propertyId, int eventId) =>
      '$apiUrl/properties/$propertyId/open-house/$eventId/';
  static String openHouseRsvp(int eventId) =>
      '$apiUrl/open-house/$eventId/rsvp/';
  static String openHouseRsvpCancel(int eventId) =>
      '$apiUrl/open-house/$eventId/rsvp/cancel/';

  // #38 QR Code Flyers
  static String propertyFlyer(int propertyId) =>
      '$apiUrl/properties/$propertyId/flyer/';

  // #39 Solicitor/Conveyancer Matching
  static String get quoteRequests => '$apiUrl/quote-requests/';
  static String quoteRequestDetail(int id) =>
      '$apiUrl/quote-requests/$id/';
  static String get conveyancerQuotes => '$apiUrl/conveyancer-quotes/';
  static String acceptQuote(int quoteId) =>
      '$apiUrl/quotes/$quoteId/accept/';

  // #40 Neighbourhood Reviews
  static String get neighbourhoodReviews => '$apiUrl/neighbourhood-reviews/';
  static String neighbourhoodSummary(String postcodeArea) =>
      '$apiUrl/neighbourhood/$postcodeArea/summary/';

  // #41 Board Orders
  static String get boardOrders => '$apiUrl/board-orders/';
  static String get boardPricing => '$apiUrl/board-pricing/';

  // #42 EPC Suggestions
  static String epcSuggestions(int propertyId) =>
      '$apiUrl/properties/$propertyId/epc-suggestions/';

  // #43 Buyer Profile
  static String get buyerProfile => '$apiUrl/buyer-profile/';
  static String get affordableProperties => '$apiUrl/affordable-properties/';

  // #44 Two-Factor Authentication
  static String get twoFaSetup => '$apiUrl/2fa/setup/';
  static String get twoFaConfirm => '$apiUrl/2fa/confirm/';
  static String get twoFaDisable => '$apiUrl/2fa/disable/';
  static String get twoFaVerify => '$apiUrl/2fa/verify/';

  // #45 Community Forum
  static String get forumCategories => '$apiUrl/forum-categories/';
  static String get forumTopics => '$apiUrl/forum-topics/';
  static String forumTopicDetail(int id) => '$apiUrl/forum-topics/$id/';
  static String forumTopicPosts(int topicId) =>
      '$apiUrl/forum-topics/$topicId/posts/';
  static String forumPostDetail(int topicId, int postId) =>
      '$apiUrl/forum-topics/$topicId/posts/$postId/';
  static String forumMarkSolution(int postId) =>
      '$apiUrl/forum-posts/$postId/mark-solution/';

  // WebSocket
  static String get _wsBaseUrl =>
      baseUrl.replaceFirst('http', 'ws');
  static String chatWebSocket(int roomId) =>
      '$_wsBaseUrl/ws/chat/$roomId/';

  // Auth
  static String get login => '$authUrl/token/login/';
  static String get logout => '$authUrl/token/logout/';
  static String get register => '$authUrl/users/';
  static String get userMe => '$authUrl/users/me/';
  static String get changePassword => '$authUrl/users/set_password/';
}
