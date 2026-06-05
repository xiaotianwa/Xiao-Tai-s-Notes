import 'dart:io';

import 'package:flutter/services.dart';

/// 设备活动监控原生通道：封装 `xiaotai_life/monitor` MethodChannel。
///
/// 仅 Android 实现；其它平台所有方法返回安全默认值（false / 空操作）。
/// 后台采集、轮询强提醒、上报、悬浮窗强弹全部在原生前台 Service 中完成，
/// 这里只负责权限查询/跳转与服务的启动、停止、配置下发。
class DeviceMonitorChannel {
  DeviceMonitorChannel._();

  static final instance = DeviceMonitorChannel._();

  static const _channel = MethodChannel('xiaotai_life/monitor');

  bool get _isSupported => Platform.isAndroid;

  Future<bool> _invokeBool(String method, [Map<String, Object?>? args]) async {
    if (!_isSupported) {
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>(method, args);
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> _invokeVoid(String method, [Map<String, Object?>? args]) async {
    if (!_isSupported) {
      return;
    }
    try {
      await _channel.invokeMethod<void>(method, args);
    } on PlatformException {
      // 忽略：跳转系统设置失败不应中断流程。
    } on MissingPluginException {
      // 忽略。
    }
  }

  /// 是否已获得「显示在其他应用上层」（悬浮窗）授权。
  Future<bool> canDrawOverlays() => _invokeBool('canDrawOverlays');

  /// 跳转到系统「显示在其他应用上层」设置页。
  Future<void> openOverlaySettings() => _invokeVoid('openOverlaySettings');

  /// 是否已加入电池优化白名单（提升后台保活成功率）。
  Future<bool> isIgnoringBatteryOptimizations() =>
      _invokeBool('isIgnoringBatteryOptimizations');

  /// 请求加入电池优化白名单。
  Future<void> requestIgnoreBatteryOptimizations() =>
      _invokeVoid('requestIgnoreBatteryOptimizations');

  /// 监控前台服务是否已开启（用户上次的选择）。
  Future<bool> isEnabled() => _invokeBool('isEnabled');

  /// 启动监控前台服务，并把后端地址、令牌、设备信息下发给原生。
  Future<bool> start({
    required String baseUrl,
    required String token,
    required String deviceId,
    required String deviceName,
    int pollIntervalSec = 20,
  }) {
    return _invokeBool('start', {
      'baseUrl': baseUrl,
      'token': token,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'pollIntervalSec': pollIntervalSec,
    });
  }

  /// 停止监控前台服务。
  Future<bool> stop() => _invokeBool('stop');

  /// 刷新 access token（Flutter 前台拿到新 token 后调用，避免后台用过期令牌）。
  Future<bool> updateToken(String token) =>
      _invokeBool('updateToken', {'token': token});
}
