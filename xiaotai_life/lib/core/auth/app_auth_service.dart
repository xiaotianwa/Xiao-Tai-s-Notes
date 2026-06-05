import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../data/app_data_store.dart';
import '../network/app_api_config.dart';

class AppAuthService {
  AppAuthService({String? baseUrl})
    : _baseUrl = (baseUrl ?? defaultBaseUrl).replaceFirst(RegExp(r'/+$'), '');

  static const defaultBaseUrl = String.fromEnvironment(
    'XIAOTAI_API_BASE_URL',
    defaultValue: AppApiConfig.localDevBaseUrl,
  );
  static final instance = AppAuthService();

  final String _baseUrl;

  Future<AppAuthSession> login({
    required String username,
    required String password,
  }) {
    return _requestTokens(
      path: '/auth/login',
      body: {'username': username, 'password': password},
    );
  }

  Future<AppAuthSession> refresh(String refreshToken) {
    return _requestTokens(
      path: '/auth/refresh',
      body: {'refreshToken': refreshToken},
    );
  }

  Future<void> logout(String refreshToken) async {
    await _requestJson(
      method: 'POST',
      path: '/auth/logout',
      body: {'refreshToken': refreshToken},
    );
  }

  Future<AppAuthSession> _requestTokens({
    required String path,
    required Map<String, Object?> body,
  }) async {
    final data = await _requestJson(method: 'POST', path: path, body: body);
    final user = (data['user'] as Map<dynamic, dynamic>? ?? const {})
        .cast<String, Object?>();
    return AppAuthSession(
      accessToken: data['accessToken'] as String? ?? '',
      refreshToken: data['refreshToken'] as String? ?? '',
      userId: user['id'] as String? ?? '',
      username: user['username'] as String? ?? '',
      role: user['role'] as String? ?? '',
      updatedAt: DateTime.now(),
    );
  }

  Future<Map<String, Object?>> _requestJson({
    required String method,
    required String path,
    Map<String, Object?>? body,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final uri = Uri.parse('$_baseUrl$path');
      final request = method == 'GET'
          ? await client.getUrl(uri).timeout(const Duration(seconds: 8))
          : await client.postUrl(uri).timeout(const Duration(seconds: 8));
      request.headers.contentType = ContentType.json;
      if (body != null) {
        request.write(jsonEncode(body));
      }
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      final raw = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw StateError('登录响应格式不正确');
      }
      final code = (decoded['code'] as num?)?.toInt() ?? -1;
      final data = decoded['data'];
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          code != 0) {
        throw StateError(
          _friendlyFailureMessage(
            path: path,
            statusCode: response.statusCode,
            serverMessage: decoded['message'] as String?,
          ),
        );
      }
      return data is Map<String, dynamic>
          ? data.cast<String, Object?>()
          : <String, Object?>{};
    } on TimeoutException {
      throw StateError('连接服务器超时，请检查后端是否已启动');
    } on SocketException {
      throw StateError('无法连接服务器，请检查网络和 API 地址');
    } on FormatException {
      throw StateError('服务器返回内容无法识别，请确认后端版本正常');
    } finally {
      client.close(force: true);
    }
  }

  String _friendlyFailureMessage({
    required String path,
    required int statusCode,
    String? serverMessage,
  }) {
    if (statusCode == HttpStatus.unauthorized ||
        statusCode == HttpStatus.forbidden) {
      if (path.contains('/auth/refresh')) {
        return '登录已过期，请重新登录';
      }
      if (path.contains('/auth/login')) {
        return '账号或密码不正确，请重新输入';
      }
      return '登录状态不可用，请重新登录';
    }
    if (statusCode >= 500) {
      return '服务器暂时不可用，请稍后重试';
    }
    final message = serverMessage?.trim();
    return message == null || message.isEmpty ? '登录请求失败' : message;
  }
}
