import 'package:flutter/foundation.dart';

import 'package:flutter_app_badger/flutter_app_badger.dart';

import '../models/user_profile.dart';
import 'api_client.dart';
import 'notification_service.dart';

class AuthStore extends ChangeNotifier {
  AuthStore({ApiClient? client}) : api = client ?? ApiClient();

  final ApiClient api;
  final NotificationService _notifications = NotificationService();

  UserProfile? _user;
  bool _initialized = false;
  bool _loadingProfile = false;
  int _unreadNotifications = 0;
  Future<void> Function()? _beforeLogout;

  bool get isReady => _initialized;
  bool get isLoggedIn => _user != null;
  UserProfile? get user => _user;
  bool get isRefreshingProfile => _loadingProfile;
  int get unreadNotifications => _unreadNotifications;

  set beforeLogout(Future<void> Function()? callback) {
    _beforeLogout = callback;
  }

  Future<void> restoreSession() async {
    try {
      final token = await api.loadToken();
      if (token != null && token.isNotEmpty) {
        await refreshProfile();
      }
    } catch (_) {
      await api.clearToken();
      _user = null;
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    final res = await api.post(
      '/auth/login',
      {'email': email, 'password': password},
      auth: false,
    ) as Map<String, dynamic>;

    final token = (res['accessToken'] as String?)?.trim();
    if (token == null || token.isEmpty) {
      throw Exception('Не удалось получить токен авторизации');
    }
    await api.storeToken(token);

    final mustChangePassword = res['user'] is Map<String, dynamic>
        ? (res['user']['mustChangePassword'] == true)
        : false;

    try {
      await refreshProfile();
    } catch (e) {
      await api.clearToken();
      rethrow;
    }

    return mustChangePassword;
  }

  Future<void> refreshProfile() async {
    _loadingProfile = true;
    notifyListeners();
    try {
      final data = await api.get('/users/me');
      if (data == null) {
        _user = null;
        throw Exception('Пользователь не найден');
      }
      _user = UserProfile.fromJson(data as Map<String, dynamic>);
      await refreshUnreadNotifications();
    } finally {
      _loadingProfile = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    if (_beforeLogout != null) {
      try {
        await _beforeLogout!();
      } catch (_) {}
    }
    await api.clearToken();
    _user = null;
    await _setUnreadNotifications(0);
    notifyListeners();
  }

  Future<void> refreshUnreadNotifications() async {
    if (!isLoggedIn) {
      await _setUnreadNotifications(0);
      return;
    }
    try {
      final count = await _notifications.unreadCount();
      await _setUnreadNotifications(count);
    } catch (_) {
      // ignore errors silently
    }
  }

  Future<void> requestPasswordReset(String email) async {
    await api.post(
      '/auth/password/forgot',
      {'email': email},
      auth: false,
    );
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    await api.patch('/users/me/password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
    await refreshProfile();
  }

  Future<void> deleteAccount(String password) async {
    await api.post('/users/me/delete', {'password': password});
    await logout();
  }

  Future<void> _setUnreadNotifications(int value) async {
    value = value < 0 ? 0 : value;
    if (_unreadNotifications == value) return;
    _unreadNotifications = value;
    if (value > 0) {
      FlutterAppBadger.updateBadgeCount(value);
    } else {
      FlutterAppBadger.removeBadge();
    }
    notifyListeners();
  }
}
