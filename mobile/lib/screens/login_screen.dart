// lib/screens/login_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ← для FilteringTextInputFormatter
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_store.dart';
import '../services/catalog_service.dart';
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
  final CatalogService _catalog = CatalogService();
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
  int _regStep = 0;
  List<Map<String, dynamic>> _regCategories = const [];
  final Set<String> _regSelectedCategories = <String>{};
  bool _regCategoriesLoading = true;
  String? _regCategoriesError;
  bool _regCategoriesInitialized = false;

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
    if (!_regCategoriesInitialized) {
      _regCategoriesInitialized = true;
      _loadRegisterCategories();
    }
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
    final loginPassword = _loginPass.text;
    setState(() => _loginBusy = true);
    try {
      final mustChange =
          await auth.login(_loginEmail.text.trim(), loginPassword);
      if (!mounted) return;
      if (mustChange) {
        final changed =
            await _openForceChangePasswordDialog(auth, loginPassword);
        if (!changed) {
          await auth.logout();
          return;
        }
      }
      _loginPass.clear();
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
                  final loginPassword = _regPass.text;
                  final mustChange = await auth.login(email, loginPassword);
                  if (!mounted) return;
                  if (mustChange) {
                    final changed = await _openForceChangePasswordDialog(
                      auth,
                      loginPassword,
                    );
                    if (!changed) {
                      await auth.logout();
                      _toast('E-mail подтверждён! Войдите и задайте новый пароль.');
                      _tab.animateTo(0);
                      return;
                    }
                  }
                  context.go('/');
                  _toast('Добро пожаловать!');
                  _regPass.clear();
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

  Future<void> _submitRegisterInfoStep() async {
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

    FocusScope.of(context).unfocus();
    if (!_regCategoriesInitialized) {
      _loadRegisterCategories();
    }

    setState(() => _regStep = 1);
  }

  Future<void> _register() async {
    if (_regStep == 0) {
      await _submitRegisterInfoStep();
      return;
    }
    if (_regSelectedCategories.length != 5) {
      _toast('Выберите ровно 5 категорий интересов');
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
        'categories': _regSelectedCategories.toList(),
      };

      final auth = _auth ?? AuthScope.of(context);
      await auth.api.post('/auth/register', body, auth: false);

      if (!mounted) return;
      // сразу открываем лист для ввода кода
      await _openVerifySheet(_regEmail.text.trim());
      if (mounted) {
        setState(() => _regStep = 0);
      }
    } catch (e) {
      final message = e.toString();
      if (message.contains('уже зарегистрирован')) {
        await _showUserExistsDialog();
      } else {
        _toast('Ошибка регистрации: $message');
      }
    } finally {
      if (mounted) setState(() => _regBusy = false);
    }
  }

  Future<void> _loadRegisterCategories() async {
    setState(() {
      _regCategoriesLoading = true;
      _regCategoriesError = null;
    });
    try {
      final list = await _catalog.categories();
      if (!mounted) return;
      setState(() {
        _regCategories = list;
        _regCategoriesLoading = false;
        if (_regSelectedCategories.isEmpty) {
          final suggested = list
              .where((item) => item['isSuggested'] == true)
              .map((item) => item['id'] as String)
              .toList(growable: false);
          final prioritized = <String>[...suggested];
          if (prioritized.length < 5) {
            for (final item in list) {
              final id = item['id'] as String?;
              if (id == null) continue;
              if (prioritized.contains(id)) continue;
              prioritized.add(id);
              if (prioritized.length == 5) break;
            }
          }
          _regSelectedCategories
            ..clear()
            ..addAll(prioritized.take(5));
        }
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _regCategoriesError = err.toString();
        _regCategoriesLoading = false;
      });
    }
  }

  void _toggleRegisterCategory(String id) {
    setState(() {
      if (_regSelectedCategories.contains(id)) {
        _regSelectedCategories.remove(id);
      } else {
        if (_regSelectedCategories.length >= 5) {
          _toast('Можно выбрать не более пяти категорий');
        } else {
          _regSelectedCategories.add(id);
        }
      }
    });
  }

  Future<void> _openForgotPasswordDialog() async {
    final emailCtrl = TextEditingController(text: _loginEmail.text.trim());
    bool busy = false;
    final auth = _auth ?? AuthScope.of(context);
    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            Future<void> submit() async {
              final email = emailCtrl.text.trim();
              if (email.isEmpty || !email.contains('@')) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Введите корректный e-mail')),
                );
                return;
              }
              setState(() => busy = true);
              try {
                await auth.requestPasswordReset(email);
                if (!mounted) return;
                Navigator.of(ctx).pop();
                _toast('Временный пароль отправлен на почту');
              } catch (err) {
                setState(() => busy = false);
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Ошибка: $err')),
                );
              }
            }

            return AlertDialog(
              title: const Text('Восстановление пароля'),
              content: TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-mail'),
              ),
              actions: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: busy ? null : submit,
                  child: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Отправить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _openForceChangePasswordDialog(
    AuthStore auth,
    String currentPassword,
  ) async {
    FocusScope.of(context).unfocus();
    final newPass = TextEditingController();
    final repeatPass = TextEditingController();
    bool busy = false;
    bool success = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            Future<void> submit() async {
              final np = newPass.text.trim();
              final rp = repeatPass.text.trim();
              if (np.length < 6) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Пароль должен содержать минимум 6 символов')),
                );
                return;
              }
              if (np != rp) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Пароли не совпадают')),
                );
                return;
              }
              setState(() => busy = true);
              try {
                await auth.changePassword(currentPassword, np);
                success = true;
                if (!mounted) return;
                _loginPass.clear();
                _regPass.clear();
                Navigator.of(ctx).pop();
              } catch (err) {
                setState(() => busy = false);
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Не удалось сохранить пароль: $err')),
                );
              }
            }

            return AlertDialog(
              title: const Text('Смените пароль'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Введите новый пароль перед продолжением работы в приложении.'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPass,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Новый пароль'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: repeatPass,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Повторите пароль'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Выйти'),
                ),
                TextButton(
                  onPressed: busy ? null : submit,
                  child: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );

    if (success) {
      _toast('Пароль обновлён');
    }
    return success;
  }

  Future<void> _showUserExistsDialog() async {
    if (!mounted) return;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Аккаунт уже существует'),
        content: const Text(
          'Пользователь с таким e-mail уже зарегистрирован. '
          'Можно войти под существующей учётной записью или восстановить пароль.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('reset'),
            child: const Text('Восстановить пароль'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('login'),
            child: const Text('Перейти ко входу'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );

    if (!mounted || result == null) return;

    setState(() => _regStep = 0);

    final email = _regEmail.text.trim();
    if (email.isNotEmpty) {
      _loginEmail.text = email;
    }
    _tab.animateTo(0);

    if (result == 'reset') {
      await _openForgotPasswordDialog();
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
          TextButton(
            onPressed: _loginBusy ? null : _openForgotPasswordDialog,
            child: const Text('Забыли пароль?'),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: _regForm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildRegisterStepHeader(theme),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _regStep == 0
                ? _buildRegisterInfoStep(theme)
                : _buildRegisterCategoriesStep(theme),
          ),
          const SizedBox(height: 24),
          if (_regStep == 1)
            TextButton(
              onPressed: _regBusy ? null : () => setState(() => _regStep = 0),
              child: const Text('Назад'),
            ),
          AppButton.primary(
            onPressed: _regBusy
                ? null
                : (_regStep == 0 ? _submitRegisterInfoStep : _register),
            label: _regStep == 0 ? 'Далее' : 'Создать аккаунт',
            busy: _regStep == 1 && _regBusy,
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterStepHeader(ThemeData theme) {
    const titles = ['Основные данные', 'Интересы'];
    const descriptions = [
      'Заполните профиль и подтвердите согласие, чтобы продолжить.',
      'Выберите ровно пять категорий, чтобы получать подходящие события.',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Шаг ${_regStep + 1} из 2',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          titles[_regStep],
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          descriptions[_regStep],
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterInfoStep(ThemeData theme) {
    ImageProvider? avatar;
    if (_avatarFile != null) {
      avatar = FileImage(_avatarFile!);
    } else if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      avatar = NetworkImage(_avatarUrl!);
    }

    return Column(
      key: const ValueKey('register-info-step'),
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
            icon: Icon(
                _regPasswordVisible ? Icons.visibility_off : Icons.visibility),
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
      ],
    );
  }

  Widget _buildRegisterCategoriesStep(ThemeData theme) {
    if (_regCategoriesLoading) {
      return const Center(
        key: ValueKey('register-categories-loading'),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_regCategoriesError != null) {
      return Column(
        key: const ValueKey('register-categories-error'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Не удалось загрузить категории: $_regCategoriesError',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _regBusy ? null : _loadRegisterCategories,
            child: const Text('Повторить попытку'),
          ),
        ],
      );
    }

    final suggestedIds = _regCategories
        .where((category) => category['isSuggested'] == true)
        .map((category) => category['id'])
        .whereType<String>()
        .toSet();

    final background = theme.colorScheme.surfaceVariant.withOpacity(
      theme.brightness == Brightness.dark ? 0.35 : 0.55,
    );

    return Column(
      key: const ValueKey('register-categories-step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Выбрано: ${_regSelectedCategories.length} из 5',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Text(
          'Выбранные категории подсвечены цветом. Нажмите на тег, чтобы добавить или убрать его.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (suggestedIds.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Категории со значком ✨ рекомендуем оставить — их чаще выбирают участники.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _regCategories.map((category) {
            final id = category['id'];
            final name = category['name'];
            if (id is! String || name is! String) {
              return const SizedBox.shrink();
            }
            final isSuggested = suggestedIds.contains(id);
            final isSelected = _regSelectedCategories.contains(id);
            final labelColor = isSelected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface;
            return ChoiceChip(
              key: ValueKey('register-category-$id'),
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
              onSelected: (_) => _toggleRegisterCategory(id),
            );
          }).toList(),
        ),
      ],
    );
  }
}
