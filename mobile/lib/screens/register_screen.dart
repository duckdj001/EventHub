import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_client.dart';
import '../services/upload_service.dart';
import '../services/catalog_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final api = ApiClient('http://192.168.0.3:3000');
  final up = UploadService();
  final catalog = CatalogService();
  final f = GlobalKey<FormState>();
  final email = TextEditingController();
  final pass = TextEditingController();
  final first = TextEditingController();
  final last = TextEditingController();
  DateTime? birth;
  File? avatar;
  bool busy = false;
  bool _acceptedTerms = false;
  bool _categoriesLoading = true;
  String? _categoriesError;
  List<Map<String, dynamic>> _categories = const [];
  final Set<String> _selectedCategories = <String>{};

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _categoriesLoading = true;
      _categoriesError = null;
    });
    try {
      final list = await catalog.categories();
      setState(() {
        _categories = list;
        _categoriesLoading = false;
        if (_selectedCategories.isEmpty) {
          final suggested = list
              .where((item) => item['isSuggested'] == true)
              .map((item) => item['id'])
              .whereType<String>()
              .toList(growable: false);
          final prioritized = <String>[...suggested];
          if (prioritized.length < 5) {
            for (final item in list) {
              final id = item['id'];
              if (id is! String || id.isEmpty) continue;
              if (prioritized.contains(id)) continue;
              prioritized.add(id);
              if (prioritized.length == 5) break;
            }
          }
          _selectedCategories
            ..clear()
            ..addAll(prioritized.take(5));
        }
      });
    } catch (err) {
      setState(() {
        _categoriesLoading = false;
        _categoriesError = err.toString();
      });
    }
  }

  void _toggleCategory(String id) {
    setState(() {
      if (_selectedCategories.contains(id)) {
        _selectedCategories.remove(id);
      } else {
        if (_selectedCategories.length >= 5) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Можно выбрать не более пяти категорий')),
          );
        } else {
          _selectedCategories.add(id);
        }
      }
    });
  }

  Future<void> _pickAvatar() async {
    final p = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (p != null) setState(()=> avatar = File(p.path));
  }

  Future<void> _submit() async {
    if (!f.currentState!.validate()) return;
    if (avatar == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Добавьте фото'))); return; }
    if (birth == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Выберите дату рождения'))); return; }
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Подтвердите согласие с пользовательским соглашением')));
      return;
    }
    if (_selectedCategories.length != 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите ровно пять категорий интересов')),
      );
      return;
    }

    setState(()=>busy=true);
    try {
      final url = await up.uploadImage(avatar!, type: 'avatars');
      await api.post('/auth/register', {
        'email': email.text.trim(),
        'password': pass.text,
        'firstName': first.text.trim(),
        'lastName': last.text.trim(),
        'birthDate': birth!.toIso8601String(),
        'avatarUrl': url,
        'acceptedTerms': _acceptedTerms,
        'categories': _selectedCategories.toList(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Проверьте почту и подтвердите email')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally { if (mounted) setState(()=>busy=false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация')),
      body: Form(
        key: f,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: InkWell(
                onTap: _pickAvatar,
                child: CircleAvatar(
                  radius: 40,
                  backgroundImage: avatar != null ? FileImage(avatar!) : null,
                  child: avatar == null ? const Icon(Icons.add_a_photo) : null,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(controller: email, decoration: const InputDecoration(labelText: 'Email'), validator: (v)=> v!=null && v.contains('@')?null:'Введите валидный email'),
            TextFormField(controller: pass, decoration: const InputDecoration(labelText: 'Пароль'), obscureText: true, validator: (v)=> v!=null && v.length>=6?null:'Минимум 6 символов'),
            TextFormField(controller: first, decoration: const InputDecoration(labelText: 'Имя'), validator: (v)=> v!.isNotEmpty?null:'Введите имя'),
            TextFormField(controller: last, decoration: const InputDecoration(labelText: 'Фамилия'), validator: (v)=> v!.isNotEmpty?null:'Введите фамилию'),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(birth == null ? 'Дата рождения' : '${birth!.day}.${birth!.month}.${birth!.year}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final now = DateTime.now();
                final d = await showDatePicker(
                  context: context,
                  firstDate: DateTime(1900),
                  lastDate: DateTime(now.year-14, now.month, now.day), // 14+
                  initialDate: DateTime(now.year-18),
                );
                if (d != null) setState(()=> birth = d);
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Выберите 5 категорий, чтобы видеть подходящие события',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            _buildCategorySelector(),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _acceptedTerms,
              onChanged: (value) => setState(() => _acceptedTerms = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Я принимаю пользовательское соглашение'),
              subtitle: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _showTerms,
                  child: const Text('Открыть условия'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: busy?null:_submit,
              child: busy ? const SizedBox(height:16,width:16,child:CircularProgressIndicator(strokeWidth:2)) : const Text('Создать аккаунт'),
            ),
          ],
        ),
      ),
    );
  }
}

  Widget _buildCategorySelector() {
    if (_categoriesLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_categoriesError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Не удалось загрузить категории: $_categoriesError'),
          const SizedBox(height: 8),
          TextButton(onPressed: _loadCategories, child: const Text('Повторить')),
        ],
      );
    }
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Выбрано: ${_selectedCategories.length} из 5',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        if (_categories.any((c) => c['isSuggested'] == true))
          Text(
            'Категории со значком звезды рекомендуем оставить — их чаще выбирают участники.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories.map((category) {
            final id = category['id'];
            final name = category['name'];
            if (id is! String || name is! String) {
              return const SizedBox.shrink();
            }
            final isSuggested = category['isSuggested'] == true;
            final isSelected = _selectedCategories.contains(id);
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
              onSelected: (_) => _toggleCategory(id),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _showTerms() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        minChildSize: 0.5,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Пользовательское соглашение', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  controller: controller,
                  children: const [
                    Text(
                      'Представьте здесь текст пользовательского соглашения. Пользователь, продолжая регистрацию, подтверждает, что ознакомился с условиями и обязуется их соблюдать. ' 
                      'Данный текст можно заменить на реальный документ или ссылку на страницу с полными условиями.',
                      style: TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
