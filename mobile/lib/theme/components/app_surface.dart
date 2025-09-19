import 'package:flutter/material.dart';

import '../app_theme_extension.dart';

/// Контейнер с единым оформлением (радиус, фон, тень).
class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.gradient,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Gradient? gradient;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>();
    final colorScheme = theme.colorScheme;

    final borderRadius = ext?.panelRadius ?? BorderRadius.circular(24);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? colorScheme.surface) : null,
        gradient: gradient,
        borderRadius: borderRadius,
        boxShadow: ext?.shadow,
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(24),
        child: child,
      ),
    );
  }
}
