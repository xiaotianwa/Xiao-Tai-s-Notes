import 'dart:io';

import 'package:flutter/services.dart';

class AppDeviceIdentity {
  AppDeviceIdentity._();

  static const _channel = MethodChannel('xiaotai_life/device_info');

  static Future<String> deviceName() async {
    if (Platform.isAndroid) {
      final nativeName = await _androidDeviceName();
      if (_isUsableDeviceName(nativeName)) {
        return nativeName!.trim();
      }
    }

    final hostname = Platform.localHostname.trim();
    if (_isUsableDeviceName(hostname)) {
      return hostname;
    }
    if (Platform.isAndroid) {
      return 'Android 设备';
    }
    if (Platform.isIOS) {
      return 'iOS 设备';
    }
    return '${Platform.operatingSystem} 设备';
  }

  static Future<String?> _androidDeviceName() async {
    try {
      return await _channel.invokeMethod<String>('deviceName');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static bool _isUsableDeviceName(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      return false;
    }
    return text.toLowerCase() != 'localhost';
  }
}
