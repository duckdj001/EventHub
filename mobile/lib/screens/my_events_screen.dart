import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/event.dart';
import '../services/api_client.dart';
import '../theme/app_spacing.dart';
import '../theme/components/components.dart';
import '../theme/app_theme_extension.dart';

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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/create'),
        icon: const Icon(Icons.add),
        label: const Text('Создать событие'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: AppSurface(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                          const SizedBox(height: AppSpacing.sm),
                          Text('Ошибка: $error', textAlign: TextAlign.center),
                          const SizedBox(height: AppSpacing.sm),
                          AppButton.primary(onPressed: _load, label: 'Повторить'),
                        ],
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xl),
                          children: [
                            AppSurface(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.event_available_outlined, size: 48),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text('Вы пока не создали ни одного события',
                                      style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                          itemCount: items.length,
                          itemBuilder: (_, i) {
                            final e = items[i];
                            final statusChip = _statusChip(context, e.status);
                            return AppSurface(
                              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                              padding: EdgeInsets.zero,
                              child: ListTile(
                                shape: (Theme.of(context).extension<AppThemeExtension>()?.panelRadius != null)
                                    ? RoundedRectangleBorder(
                                        borderRadius: Theme.of(context).extension<AppThemeExtension>()!.panelRadius,
                                      )
                                    : null,
                                onTap: () => context.push('/events/${e.id}'),
                                title: Text(e.title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  '${e.city} · ${dateFmt.format(e.startAt.toLocal())}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                              ),
                            );
                          },
                        ),
                ),
    );
  }

  Widget? _statusChip(BuildContext context, String status) {
    switch (status) {
      case 'draft':
        return _chip(context, 'Черновик', Colors.orange.shade100, Colors.orange.shade700);
      case 'published':
        return _chip(context, 'Опубликовано', Colors.green.shade100, Colors.green.shade700);
      case 'cancelled':
        return _chip(context, 'Отменено', Colors.red.shade100, Colors.red.shade700);
      default:
        return null;
    }
  }

  Widget _chip(BuildContext context, String text, Color bg, Color fg) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: fg, fontWeight: FontWeight.w600)),
    );
  }
}
