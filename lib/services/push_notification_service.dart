import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config/firebase_bootstrap.dart';

/// Manages FCM token lifecycle and incoming push notification handling.
///
/// Tokens are stored as a server-side array on `profiles/{uid}.fcmTokens`
/// so Cloud Functions can fan-out to every device the user is signed in on.
class PushNotificationService {
  PushNotificationService._();

  static final _messaging = FirebaseMessaging.instance;
  static final _db = FirebaseFirestore.instance;

  static StreamSubscription<String>? _tokenRefreshSub;
  static StreamSubscription<RemoteMessage>? _foregroundSub;
  static String? _activeUid;
  static String? _currentToken;

  /// Callback set by the UI layer to show an in-app banner when a message
  /// arrives while the app is in the foreground.
  static void Function(RemoteMessage message)? onForegroundMessage;

  /// Callback set by the UI layer to navigate when the user taps a
  /// notification (from background or terminated state).
  static void Function(RemoteMessage message)? onNotificationTap;

  /// Call after the user is authenticated. Requests permission, saves the FCM
  /// token to Firestore, and starts listening for token refreshes + messages.
  static Future<void> initialize(String uid) async {
    if (!isFirebaseInitialized) return;
    if (kIsWeb) return; // Web FCM requires VAPID key setup separately.

    _activeUid = uid;

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('Push notifications: permission denied by user');
      return;
    }

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    final token = await _messaging.getToken();
    if (token != null) {
      _currentToken = token;
      await _saveToken(uid, token);
    }

    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) {
      if (_activeUid == null) return;
      _currentToken = newToken;
      _saveToken(_activeUid!, newToken);
    });

    await _foregroundSub?.cancel();
    _foregroundSub =
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      _handleNotificationTap(initial);
    }
  }

  /// Remove this device's token from the user's profile and stop listeners.
  static Future<void> clearTokenAndDispose() async {
    final uid = _activeUid;
    final token = _currentToken;
    _activeUid = null;
    _currentToken = null;
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    await _foregroundSub?.cancel();
    _foregroundSub = null;

    if (uid != null && token != null && isFirebaseInitialized) {
      try {
        await _db.collection('profiles').doc(uid).update({
          'fcmTokens': FieldValue.arrayRemove([token]),
        });
      } catch (e) {
        debugPrint('Failed to remove FCM token on sign-out: $e');
      }
    }
  }

  static Future<void> _saveToken(String uid, String token) async {
    try {
      await _db.collection('profiles').doc(uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to save FCM token: $e');
    }
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    debugPrint(
      'FCM foreground: ${message.notification?.title} – '
      '${message.notification?.body}',
    );
    onForegroundMessage?.call(message);
  }

  static void _handleNotificationTap(RemoteMessage message) {
    debugPrint('FCM notification tapped: ${message.data}');
    onNotificationTap?.call(message);
  }
}
