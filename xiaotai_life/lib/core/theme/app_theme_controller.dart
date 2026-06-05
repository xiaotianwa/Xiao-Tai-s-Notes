import 'package:flutter/foundation.dart';

import '../data/app_data_store.dart';
import 'app_theme_tokens.dart';

class AppThemeController extends ChangeNotifier {
  AppThemeController._();

  static final instance = AppThemeController._();

  AppThemeTokens _tokens = AppThemeTokens.classic;
  bool _initialized = false;

  AppThemeTokens get tokens => _tokens;
  bool get initialized => _initialized;

  Future<void> hydrate() async {
    final store = await AppLocalStore.create();
    applySettings(store.getSettings(), notify: false);
    _initialized = true;
    notifyListeners();
  }

  void applySettings(AppSettings settings, {bool notify = true}) {
    final next = AppThemeTokens.fromStorageKey(settings.themeId);
    if (_tokens.id == next.id) {
      return;
    }
    _tokens = next;
    if (notify) {
      notifyListeners();
    }
  }

  void use(AppThemeId id) {
    final next = AppThemeTokens.byId(id);
    if (_tokens.id == next.id) {
      return;
    }
    _tokens = next;
    notifyListeners();
  }
}
