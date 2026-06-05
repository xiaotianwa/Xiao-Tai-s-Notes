import 'package:flutter/material.dart';

import 'app_theme_tokens.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light([AppThemeTokens tokens = AppThemeTokens.classic]) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: tokens.primary,
      primary: tokens.primary,
      error: tokens.danger,
      surface: tokens.surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.transparent,
      extensions: <ThemeExtension<dynamic>>[tokens],
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          color: tokens.textPrimary,
          fontSize: 25,
          fontWeight: FontWeight.w900,
          height: 1.18,
          letterSpacing: 0,
        ),
        titleLarge: TextStyle(
          color: tokens.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          height: 1.28,
          letterSpacing: 0,
        ),
        titleMedium: TextStyle(
          color: tokens.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          height: 1.34,
          letterSpacing: 0,
        ),
        titleSmall: TextStyle(
          color: tokens.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.35,
          letterSpacing: 0,
        ),
        bodyMedium: TextStyle(
          color: tokens.textPrimary,
          fontSize: 13.5,
          height: 1.5,
          letterSpacing: 0,
        ),
        bodySmall: TextStyle(
          color: tokens.textSecondary,
          fontSize: 12,
          height: 1.5,
          letterSpacing: 0,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: tokens.textPrimary,
        centerTitle: false,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(
        color: tokens.border.withValues(alpha: .7),
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: tokens.surface.withValues(alpha: .86),
        elevation: 0,
        height: 62,
        indicatorColor: tokens.primary.withValues(alpha: .13),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? tokens.primary
              : tokens.textPrimary;
          return IconThemeData(color: color, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? tokens.primary
              : tokens.textSecondary;
          return TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w400,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: tokens.surface.withValues(alpha: .70),
        elevation: 0,
        shadowColor: tokens.primary.withValues(alpha: .10),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.shape.cardRadius),
          side: BorderSide(
            color: tokens.border.withValues(alpha: .86),
            width: tokens.shape.borderWidth,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surface.withValues(alpha: .72),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: TextStyle(
          color: tokens.textTertiary,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.shape.controlRadius),
          borderSide: BorderSide(
            color: tokens.border,
            width: tokens.shape.borderWidth,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.shape.controlRadius),
          borderSide: BorderSide(
            color: tokens.border,
            width: tokens.shape.borderWidth,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.shape.controlRadius),
          borderSide: BorderSide(color: tokens.primary, width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surface.withValues(alpha: .86),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.shape.cardRadius),
          side: BorderSide(color: tokens.border.withValues(alpha: .8)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: tokens.primary,
          foregroundColor: tokens.surface,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.shape.controlRadius + 4),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: tokens.primary,
          backgroundColor: tokens.surface.withValues(alpha: .66),
          side: BorderSide(color: tokens.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.shape.controlRadius + 4),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: tokens.surface.withValues(alpha: .72),
        selectedColor: tokens.primary.withValues(alpha: .12),
        labelStyle: TextStyle(
          color: tokens.textSecondary,
          fontWeight: FontWeight.w800,
        ),
        secondaryLabelStyle: TextStyle(
          color: tokens.primary,
          fontWeight: FontWeight.w800,
        ),
        side: BorderSide(color: tokens.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.shape.controlRadius),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? tokens.surface
              : tokens.textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? tokens.success.withValues(alpha: .76)
              : tokens.border;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: tokens.textPrimary,
        contentTextStyle: TextStyle(
          color: tokens.surface,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.shape.controlRadius),
        ),
        insetPadding: const EdgeInsets.fromLTRB(24, 0, 24, 118),
      ),
    );
  }
}
