// lib/screens/create_event_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_client.dart';
import '../services/upload_service.dart';        // ← есть у тебя
import '../services/catalog_service.dart';
import '../widgets/address_picker_field.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});
  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  // services
  final api = ApiClient('http://localhost:3000');
  final uploader = UploadService();
  final catalog = CatalogService();

  // form
  final _form = GlobalKey<FormState>();

  // controllers
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  // state
  DateTime? _startAt;
  DateTime? _endAt;
  bool _isPaid = false;
  bool _requiresApproval = false;
  String? _currency = 'RUB';
  String? _categoryId;

  // geo from AddressPickerField
  double? _lat;
  double? _lon;

  // cover
  File? _coverFile;
  String? _coverUrl;

  // data
  List<Map<String, dynamic>> _categories = [];

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      final list = await catalog.categories(); // GET /categories
      if (!mounted) return;
      setState(() => _categories = list);
    } catch (_) {
      if (!mounted) return;
      _toast('Не удалось загрузить категории');
    }
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _pickCover() async {
    final p = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (p != null) setState(() => _coverFile = File(p.path));
  }

  Future<void> _pickDateTime({required bool start}) async {
    final now = DateTime.now();
    final initial = start ? (_startAt ?? now) : (_endAt ?? _startAt ?? now);

    final d = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      initialDate: initial,
    );
    if (d == null) return;

    final t = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 18, minute: 0),
    );
    if (t == null) return;

    final dt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    setState(() {
      if (start) {
        _startAt = dt;
        if (_endAt != null && _endAt!.isBefore(_startAt!)) _endAt = null;
      } else {
        _endAt = dt;
      }
    });
  }

  String _fmtDate(DateTime? d) => d == null
      ? 'Выбрать'
      : '${d.day}.${d.month}.${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Future<void> _create() async {
    if (!_form.currentState!.validate()) return;

    if (_coverFile == null && _coverUrl == null) {
      _toast('Добавьте обложку');
      return;
    }
    if (_startAt == null || _endAt == null) {
      _toast('Выберите даты');
      return;
    }
    if (_lat == null || _lon == null) {
      _toast('Выберите адрес из подсказок');
      return;
    }
    if (_categoryId == null) {
      _toast('Выберите категорию');
      return;
    }

    setState(() => _busy = true);
    try {
      // 1) upload cover
      final coverUrl =
          _coverUrl ?? await uploader.uploadImage(_coverFile!, type: 'covers');

      // 2) compose body
      final body = {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'categoryId': _categoryId,
        'startAt': _startAt!.toIso8601String(),
        'endAt': _endAt!.toIso8601String(),
        'address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'lat': _lat!.toString(),
        'lon': _lon!.toString(),
        'coverUrl': coverUrl,
        'isPaid': _isPaid,
        'price': _isPaid && _priceCtrl.text.isNotEmpty
            ? int.tryParse(_priceCtrl.text)
            : null,
        'currency': _isPaid ? _currency : null,
        'requiresApproval': _requiresApproval,
      };

      await api.post('/events', body);
      if (!mounted) return;
      Navigator.pop(context, true);
      _toast('Событие создано');
    } catch (e) {
      _toast('Ошибка: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Создать событие')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // cover
            InkWell(
              onTap: _pickCover,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF2F7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _coverFile != null
                      ? Image.file(_coverFile!, fit: BoxFit.cover)
                      : const Center(
                          child: Text('Нажмите, чтобы выбрать обложку'),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Название'),
              validator: (v) =>
                  v != null && v.trim().isNotEmpty ? null : 'Введите название',
            ),
            const SizedBox(height: 8),

            TextFormField(
              controller: _descCtrl,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Описание'),
              validator: (v) =>
                  v != null && v.trim().isNotEmpty ? null : 'Добавьте описание',
            ),
            const SizedBox(height: 8),

            // category
            DropdownButtonFormField<String>(
              value: _categoryId,
              decoration: const InputDecoration(labelText: 'Категория'),
              items: _categories
                  .map((c) => DropdownMenuItem(
                        value: c['id'] as String,
                        child: Text(c['name'] as String),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _categoryId = v),
              validator: (v) => v == null ? 'Выберите категорию' : null,
            ),
            const SizedBox(height: 8),

            // address (autocomplete + lat/lon callback)
            AddressPickerField(
              api: api,
              addressCtrl: _addressCtrl,
              cityCtrl: _cityCtrl,
              onLatLon: (lat, lon) {
                _lat = lat;
                _lon = lon;
              },
            ),
            const SizedBox(height: 8),

            // dates
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Начало'),
              subtitle: Text(_fmtDate(_startAt)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _pickDateTime(start: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Окончание'),
              subtitle: Text(_fmtDate(_endAt)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _pickDateTime(start: false),
            ),
            const SizedBox(height: 8),

            // payment
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Платное мероприятие'),
              value: _isPaid,
              onChanged: (v) => setState(() => _isPaid = v),
            ),
            if (_isPaid) ...[
              TextFormField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Цена'),
                validator: (v) {
                  if (!_isPaid) return null;
                  final n = int.tryParse((v ?? '').trim());
                  if (n == null || n <= 0) return 'Введите корректную цену';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _currency,
                decoration: const InputDecoration(labelText: 'Валюта'),
                items: const [
                  DropdownMenuItem(value: 'RUB', child: Text('RUB ₽')),
                  DropdownMenuItem(value: 'USD', child: Text('USD \$')),
                  DropdownMenuItem(value: 'EUR', child: Text('EUR €')),
                ],
                onChanged: (v) => setState(() => _currency = v),
              ),
            ],

            // approval
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Участие по подтверждению'),
              value: _requiresApproval,
              onChanged: (v) => setState(() => _requiresApproval = v),
            ),

            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _create,
              child: _busy
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Создать'),
            ),
          ],
        ),
      ),
    );
  }
}
