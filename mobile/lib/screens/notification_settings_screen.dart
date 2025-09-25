import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/notification_preferences.dart';
import '../services/notification_service.dart';
import '../theme/app_spacing.dart';
import '../theme/components/components.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final NotificationService _service = NotificationService();

  NotificationPreferences? _prefs;
  bool _loading = true;
  bool _saving = false;
  String? _error;

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
      final prefs = await _service.loadPreferences();
      if (!mounted) return;
      setState(() => _prefs = prefs);
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _update(NotificationPreferenceKey key, bool value) async {
    final prefs = _prefs;
    if (prefs == null || _saving) return;

    final updated = _apply(prefs, key, value);
    setState(() {
      _prefs = updated;
      _saving = true;
    });

    try {
      final saved = await _service.savePreferences(updated);
      if (!mounted) return;
      setState(() => _prefs = saved);
    } catch (err) {
      if (!mounted) return;
      setState(() => _prefs = prefs);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить: $err')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  NotificationPreferences _apply(
    NotificationPreferences prefs,
    NotificationPreferenceKey key,
    bool value,
  ) {
    switch (key) {
      case NotificationPreferenceKey.newEvent:
        return prefs.copyWith(newEvent: value);
      case NotificationPreferenceKey.eventReminder:
        return prefs.copyWith(eventReminder: value);
      case NotificationPreferenceKey.participationApproved:
        return prefs.copyWith(participationApproved: value);
      case NotificationPreferenceKey.newFollower:
        return prefs.copyWith(newFollower: value);
      case NotificationPreferenceKey.organizerContent:
        return prefs.copyWith(organizerContent: value);
      case NotificationPreferenceKey.followedStory:
        return prefs.copyWith(followedStory: value);
      case NotificationPreferenceKey.eventUpdated:
        return prefs.copyWith(eventUpdated: value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки уведомлений'),
        actions: [
          IconButton(
            tooltip: 'История уведомлений',
            icon: const Icon(Icons.list_alt_outlined),
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (_saving)
                        const SizedBox(
                          height: 4,
                          child: LinearProgressIndicator(),
                        ),
                      if (_saving) const SizedBox(height: AppSpacing.sm),
                      AppSurface(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Push и внутренняя лента',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Выберите, о чём присылать уведомления. Настройки применяются и к пушам, и к внутренней ленте.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _NotificationSwitches(
                        prefs: _prefs!,
                        disabled: _saving,
                        onChanged: _update,
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _NotificationSwitches extends StatelessWidget {
  const _NotificationSwitches({
    required this.prefs,
    required this.onChanged,
    required this.disabled,
  });

  final NotificationPreferences prefs;
  final bool disabled;
  final void Function(NotificationPreferenceKey key, bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = [
      (
        key: NotificationPreferenceKey.newEvent,
        title: 'Новые события',
        subtitle: 'Когда организаторы, на которых вы подписаны, создают новые ивенты',
      ),
      (
        key: NotificationPreferenceKey.eventReminder,
        title: 'Напоминания о старте',
        subtitle: 'За день до начала событий, куда вы записаны',
      ),
      (
        key: NotificationPreferenceKey.participationApproved,
        title: 'Подтверждение участия',
        subtitle: 'Когда организатор одобряет вашу заявку на участие',
      ),
      (
        key: NotificationPreferenceKey.newFollower,
        title: 'Новые подписчики',
        subtitle: 'Кто-то подписался на ваш профиль',
      ),
      (
        key: NotificationPreferenceKey.organizerContent,
        title: 'Истории и фото в моих событиях',
        subtitle: 'Участники добавляют историю или фото в ваше событие',
      ),
      (
        key: NotificationPreferenceKey.followedStory,
        title: 'Истории во время событий',
        subtitle: 'Люди, на которых вы подписаны, делятся историями прямо сейчас',
      ),
      (
        key: NotificationPreferenceKey.eventUpdated,
        title: 'Изменения событий',
        subtitle: 'Организатор редактирует событие, где вы участвуете',
      ),
    ];

    return AppSurface(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            Column(
              children: [
                SwitchListTile.adaptive(
                  value: prefs.flag(items[i].key),
                  onChanged: disabled
                      ? null
                      : (value) => onChanged(items[i].key, value),
                  title: Text(items[i].title, style: theme.textTheme.bodyLarge),
                  subtitle: Text(
                    items[i].subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                ),
                if (i < items.length - 1)
                  const Divider(height: 1, indent: AppSpacing.md, endIndent: AppSpacing.md),
              ],
            ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: AppSurface(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Не удалось загрузить настройки:\n$message',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton.primary(onPressed: onRetry, label: 'Повторить'),
            ],
          ),
        ),
      ),
    );
  }
}
