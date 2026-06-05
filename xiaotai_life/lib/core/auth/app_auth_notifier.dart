import 'package:flutter/foundation.dart';

import '../data/app_data_store.dart';

/// 全局登录状态通知器。
///
/// - hydrate() 在 App 启动时调用一次，读取本地持久化的 AuthSession。
/// - 登录/退出后调用 setSession 同步内存状态并通知监听者（GoRouter 据此 refresh）。
class AppAuthNotifier extends ChangeNotifier {
  AppAuthNotifier._();

  static final AppAuthNotifier instance = AppAuthNotifier._();

  AppAuthSession? _session;
  bool _initialized = false;

  AppAuthSession? get session => _session;
  bool get isSignedIn => _session?.isSignedIn ?? false;
  bool get initialized => _initialized;

  Future<void> hydrate() async {
    if (_initialized) {
      return;
    }
    try {
      final store = await AppLocalStore.create();
      _session = store.getAuthSession();
    } catch (_) {
      _session = null;
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  void setSession(AppAuthSession? session) {
    final next = (session != null && session.isSignedIn) ? session : null;
    final wasSignedIn = isSignedIn;
    _session = next;
    // 始终通知一次，登录信息更新（如刷新 token、updatedAt 变化）也让监听者重算。
    notifyListeners();
    // 仅供调试时观察登录/退出切换。
    assert(() {
      // ignore: avoid_print
      print('AppAuthNotifier.setSession: $wasSignedIn -> $isSignedIn');
      return true;
    }());
  }

  void clear() => setSession(null);
}
