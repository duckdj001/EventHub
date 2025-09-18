import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';
import 'api_client.dart';

class AuthStore extends ChangeNotifier {
  AuthStore({ApiClient? client}) : api = client ?? ApiClient();

  final ApiClient api;

  UserProfile? _user;
  bool _initialized = false;
  bool _loadingProfile = false;

  bool get isReady => _initialized;
  bool get isLoggedIn => _user != null;
  UserProfile? get user => _user;
  bool get isRefreshingProfile => _loadingProfile;

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

  Future<void> login(String email, String password) async {
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

    try {
      await refreshProfile();
    } catch (e) {
      await api.clearToken();
      rethrow;
    }
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
    } finally {
      _loadingProfile = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await api.clearToken();
    _user = null;
    notifyListeners();
  }
}
