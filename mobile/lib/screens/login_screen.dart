// lib/screens/login_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ← для FilteringTextInputFormatter
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_store.dart';
import '../services/upload_service.dart';
import '../widgets/auth_scope.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  // Сервисы
  late final UploadService uploader;
  AuthStore? _auth;

  // Табы: Вход / Регистрация
  late final TabController _tab;

  // ---------- Вход ----------
  final _loginForm = GlobalKey<FormState>();
  final _loginEmail = TextEditingController();
  final _loginPass = TextEditingController();
  bool _loginBusy = false;

  // ------- Регистрация -------
  final _regForm = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _regEmail = TextEditingController();
  final _regPass = TextEditingController();
  DateTime? _birthDate;
  File? _avatarFile;
  String? _avatarUrl;
  bool _regBusy = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    uploader = UploadService();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _auth ??= AuthScope.of(context);
  }

  @override
  void dispose() {
    _tab.dispose();

    _loginEmail.dispose();
    _loginPass.dispose();

    _firstName.dispose();
    _lastName.dispose();
    _regEmail.dispose();
    _regPass.dispose();
    super.dispose();
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  // ================= LOGIN =================
  Future<void> _login() async {
    if (!_loginForm.currentState!.validate()) return;
    final auth = _auth ?? AuthScope.of(context);
    setState(() => _loginBusy = true);
    try {
      await auth.login(_loginEmail.text.trim(), _loginPass.text);
      if (!mounted) return;
      context.go('/'); // на главную
    } catch (e) {
      _toast('Ошибка входа: $e');
    } finally {
      if (mounted) setState(() => _loginBusy = false);
    }
  }

  // ================ VERIFY SHEET (6 цифр) ================
  Future<void> _openVerifySheet(String email) async {
    final codeCtrl = TextEditingController();
    bool busy = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) {
            Future<void> verify() async {
              final code = codeCtrl.text.trim();
              if (code.length != 6) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Введите 6 цифр')),
                );
                return;
              }
              setSt(() => busy = true);
              try {
                final auth = _auth ?? AuthScope.of(context);
                final api = auth.api;
                await api.post('/auth/verify', {
                  'email': email,
                  'code': code,
                }, auth: false);
                if (!mounted) return;
                Navigator.of(ctx).pop(); // закрыть лист
                try {
                  await auth.login(email, _regPass.text);
                  if (!mounted) return;
                  context.go('/');
                  _toast('Добро пожаловать!');
                } catch (err) {
                  _toast('E-mail подтверждён! Войдите, используя свои данные.');
                  _tab.animateTo(0);
                }
              } catch (e) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Ошибка: $e')),
                );
              } finally {
                setSt(() => busy = false);
              }
            }

            Future<void> resend() async {
              setSt(() => busy = true);
              try {
                final auth = _auth ?? AuthScope.of(context);
                final api = auth.api;
                await api.post('/auth/resend', {'email': email}, auth: false);
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Код отправлен ещё раз')),
                );
              } catch (e) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Ошибка: $e')),
                );
              } finally {
                setSt(() => busy = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Подтверждение e-mail',
                      style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('Мы отправили 6-значный код на $email'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'Код из письма',
                      counterText: '',
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onSubmitted: (_) => busy ? null : verify(),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: busy ? null : verify,
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Подтвердить'),
                  ),
                  TextButton(
                    onPressed: busy ? null : resend,
                    child: const Text('Отправить код ещё раз'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ================ REGISTER ================
  Future<void> _pickAvatar() async {
    final x = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x != null) setState(() => _avatarFile = File(x.path));
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(1900, 1, 1);
    final lastDate = DateTime(now.year - 14, now.month, now.day); // 14+
    final init = _birthDate ?? DateTime(now.year - 18, now.month, now.day);
    final d = await showDatePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDate: init,
    );
    if (d != null) setState(() => _birthDate = d);
  }

  Future<void> _register() async {
    if (!_regForm.currentState!.validate()) return;

    if (_avatarFile == null && _avatarUrl == null) {
      _toast('Загрузите фото профиля');
      return;
    }
    if (_birthDate == null) {
      _toast('Укажите дату рождения');
      return;
    }

    setState(() => _regBusy = true);
    try {
      // 1) грузим аватар (если ещё не было URL)
      final avatarUrl = _avatarUrl ??
          await uploader.uploadImage(_avatarFile!, type: 'avatars', auth: false);

      // 2) делаем ПОЛНЫЙ ISO (UTC) — чтобы прошло @IsDateString()
      final onlyDate =
          DateTime(_birthDate!.year, _birthDate!.month, _birthDate!.day);
      final birthIso =
          onlyDate.toUtc().toIso8601String(); // 1994-05-12T00:00:00.000Z

      // 3) запрос
      final body = {
        'firstName': _firstName.text.trim(),
        'lastName': _lastName.text.trim(),
        'email': _regEmail.text.trim(),
        'password': _regPass.text,
        'birthDate': birthIso,
        'avatarUrl': avatarUrl,
      };

      final auth = _auth ?? AuthScope.of(context);
      await auth.api.post('/auth/register', body, auth: false);

      if (!mounted) return;
      // сразу открываем лист для ввода кода
      await _openVerifySheet(_regEmail.text.trim());
    } catch (e) {
      _toast('Ошибка регистрации: $e');
    } finally {
      if (mounted) setState(() => _regBusy = false);
    }
  }

  // ================== UI ===================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EventHub'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Вход'),
            Tab(text: 'Регистрация'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // -------- ВХОД --------
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _loginForm,
              child: Column(
                children: [
                  TextFormField(
                    controller: _loginEmail,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                    validator: (v) => v != null && v.contains('@')
                        ? null
                        : 'Введите корректный e-mail',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _loginPass,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Пароль'),
                    validator: (v) => v != null && v.length >= 6
                        ? null
                        : 'Мин. 6 символов',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loginBusy ? null : _login,
                    child: _loginBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Войти'),
                  ),
                ],
              ),
            ),
          ),

          // ------ РЕГИСТРАЦИЯ ------
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _regForm,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // аватар
                  Center(
                    child: InkWell(
                      onTap: _pickAvatar,
                      borderRadius: BorderRadius.circular(48),
                      child: CircleAvatar(
                        radius: 48,
                        backgroundImage:
                            _avatarFile != null ? FileImage(_avatarFile!) : null,
                        child: _avatarFile == null
                            ? const Icon(Icons.add_a_photo_outlined, size: 28)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _firstName,
                          decoration: const InputDecoration(labelText: 'Имя'),
                          validator: (v) => v != null && v.trim().isNotEmpty
                              ? null
                              : 'Укажите имя',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _lastName,
                          decoration: const InputDecoration(labelText: 'Фамилия'),
                          validator: (v) => v != null && v.trim().isNotEmpty
                              ? null
                              : 'Укажите фамилию',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _regEmail,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                    validator: (v) => v != null && v.contains('@')
                        ? null
                        : 'Введите корректный e-mail',
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _regPass,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'Пароль (мин. 6)'),
                    validator: (v) => v != null && v.length >= 6
                        ? null
                        : 'Мин. 6 символов',
                  ),
                  const SizedBox(height: 12),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Дата рождения'),
                    subtitle: Text(_birthDate == null
                        ? 'Выбрать'
                        : '${_birthDate!.day.toString().padLeft(2, '0')}.'
                            '${_birthDate!.month.toString().padLeft(2, '0')}.'
                            '${_birthDate!.year}'),
                    trailing: const Icon(Icons.event_outlined),
                    onTap: _pickBirthDate,
                  ),
                  const SizedBox(height: 16),

                  FilledButton(
                    onPressed: _regBusy ? null : _register,
                    child: _regBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Зарегистрироваться'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
