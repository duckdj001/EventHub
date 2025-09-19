import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app_theme.dart';
import 'app_router.dart';
import 'services/auth_store.dart';
import 'services/push_notifications_manager.dart';
import 'theme/theme_controller.dart';
import 'theme/theme_scope.dart';
import 'widgets/auth_scope.dart';
import 'widgets/review_prompt_manager.dart';

const bool kPushNotificationsEnabled = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'ru_RU';
  await initializeDateFormatting('ru_RU', null); // <-- инициализация данных локали
  final auth = AuthStore();
  await auth.restoreSession();
  final themeController = ThemeController();
  await themeController.load();
  PushNotificationsManager? pushManager;
  if (kPushNotificationsEnabled) {
    try {
      await Firebase.initializeApp();
    } catch (err) {
      debugPrint('Firebase initialization failed: $err');
    }
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    pushManager = PushNotificationsManager(auth);
    await pushManager.init();
  }
  runApp(ThemeScope(
    controller: themeController,
    child: VibeApp(auth: auth),
  ));
}

class VibeApp extends StatelessWidget {
  const VibeApp({super.key, required this.auth});

  final AuthStore auth;

  @override
  Widget build(BuildContext context) {
    final router = buildRouter(auth);
    final themeController = ThemeScope.of(context);
    return AuthScope(
      store: auth,
      child: MaterialApp.router(
        title: 'Vibe',
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: themeController.mode,
        routerConfig: router,
        builder: (context, child) => ReviewPromptManager(child: child ?? const SizedBox()),
      ),
    );
  }
}
