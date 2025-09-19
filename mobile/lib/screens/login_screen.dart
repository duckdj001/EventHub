// lib/screens/login_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ← для FilteringTextInputFormatter
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_store.dart';
import '../services/upload_service.dart';
import '../widgets/auth_scope.dart';
import '../theme/components/components.dart';
import '../theme/app_spacing.dart';

const String _termsText = '''
1. Общие положения
1.1. Настоящее пользовательское соглашение (далее — "Соглашение") регулирует порядок использования сервиса Vibe и заключено в соответствии с требованиями законодательства Российской Федерации, в том числе Гражданского кодекса РФ, Федерального закона от 27.07.2006 № 149-ФЗ "Об информации, информационных технологиях и о защите информации" и Федерального закона от 27.07.2006 № 152-ФЗ "О персональных данных".
1.2. Регистрируясь в приложении, пользователь подтверждает, что достиг возраста 18 лет, ознакомился с условиями Соглашения и обязуется их соблюдать.

2. Персональные данные
2.1. Предоставляя свои персональные данные, пользователь подтверждает согласие на их обработку организатором сервиса в целях регистрации, идентификации, предоставления функционала приложения, рассылки уведомлений, а также исполнения требований законодательства РФ.
2.2. Обработка персональных данных осуществляется с соблюдением принципов и требований Федерального закона № 152-ФЗ, в том числе с использованием средств автоматизации. Пользователь вправе в любой момент отозвать согласие на обработку персональных данных, направив письменное уведомление на адрес электронной почты службы поддержки Vibe.

3. Использование сервиса
3.1. Пользователь обязуется:
    • предоставлять достоверные сведения при регистрации и при создании мероприятий;
    • не размещать материалы, нарушающие законодательство РФ, права и законные интересы третьих лиц;
    • самостоятельно отвечать за сохранность учётных данных.
3.2. Организатор сервиса вправе ограничить или прекратить доступ пользователя к приложению при нарушении условий Соглашения или требований законодательства РФ.

4. Заключительные положения
4.1. Организатор сервиса вправе вносить изменения в Соглашение в одностороннем порядке, публикуя обновлённую редакцию в приложении. Продолжение использования сервиса после изменения условий означает согласие пользователя с новой редакцией.
4.2. По вопросам, связанным с исполнением Соглашения и обработкой персональных данных, пользователь может обратиться в службу поддержки Vibe по адресу support@vibe.example.''';

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
  bool _loginPasswordVisible = false;

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
  bool _regAcceptedTerms = false;
  bool _regPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(_handleTabChange);
    uploader = UploadService();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _auth ??= AuthScope.of(context);
  }

  @override
  void dispose() {
    _tab.removeListener(_handleTabChange);
    _tab.dispose();

    _loginEmail.dispose();
    _loginPass.dispose();

    _firstName.dispose();
    _lastName.dispose();
    _regEmail.dispose();
    _regPass.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (!mounted) return;
    setState(() {});
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
      await _showLoginErrorDialog();
    } finally {
      if (mounted) setState(() => _loginBusy = false);
    }
  }

  Future<void> _showLoginErrorDialog() async {
    if (!mounted) return;
    const message = 'Неверный e-mail или пароль. Проверьте введённые данные и попробуйте ещё раз.';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ошибка входа'),
        content: Text(message.isNotEmpty ? message : 'Неверный логин или пароль.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Ок')),
        ],
      ),
    );
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
    if (!_regAcceptedTerms) {
      _toast('Подтвердите согласие с пользовательским соглашением');
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
        'acceptedTerms': _regAcceptedTerms,
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

  void _openTerms() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.9,
          minChildSize: 0.6,
          builder: (_, controller) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Пользовательское соглашение',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close),
                        tooltip: 'Закрыть',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Expanded(
                    child: SelectionArea(
                      child: ListView(
                        controller: controller,
                        children: [
                          Text(
                            _termsText,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ================== UI ===================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLogin = _tab.index == 0;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF101217), Color(0xFF131821), Color(0xFF161E28)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Vibe',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Планируйте и посещайте события в один клик',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.72),
                      ),
                    ),
                    const SizedBox(height: 32),
                    AppSurface(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSegmentedToggle(theme),
                          const SizedBox(height: 24),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeInOut,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              switchInCurve: Curves.easeOut,
                              switchOutCurve: Curves.easeIn,
                              child: isLogin
                                  ? _buildLoginForm(context)
                                  : _buildRegisterForm(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentedToggle(ThemeData theme) {
    final isLogin = _tab.index == 0;
    final baseColor = theme.colorScheme.surfaceVariant.withOpacity(
      theme.brightness == Brightness.dark ? 0.25 : 0.4,
    );

    return Container(
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildToggleButton(theme, 'Вход', 0, isLogin),
          _buildToggleButton(theme, 'Регистрация', 1, !isLogin),
        ],
      ),
    );
  }

  Widget _buildToggleButton(ThemeData theme, String title, int index, bool active) {
    final colorScheme = theme.colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: () => _tab.animateTo(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: active
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(BuildContext context) {
    return Form(
      key: _loginForm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _loginEmail,
            keyboardType: TextInputType.emailAddress,
            label: 'E-mail',
            prefixIcon: Icons.mail_outline,
            validator: (v) => v != null && v.contains('@')
                ? null
                : 'Введите корректный e-mail',
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _loginPass,
            obscureText: !_loginPasswordVisible,
            label: 'Пароль',
            prefixIcon: Icons.lock_outline,
            suffix: IconButton(
              icon: Icon(_loginPasswordVisible ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _loginPasswordVisible = !_loginPasswordVisible),
            ),
            validator: (v) => v != null && v.length >= 6
                ? null
                : 'Мин. 6 символов',
          ),
          const SizedBox(height: 24),
          AppButton.primary(
            onPressed: _loginBusy ? null : _login,
            label: 'Войти',
            busy: _loginBusy,
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm(BuildContext context) {
    final theme = Theme.of(context);

    ImageProvider? avatar;
    if (_avatarFile != null) {
      avatar = FileImage(_avatarFile!);
    } else if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      avatar = NetworkImage(_avatarUrl!);
    }

    return Form(
      key: _regForm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: theme.colorScheme.surfaceVariant.withOpacity(
              theme.brightness == Brightness.dark ? 0.25 : 0.4,
            ),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: _regBusy ? null : _pickAvatar,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                      backgroundImage: avatar,
                      child: avatar == null
                          ? const Icon(Icons.add_a_photo_outlined, size: 22)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            avatar == null
                                ? 'Добавьте фото профиля'
                                : 'Фото обновлено',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'JPG или PNG до 5 МБ',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: theme.iconTheme.color?.withOpacity(0.4)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _firstName,
                  label: 'Имя',
                  prefixIcon: Icons.person_outline,
                  validator: (v) => v != null && v.trim().isNotEmpty
                      ? null
                      : 'Укажите имя',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  controller: _lastName,
                  label: 'Фамилия',
                  validator: (v) => v != null && v.trim().isNotEmpty
                      ? null
                      : 'Укажите фамилию',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _regEmail,
            keyboardType: TextInputType.emailAddress,
            label: 'E-mail',
            prefixIcon: Icons.mail_outline,
            validator: (v) => v != null && v.contains('@')
                ? null
                : 'Введите корректный e-mail',
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _regPass,
            obscureText: !_regPasswordVisible,
            label: 'Пароль (мин. 6)',
            prefixIcon: Icons.lock_outline,
            suffix: IconButton(
              icon: Icon(_regPasswordVisible ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _regPasswordVisible = !_regPasswordVisible),
            ),
            validator: (v) => v != null && v.length >= 6
                ? null
                : 'Мин. 6 символов',
          ),
          const SizedBox(height: 16),
          Material(
            color: theme.colorScheme.surfaceVariant.withOpacity(
              theme.brightness == Brightness.dark ? 0.2 : 0.32,
            ),
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: _regBusy ? null : _pickBirthDate,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.event_outlined, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Дата рождения',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _birthDate == null
                                ? 'Выберите дату'
                                : '${_birthDate!.day.toString().padLeft(2, '0')}.'
                                    '${_birthDate!.month.toString().padLeft(2, '0')}.'
                                    '${_birthDate!.year}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: theme.iconTheme.color?.withOpacity(0.4)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _regAcceptedTerms,
                onChanged: (value) => setState(() => _regAcceptedTerms = value ?? false),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Я принимаю пользовательское соглашение',
                      style: theme.textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: _openTerms,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        alignment: Alignment.centerLeft,
                      ),
                      child: const Text('Открыть условия'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AppButton.primary(
            onPressed: _regBusy ? null : _register,
            label: 'Создать аккаунт',
            busy: _regBusy,
          ),
        ],
      ),
    );
  }

}
