import 'package:flutter/widgets.dart';

import '../services/auth_store.dart';

class AuthScope extends InheritedNotifier<AuthStore> {
  const AuthScope({super.key, required AuthStore store, required Widget child})
      : super(notifier: store, child: child);

  static AuthStore of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'AuthScope is missing in the widget tree');
    return scope!.notifier!;
  }

  static AuthStore? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AuthScope>()?.notifier;
  }

  @override
  bool updateShouldNotify(covariant AuthScope oldWidget) => notifier != oldWidget.notifier;
}
