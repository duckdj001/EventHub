import 'api_client.dart';

class UserCategoriesService {
  UserCategoriesService({ApiClient? client}) : api = client ?? ApiClient();

  final ApiClient api;

  Future<List<Map<String, dynamic>>> list() async {
    final res = await api.get('/users/me/categories');
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> update(List<String> categories) async {
    final res = await api.patch('/users/me/categories', {
      'categories': categories,
    });
    return (res as List).cast<Map<String, dynamic>>();
  }
}
