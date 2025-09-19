import 'package:flutter/material.dart';

/// Универсальная кнопка, работающая поверх FilledButton.
class AppButton extends StatelessWidget {
  const AppButton.primary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.fullWidth = true,
    this.busy = false,
  }) : _type = _AppButtonType.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.fullWidth = true,
    this.busy = false,
  }) : _type = _AppButtonType.secondary;

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool fullWidth;
  final bool busy;
  final _AppButtonType _type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final ButtonStyle style;
    switch (_type) {
      case _AppButtonType.primary:
        style = FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: fullWidth ? const Size.fromHeight(52) : null,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        );
        break;
      case _AppButtonType.secondary:
        style = FilledButton.styleFrom(
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.primary,
          minimumSize: fullWidth ? const Size.fromHeight(52) : null,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          side: BorderSide(color: colorScheme.primary.withOpacity(0.4), width: 1.2),
        );
        break;
    }

    Widget child;
    if (busy) {
      final spinnerColor = _type == _AppButtonType.primary
          ? colorScheme.onPrimary
          : colorScheme.primary;
      child = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: spinnerColor),
      );
    } else if (icon == null) {
      child = Text(label);
    } else {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon!,
          const SizedBox(width: 10),
          Flexible(child: Text(label)),
        ],
      );
    }

    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: style,
      child: child,
    );
  }
}

enum _AppButtonType { primary, secondary }
