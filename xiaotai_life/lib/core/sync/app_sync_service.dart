import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../data/app_data_store.dart';
import '../network/app_api_config.dart';

class AppSyncResult {
  const AppSyncResult({
    required this.pushed,
    required this.pulled,
    required this.conflicts,
  });

  final int pushed;
  final int pulled;
  final List<AppSyncConflict> conflicts;

  int get conflictCount => conflicts.length;
}

class AppSyncService {
  AppSyncService(this.store, {String? baseUrl})
    : _baseUrl = (baseUrl ?? defaultBaseUrl).replaceFirst(RegExp(r'/$'), '');

  static const defaultBaseUrl = String.fromEnvironment(
    'XIAOTAI_API_BASE_URL',
    defaultValue: AppApiConfig.localDevBaseUrl,
  );

  final AppLocalStore store;
  final String _baseUrl;

  Future<AppSyncResult> sync({required String accessToken}) async {
    final pushResult = await pushPending(accessToken: accessToken);
    final pulled = await pullRemoteChanges(accessToken: accessToken);
    return AppSyncResult(
      pushed: pushResult.pushed,
      pulled: pulled,
      conflicts: pushResult.conflicts,
    );
  }

  Future<({int pushed, List<AppSyncConflict> conflicts})> pushPending({
    required String accessToken,
  }) async {
    final queue = store.getSyncQueue();
    if (queue.isEmpty) {
      return (pushed: 0, conflicts: const <AppSyncConflict>[]);
    }

    final data = await _requestJson(
      accessToken: accessToken,
      method: 'POST',
      path: '/sync/items/batch',
      body: {
        'deviceId': store.getSyncDeviceId(),
        'device': {
          'deviceName': Platform.localHostname,
          'platform': Platform.operatingSystem,
        },
        'items': queue
            .map(
              (item) => {
                'type': item.type,
                'clientId': item.clientId,
                'clientUpdatedAt': item.clientUpdatedAt.toIso8601String(),
                'deletedAt': item.deletedAt?.toIso8601String(),
                'data': item.data,
              },
            )
            .toList(),
      },
    );

    final rawConflicts = (data['conflicts'] as List<dynamic>? ?? const [])
        .cast<Map<dynamic, dynamic>>();
    final queueByKey = {
      for (final item in queue) '${item.type}:${item.clientId}': item,
    };
    final conflicts = rawConflicts.map((item) {
      final key =
          '${item['type'] as String? ?? ''}:${item['clientId'] as String? ?? ''}';
      return AppSyncConflict.fromServerJson(item, localItem: queueByKey[key]);
    }).toList();
    final conflictKeys = conflicts.map((item) => item.key).toSet();
    final acceptedIds = queue
        .where(
          (item) => !conflictKeys.contains('${item.type}:${item.clientId}'),
        )
        .map((item) => item.id)
        .toSet();
    await store.removeSyncedQueueItems(acceptedIds);

    return (
      pushed: (data['accepted'] as num?)?.toInt() ?? acceptedIds.length,
      conflicts: conflicts,
    );
  }

  Future<int> pullRemoteChanges({required String accessToken}) async {
    var page = 1;
    var pulled = 0;
    final since = store.getLastPulledAt();
    String? serverTime;

    while (true) {
      final params = <String, String>{
        'page': '$page',
        'pageSize': '100',
        if (since != null) 'since': since.toIso8601String(),
      };
      final data = await _requestJson(
        accessToken: accessToken,
        method: 'GET',
        path: '/sync/items?${Uri(queryParameters: params).query}',
      );
      final items = (data['items'] as List<dynamic>? ?? const [])
          .cast<Map<dynamic, dynamic>>();
      for (final item in items) {
        final rawData = (item['data'] as Map<dynamic, dynamic>? ?? const {})
            .cast<String, Object?>();
        final deletedAtText = item['deletedAt'] as String?;
        await store.applyRemoteSyncItem(
          type: item['type'] as String,
          clientId: item['clientId'] as String,
          data: rawData,
          deletedAt: deletedAtText == null
              ? null
              : DateTime.tryParse(deletedAtText),
        );
      }

      pulled += items.length;
      serverTime = data['serverTime'] as String? ?? serverTime;
      final total = (data['total'] as num?)?.toInt() ?? pulled;
      if (pulled >= total || items.isEmpty) {
        break;
      }
      page += 1;
    }

    final parsedServerTime = serverTime == null
        ? null
        : DateTime.tryParse(serverTime);
    if (parsedServerTime != null) {
      await store.saveLastPulledAt(parsedServerTime);
    }
    return pulled;
  }

  Future<Map<String, Object?>> _requestJson({
    required String accessToken,
    required String method,
    required String path,
    Map<String, Object?>? body,
  }) async {
    final token = accessToken.trim();
    if (token.isEmpty) {
      throw StateError('缺少登录令牌，无法同步');
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final uri = Uri.parse('$_baseUrl$path');
      final request = method == 'GET'
          ? await client.getUrl(uri).timeout(const Duration(seconds: 8))
          : await client.postUrl(uri).timeout(const Duration(seconds: 8));
      request.headers.contentType = ContentType.json;
      request.headers.set('Authorization', 'Bearer $token');
      if (body != null) {
        request.write(jsonEncode(body));
      }

      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      final raw = await response.transform(utf8.decoder).join();
      final decoded = _decodeEnvelope(raw);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          _friendlyFailureMessage(
            statusCode: response.statusCode,
            serverMessage: decoded.message,
          ),
        );
      }
      if (decoded.code != 0) {
        throw StateError(decoded.message ?? '同步失败');
      }
      return decoded.data;
    } on TimeoutException {
      throw StateError('同步连接超时，请检查服务器是否可用');
    } on SocketException {
      throw StateError('无法连接同步服务器，请检查网络和 API 地址');
    } on FormatException {
      throw StateError('同步响应格式不正确，请确认后端版本正常');
    } finally {
      client.close(force: true);
    }
  }

  ({int code, String? message, Map<String, Object?> data}) _decodeEnvelope(
    String raw,
  ) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('同步响应格式不正确');
    }
    final data = decoded['data'];
    return (
      code: (decoded['code'] as num?)?.toInt() ?? -1,
      message: decoded['message'] as String?,
      data: data is Map<String, dynamic>
          ? data.cast<String, Object?>()
          : <String, Object?>{},
    );
  }

  String _friendlyFailureMessage({
    required int statusCode,
    String? serverMessage,
  }) {
    if (statusCode == HttpStatus.unauthorized) {
      return '登录已过期，请重新登录后同步';
    }
    if (statusCode == HttpStatus.forbidden) {
      return '当前账号没有同步权限';
    }
    if (statusCode >= 500) {
      return '同步服务器暂时不可用，请稍后重试';
    }
    final message = serverMessage?.trim();
    return message == null || message.isEmpty
        ? '同步失败：HTTP $statusCode'
        : message;
  }
}
