import 'package:eventhub/services/api_client.dart';

class CatalogService {
  final api = ApiClient('http://localhost:3000');

  Future<List<Map<String,dynamic>>> categories() async {
    try {
      final data = await api.get('/categories');
      return (data as List).cast<Map<String,dynamic>>();
    } catch (_) {
      // Фолбэк, если бэк не готов — не валимся
      return const [
        {'id': 'default-category', 'name': 'Встречи'},
        {'id': 'music', 'name': 'Музыка'},
        {'id': 'sport', 'name': 'Спорт'},
        {'id': 'education', 'name': 'Обучение'},
      ];
    }
  }
}
