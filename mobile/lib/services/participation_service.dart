import '../models/event.dart';
import '../models/participation.dart';
import '../models/review.dart';
import 'api_client.dart';

class ParticipationService {
  final ApiClient api = ApiClient();

  Future<ParticipationRequestResult> request(String eventId) async {
    final res = await api.post('/events/$eventId/participations', {});
    final data = res as Map<String, dynamic>;
    final participation = Participation.fromJson(data);
    final autoconfirmed = (data['autoconfirmed'] as bool?) ?? false;
    return ParticipationRequestResult(
      participation: participation,
      autoconfirmed: autoconfirmed,
      availableSpots: participation.availableSpots ?? (data['availableSpots'] as num?)?.toInt(),
    );
  }

  Future<Participation?> myStatus(String eventId) async {
    final res = await api.get('/events/$eventId/participations/me');
    if (res == null) return null;
    return Participation.fromJson(res as Map<String, dynamic>);
  }

  Future<Participation> cancel(String eventId) async {
    final res = await api.delete('/events/$eventId/participations/me');
    return Participation.fromJson(res as Map<String, dynamic>);
  }

  Future<List<Participation>> listForOwner(String eventId) async {
    final res = await api.get('/events/$eventId/participations');
    final list = (res as List).cast<Map<String, dynamic>>();
    return list.map(Participation.fromJson).toList();
  }

  Future<Participation> setStatus(String eventId, String participationId, String status) async {
    final res = await api.patch('/events/$eventId/participations/$participationId', {
      'status': status,
    });
    return Participation.fromJson(res as Map<String, dynamic>);
  }

  Future<List<Event>> participatingEvents() async {
    final res = await api.get('/events/participating');
    final list = (res as List).cast<Map<String, dynamic>>();
    return list.map(Event.fromJson).toList();
  }

  Future<List<Review>> eventReviews(String eventId, {int? rating}) async {
    final query = rating != null ? '?rating=$rating' : '';
    final res = await api.get('/events/$eventId/reviews$query');
    final list = (res as List).cast<Map<String, dynamic>>();
    return list.map(Review.fromJson).toList();
  }

  Future<Review?> myReview(String eventId) async {
    final res = await api.get('/events/$eventId/reviews/me');
    if (res == null) return null;
    return Review.fromJson(res as Map<String, dynamic>);
  }

  Future<Review> submitReview(String eventId, {required int rating, String? text}) async {
    final res = await api.post('/events/$eventId/reviews', {
      'rating': rating,
      if (text != null && text.trim().isNotEmpty) 'text': text.trim(),
    });
    return Review.fromJson(res as Map<String, dynamic>);
  }

  Future<Review> rateParticipant(String eventId, String participationId, {required int rating, String? text}) async {
    final res = await api.post('/events/$eventId/participations/$participationId/rating', {
      'rating': rating,
      if (text != null && text.trim().isNotEmpty) 'text': text.trim(),
    });
    return Review.fromJson(res as Map<String, dynamic>);
  }
}
