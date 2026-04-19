import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';

/// Background message handler. Must be a top-level function annotated
/// with @pragma('vm:entry-point') so Flutter can invoke it from a
/// background isolate. Notifications are displayed by the OS on
/// Android and iOS without any extra work here.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Nothing to do — the OS already renders the system notification.
  // If we ever needed to do local work (e.g. update a badge count or
  // invalidate a cache) we'd ensure Firebase initialised and handle
  // the payload here.
}

/// Wraps Firebase Cloud Messaging for the app. Responsible for:
/// - Initialising Firebase at boot
/// - Requesting notification permission on iOS
/// - Fetching the device FCM token and POSTing it to
///   /api/push/register/ when the user is logged in
/// - Showing in-app notifications when a message arrives while the
///   app is in the foreground (Android doesn't show system
///   notifications for data messages received in foreground;
///   flutter_local_notifications handles that)
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialised = false;
  String? _lastRegisteredToken;

  /// Initialise Firebase. Safe to call multiple times.
  Future<void> init() async {
    if (_initialised) return;
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Firebase initialisation failed: $e');
      return;
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    // Local notifications channel for Android foreground messages.
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    // Android 13+ requires runtime notification permission, as does iOS.
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    _initialised = true;
  }

  /// Register the device's FCM token against the authenticated user.
  /// Call this after a successful login. Tokens can rotate (after an
  /// uninstall/reinstall or Firebase-side churn) so we also listen
  /// for [FirebaseMessaging.onTokenRefresh].
  Future<void> registerDeviceForUser(String? Function() tokenGetter) async {
    if (!_initialised) return;
    final messaging = FirebaseMessaging.instance;
    try {
      final fcmToken = await messaging.getToken();
      if (fcmToken != null) {
        await _postTokenToBackend(fcmToken, tokenGetter);
      }
    } catch (e) {
      debugPrint('FCM getToken failed: $e');
    }

    messaging.onTokenRefresh.listen((fcmToken) {
      _postTokenToBackend(fcmToken, tokenGetter);
    });
  }

  /// Tell the backend to stop sending pushes to this device and clear
  /// the last-registered token tracking so a subsequent
  /// [registerDeviceForUser] call (e.g. after a different user logs in)
  /// will re-post. Call this BEFORE the auth token is cleared so the
  /// unregister request is still authenticated.
  Future<void> onLogout(String? authToken) async {
    final fcmToken = _lastRegisteredToken;
    _lastRegisteredToken = null;
    if (fcmToken == null || authToken == null) return;
    try {
      await http
          .post(
            Uri.parse(ApiConstants.pushUnregister),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Token $authToken',
            },
            body: jsonEncode({'token': fcmToken}),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Push token unregister failed: $e');
    }
  }

  Future<void> _postTokenToBackend(
    String fcmToken,
    String? Function() tokenGetter,
  ) async {
    if (fcmToken == _lastRegisteredToken) return;
    final authToken = tokenGetter();
    if (authToken == null) return;
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.pushRegister),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $authToken',
        },
        body: jsonEncode({
          'token': fcmToken,
          'platform': Platform.isIOS ? 'ios' : 'android',
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        _lastRegisteredToken = fcmToken;
      } else {
        debugPrint('Push token registration failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Push token registration error: $e');
    }
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final android = notification?.android;
    if (notification == null || android == null) return;
    // On iOS the system shows foreground notifications itself when
    // presentation options are enabled at permission request time.
    if (Platform.isIOS) return;
    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'fsbo_default',
          'Notifications',
          channelDescription: 'For Sale By Owner notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }
}
