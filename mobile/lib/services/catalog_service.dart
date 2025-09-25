import 'package:vibe/services/api_client.dart';

class CatalogService {
  CatalogService({ApiClient? client}) : api = client ?? ApiClient();

  final ApiClient api;

  static const List<Map<String, dynamic>> _fallback = [
    {'id': 'default-category', 'name': 'Встречи', 'isSuggested': true},
    {'id': 'music', 'name': 'Музыка', 'isSuggested': true},
    {'id': 'sport', 'name': 'Спорт', 'isSuggested': true},
    {'id': 'education', 'name': 'Обучение', 'isSuggested': true},
    {'id': 'art', 'name': 'Искусство', 'isSuggested': true},
    {'id': 'business', 'name': 'Бизнес', 'isSuggested': false},
    {'id': 'family', 'name': 'Семья', 'isSuggested': false},
    {'id': 'health', 'name': 'Здоровье', 'isSuggested': false},
    {'id': 'travel', 'name': 'Путешествия', 'isSuggested': false},
    {'id': 'food', 'name': 'Еда', 'isSuggested': false},
    {'id': 'tech', 'name': 'Технологии', 'isSuggested': false},
    {'id': 'games', 'name': 'Игры', 'isSuggested': false},
  ];

  Future<List<Map<String, dynamic>>> categories() async {
    try {
      final data = await api.get('/categories', auth: false);
      final list = (data as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .map((item) => {
                ...item,
                'isSuggested': item['isSuggested'] == true,
              })
          .toList(growable: false);
      if (list.isEmpty) return _fallback;
      return list;
    } catch (_) {
      // Фолбэк, если бэк не готов — не валимся
      return _fallback;
    }
  }
}
