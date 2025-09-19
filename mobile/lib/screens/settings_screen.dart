import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_spacing.dart';
import '../theme/components/components.dart';
import '../theme/theme_scope.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeScope.of(context);
    final isDark = themeController.mode == ThemeMode.dark;

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
              subtitle: const Text('Настройки уведомлений и просмотр истории'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/notifications'),
            ),
          ),
        ],
      ),
    );
  }
}
