import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_client.dart';
import '../services/upload_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final api = ApiClient('http://localhost:3000');
  final up = UploadService();
  final f = GlobalKey<FormState>();
  final email = TextEditingController();
  final pass = TextEditingController();
  final first = TextEditingController();
  final last = TextEditingController();
  DateTime? birth;
  File? avatar;
  bool busy = false;
  bool _acceptedTerms = false;

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
