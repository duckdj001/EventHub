import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/event.dart';
import '../services/api_client.dart';

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
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await api.get('/events/mine');
      final arr = (data as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();
      setState(() {
        items = arr.map(Event.fromJson).toList();
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  Future<void> _setStatus(String id, String status) async {
    try {
      await api.patch('/events/$id/status', {'status': status});
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(status == 'published' ? 'Опубликовано' : 'Сохранено в черновиках')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось обновить статус: $e')),
      );
    }
  }

  Future<void> _delete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить событие?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Удалить')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await api.delete('/events/$id');
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Событие удалено')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка удаления: $e')));
    }
  }

  Future<void> _edit(Event event) async {
    final updated = await context.push('/create', extra: event);
    if (updated == true) {
      await _load();
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd.MM.yyyy HH:mm');
    return Scaffold(
      appBar: AppBar(title: const Text('Мои события')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text('Ошибка: $error'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(32),
                          children: const [
                            Center(child: Text('Вы пока не создали ни одного события')),
                          ],
                        )
                      : ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (_, i) {
                            final e = items[i];
                            final statusChip = _statusChip(e.status);
                            return ListTile(
                              onTap: () => context.push('/events/${e.id}'),
                              title: Text(e.title),
                              subtitle: Text(
                                '${e.city} · ${dateFmt.format(e.startAt.toLocal())}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (statusChip != null) statusChip,
                                  PopupMenuButton<String>(
                                    onSelected: (v) {
                                      if (v == 'edit') _edit(e);
                                      if (v == 'pub') _setStatus(e.id, 'published');
                                      if (v == 'draft') _setStatus(e.id, 'draft');
                                      if (v == 'del') _delete(e.id);
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 'edit', child: Text('Редактировать')),
                                      PopupMenuItem(value: 'pub', child: Text('Опубликовать')),
                                      PopupMenuItem(value: 'draft', child: Text('Снять с публикации')),
                                      PopupMenuItem(value: 'del', child: Text('Удалить')),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
    );
  }

  Widget? _statusChip(String status) {
    switch (status) {
      case 'draft':
        return _chip('Черновик', Colors.orange.shade100, Colors.orange.shade700);
      case 'published':
        return _chip('Опубликовано', Colors.green.shade100, Colors.green.shade700);
      case 'cancelled':
        return _chip('Отменено', Colors.red.shade100, Colors.red.shade700);
      default:
        return null;
    }
  }

  Widget _chip(String text, Color bg, Color fg) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
    );
  }
}
