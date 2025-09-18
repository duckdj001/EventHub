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
  bool _excludeMine = false;

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
      if (_excludeMine) params.add('excludeMine=true');

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

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: DropdownButtonFormField<String?>(
            value: selectedCategoryId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Категория'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Все категории')),
              ...categories.map((c) => DropdownMenuItem(
                    value: c['id'] as String,
                    child: Text(c['name'] as String),
                  )),
            ],
            onChanged: (value) async {
              setState(() {
                selectedCategoryId = value;
                loading = true;
              });
              await _load();
            },
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Не показывать мои события'),
            value: _excludeMine,
            onChanged: (v) async {
              setState(() {
                _excludeMine = v ?? false;
                loading = true;
              });
              await _load();
            },
          ),
        ),
      ],
    );
  }

  // ---------- /UI: Фильтры ----------

  @override
  Widget build(BuildContext context) {
    late Widget content;
    if (loading) {
      content = Column(
        children: [
          _filters(),
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      );
    } else if (error != null) {
      content = Column(
        children: [
          _filters(),
          Expanded(
            child: ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('Не удалось загрузить события')),
                SizedBox(height: 8),
              ],
            ),
          ),
        ],
      );
    } else if (events.isEmpty) {
      content = Column(
        children: [
          _filters(),
          Expanded(
            child: ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('Событий пока нет')),
                SizedBox(height: 8),
              ],
            ),
          ),
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
                onOwnerTap: events[i].owner != null
                    ? () => context.push('/users/${events[i].owner!.id}')
                    : null,
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
