import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_store.dart';
import '../theme/app_spacing.dart';
import '../theme/components/components.dart';
import '../theme/theme_scope.dart';
import '../widgets/auth_scope.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeScope.of(context);
    final isDark = themeController.mode == ThemeMode.dark;

    final auth = AuthScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          AppSurface(
            child: SwitchListTile.adaptive(
              value: isDark,
              onChanged: (value) => themeController.toggleDark(value),
              title: const Text('Тёмная тема'),
              subtitle: const Text('Переключить оформление приложения'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppSurface(
            child: ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Уведомления'),
              subtitle: const Text('Настроить пуши и историю уведомлений'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/notifications'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppSurface(
            child: ListTile(
              leading: const Icon(Icons.favorite_outline),
              title: const Text('Интересы'),
              subtitle: const Text('Выбрать категории событий'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/categories'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppSurface(
            child: ListTile(
              leading: const Icon(Icons.history_outlined),
              title: const Text('История уведомлений'),
              subtitle: const Text('Последние события и оповещения'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/notifications'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppSurface(
            child: ListTile(
              leading: const Icon(Icons.lock_reset_outlined),
              title: const Text('Изменить пароль'),
              subtitle: const Text('Старый и новый пароль'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openChangePasswordDialog(context, auth),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppSurface(
            child: ListTile(
              leading: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent),
              title: const Text('Удалить профиль'),
              subtitle: const Text('Аккаунт будет обезличен'),
              trailing: const Icon(Icons.chevron_right, color: Colors.redAccent),
              onTap: () => _confirmDeleteAccount(context, auth),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openChangePasswordDialog(BuildContext context, AuthStore auth) async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final repeatCtrl = TextEditingController();
    bool busy = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setState) {
          Future<void> submit() async {
            final current = currentCtrl.text.trim();
            final np = newCtrl.text.trim();
            final rp = repeatCtrl.text.trim();

            if (current.length < 6) {
              _toast(ctx, 'Введите текущий пароль (минимум 6 символов)');
              return;
            }
            if (np.length < 6) {
              _toast(ctx, 'Новый пароль должен содержать минимум 6 символов');
              return;
            }
            if (np != rp) {
              _toast(ctx, 'Пароли не совпадают');
              return;
            }

            setState(() => busy = true);
            try {
              await auth.changePassword(current, np);
              if (!context.mounted) return;
              Navigator.of(ctx).pop();
              _toast(context, 'Пароль обновлён');
            } catch (err) {
              setState(() => busy = false);
              _toast(ctx, 'Не удалось изменить пароль: $err');
            }
          }

          return AlertDialog(
            title: const Text('Изменить пароль'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Текущий пароль'),
                ),
                TextField(
                  controller: newCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Новый пароль'),
                ),
                TextField(
                  controller: repeatCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Повторите пароль'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: busy ? null : submit,
                child: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Сохранить'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context, AuthStore auth) async {
    final passCtrl = TextEditingController();
    bool busy = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setState) {
          Future<void> submit() async {
            final password = passCtrl.text.trim();
            if (password.length < 6) {
              _toast(ctx, 'Введите пароль (минимум 6 символов)');
              return;
            }
            setState(() => busy = true);
            try {
              await auth.deleteAccount(password);
              if (!context.mounted) return;
              GoRouter.of(context).go('/login');
            } catch (err) {
              setState(() => busy = false);
              _toast(ctx, 'Не удалось удалить профиль: $err');
            }
          }

          return AlertDialog(
            title: const Text('Удалить профиль?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Действие необратимо. Введите пароль для подтверждения.'),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Пароль'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.of(ctx).pop(false),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: busy ? null : submit,
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                child: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Удалить'),
              ),
            ],
          );
        });
      },
    );

    if (result == true && context.mounted) {
      _toast(context, 'Профиль удалён');
    }
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
