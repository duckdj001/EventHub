import '../models/event_photo.dart';
import 'api_client.dart';

class EventPhotosService {
  final ApiClient api = ApiClient();

  Future<List<EventPhoto>> list(String eventId) async {
    final res = await api.get('/events/$eventId/photos', auth: false);
    final list = (res as List).cast<Map<String, dynamic>>();
    return list.map(EventPhoto.fromJson).toList();
  }

  Future<EventPhoto> create(String eventId, {required String url}) async {
    final res = await api.post('/events/$eventId/photos', {'url': url});
    return EventPhoto.fromJson(res as Map<String, dynamic>);
  }

  Future<void> delete(String eventId, String photoId) async {
    await api.delete('/events/$eventId/photos/$photoId');
  }
}
