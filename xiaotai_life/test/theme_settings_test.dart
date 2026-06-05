import 'package:flutter_test/flutter_test.dart';
import 'package:xiaotai_life/core/data/app_models.dart';
import 'package:xiaotai_life/core/theme/app_theme_tokens.dart';

void main() {
  test('AppSettings keeps selected theme in storage payload', () {
    final settings = AppSettings.defaults.copyWith(
      themeId: AppThemeId.eggyParty.storageKey,
    );

    final decoded = AppSettings.fromJson(settings.toJson());

    expect(decoded.themeId, AppThemeId.eggyParty.storageKey);
    expect(AppThemeTokens.fromStorageKey(decoded.themeId).name, 'dongdong羊主题');
  });

  test('Theme picker exposes all selectable visual themes', () {
    expect(AppThemeTokens.all.map((theme) => theme.id), [
      AppThemeId.classic,
      AppThemeId.eggyParty,
    ]);
  });

  test('Available themes provide scene-specific asset packs', () {
    for (final theme in AppThemeTokens.all) {
      final assets = [
        theme.assets.preview,
        theme.assets.login,
        theme.assets.splash,
        theme.assets.snack,
        theme.assets.reading,
        theme.assets.reminder,
        theme.assets.travel,
        theme.assets.flowers,
        theme.assets.profile,
        theme.assets.homeMascot,
      ];

      expect(assets.toSet(), hasLength(assets.length));
      expect(theme.backdropAsset, isNotNull);
    }
  });

  test('Retired theme storage keys fall back to default theme', () {
    expect(AppThemeTokens.fromStorageKey('shinchan').id, AppThemeId.classic);
    expect(AppThemeTokens.fromStorageKey('jay_chou').id, AppThemeId.classic);
  });

  test('Unknown theme storage keys fall back to default theme', () {
    expect(
      AppThemeTokens.fromStorageKey('missing-theme').id,
      AppThemeId.classic,
    );
  });
}
