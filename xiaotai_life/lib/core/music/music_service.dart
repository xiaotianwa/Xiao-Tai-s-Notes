import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../network/app_api_config.dart';

class AppMusicTrack {
  const AppMusicTrack({
    required this.id,
    required this.title,
    required this.audioUrl,
    required this.originalName,
    required this.mimeType,
    required this.size,
    required this.enabled,
    required this.sortOrder,
    this.artist,
    this.album,
    this.coverUrl,
    this.lyrics,
    this.durationSeconds,
  });

  factory AppMusicTrack.fromJson(Map<String, Object?> json) {
    return AppMusicTrack(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String?,
      album: json['album'] as String?,
      audioUrl: json['audioUrl'] as String? ?? '',
      coverUrl: json['coverUrl'] as String?,
      lyrics: json['lyrics'] as String?,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      originalName: json['originalName'] as String? ?? '',
      mimeType: json['mimeType'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      enabled: json['enabled'] as bool? ?? false,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String title;
  final String? artist;
  final String? album;
  final String audioUrl;
  final String? coverUrl;
  final String? lyrics;
  final int? durationSeconds;
  final String originalName;
  final String mimeType;
  final int size;
  final bool enabled;
  final int sortOrder;

  bool get isValid => id.isNotEmpty && title.isNotEmpty && audioUrl.isNotEmpty;
}

class AppMusicPage {
  const AppMusicPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  factory AppMusicPage.fromJson(Map<String, Object?> json) {
    final items = (json['items'] as List? ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map((item) => AppMusicTrack.fromJson(item.cast<String, Object?>()))
        .where((track) => track.isValid)
        .toList();
    return AppMusicPage(
      items: items,
      total: (json['total'] as num?)?.toInt() ?? items.length,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? items.length,
    );
  }

  final List<AppMusicTrack> items;
  final int total;
  final int page;
  final int pageSize;
}

class MusicService {
  MusicService({String? baseUrl})
    : _baseUrl = (baseUrl ?? defaultBaseUrl).replaceFirst(RegExp(r'/+$'), '');

  static const defaultBaseUrl = String.fromEnvironment(
    'XIAOTAI_API_BASE_URL',
    defaultValue: AppApiConfig.localDevBaseUrl,
  );
  static final instance = MusicService();

  final String _baseUrl;

  String resolveAssetUrl(String path) {
    return AppApiConfig.resolveAssetUrl(path, baseUrl: _baseUrl);
  }

  Future<AppMusicPage> fetchTracks({int page = 1, int pageSize = 50}) async {
    final decoded = await _getJson(
      '/music/tracks?page=$page&pageSize=$pageSize',
    );
    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw StateError('音乐列表格式不正确');
    }
    return AppMusicPage.fromJson(data);
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final request = await client
          .getUrl(Uri.parse('$_baseUrl$path'))
          .timeout(const Duration(seconds: 6));
      request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      final raw = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw StateError('音乐服务响应格式不正确');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(decoded['message'] as String? ?? '音乐列表获取失败');
      }
      if ((decoded['code'] as num?)?.toInt() != 0) {
        throw StateError(decoded['message'] as String? ?? '音乐列表获取失败');
      }
      return decoded;
    } on TimeoutException {
      throw StateError('音乐服务响应超时');
    } on SocketException {
      throw StateError('无法连接音乐服务');
    } finally {
      client.close(force: true);
    }
  }
}
