import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/device_token_storage.dart';
import '../services/notification_service.dart';
import 'auth_store.dart';

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationsManager {
  PushNotificationsManager(this.auth);

  final AuthStore auth;
  final NotificationService _notifications = NotificationService();

  bool _initialized = false;
  String? _currentToken;
  late final FirebaseMessaging _messaging;
  bool _lastLoggedIn = false;
  String? _lastUserId;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    _messaging = FirebaseMessaging.instance;

    await _ensureFirebaseInitialized();
    await _requestPermissions();

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
    _messaging.onTokenRefresh.listen(_handleTokenRefresh);

    auth.addListener(_handleAuthChanged);
    auth.beforeLogout = () async {
      await _deregisterCurrentToken();
    };
    await _handleAuthChanged();
  }

  Future<void> _ensureFirebaseInitialized() async {
    try {
      await Firebase.initializeApp();
    } catch (err) {
      if (kDebugMode) {
        debugPrint('Firebase already initialized or failed: $err');
      }
    }
  }

  Future<void> _requestPermissions() async {
    if (Platform.isIOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
    await _messaging.requestPermission();
  }

  Future<void> _handleAuthChanged() async {
    final loggedIn = auth.isLoggedIn;
    final userId = auth.user?.id;

    if (!loggedIn) {
      if (_lastLoggedIn) {
        await _deregisterCurrentToken();
      }
      _lastLoggedIn = false;
      _lastUserId = null;
      return;
    }

    if (userId == null) return;
    if (_lastLoggedIn && _lastUserId == userId) {
      return;
    }

    await _registerCurrentToken();
    _lastLoggedIn = true;
    _lastUserId = userId;
  }

  Future<void> _registerCurrentToken() async {
    final token = await _messaging.getToken();
    if (token == null) return;
    _currentToken = token;
    final userId = auth.user?.id;
    if (userId != null) {
      try {
        await _notifications.registerDevice(token: token, platform: _platformName());
      } catch (err) {
        if (kDebugMode) {
          debugPrint('Failed to register push token: $err');
        }
      }
      await DeviceTokenStorage.save(token: token, userId: userId);
    } else {
      await DeviceTokenStorage.save(token: token, userId: null);
    }
  }

  Future<void> _deregisterCurrentToken() async {
    final storedToken = await DeviceTokenStorage.getToken();
    if (storedToken != null && auth.isLoggedIn) {
      try {
        await _notifications.deregisterDevice(storedToken);
      } catch (err) {
        if (kDebugMode) {
          debugPrint('Failed to deregister push token: $err');
        }
      }
    }
    await DeviceTokenStorage.clear();
    _currentToken = null;
  }

  void dispose() {
    auth.removeListener(_handleAuthChanged);
  }

  Future<void> _handleTokenRefresh(String token) async {
    _currentToken = token;
    if (auth.isLoggedIn) {
      try {
        await _notifications.registerDevice(token: token, platform: _platformName());
      } catch (err) {
        if (kDebugMode) {
          debugPrint('Failed to refresh push token: $err');
        }
      }
      await DeviceTokenStorage.save(token: token, userId: auth.user?.id);
      await auth.refreshUnreadNotifications();
    } else {
      await DeviceTokenStorage.save(token: token, userId: null);
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (kDebugMode) {
      debugPrint('Push message received in foreground: ${message.data}');
    }
    await auth.refreshUnreadNotifications();
  }

  Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    await auth.refreshUnreadNotifications();
  }

  String _platformName() {
    if (Platform.isIOS) return 'ios';
    return 'android';
  }
}
