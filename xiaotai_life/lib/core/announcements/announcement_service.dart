import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../network/app_api_config.dart';

class AppAnnouncement {
  const AppAnnouncement({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.priority,
    required this.enabled,
    this.imageUrl,
    this.startAt,
    this.endAt,
  });

  factory AppAnnouncement.fromJson(Map<String, Object?> json) {
    return AppAnnouncement(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      type: json['type'] as String? ?? 'info',
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      enabled: json['enabled'] as bool? ?? true,
      imageUrl: json['imageUrl'] as String?,
      startAt: _parseDate(json['startAt']),
      endAt: _parseDate(json['endAt']),
    );
  }

  final String id;
  final String title;
  final String content;
  final String type;
  final int priority;
  final bool enabled;
  final String? imageUrl;
  final DateTime? startAt;
  final DateTime? endAt;

  static DateTime? _parseDate(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}

class AnnouncementService {
  AnnouncementService({String? baseUrl})
    : _baseUrl = (baseUrl ?? defaultBaseUrl).replaceFirst(RegExp(r'/+$'), '');

  static const defaultBaseUrl = String.fromEnvironment(
    'XIAOTAI_API_BASE_URL',
    defaultValue: AppApiConfig.localDevBaseUrl,
  );
  static final instance = AnnouncementService();

  final String _baseUrl;

  String resolveAssetUrl(String path) {
    return AppApiConfig.resolveAssetUrl(path, baseUrl: _baseUrl);
  }

  Future<List<AppAnnouncement>> fetchActive() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final request = await client
          .getUrl(Uri.parse('$_baseUrl/announcements/active'))
          .timeout(const Duration(seconds: 6));
      request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      final raw = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw StateError('公告响应格式不正确');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(decoded['message'] as String? ?? '公告获取失败');
      }
      if ((decoded['code'] as num?)?.toInt() != 0) {
        throw StateError(decoded['message'] as String? ?? '公告获取失败');
      }
      final data = decoded['data'];
      if (data is! List) {
        return const [];
      }
      return data
          .whereType<Map<dynamic, dynamic>>()
          .map((item) => AppAnnouncement.fromJson(item.cast<String, Object?>()))
          .where((item) => item.id.isNotEmpty && item.title.isNotEmpty)
          .toList();
    } on TimeoutException {
      throw StateError('公告服务响应超时');
    } on SocketException {
      throw StateError('无法连接公告服务');
    } finally {
      client.close(force: true);
    }
  }
}
