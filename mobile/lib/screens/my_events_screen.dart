import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../models/event.dart';

class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});
  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> {
  final api = ApiClient('http://localhost:3000');
  List<Event> items = [];
  bool loading = true;
  String? error;

  Future<void> _load() async {
    try {
      final data = await api.get('/events/mine');
      final arr = (data as List).cast<Map<String,dynamic>>();
      setState(() { items = arr.map(Event.fromJson).toList(); loading = false; error = null; });
    } catch (e) {
      setState(() { loading = false; error = e.toString(); });
    }
  }

  Future<void> _setStatus(String id, String status) async {
    await api.post('/events/$id/status', {'status': status}); // если сделал PATCH, добавь метод patch в ApiClient
    await _load();
  }

  Future<void> _delete(String id) async {
    // добавь метод delete в ApiClient или временно через post на /events/:id/delete
  }

  @override
  void initState() { super.initState(); _load(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Мои события')),
      body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
          ? Center(child: Text('Ошибка: $error'))
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) {
                final e = items[i];
                return ListTile(
                  title: Text(e.title),
                  subtitle: Text('${e.city} · ${e.startAt}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'pub') _setStatus(e.id, 'published');
                      if (v == 'draft') _setStatus(e.id, 'draft');
                      if (v == 'del') _delete(e.id);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'pub', child: Text('Опубликовать')),
                      PopupMenuItem(value: 'draft', child: Text('Снять с публикации')),
                      PopupMenuItem(value: 'del', child: Text('Удалить')),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
