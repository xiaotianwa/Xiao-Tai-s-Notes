import '../data/app_data_store.dart';
import '../notifications/local_notification_service.dart';

class AppPermissionService {
  AppPermissionService._();

  static final instance = AppPermissionService._();

  bool _requestedThisLaunch = false;

  Future<void> requestStartupPermissions() async {
    if (_requestedThisLaunch) {
      return;
    }
    _requestedThisLaunch = true;
    await Future<void>.delayed(const Duration(milliseconds: 450));
    await _maybeInitializeNotifications();
  }

  /// 仅在用户已经显式打开通知提醒后，才在启动时初始化通知插件并请求系统权限。
  ///
  /// 首次登录时权限弹窗会由登录后的欢迎引导主动触发，避免一进 App 就弹权限。
  Future<void> _maybeInitializeNotifications() async {
    try {
      final store = await AppLocalStore.create();
      final settings = store.getSettings();
      if (!settings.notificationsEnabled) {
        return;
      }
      await LocalNotificationService.instance.initialize().timeout(
        const Duration(seconds: 12),
      );
    } on Object {
      return;
    }
  }
}
