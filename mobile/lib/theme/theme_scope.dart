import 'package:flutter/material.dart';

import 'theme_controller.dart';

class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({super.key, required ThemeController controller, required Widget child})
      : super(notifier: controller, child: child);

  static ThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'ThemeScope.of() called with a context that does not contain ThemeScope');
    return scope!.notifier!;
  }

  @override
  bool updateShouldNotify(covariant ThemeScope oldWidget) => notifier != oldWidget.notifier;
}
