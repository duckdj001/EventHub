import 'package:characters/characters.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/notification_item.dart';
import '../services/notification_service.dart';
import '../widgets/auth_scope.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme_extension.dart';
import '../theme/components/components.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _service = NotificationService();
  final DateFormat _dateFmt = DateFormat('dd.MM.yyyy HH:mm');

  List<AppNotification> _items = const [];
  bool _loading = true;
  String? _error;
  bool _markingAll = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _service.list();
      if (!mounted) return;
      setState(() {
        _items = items;
      });
      AuthScope.of(context).refreshUnreadNotifications();
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _markAllRead() async {
    if (_markingAll) return;
    setState(() => _markingAll = true);
    try {
      await _service.markAllRead();
      await _load();
      if (mounted) {
        AuthScope.of(context).refreshUnreadNotifications();
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Не удалось отметить все: $err')));
      }
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _markOne(AppNotification notification) async {
    if (!notification.isUnread) return;
    final index = _items.indexWhere((n) => n.id == notification.id);
    if (index == -1) return;
    try {
      await _service.markRead(notification.id);
      if (!mounted) return;
      setState(() {
        _items = List<AppNotification>.from(_items)
          ..[index] = _items[index].copyWith(read: true);
      });
      AuthScope.of(context).refreshUnreadNotifications();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Не удалось отметить: $err')));
    }
  }

  IconData _iconFor(AppNotification notification) {
    switch (notification.type) {
      case NotificationType.newEvent:
        return Icons.campaign_outlined;
      case NotificationType.eventReminder:
        return Icons.notifications_active_outlined;
      case NotificationType.unknown:
        return Icons.notifications_none;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadExists = _items.any((n) => n.isUnread);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Уведомления'),
        actions: [
          IconButton(
            onPressed: (!_loading && unreadExists && !_markingAll) ? _markAllRead : null,
            icon: _markingAll
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.done_all),
            tooltip: 'Отметить все прочитанными',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: AppSurface(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                          const SizedBox(height: AppSpacing.sm),
                          Text('Ошибка загрузки: $_error', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: AppSpacing.sm),
                          AppButton.primary(onPressed: _load, label: 'Повторить'),
                        ],
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _items.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xl),
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            AppSurface(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.inbox_outlined, size: 48),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text('Уведомлений пока нет', style: Theme.of(context).textTheme.bodyMedium),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return _NotificationTile(
                              item: item,
                              dateFmt: _dateFmt,
                              icon: _iconFor(item),
                              onMarkRead: () => _markOne(item),
                              onOpenEvent: item.event != null
                                  ? () async {
                                      if (item.event == null) return;
                                      await context.push('/events/${item.event!.id}');
                                      await _markOne(item);
                                    }
                                  : null,
                              onOpenOwner: item.event?.owner != null
                                  ? () async {
                                      final owner = item.event!.owner!;
                                      await context.push('/users/${owner.id}');
                                      await _markOne(item);
                                    }
                                  : null,
                            );
                          },
                        ),
                ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.dateFmt,
    required this.icon,
    required this.onMarkRead,
    this.onOpenEvent,
    this.onOpenOwner,
  });

  final AppNotification item;
  final DateFormat dateFmt;
  final IconData icon;
  final VoidCallback onMarkRead;
  final VoidCallback? onOpenEvent;
  final VoidCallback? onOpenOwner;

  @override
  Widget build(BuildContext context) {
    final subtitle = <String>[
      dateFmt.format(item.createdAt),
      if (item.event?.startAt != null) 'Начало: ${dateFmt.format(item.event!.startAt!)}',
    ].join('    ');

    final eventTitle = item.event?.title;

    final theme = Theme.of(context);
    final bgColor = item.isUnread ? theme.colorScheme.primary.withOpacity(0.12) : null;

    return AppSurface(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      padding: EdgeInsets.zero,
      color: bgColor,
      child: InkWell(
        borderRadius: theme.extension<AppThemeExtension>()?.panelRadius ?? BorderRadius.circular(24),
        onTap: onOpenEvent,
        child: ListTile(
          leading: Icon(icon, color: theme.colorScheme.primary),
          title: Text(
            item.message,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: item.isUnread ? FontWeight.w700 : FontWeight.w500),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              if (eventTitle != null && eventTitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(eventTitle, style: theme.textTheme.bodySmall),
                ),
              if (item.event?.owner != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: InkWell(
                    onTap: onOpenOwner,
                    borderRadius: BorderRadius.circular(12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: theme.colorScheme.surfaceVariant,
                          backgroundImage: (item.event!.owner!.avatarUrl != null &&
                                  item.event!.owner!.avatarUrl!.isNotEmpty)
                              ? NetworkImage(item.event!.owner!.avatarUrl!)
                              : null,
                          child: (item.event!.owner!.avatarUrl == null ||
                                  item.event!.owner!.avatarUrl!.isEmpty)
                              ? Text(
                                  item.event!.owner!.fullName.isNotEmpty
                                      ? item.event!.owner!.fullName.characters.first.toUpperCase()
                                      : 'U',
                                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.event!.owner!.fullName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right, size: 18, color: theme.colorScheme.primary),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          isThreeLine: (eventTitle != null && eventTitle.isNotEmpty) || item.event?.owner != null,
          trailing: item.isUnread
              ? IconButton(
                  icon: const Icon(Icons.done),
                  tooltip: 'Прочитано',
                  onPressed: onMarkRead,
                )
              : null,
        ),
      ),
    );
  }
}
