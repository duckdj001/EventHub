import '../models/notification_item.dart';
import 'api_client.dart';

class NotificationService {
  NotificationService({ApiClient? apiClient}) : api = apiClient ?? ApiClient();

  final ApiClient api;

  Future<List<AppNotification>> list() async {
    final res = await api.get('/notifications');
    final list = (res as List).cast<Map<String, dynamic>>();
    return list.map(AppNotification.fromJson).toList();
  }

  Future<void> markAllRead() async {
    await api.post('/notifications/read-all', {});
  }

  Future<void> markRead(String id) async {
    await api.post('/notifications/$id/read', {});
  }

  Future<int> unreadCount() async {
    final res = await api.get('/notifications/unread-count');
    if (res is Map<String, dynamic>) {
      return (res['count'] as num? ?? 0).toInt();
    }
    return 0;
  }

  Future<void> registerDevice({required String token, required String platform}) async {
    await api.post('/notifications/device/register', {
      'token': token,
      'platform': platform,
    });
  }

  Future<void> deregisterDevice(String token) async {
    await api.post('/notifications/device/deregister', {
      'token': token,
    });
  }
}
