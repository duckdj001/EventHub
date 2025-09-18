import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app_theme.dart';
import 'app_router.dart';
import 'services/auth_store.dart';
import 'widgets/auth_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'ru_RU';
  await initializeDateFormatting('ru_RU', null); // <-- инициализация данных локали
  final auth = AuthStore();
  await auth.restoreSession();
  runApp(EventHubApp(auth: auth));
}

class EventHubApp extends StatelessWidget {
  const EventHubApp({super.key, required this.auth});

  final AuthStore auth;

  @override
  Widget build(BuildContext context) {
    final router = buildRouter(auth);
    return AuthScope(
      store: auth,
      child: MaterialApp.router(
        title: 'EventHub',
        theme: buildTheme(),
        routerConfig: router,
      ),
    );
  }
}
