// lib/services/api_client.dart
// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  /// Базовый URL твоего API (например, http://localhost:3000)
  final String base;

  /// Публичный базовый URL бакета (например, http://127.0.0.1:9000/eventhub).
  /// Нужен, если сервер не возвращает готовый publicUrl в /files/presign-public.
  static String basePublicS3 = '';

  ApiClient(this.base);

  static const _kTokenKey = 'auth_token';
  String? _token;

  // ====== Token helpers ======
  Future<void> storeToken(String token) async {
    _token = token;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kTokenKey, token);
  }

  Future<String?> loadToken() async {
    if (_token != null) return _token;
    final sp = await SharedPreferences.getInstance();
    _token = sp.getString(_kTokenKey);
    return _token;
  }

  Future<void> clearToken() async {
    _token = null;
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kTokenKey);
  }

  // ====== Internal headers ======
  Map<String, String> _headers({bool auth = true, Map<String, String>? extra}) {
    final h = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
    };
    if (auth && _token != null && _token!.isNotEmpty) {
      h['Authorization'] = 'Bearer $_token';
    }
    if (extra != null) h.addAll(extra);
    return h;
  }

  // ====== Requests ======
  Future<dynamic> get(String path, {bool auth = true}) async {
    // гарантируем, что токен подтянем, если ещё не в памяти
    if (auth && _token == null) { await loadToken(); }

    final url = Uri.parse('$base$path');
    print('flutter: [API] GET  $url  auth=$auth');
    final r = await http.get(url, headers: _headers(auth: auth));
    print('flutter: [API] <- ${r.statusCode} ${r.reasonPhrase}  ${r.body}');
    if (r.statusCode >= 400) {
      throw Exception(r.body.isNotEmpty ? r.body : 'HTTP ${r.statusCode}');
    }
    return r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
  }

  Future<dynamic> post(String path, Map<String, dynamic> body, {bool auth = true}) async {
    if (auth && _token == null) { await loadToken(); }

    final url = Uri.parse('$base$path');
    print('flutter: [API] POST $url  auth=$auth  body=$body');
    final r = await http.post(url, headers: _headers(auth: auth), body: jsonEncode(body));
    print('flutter: [API] <- ${r.statusCode} ${r.reasonPhrase}  ${r.body}');
    if (r.statusCode >= 400) {
      throw Exception(r.body.isNotEmpty ? r.body : 'HTTP ${r.statusCode}');
    }
    return r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
  }

  Future<dynamic> delete(String path, {bool auth = true}) async {
    if (auth && _token == null) { await loadToken(); }

    final url = Uri.parse('$base$path');
    print('flutter: [API] DELETE $url  auth=$auth');
    final r = await http.delete(url, headers: _headers(auth: auth));
    print('flutter: [API] <- ${r.statusCode} ${r.reasonPhrase}  ${r.body}');
    if (r.statusCode >= 400) {
      throw Exception(r.body.isNotEmpty ? r.body : 'HTTP ${r.statusCode}');
    }
    return r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
  }

  // ====== Helpers for uploads ======

  /// PUT загрузка файла по presigned URL (MinIO/S3).
  Future<void> putPresigned({
    required String uploadUrl,
    required List<int> bytes,
    required String contentType,
  }) async {
    final uri = Uri.parse(uploadUrl);
    print('flutter: [API] PUT  $uri  contentType=$contentType  bytes=${bytes.length}');
    final r = await http.put(uri, headers: {'Content-Type': contentType}, body: bytes);
    print('flutter: [API] <- ${r.statusCode} ${r.reasonPhrase}');
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception('Upload failed: ${r.statusCode} ${r.reasonPhrase} ${r.body}');
    }
  }

  /// Возвращает итоговый публичный URL из ответа пресайна.
  /// Если `publicUrl` отсутствует — соберёт из [basePublicS3] + '/' + key.
  String publicUrlFromPresign(Map data) {
    final publicUrl = (data['publicUrl'] as String?)?.trim();
    if (publicUrl != null && publicUrl.isNotEmpty) return publicUrl;

    final key = (data['key'] as String?)?.trim();
    if (key != null && key.isNotEmpty && basePublicS3.isNotEmpty) {
      return '$basePublicS3/$key';
    }
    throw Exception('publicUrl not provided and basePublicS3/key are empty');
  }
}
