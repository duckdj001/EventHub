// lib/screens/event_details_screen.dart
import 'package:flutter/material.dart';
import '../models/event.dart';
import '../services/api_client.dart';

class EventDetailsScreen extends StatefulWidget {
  final String id;
  const EventDetailsScreen({super.key, required this.id});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  final api = ApiClient('http://localhost:3000');
  Event? e;
  String? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final data = await api.get('/events/${widget.id}');
      setState(() {
        e = Event.fromJson(data as Map<String, dynamic>);
        loading = false;
      });
    } catch (err) {
      setState(() { error = err.toString(); loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Событие')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : (error != null)
              ? Center(child: Text('Ошибка: $error'))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final ev = e!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: (ev.coverUrl != null && ev.coverUrl!.isNotEmpty)
                ? Image.network(ev.coverUrl!, fit: BoxFit.cover)
                : Container(color: const Color(0xFFEFF2F7)),
          ),
        ),
        const SizedBox(height: 12),
        Text(ev.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),

        Row(children: const [
          Icon(Icons.place_outlined, size: 18, color: Colors.black54),
          SizedBox(width: 6),
          Text('Адрес', style: TextStyle(fontWeight: FontWeight.w600)),
        ]),
        Padding(
          padding: const EdgeInsets.only(left: 24, top: 4),
          child: Text(ev.address, style: const TextStyle(fontSize: 16, color: Colors.black87)),
        ),
        const SizedBox(height: 12),

        Row(children: const [
          Icon(Icons.schedule, size: 18, color: Colors.black54),
          SizedBox(width: 6),
          Text('Время', style: TextStyle(fontWeight: FontWeight.w600)),
        ]),
        Padding(
          padding: const EdgeInsets.only(left: 24, top: 4),
          child: Text(
            '${ev.startAt.toLocal()} — ${ev.endAt.toLocal()}',
            style: const TextStyle(fontSize: 16, color: Colors.black87),
          ),
        ),
        const SizedBox(height: 12),

        const Text('Описание', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(ev.description),
      ],
    );
  }
}
