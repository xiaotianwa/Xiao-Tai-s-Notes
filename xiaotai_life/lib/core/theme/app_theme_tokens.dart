import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_colors.dart';

enum AppThemeId {
  classic('classic'),
  eggyParty('eggy_party');

  const AppThemeId(this.storageKey);

  final String storageKey;

  static AppThemeId fromStorageKey(String? value) {
    return switch (value) {
      'eggy_party' => eggyParty,
      _ => classic,
    };
  }
}

@immutable
class AppThemeAssets {
  const AppThemeAssets({
    required this.preview,
    required this.login,
    required this.splash,
    required this.snack,
    required this.reading,
    required this.reminder,
    required this.travel,
    required this.flowers,
    required this.profile,
    required this.homeMascot,
    this.backdrop,
  });

  final String preview;
  final String login;
  final String splash;
  final String snack;
  final String reading;
  final String reminder;
  final String travel;
  final String flowers;
  final String profile;
  final String homeMascot;
  final String? backdrop;
}

@immutable
class AppThemeShape {
  const AppThemeShape({
    required this.cardRadius,
    required this.controlRadius,
    required this.imageRadius,
    required this.navRadius,
    required this.borderWidth,
  });

  final double cardRadius;
  final double controlRadius;
  final double imageRadius;
  final double navRadius;
  final double borderWidth;

  static const classic = AppThemeShape(
    cardRadius: 22,
    controlRadius: 17,
    imageRadius: 20,
    navRadius: 26,
    borderWidth: 1,
  );

  static const playground = AppThemeShape(
    cardRadius: 22,
    controlRadius: 18,
    imageRadius: 20,
    navRadius: 27,
    borderWidth: 1,
  );

  AppThemeShape lerp(AppThemeShape other, double t) {
    return AppThemeShape(
      cardRadius: lerpDouble(cardRadius, other.cardRadius, t) ?? cardRadius,
      controlRadius:
          lerpDouble(controlRadius, other.controlRadius, t) ?? controlRadius,
      imageRadius: lerpDouble(imageRadius, other.imageRadius, t) ?? imageRadius,
      navRadius: lerpDouble(navRadius, other.navRadius, t) ?? navRadius,
      borderWidth: lerpDouble(borderWidth, other.borderWidth, t) ?? borderWidth,
    );
  }
}

@immutable
class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  const AppThemeTokens({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.loginSubtitle,
    required this.assets,
    required this.shape,
    required this.backdropOpacity,
    required this.primary,
    required this.accent,
    required this.success,
    required this.danger,
    required this.warning,
    required this.background,
    required this.surface,
    required this.warmSurface,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.border,
    required this.softBlue,
    required this.softPink,
    required this.softGreen,
    required this.softOrange,
  });

  final AppThemeId id;
  final String name;
  final String subtitle;
  final String loginSubtitle;
  final AppThemeAssets assets;
  final AppThemeShape shape;
  final double backdropOpacity;
  final Color primary;
  final Color accent;
  final Color success;
  final Color danger;
  final Color warning;
  final Color background;
  final Color surface;
  final Color warmSurface;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color border;
  final Color softBlue;
  final Color softPink;
  final Color softGreen;
  final Color softOrange;

  String get heroAsset => assets.preview;
  String? get backdropAsset => assets.backdrop;

  static const classic = AppThemeTokens(
    id: AppThemeId.classic,
    name: '一二布布主题',
    subtitle: '布布和小伙伴的温柔手账日常',
    loginSubtitle: '和一二布布一起记下每个小日常。',
    assets: AppThemeAssets(
      preview: 'assets/themes/default/preview.png',
      login: 'assets/themes/default/login.png',
      splash: 'assets/themes/default/splash.png',
      backdrop: 'assets/themes/default/preview.png',
      snack: 'assets/themes/default/snack.png',
      reading: 'assets/themes/default/reading.png',
      reminder: 'assets/themes/default/reminder.png',
      travel: 'assets/themes/default/travel.png',
      flowers: 'assets/themes/default/flowers.png',
      profile: 'assets/themes/default/profile.png',
      homeMascot: 'assets/themes/default/home_mascot.png',
    ),
    shape: AppThemeShape.classic,
    backdropOpacity: .16,
    primary: AppColors.primary,
    accent: AppColors.accent,
    success: AppColors.success,
    danger: AppColors.danger,
    warning: AppColors.warning,
    background: AppColors.background,
    surface: AppColors.surface,
    warmSurface: AppColors.warmSurface,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textTertiary: AppColors.textTertiary,
    border: AppColors.border,
    softBlue: AppColors.softBlue,
    softPink: AppColors.softPink,
    softGreen: AppColors.softGreen,
    softOrange: AppColors.softOrange,
  );

  static const eggyParty = AppThemeTokens(
    id: AppThemeId.eggyParty,
    name: 'dongdong羊主题',
    subtitle: '软萌羊羊、甜色装扮和轻快陪伴感',
    loginSubtitle: '让 dongdong 羊陪你开启今天的小计划。',
    assets: AppThemeAssets(
      preview: 'assets/themes/eggy/preview.png',
      login: 'assets/themes/eggy/login.png',
      splash: 'assets/themes/eggy/splash.png',
      backdrop: 'assets/themes/eggy/preview.png',
      snack: 'assets/themes/eggy/snack.png',
      reading: 'assets/themes/eggy/reading.png',
      reminder: 'assets/themes/eggy/reminder.png',
      travel: 'assets/themes/eggy/travel.png',
      flowers: 'assets/themes/eggy/flowers.png',
      profile: 'assets/themes/eggy/profile.png',
      homeMascot: 'assets/themes/eggy/home_mascot.png',
    ),
    shape: AppThemeShape.playground,
    backdropOpacity: .055,
    primary: AppColors.primary,
    accent: AppColors.accent,
    success: AppColors.success,
    danger: AppColors.danger,
    warning: AppColors.warning,
    background: AppColors.background,
    surface: Color(0xFFFFFFFF),
    warmSurface: AppColors.warmSurface,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textTertiary: AppColors.textTertiary,
    border: AppColors.border,
    softBlue: AppColors.softBlue,
    softPink: AppColors.softPink,
    softGreen: AppColors.softGreen,
    softOrange: AppColors.softOrange,
  );

  static const all = <AppThemeTokens>[classic, eggyParty];

  static AppThemeTokens byId(AppThemeId id) {
    return switch (id) {
      AppThemeId.classic => classic,
      AppThemeId.eggyParty => eggyParty,
    };
  }

  static AppThemeTokens fromStorageKey(String? value) {
    return byId(AppThemeId.fromStorageKey(value));
  }

  @override
  AppThemeTokens copyWith({
    AppThemeId? id,
    String? name,
    String? subtitle,
    String? loginSubtitle,
    AppThemeAssets? assets,
    AppThemeShape? shape,
    double? backdropOpacity,
    Color? primary,
    Color? accent,
    Color? success,
    Color? danger,
    Color? warning,
    Color? background,
    Color? surface,
    Color? warmSurface,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? border,
    Color? softBlue,
    Color? softPink,
    Color? softGreen,
    Color? softOrange,
  }) {
    return AppThemeTokens(
      id: id ?? this.id,
      name: name ?? this.name,
      subtitle: subtitle ?? this.subtitle,
      loginSubtitle: loginSubtitle ?? this.loginSubtitle,
      assets: assets ?? this.assets,
      shape: shape ?? this.shape,
      backdropOpacity: backdropOpacity ?? this.backdropOpacity,
      primary: primary ?? this.primary,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      warning: warning ?? this.warning,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      warmSurface: warmSurface ?? this.warmSurface,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      border: border ?? this.border,
      softBlue: softBlue ?? this.softBlue,
      softPink: softPink ?? this.softPink,
      softGreen: softGreen ?? this.softGreen,
      softOrange: softOrange ?? this.softOrange,
    );
  }

  @override
  AppThemeTokens lerp(ThemeExtension<AppThemeTokens>? other, double t) {
    if (other is! AppThemeTokens) {
      return this;
    }
    return AppThemeTokens(
      id: t < .5 ? id : other.id,
      name: t < .5 ? name : other.name,
      subtitle: t < .5 ? subtitle : other.subtitle,
      loginSubtitle: t < .5 ? loginSubtitle : other.loginSubtitle,
      assets: t < .5 ? assets : other.assets,
      shape: shape.lerp(other.shape, t),
      backdropOpacity:
          lerpDouble(backdropOpacity, other.backdropOpacity, t) ??
          backdropOpacity,
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      success: Color.lerp(success, other.success, t) ?? success,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      background: Color.lerp(background, other.background, t) ?? background,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      warmSurface: Color.lerp(warmSurface, other.warmSurface, t) ?? warmSurface,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary:
          Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      textTertiary:
          Color.lerp(textTertiary, other.textTertiary, t) ?? textTertiary,
      border: Color.lerp(border, other.border, t) ?? border,
      softBlue: Color.lerp(softBlue, other.softBlue, t) ?? softBlue,
      softPink: Color.lerp(softPink, other.softPink, t) ?? softPink,
      softGreen: Color.lerp(softGreen, other.softGreen, t) ?? softGreen,
      softOrange: Color.lerp(softOrange, other.softOrange, t) ?? softOrange,
    );
  }
}

extension AppThemeTokensContext on BuildContext {
  AppThemeTokens get themeTokens {
    return Theme.of(this).extension<AppThemeTokens>() ?? AppThemeTokens.classic;
  }
}
