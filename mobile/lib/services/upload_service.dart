// lib/services/upload_service.dart
import 'dart:io';
import 'package:http/http.dart' as http;

import 'api_client.dart';

class UploadService {
  final api = ApiClient('http://localhost:3000');

  /// Загружает файл на S3/MinIO через пресайн.
  /// [type] — папка/префикс (например, 'avatars' или 'covers')
  /// [auth] — для /files/presign (true) или /files/presign-public (false)
  Future<String> uploadImage(
    File file, {
    required String type,
    bool auth = true,
  }) async {
    final ext = _ext(file.path);
    final endpoint = auth ? '/files/presign' : '/files/presign-public';

    // 1) Берём пресайн
    final presign = await api.get('$endpoint?type=$type&ext=$ext', auth: auth)
    as Map<String, dynamic>;

// правильные имена полей!
    final uploadUrl = presign['uploadUrl'] as String;   // <-- было 'url'
    final publicUrl = presign['publicUrl'] as String?;
    final key       = presign['key'] as String?;
    final basePublicUrl = presign['basePublicUrl'] as String?;

    // 2) PUT файла
    final put = await http.put(
        Uri.parse(uploadUrl),
        headers: {'Content-Type': _mimeByExt(ext)},
        body: await file.readAsBytes(),
        );
        if (put.statusCode >= 400) {
        throw Exception('S3 upload failed: ${put.statusCode} ${put.body}');
        }


    // 3) Возвращаем публичный URL
    // предпочтительно то, что дал сервер:
    if (publicUrl != null && publicUrl.isNotEmpty) return publicUrl;
    if (basePublicUrl != null && basePublicUrl.isNotEmpty && key != null && key.isNotEmpty) {
    return '$basePublicUrl/$key';
    }
    if (key != null && key.isNotEmpty && ApiClient.basePublicS3.isNotEmpty) {
    return '${ApiClient.basePublicS3}/$key';
    }
    return uploadUrl.split('?').first;
  }

  String _ext(String path) {
    final i = path.lastIndexOf('.');
    if (i < 0) return 'jpg';
    return path.substring(i + 1).toLowerCase();
  }

  String _mimeByExt(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}
