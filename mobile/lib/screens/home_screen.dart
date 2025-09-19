import 'dart:async';

import 'package:characters/characters.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../services/api_client.dart';
import '../models/event.dart';
import '../widgets/event_card.dart';
import '../services/location_service.dart';
import '../services/city_store.dart';
import '../widgets/city_picker.dart';
import '../services/catalog_service.dart';
import '../widgets/auth_scope.dart';
import '../theme/app_spacing.dart';
import '../theme/components/components.dart';
import '../models/user_summary.dart';
import '../services/user_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final api = ApiClient('http://localhost:3000');
  final loc = LocationService();
  final store = CityStore();
  final catalog = CatalogService();

  // данные
  List<Event> events = [];
  List<Event> _filteredEvents = [];
  Map<String, double?> _distanceByEventId = {};
  List<UserSummary> _userResults = [];
  List<Map<String, dynamic>> categories = [];

  // состояние
  bool loading = true;
  String? error;
  String? cityLabel;

  // фильтры
  String? selectedCategoryId;
  bool? filterPaid; // null = все, true = платно, false = бесплатно
  bool _excludeMine = false;
  String? _timeframe;
  DateTime? _customRangeStart;
  DateTime? _customRangeEnd;
  bool _filtersExpanded = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _searchExpanded = false;
  final FocusNode _searchFocus = FocusNode();
  Timer? _searchDebounce;
  bool _searchingUsers = false;
  final UserService _userService = UserService();

  Future<void> _load() async {
    try {
      await store.load();
      categories = await catalog.categories();

      final params = <String>[];
      if (store.hasCity) {
        cityLabel = store.name;
        params.add('lat=${store.lat}');
        params.add('lon=${store.lon}');
        params.add('radiusKm=50');
      } else {
        final current = await loc.getCurrent();
        if (current != null) {
          cityLabel = current.city;
          params.add('lat=${current.lat}');
          params.add('lon=${current.lon}');
          params.add('radiusKm=50');
        }
      }
      if (selectedCategoryId != null)
        params.add('categoryId=$selectedCategoryId');
      if (filterPaid != null) params.add('isPaid=${filterPaid!}');
      if (_customRangeStart != null)
        params.add('startDate=${_customRangeStart!.toIso8601String()}');
      if (_customRangeEnd != null)
        params.add('endDate=${_customRangeEnd!.toIso8601String()}');
      if (_timeframe != null && _timeframe!.isNotEmpty)
        params.add('timeframe=$_timeframe');
      if (_excludeMine) params.add('excludeMine=true');

      var query = '/events';
      if (params.isNotEmpty) query += '?${params.join('&')}';

      final data = await api.get(query);
      final items = (data as List).cast<Map<String, dynamic>>();

      setState(() {
        events = items.map(Event.fromJson).toList();
        _distanceByEventId = {
          for (var i = 0; i < items.length; i++)
            events[i].id: (items[i]['distanceKm'] as num?)?.toDouble(),
        };
        loading = false;
        error = null;
        _applySearch();
        if (_searchQuery.trim().isNotEmpty) {
          _triggerUserSearch(_searchQuery.trim(), immediate: true);
        }
      });
    } catch (e) {
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  void _applySearch() {
    final query = _searchQuery.trim().toLowerCase();
    _filteredEvents = query.isEmpty
        ? List<Event>.from(events)
        : events.where((event) {
            final title = event.title.toLowerCase();
            final description = event.description.toLowerCase();
            final city = event.city.toLowerCase();
            return title.contains(query) ||
                description.contains(query) ||
                city.contains(query);
          }).toList();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final trimmed = value.trim();
    setState(() {
      _searchQuery = value;
      _applySearch();
      if (trimmed.isEmpty) {
        _userResults = [];
        _searchingUsers = false;
      }
    });

    if (trimmed.isEmpty) {
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _triggerUserSearch(trimmed);
    });
  }

  void _clearSearchText() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _userResults = [];
      _searchingUsers = false;
      _searchDebounce?.cancel();
      _applySearch();
    });
  }

  void _collapseSearch() {
    FocusScope.of(context).unfocus();
    setState(() {
      _searchExpanded = false;
      _searchController.clear();
      _searchQuery = '';
      _userResults = [];
      _searchingUsers = false;
      _searchDebounce?.cancel();
      _applySearch();
    });
  }

  void _triggerUserSearch(String query, {bool immediate = false}) {
    _searchDebounce?.cancel();
    _performUserSearch(query);
  }

  Future<void> _performUserSearch(String query) async {
    setState(() {
      _searchingUsers = true;
    });
    try {
      final results = await _userService.search(query, limit: 12);
      if (!mounted) return;
      setState(() {
        _userResults = results;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _userResults = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _searchingUsers = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  // ---------- UI: Фильтры ----------
  Widget _filters() {
    final theme = Theme.of(context);
    final activeCount = _activeFiltersCount;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: AppSurface(
        padding: EdgeInsets.zero,
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: _filtersExpanded,
            onExpansionChanged: (value) =>
                setState(() => _filtersExpanded = value),
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            childrenPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            trailing: Icon(
                _filtersExpanded ? Icons.expand_less : Icons.expand_more,
                color: theme.colorScheme.onSurfaceVariant),
            title: Row(
              children: [
                Icon(Icons.filter_alt_rounded,
                    color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Фильтры',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (activeCount > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$activeCount',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            children: [
              if (activeCount > 0)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Сбросить'),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Стоимость и участие',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  _buildPaidChip('Все', null),
                  _buildPaidChip('Бесплатно', false),
                  _buildPaidChip('Платно', true),
                  _buildExcludeMineChip(theme),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Даты',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildTimeframeChip('Любые даты', null),
                  _buildTimeframeChip('На этой неделе', 'this-week'),
                  _buildTimeframeChip('Следующая неделя', 'next-week'),
                  _buildTimeframeChip('В этом месяце', 'this-month'),
                  _buildCustomRangeButton(theme),
                  if (_customRangeStart != null && _customRangeEnd != null)
                    Chip(
                      label: Text(
                        _formatRange(),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      avatar: Icon(Icons.event,
                          size: 18, color: theme.colorScheme.primary),
                      deleteIconColor: theme.colorScheme.primary,
                      backgroundColor:
                          theme.colorScheme.primary.withOpacity(0.1),
                      onDeleted: () async {
                        setState(() {
                          _customRangeStart = null;
                          _customRangeEnd = null;
                          loading = true;
                        });
                        await _load();
                      },
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Категория',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              DropdownButtonFormField<String?>(
                value: selectedCategoryId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Категория'),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('Все категории')),
                  ...categories.map(
                    (c) => DropdownMenuItem(
                      value: c['id'] as String,
                      child: Text(c['name'] as String),
                    ),
                  ),
                ],
                onChanged: (value) async {
                  setState(() {
                    selectedCategoryId = value;
                    loading = true;
                  });
                  await _load();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExcludeMineChip(ThemeData theme) {
    final selected = _excludeMine;
    return FilterChip(
      label: const Text('Не показывать мои'),
      labelStyle: theme.textTheme.bodyMedium?.copyWith(
        color: selected
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      showCheckmark: false,
      backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.6),
      selectedColor: theme.colorScheme.primary,
      selected: selected,
      onSelected: (value) async {
        setState(() {
          _excludeMine = value;
          loading = true;
        });
        await _load();
      },
    );
  }

  FilterChip _buildPaidChip(String label, bool? value) {
    final theme = Theme.of(context);
    final selected = filterPaid == value;
    return FilterChip(
      label: Text(label),
      labelStyle: theme.textTheme.bodyMedium?.copyWith(
        color: selected
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      showCheckmark: false,
      backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.6),
      selectedColor: theme.colorScheme.primary,
      selected: selected,
      onSelected: (_) async {
        setState(() {
          filterPaid = value;
          loading = true;
        });
        await _load();
      },
    );
  }

  FilterChip _buildTimeframeChip(String label, String? value) {
    final isCustomActive = _customRangeStart != null && _customRangeEnd != null;
    final selected = !isCustomActive && _timeframe == value;
    final theme = Theme.of(context);
    return FilterChip(
      label: Text(label),
      labelStyle: theme.textTheme.bodyMedium?.copyWith(
        color: selected
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      showCheckmark: false,
      backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.6),
      selectedColor: theme.colorScheme.primary,
      selected: selected,
      onSelected: (_) async {
        setState(() {
          _timeframe = value;
          if (value != null) {
            _customRangeStart = null;
            _customRangeEnd = null;
          }
          loading = true;
        });
        await _load();
      },
    );
  }

  Widget _buildCustomRangeButton(ThemeData theme) {
    final color = theme.colorScheme.primary;
    return InkWell(
      onTap: _pickCustomRange,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.date_range, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              'Выбрать даты',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final initialStart = _customRangeStart ?? now;
    final initialEnd = _customRangeEnd ?? now.add(const Duration(days: 1));

    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(useMaterial3: true),
        child: child!,
      ),
    );
    if (range == null) return;

    setState(() {
      _customRangeStart =
          DateTime(range.start.year, range.start.month, range.start.day);
      _customRangeEnd =
          DateTime(range.end.year, range.end.month, range.end.day);
      _timeframe = null;
      loading = true;
    });
    await _load();
  }

  String _formatRange() {
    if (_customRangeStart == null || _customRangeEnd == null) return '';
    final fmt = DateFormat('d MMM', 'ru_RU');
    final start = fmt.format(_customRangeStart!);
    final end = fmt.format(_customRangeEnd!);
    return '$start — $end';
  }

  Future<void> _clearFilters() async {
    setState(() {
      selectedCategoryId = null;
      filterPaid = null;
      _excludeMine = false;
      _timeframe = null;
      _customRangeStart = null;
      _customRangeEnd = null;
      loading = true;
    });
    await _load();
  }

  int get _activeFiltersCount {
    var count = 0;
    if (filterPaid != null) count++;
    if (_excludeMine) count++;
    if (_timeframe != null && _timeframe!.isNotEmpty) count++;
    if (_customRangeStart != null && _customRangeEnd != null) count++;
    if (selectedCategoryId != null) count++;
    return count;
  }

// ---------- /UI: Фильтры ----------

  @override
  Widget build(BuildContext context) {
    const listPadding = EdgeInsets.only(bottom: AppSpacing.lg);
    final hasEventResults = _filteredEvents.isNotEmpty;
    final queryNotEmpty = _searchQuery.trim().isNotEmpty;
    final noResultsDueToSearch = !loading &&
        error == null &&
        events.isNotEmpty &&
        !hasEventResults &&
        queryNotEmpty &&
        _userResults.isEmpty &&
        !_searchingUsers;

    late Widget content;
    if (loading) {
      content = ListView(
        padding: listPadding,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _filters(),
          const SizedBox(height: AppSpacing.md),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    } else if (error != null) {
      content = ListView(
        padding: listPadding,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _filters(),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.xl, AppSpacing.md, 0),
            child: AppSurface(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: Colors.redAccent),
                  const SizedBox(height: AppSpacing.sm),
                  const Text('Не удалось загрузить события',
                      textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton.primary(onPressed: _load, label: 'Повторить'),
                ],
              ),
            ),
          ),
        ],
      );
    } else if (events.isEmpty) {
      content = ListView(
        padding: listPadding,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _filters(),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.xl, AppSpacing.md, 0),
            child: AppSurface(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.event_busy_outlined, size: 48),
                  SizedBox(height: AppSpacing.sm),
                  Text('Событий пока нет', textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ],
      );
    } else if (noResultsDueToSearch) {
      content = ListView(
        padding: listPadding,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _filters(),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.xl, AppSpacing.md, 0),
            child: AppSurface(
              child: Text(
                'Ничего не найдено по запросу "$_searchQuery"',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      );
    } else {
      final listChildren = <Widget>[
        _filters(),
        const SizedBox(height: AppSpacing.md),
      ];

      if (queryNotEmpty) {
        listChildren.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
            child: Text('Пользователи',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
        );

        if (_searchingUsers) {
          listChildren.add(
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        } else if (_userResults.isNotEmpty) {
          listChildren.addAll(
            _userResults.map(
              (u) => Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, 0, AppSpacing.md, AppSpacing.xs),
                child: AppSurface(
                  child: ListTile(
                    onTap: () => context.push('/users/${u.id}'),
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceVariant,
                      backgroundImage:
                          (u.avatarUrl != null && u.avatarUrl!.isNotEmpty)
                              ? NetworkImage(u.avatarUrl!)
                              : null,
                      child: (u.avatarUrl == null || u.avatarUrl!.isEmpty)
                          ? Text(u.fullName.characters.first.toUpperCase())
                          : null,
                    ),
                    title: Text(u.fullName,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    subtitle: u.email != null ? Text(u.email!) : null,
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
              ),
            ),
          );
        }

        if (_filteredEvents.isNotEmpty) {
          listChildren.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
              child: Text('События',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
          );
        }
      }

      listChildren.addAll(
        _filteredEvents.map(
          (event) => Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
            child: EventCard(
              e: event,
              distanceKm: _distanceByEventId[event.id],
              onTap: () => context.push('/events/${event.id}'),
              onOwnerTap: event.owner != null
                  ? () => context.push('/users/${event.owner!.id}')
                  : null,
            ),
          ),
        ),
      );

      content = ListView(
        padding: listPadding,
        physics: const AlwaysScrollableScrollPhysics(),
        children: listChildren,
      );
    }

    final authStore = AuthScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(cityLabel != null ? 'Рядом: $cityLabel' : 'События рядом'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(_searchExpanded ? Icons.close : Icons.search),
            tooltip: _searchExpanded ? 'Скрыть поиск' : 'Поиск',
            onPressed: () {
              if (_searchExpanded) {
                _collapseSearch();
              } else {
                setState(() {
                  _searchExpanded = true;
                  _searchController.text = _searchQuery;
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _searchFocus.requestFocus();
                });
              }
            },
          ),
          AnimatedBuilder(
            animation: authStore,
            builder: (context, _) {
              final count = authStore.unreadNotifications;
              return IconButton(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_outlined),
                    if (count > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(minWidth: 18),
                          child: Text(
                            count > 99 ? '99+' : '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () => context.push('/notifications'),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.location_on_outlined),
            onSelected: (value) async {
              if (value == 'pick') {
                await showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  builder: (_) => CityPickerSheet(
                    onSelected: (c) async {
                      await store.save(name: c.name, lat: c.lat, lon: c.lon);
                    },
                  ),
                );
                setState(() => loading = true);
                await _load();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Город: ${store.name}')),
                  );
                }
              } else if (value == 'clear') {
                await store.clear();
                setState(() => loading = true);
                await _load();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Город сброшен')),
                  );
                }
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'pick', child: Text('Выбрать город')),
              PopupMenuItem(value: 'clear', child: Text('Сбросить город')),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_searchExpanded ? 78 : 0),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: !_searchExpanded
                ? const SizedBox.shrink()
                : Padding(
                    key: const ValueKey('search-bar'),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: SearchBar(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      hintText: 'Поиск событий и людей',
                      leading: const Icon(Icons.search),
                      onChanged: _onSearchChanged,
                      onSubmitted: (value) {
                        final trimmed = value.trim();
                        if (trimmed.isEmpty) return;
                        _triggerUserSearch(trimmed, immediate: true);
                      },
                      textInputAction: TextInputAction.search,
                      trailing: [
                        if (_searchQuery.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            tooltip: 'Очистить',
                            onPressed: _clearSearchText,
                          ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
      body: RefreshIndicator(onRefresh: _load, child: content),
    );
  }
}
