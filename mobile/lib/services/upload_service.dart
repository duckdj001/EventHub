import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'api_client.dart';

class UploadService {
  static const int _chunkSize = 64 * 1024; // 64 KB
  final ApiClient api = ApiClient();

  Future<String> uploadImage(
    File file, {
    required String type,
    bool auth = true,
    void Function(double progress)? onProgress,
  }) async {
    final ext = _ext(file.path);
    final endpoint = auth ? '/files/presign' : '/files/presign-public';

    final response = await api.get('$endpoint?type=$type&ext=$ext', auth: auth)
        as Map<String, dynamic>;
    final uploadUrl = (response['uploadUrl'] ?? response['url']) as String;
    final publicUrl = response['publicUrl'] as String?;
    final key = response['key'] as String?;
    final basePublicUrl = response['basePublicUrl'] as String?;

    final client = HttpClient();
    try {
      final uri = Uri.parse(uploadUrl);
      final request = await client.openUrl('PUT', uri);
      request.headers.set(HttpHeaders.contentTypeHeader, _mimeByExt(ext));
      request.headers.removeAll(HttpHeaders.expectHeader);

      final totalBytes = await file.length();
      if (totalBytes > 0) {
        request.contentLength = totalBytes;
      }

      var uploaded = 0;
      onProgress?.call(0.0);

      await for (final chunk in file.openRead()) {
        final data = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
        var offset = 0;
        while (offset < data.length) {
          final end = math.min(offset + _chunkSize, data.length);
          final slice = Uint8List.sublistView(data, offset, end);
          request.add(slice);
          if (totalBytes > 0) {
            uploaded += slice.length;
            final progress = (uploaded / totalBytes).clamp(0.0, 1.0);
            onProgress?.call(progress.toDouble());
          }
          // Дожидаемся, пока сокет примет буфер — так прогресс отражает реальную отдачу.
          await request.flush();
          offset = end;
          // Yield to event loop so UI can repaint.
          await Future<void>.delayed(Duration.zero);
        }
      }

      final response = await request.close();
      if (response.statusCode >= 400) {
        final body = await utf8.decoder.bind(response).join();
        throw Exception('S3 upload failed: ${response.statusCode} $body');
      }
      await response.drain<void>();
    } finally {
      client.close(force: true);
    }

    onProgress?.call(1.0);

    if (publicUrl != null && publicUrl.isNotEmpty) return publicUrl;
    if (basePublicUrl != null &&
        basePublicUrl.isNotEmpty &&
        key != null &&
        key.isNotEmpty) {
      return '$basePublicUrl/$key';
    }
    if (key != null && key.isNotEmpty && ApiClient.basePublicS3.isNotEmpty) {
      return '${ApiClient.basePublicS3}/$key';
    }
    if (key != null && key.isNotEmpty) return key;
    return uploadUrl.split('?').first;
  }

  String _ext(String path) {
    final index = path.lastIndexOf('.');
    if (index < 0) return 'jpg';
    return path.substring(index + 1).toLowerCase();
  }

  String _mimeByExt(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'm4v':
        return 'video/x-m4v';
      case 'webm':
        return 'video/webm';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}
