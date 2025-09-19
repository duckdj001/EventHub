import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme/app_colors.dart';
import 'theme/app_spacing.dart';
import 'theme/app_theme_extension.dart';
import 'theme/app_typography.dart';

ThemeData buildTheme(Brightness brightness) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );

  final isDark = brightness == Brightness.dark;
  final seedColor = AppColors.primary;
  final colorScheme = ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness).copyWith(
    background: isDark ? AppColors.neutral900 : AppColors.neutral100,
    surface: isDark ? AppColors.neutral700 : Colors.white,
    surfaceVariant: isDark ? AppColors.neutral500 : AppColors.neutral200,
    onSurface: isDark ? Colors.white : AppColors.neutral900,
    onSurfaceVariant: isDark ? Colors.white70 : AppColors.neutral500,
    outline: isDark ? Colors.white24 : AppColors.neutral200,
  );

  final textTheme = buildAppTextTheme(base.textTheme).apply(
    bodyColor: colorScheme.onSurface,
    displayColor: colorScheme.onSurface,
  );

  final ext = AppThemeExtension(
    cardRadius: BorderRadius.circular(18),
    panelRadius: BorderRadius.circular(28),
    shadow: [
      BoxShadow(
        color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
        blurRadius: isDark ? 26 : 32,
        offset: const Offset(0, 20),
      ),
    ],
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: colorScheme.background,
    extensions: [ext],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: colorScheme.onBackground,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: AppSpacing.md),
      shape: RoundedRectangleBorder(borderRadius: ext.cardRadius),
      color: colorScheme.surface,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? colorScheme.surfaceVariant.withOpacity(0.35) : colorScheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.outline.withOpacity(isDark ? 0.4 : 0.6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.primary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      labelStyle: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: colorScheme.surfaceVariant,
      selectedColor: colorScheme.primary.withOpacity(0.16),
      labelStyle: textTheme.bodyMedium,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: textTheme.labelLarge,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: textTheme.labelLarge,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outline.withOpacity(isDark ? 0.3 : 0.4),
      space: AppSpacing.md,
      thickness: 1,
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      tileColor: colorScheme.surface,
      iconColor: colorScheme.onSurfaceVariant,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: colorScheme.surface,
      selectedItemColor: colorScheme.primary,
      unselectedItemColor: colorScheme.onSurfaceVariant,
      showSelectedLabels: true,
      showUnselectedLabels: false,
      type: BottomNavigationBarType.fixed,
      elevation: 12,
    ),
    scrollbarTheme: ScrollbarThemeData(
      radius: const Radius.circular(18),
      thumbColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.dragged)) {
          return colorScheme.primary;
        }
        return colorScheme.onSurfaceVariant.withOpacity(0.4);
      }),
    ),
  );
}
