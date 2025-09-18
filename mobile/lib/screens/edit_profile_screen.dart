import 'package:flutter/material.dart';

import '../services/auth_store.dart';
import '../services/user_service.dart';
import '../widgets/auth_scope.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final UserService _service = UserService();
  AuthStore? _auth;

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();

  final _newEmailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _savingProfile = false;
  bool _emailRequestBusy = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = AuthScope.of(context);
    if (_auth != store) {
      _auth = store;
      final user = store.user;
      if (user != null) {
        _firstNameCtrl.text = user.firstName;
        _lastNameCtrl.text = user.lastName;
        _bioCtrl.text = user.bio ?? '';
        _birthDateCtrl.text = user.birthDate != null
            ? '${user.birthDate!.year.toString().padLeft(4, '0')}-${user.birthDate!.month.toString().padLeft(2, '0')}-${user.birthDate!.day.toString().padLeft(2, '0')}'
            : '';
      }
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _bioCtrl.dispose();
    _birthDateCtrl.dispose();
    _newEmailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveProfile() async {
    setState(() => _savingProfile = true);
    try {
      await _service.updateProfile(
        firstName: _firstNameCtrl.text.trim().isEmpty ? null : _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim().isEmpty ? null : _lastNameCtrl.text.trim(),
        bio: _bioCtrl.text.trim(),
        birthDate: _birthDateCtrl.text.trim().isEmpty ? null : _birthDateCtrl.text.trim(),
      );
      await (_auth?.refreshProfile() ?? Future<void>.value());
      if (!mounted) return;
      _toast('Профиль обновлён');
      Navigator.of(context).pop(true);
    } catch (err) {
      if (!mounted) return;
      _toast('Не удалось сохранить профиль: $err');
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _requestEmailChange() async {
    setState(() => _emailRequestBusy = true);
    try {
      await _service.requestEmailChange(
        newEmail: _newEmailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      if (!mounted) return;
      _toast('Код отправлен на новый e-mail');
      await _openConfirmEmailSheet();
    } catch (err) {
      if (!mounted) return;
      _toast('Не удалось запросить смену e-mail: $err');
    } finally {
      if (mounted) setState(() => _emailRequestBusy = false);
    }
  }

  Future<void> _openConfirmEmailSheet() async {
    final codeCtrl = TextEditingController();
    bool busy = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (ctx, setStateModal) {
              Future<void> submit() async {
                setStateModal(() => busy = true);
                try {
                  await _service.confirmEmailChange(code: codeCtrl.text.trim());
                  await (_auth?.refreshProfile() ?? Future<void>.value());
                  if (!mounted) return;
                  Navigator.of(ctx).pop();
                  _toast('E-mail обновлён');
                } catch (err) {
                  if (!mounted) return;
                  _toast('Не удалось подтвердить e-mail: $err');
                } finally {
                  if (mounted) setStateModal(() => busy = false);
                }
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Подтверждение нового e-mail', style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(labelText: 'Код из письма'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    child: busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Подтвердить'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingEmail = _auth?.user?.pendingEmail;

    return Scaffold(
      appBar: AppBar(title: const Text('Редактирование профиля')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _firstNameCtrl,
            decoration: const InputDecoration(labelText: 'Имя'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _lastNameCtrl,
            decoration: const InputDecoration(labelText: 'Фамилия'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _birthDateCtrl,
            decoration: const InputDecoration(labelText: 'Дата рождения (YYYY-MM-DD)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bioCtrl,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'О себе'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _savingProfile ? null : _saveProfile,
            child: _savingProfile
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Сохранить'),
          ),
          const SizedBox(height: 32),
          const Text('Смена e-mail', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          if (pendingEmail != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Ожидает подтверждения: $pendingEmail', style: const TextStyle(color: Colors.orange)),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _newEmailCtrl,
            decoration: const InputDecoration(labelText: 'Новый e-mail'),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordCtrl,
            decoration: const InputDecoration(labelText: 'Текущий пароль'),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _emailRequestBusy ? null : _requestEmailChange,
            child: _emailRequestBusy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Отправить код'),
          ),
        ],
      ),
    );
  }
}
