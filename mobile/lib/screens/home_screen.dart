import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/api_client.dart';
import '../models/event.dart';
import '../widgets/event_card.dart';
import '../services/location_service.dart';
import '../services/city_store.dart';
import '../widgets/city_picker.dart';
import '../services/catalog_service.dart';

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
  List<double?> distances = []; // км из ответа (distanceKm)
  List<Map<String, dynamic>> categories = [];

  // состояние
  bool loading = true;
  String? error;
  String? cityLabel;

  // фильтры
  String? selectedCategoryId;
  bool? filterPaid; // null = все, true = платно, false = бесплатно

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
      if (selectedCategoryId != null) params.add('categoryId=$selectedCategoryId');
      if (filterPaid != null) params.add('isPaid=${filterPaid!}');

      var query = '/events';
      if (params.isNotEmpty) query += '?${params.join('&')}';

      final data = await api.get(query);
      final items = (data as List).cast<Map<String, dynamic>>();

      setState(() {
        events = items.map(Event.fromJson).toList();
        distances = items.map((j) => (j['distanceKm'] as num?)?.toDouble()).toList();
        loading = false;
        error = null;
      });
    } catch (e) {
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ---------- UI: Фильтры ----------
  Widget _filters() {
    return Column(
      children: [
        // сегмент Все/Бесплатно/Платно
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Все')),
              ButtonSegment(value: 1, label: Text('Бесплатно')),
              ButtonSegment(value: 2, label: Text('Платно')),
            ],
            selected: <int>{ filterPaid == null ? 0 : (filterPaid! ? 2 : 1) },
            onSelectionChanged: (s) async {
              final v = s.first;
              setState(() {
                filterPaid = v == 0 ? null : (v == 2);
                loading = true;
              });
              await _load();
            },
          ),
        ),

        // ОДНА линия категорий — без переносов
        SizedBox(
          height: 46, // фиксируем, чтобы ничего не «пролезало» вторым рядом
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Row(
              children: [
                ..._firstCategories().map((c) {
                  final id = c['id'] as String;
                  final name = c['name'] as String;
                  final selected = selectedCategoryId == id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(name),
                      selected: selected,
                      onSelected: (_) async {
                        setState(() { selectedCategoryId = selected ? null : id; loading = true; });
                        await _load();
                      },
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  );
                }),
                if (_hasMoreCategories())
                  ChoiceChip(
                    label: const Text('Ещё…'),
                    selected: false,
                    onSelected: (_) => _showAllCategories(),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Map<String,dynamic>> _firstCategories() {
    if (categories.length <= 6) return categories;
    return categories.take(6).toList();
  }

  bool _hasMoreCategories() => categories.length > 6;

  Future<void> _showAllCategories() async {
    final picked = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Категории', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories.map((c) {
                    final id = c['id'] as String;
                    final name = c['name'] as String;
                    final selected = selectedCategoryId == id;
                    return ChoiceChip(
                      label: Text(name),
                      selected: selected,
                      onSelected: (_) => Navigator.of(context).pop(selected ? null : id),
                      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: const Text('Сбросить'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null || selectedCategoryId != null) {
      setState(() { selectedCategoryId = picked; loading = true; });
      await _load();
    }
  }
  // ---------- /UI: Фильтры ----------

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (loading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (error != null) {
      content = ListView(
        children: [
          const SizedBox(height: 120),
          const Center(child: Text('Не удалось загрузить события')),
          const SizedBox(height: 8),
          Center(child: Text('$error')),
        ],
      );
    } else if (events.isEmpty) {
      content = ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: Text('Событий пока нет')),
          SizedBox(height: 8),
        ],
      );
    } else {
      content = Column(
        children: [
          _filters(),
          Expanded(
            child: ListView.builder(
              itemCount: events.length,
              itemBuilder: (_, i) => EventCard(
                e: events[i],
                distanceKm: i < distances.length ? distances[i] : null,
                onTap: () => context.push('/events/${events[i].id}'),
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(cityLabel != null ? 'Рядом: $cityLabel' : 'События рядом'),
        automaticallyImplyLeading: false,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.location_on_outlined),
            onSelected: (value) async {
              if (value == 'pick') {
                await showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
      ),
      body: RefreshIndicator(onRefresh: _load, child: content),
    );
  }
}
