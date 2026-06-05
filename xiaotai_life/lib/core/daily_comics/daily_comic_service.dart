import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../network/app_api_config.dart';

class AppDailyComicImage {
  const AppDailyComicImage({
    required this.id,
    required this.imageUrl,
    required this.sortOrder,
    this.originalName,
  });

  factory AppDailyComicImage.fromJson(Map<String, Object?> json) {
    return AppDailyComicImage(
      id: json['id'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      originalName: json['originalName'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String imageUrl;
  final String? originalName;
  final int sortOrder;
}

class AppDailyComic {
  const AppDailyComic({
    required this.id,
    required this.title,
    required this.publishDate,
    required this.images,
    this.description,
  });

  factory AppDailyComic.fromJson(Map<String, Object?> json) {
    final images =
        (json['images'] as List? ?? const [])
            .whereType<Map<dynamic, dynamic>>()
            .map(
              (item) =>
                  AppDailyComicImage.fromJson(item.cast<String, Object?>()),
            )
            .where((item) => item.id.isNotEmpty && item.imageUrl.isNotEmpty)
            .toList()
          ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
    return AppDailyComic(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      publishDate: _parseDate(json['publishDate']),
      images: images,
    );
  }

  final String id;
  final String title;
  final String? description;
  final DateTime publishDate;
  final List<AppDailyComicImage> images;

  bool get isValid => id.isNotEmpty && title.isNotEmpty && images.isNotEmpty;

  static DateTime _parseDate(Object? value) {
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }
}

class AppDailyComicPage {
  const AppDailyComicPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  factory AppDailyComicPage.fromJson(Map<String, Object?> json) {
    final items = (json['items'] as List? ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map((item) => AppDailyComic.fromJson(item.cast<String, Object?>()))
        .where((comic) => comic.isValid)
        .toList();
    return AppDailyComicPage(
      items: items,
      total: (json['total'] as num?)?.toInt() ?? items.length,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? items.length,
    );
  }

  final List<AppDailyComic> items;
  final int total;
  final int page;
  final int pageSize;
}

class DailyComicService {
  DailyComicService({String? baseUrl})
    : _baseUrl = (baseUrl ?? defaultBaseUrl).replaceFirst(RegExp(r'/+$'), '');

  static const defaultBaseUrl = String.fromEnvironment(
    'XIAOTAI_API_BASE_URL',
    defaultValue: AppApiConfig.localDevBaseUrl,
  );
  static final instance = DailyComicService();

  final String _baseUrl;

  String resolveAssetUrl(String path) {
    return AppApiConfig.resolveAssetUrl(path, baseUrl: _baseUrl);
  }

  Future<AppDailyComic?> fetchLatest() async {
    final decoded = await _getJson('/daily-comics/latest');
    final data = decoded['data'];
    if (data == null) {
      return null;
    }
    if (data is! Map<String, dynamic>) {
      throw StateError('漫画数据格式不正确');
    }
    final comic = AppDailyComic.fromJson(data);
    return comic.isValid ? comic : null;
  }

  Future<AppDailyComicPage> fetchPublished({
    int page = 1,
    int pageSize = 30,
  }) async {
    final decoded = await _getJson(
      '/daily-comics/published?page=$page&pageSize=$pageSize',
    );
    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw StateError('漫画列表格式不正确');
    }
    return AppDailyComicPage.fromJson(data);
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
        throw StateError('漫画响应格式不正确');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(decoded['message'] as String? ?? '漫画获取失败');
      }
      if ((decoded['code'] as num?)?.toInt() != 0) {
        throw StateError(decoded['message'] as String? ?? '漫画获取失败');
      }
      return decoded;
    } on TimeoutException {
      throw StateError('漫画服务响应超时');
    } on SocketException {
      throw StateError('无法连接漫画服务');
    } finally {
      client.close(force: true);
    }
  }
}
