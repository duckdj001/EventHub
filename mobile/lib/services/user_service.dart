import '../models/event.dart';
import '../models/review.dart';
import '../models/user_profile.dart';
import 'api_client.dart';

class UserService {
  final ApiClient api = ApiClient();

  Future<UserProfile> updateProfile({
    String? firstName,
    String? lastName,
    String? avatarUrl,
    String? bio,
    String? birthDate,
  }) async {
    final body = <String, dynamic>{};
    if (firstName != null) body['firstName'] = firstName;
    if (lastName != null) body['lastName'] = lastName;
    if (avatarUrl != null) body['avatarUrl'] = avatarUrl;
    if (bio != null) body['bio'] = bio;
    if (birthDate != null) body['birthDate'] = birthDate;

    final res = await api.patch('/users/me', body);
    return UserProfile.fromJson(res as Map<String, dynamic>);
  }

  Future<void> requestEmailChange({required String newEmail, required String password}) async {
    await api.post('/users/me/email-request', {
      'newEmail': newEmail,
      'password': password,
    });
  }

  Future<void> confirmEmailChange({required String code}) async {
    await api.post('/users/me/email-confirm', {'code': code});
  }

  Future<UserProfile> publicProfile(String userId) async {
    final res = await api.get('/users/$userId/public', auth: true);
    return UserProfile.fromJson(res as Map<String, dynamic>);
  }

  Future<List<Event>> eventsCreated(String userId, {String filter = 'all'}) async {
    final query = filter == 'all' ? '' : '?filter=$filter';
    final res = await api.get('/users/$userId/events$query');
    final list = (res as List).cast<Map<String, dynamic>>();
    return list.map(Event.fromJson).toList();
  }

  Future<List<Review>> reviews(String userId, {int? rating, String type = 'event'}) async {
    final params = <String>[];
    params.add('type=$type');
    if (rating != null) params.add('rating=$rating');
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    final res = await api.get('/users/$userId/reviews$query');
    final list = (res as List).cast<Map<String, dynamic>>();
    return list.map(Review.fromJson).toList();
  }
}
