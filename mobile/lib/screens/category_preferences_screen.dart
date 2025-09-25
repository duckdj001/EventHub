import 'package:flutter/material.dart';

import '../services/catalog_service.dart';
import '../services/user_categories_service.dart';
import '../theme/app_spacing.dart';
import '../theme/components/components.dart';
import '../widgets/auth_scope.dart';

class CategoryPreferencesScreen extends StatefulWidget {
  const CategoryPreferencesScreen({super.key});

  @override
  State<CategoryPreferencesScreen> createState() => _CategoryPreferencesScreenState();
}

class _CategoryPreferencesScreenState extends State<CategoryPreferencesScreen> {
  final CatalogService _catalog = CatalogService();
  final UserCategoriesService _service = UserCategoriesService();

  final Set<String> _selected = <String>{};
  List<Map<String, dynamic>> _categories = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cats = await _catalog.categories();
      List<Map<String, dynamic>> selected = const [];
      try {
        selected = await _service.list();
      } catch (_) {
        // ignore, fallback to existing profile data
      }

      final auth = AuthScope.maybeOf(context);
      final currentFromProfile = auth?.user?.categories ?? const [];
      final initialIds = selected.isNotEmpty
          ? selected
              .map((item) => (item['id'] as String?) ?? '')
              .where((id) => id.isNotEmpty)
              .toList()
          : currentFromProfile.map((c) => c.id).toList();

      final prioritized = <String>[];
      for (final id in initialIds) {
        if (id.isEmpty) continue;
        if (prioritized.contains(id)) continue;
        prioritized.add(id);
        if (prioritized.length == 5) break;
      }

      final suggested = cats
          .where((item) => item['isSuggested'] == true)
          .map((item) => item['id'])
          .whereType<String>()
          .toList(growable: false);
      if (prioritized.length < 5) {
        for (final id in suggested) {
          if (prioritized.contains(id)) continue;
          prioritized.add(id);
          if (prioritized.length == 5) break;
        }
      }
      if (prioritized.length < 5) {
        for (final item in cats) {
          final id = item['id'];
          if (id is! String || id.isEmpty) continue;
          if (prioritized.contains(id)) continue;
          prioritized.add(id);
          if (prioritized.length == 5) break;
        }
      }

      setState(() {
        _categories = cats;
        _selected
          ..clear()
          ..addAll(prioritized.take(5));
        _loading = false;
      });
    } catch (err) {
      setState(() {
        _error = err.toString();
        _loading = false;
      });
    }
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        if (_selected.length >= 5) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Можно выбрать не более пяти категорий')),
          );
        } else {
          _selected.add(id);
        }
      }
    });
  }

  Future<void> _save() async {
    if (_selected.length != 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите ровно пять категорий')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _service.update(_selected.toList());
      final auth = AuthScope.maybeOf(context);
      await auth?.refreshProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Интересы обновлены')));
      Navigator.of(context).maybePop();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Не удалось сохранить: $err')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suggestedIds = _categories
        .where((category) => category['isSuggested'] == true)
        .map((category) => category['id'])
        .whereType<String>()
        .toSet();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Интересы'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Сохранить'),
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
                          const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                          const SizedBox(height: AppSpacing.sm),
                          Text('Ошибка: $_error', textAlign: TextAlign.center),
                          const SizedBox(height: AppSpacing.sm),
                          AppButton.primary(onPressed: _load, label: 'Повторить'),
                        ],
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      AppSurface(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Выберите ровно пять категорий, чтобы видеть больше подходящих событий.',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                            if (suggestedIds.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Категории со значком звезды рекомендуем оставить — их чаще выбирают участники.',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Выбрано: ${_selected.length} из 5',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppSurface(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _categories.map((category) {
                            final id = category['id'];
                            final name = category['name'];
                            if (id is! String || name is! String) {
                              return const SizedBox.shrink();
                            }
                            final isSuggested = suggestedIds.contains(id);
                            final isSelected = _selected.contains(id);
                            final background = theme.colorScheme.surfaceVariant.withOpacity(
                              theme.brightness == Brightness.dark ? 0.35 : 0.55,
                            );
                            final labelColor = isSelected
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurface;
                            return ChoiceChip(
                              avatar: isSuggested
                                  ? Icon(
                                      Icons.auto_awesome,
                                      size: 18,
                                      color: isSelected
                                          ? theme.colorScheme.onPrimary
                                          : theme.colorScheme.primary,
                                    )
                                  : null,
                              label: Text(name),
                              labelStyle: theme.textTheme.bodyMedium?.copyWith(
                                color: labelColor,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              ),
                              selected: isSelected,
                              selectedColor: theme.colorScheme.primary,
                              backgroundColor: background,
                              showCheckmark: false,
                              side: BorderSide(
                                color: isSelected
                                    ? Colors.transparent
                                    : theme.colorScheme.outline.withOpacity(0.3),
                              ),
                              onSelected: (_) => _toggle(id),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
