import '../models/event_story.dart';
import 'api_client.dart';

class EventStoriesService {
  final ApiClient api = ApiClient();

  Future<List<EventStory>> list(String eventId) async {
    final res = await api.get('/events/$eventId/stories', auth: false);
    final list = (res as List).cast<Map<String, dynamic>>();
    return list.map(EventStory.fromJson).toList();
  }

  Future<EventStory> create(String eventId, {required String url}) async {
    final res = await api.post('/events/$eventId/stories', {'url': url});
    return EventStory.fromJson(res as Map<String, dynamic>);
  }

  Future<void> delete(String eventId, String storyId) async {
    await api.delete('/events/$eventId/stories/$storyId');
  }
}
