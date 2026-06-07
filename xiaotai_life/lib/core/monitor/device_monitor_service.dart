import 'dart:io';

import '../data/app_data_store.dart';
import '../device/app_device_identity.dart';
import '../network/app_api_config.dart';
import 'device_monitor_channel.dart';

/// 三项关键权限/设置的当前状态快照。
class DeviceMonitorPermissions {
  const DeviceMonitorPermissions({
    required this.overlay,
    required this.batteryWhitelisted,
  });

  /// 悬浮窗（在其他应用上层强弹）。
  final bool overlay;

  /// 已加入电池优化白名单（保活）。
  final bool batteryWhitelisted;

  /// 强提醒生效所需的核心授权是否齐全。
  bool get coreGranted => overlay;
}

/// 设备活动监控高层封装：聚合权限状态、装配后端配置并启停原生前台服务。
class DeviceMonitorService {
  DeviceMonitorService._();

  static final instance = DeviceMonitorService._();

  final _channel = DeviceMonitorChannel.instance;

  static String get _baseUrl =>
      AppApiConfig.normalizedBaseUrl(AppApiConfig.baseUrl);

  /// 读取强提醒相关权限/设置的当前状态。
  Future<DeviceMonitorPermissions> loadPermissions() async {
    final overlay = await _channel.canDrawOverlays();
    final battery = await _channel.isIgnoringBatteryOptimizations();
    return DeviceMonitorPermissions(
      overlay: overlay,
      batteryWhitelisted: battery,
    );
  }

  Future<bool> get isEnabled => _channel.isEnabled();

  Future<void> openOverlaySettings() => _channel.openOverlaySettings();

  Future<void> requestBatteryWhitelist() =>
      _channel.requestIgnoreBatteryOptimizations();

  /// 开启监控：校验登录态与权限后，把配置下发原生并启动前台服务。
  ///
  /// 返回 null 表示成功；否则返回中文失败原因，供 UI 提示。
  Future<String?> enable({int pollIntervalSec = 20}) async {
    if (!Platform.isAndroid) {
      return '当前平台不支持强提醒';
    }
    final permissions = await loadPermissions();
    if (!permissions.overlay) {
      return '请先授予「显示在其他应用上层」权限';
    }

    final store = await AppLocalStore.create();
    final session = store.getAuthSession();
    final token = session?.accessToken.trim() ?? '';
    if (token.isEmpty) {
      return '请先登录后再开启强提醒';
    }
    final deviceId = store.getSyncDeviceId();
    if (deviceId.isEmpty) {
      return '设备标识不可用，请稍后重试';
    }
    final deviceName = await AppDeviceIdentity.deviceName();

    final ok = await _channel.start(
      baseUrl: _baseUrl,
      token: token,
      deviceId: deviceId,
      deviceName: deviceName,
      pollIntervalSec: pollIntervalSec,
    );
    return ok ? null : '启动强提醒服务失败，请重试';
  }

  /// 关闭监控前台服务。
  Future<void> disable() => _channel.stop();

  /// 用最新登录令牌刷新原生侧（建议在 App 回到前台、刷新 token 后调用）。
  Future<void> syncToken() async {
    if (!Platform.isAndroid) {
      return;
    }
    if (!await _channel.isEnabled()) {
      return;
    }
    final store = await AppLocalStore.create();
    final token = store.getAuthSession()?.accessToken.trim() ?? '';
    if (token.isNotEmpty) {
      await _channel.updateToken(token);
    }
  }

  Future<void> resumeIfEnabled() async {
    if (!Platform.isAndroid) {
      return;
    }
    if (!await _channel.isEnabled()) {
      return;
    }
    await enable();
  }
}
