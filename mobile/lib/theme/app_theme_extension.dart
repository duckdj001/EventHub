import 'package:flutter/material.dart';

class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  const AppThemeExtension({
    required this.cardRadius,
    required this.panelRadius,
    required this.shadow,
  });

  final BorderRadius cardRadius;
  final BorderRadius panelRadius;
  final List<BoxShadow> shadow;

  @override
  ThemeExtension<AppThemeExtension> copyWith({
    BorderRadius? cardRadius,
    BorderRadius? panelRadius,
    List<BoxShadow>? shadow,
  }) {
    return AppThemeExtension(
      cardRadius: cardRadius ?? this.cardRadius,
      panelRadius: panelRadius ?? this.panelRadius,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  ThemeExtension<AppThemeExtension> lerp(ThemeExtension<AppThemeExtension>? other, double t) {
    if (other is! AppThemeExtension) return this;
    return AppThemeExtension(
      cardRadius: BorderRadius.lerp(cardRadius, other.cardRadius, t) ?? cardRadius,
      panelRadius: BorderRadius.lerp(panelRadius, other.panelRadius, t) ?? panelRadius,
      shadow: <BoxShadow>[
        for (var i = 0; i < shadow.length; i++)
          BoxShadow.lerp(
                shadow[i],
                other.shadow.length > i ? other.shadow[i] : shadow[i],
                t,
              ) ??
              shadow[i],
      ],
    );
  }
}
