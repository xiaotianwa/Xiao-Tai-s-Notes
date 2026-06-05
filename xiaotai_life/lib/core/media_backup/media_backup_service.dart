import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../network/app_api_config.dart';

class MediaBackupUploadSummary {
  const MediaBackupUploadSummary({
    required this.uploaded,
    required this.failedPaths,
  });

  final int uploaded;
  final List<String> failedPaths;
}

class MediaBackupService {
  MediaBackupService({HttpClient? client, String? baseUrl, String? accessToken})
    : _client = client ?? HttpClient(),
      _baseUrl = (baseUrl ?? defaultBaseUrl).replaceFirst(RegExp(r'/+$'), ''),
      _accessToken = accessToken ?? defaultAccessToken;

  static const defaultBaseUrl = String.fromEnvironment(
    'XIAOTAI_API_BASE_URL',
    defaultValue: AppApiConfig.localDevBaseUrl,
  );
  static const defaultAccessToken = String.fromEnvironment(
    'XIAOTAI_ACCESS_TOKEN',
  );
  static final instance = MediaBackupService();

  final HttpClient _client;
  final String _baseUrl;
  final String _accessToken;

  bool get isConfigured => _accessToken.trim().isNotEmpty;

  bool isReady({String? accessTokenOverride}) {
    return (accessTokenOverride ?? _accessToken).trim().isNotEmpty;
  }

  Future<MediaBackupUploadSummary> uploadImages({
    required List<String> paths,
    required String deviceId,
    String? accessTokenOverride,
  }) async {
    final token = (accessTokenOverride ?? _accessToken).trim();
    if (token.isEmpty) {
      throw StateError('XIAOTAI_ACCESS_TOKEN is not configured');
    }
    final selected = paths
        .where((path) => path.trim().isNotEmpty)
        .take(3)
        .toList();
    var uploaded = 0;
    final failed = <String>[];
    for (final path in selected) {
      try {
        await _uploadOne(path: path, deviceId: deviceId, accessToken: token);
        uploaded += 1;
      } catch (_) {
        failed.add(path);
      }
    }
    return MediaBackupUploadSummary(uploaded: uploaded, failedPaths: failed);
  }

  /// 上传单张图片并返回服务端分配的 mediaId。
  /// 失败时返回 null（不抛异常，便于在保存流程里降级）。
  Future<String?> uploadOneReturningId({
    required String path,
    required String deviceId,
    required String accessToken,
  }) async {
    final token = accessToken.trim();
    if (token.isEmpty || path.trim().isEmpty) {
      return null;
    }
    try {
      return await _uploadOne(
        path: path,
        deviceId: deviceId,
        accessToken: token,
      );
    } catch (_) {
      return null;
    }
  }

  /// 批量上传：按入参顺序返回 mediaId 列表，失败位置为 null。
  Future<List<String?>> uploadManyReturningIds({
    required List<String> paths,
    required String deviceId,
    required String accessToken,
  }) async {
    final results = <String?>[];
    for (final path in paths) {
      results.add(
        await uploadOneReturningId(
          path: path,
          deviceId: deviceId,
          accessToken: accessToken,
        ),
      );
    }
    return results;
  }

  Future<String?> _uploadOne({
    required String path,
    required String deviceId,
    required String accessToken,
  }) async {
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('Media file does not exist', path);
    }
    final uri = Uri.parse('$_baseUrl/media');
    final boundary =
        '----xiaotai_media_${DateTime.now().microsecondsSinceEpoch}';
    final request = await _client
        .postUrl(uri)
        .timeout(const Duration(seconds: 10));
    request.headers
      ..set(HttpHeaders.authorizationHeader, 'Bearer $accessToken')
      ..set(
        HttpHeaders.contentTypeHeader,
        'multipart/form-data; boundary=$boundary',
      );
    final bodyStart = BytesBuilder(copy: false);
    _addFormField(bodyStart, boundary, 'deviceId', deviceId);
    _addFileHeader(bodyStart, boundary, file);
    final bodyStartBytes = bodyStart.takeBytes();
    final bodyEndBytes = ascii.encode('\r\n--$boundary--\r\n');
    request.contentLength =
        bodyStartBytes.length + await file.length() + bodyEndBytes.length;
    request.add(bodyStartBytes);
    await request.addStream(file.openRead());
    request.add(bodyEndBytes);
    final response = await request.close().timeout(const Duration(minutes: 5));
    final raw = await utf8.decodeStream(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Upload failed: ${response.statusCode} $raw');
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Upload failed: invalid response');
    }
    if (decoded['code'] != 0) {
      throw StateError(decoded['message'] as String? ?? 'Upload failed');
    }
    final data = decoded['data'];
    if (data is Map<String, dynamic>) {
      return data['id'] as String?;
    }
    return null;
  }

  void _addFormField(
    BytesBuilder body,
    String boundary,
    String name,
    String value,
  ) {
    body
      ..add(ascii.encode('--$boundary\r\n'))
      ..add(
        ascii.encode('Content-Disposition: form-data; name="$name"\r\n\r\n'),
      )
      ..add(utf8.encode(value))
      ..add(ascii.encode('\r\n'));
  }

  void _addFileHeader(BytesBuilder body, String boundary, File file) {
    final fileName = file.uri.pathSegments.isEmpty
        ? 'photo.jpg'
        : file.uri.pathSegments.last;
    final safeName = fileName.replaceAll('"', '_');
    final mime = _mimeForPath(file.path);
    body
      ..add(ascii.encode('--$boundary\r\n'))
      ..add(
        ascii.encode(
          'Content-Disposition: form-data; name="file"; filename="$safeName"\r\n',
        ),
      )
      ..add(ascii.encode('Content-Type: $mime\r\n\r\n'));
  }

  String _mimeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lower.endsWith('.gif')) {
      return 'image/gif';
    }
    if (lower.endsWith('.mp4')) {
      return 'video/mp4';
    }
    if (lower.endsWith('.mov')) {
      return 'video/quicktime';
    }
    if (lower.endsWith('.webm')) {
      return 'video/webm';
    }
    if (lower.endsWith('.3gp')) {
      return 'video/3gpp';
    }
    if (lower.endsWith('.mkv')) {
      return 'video/x-matroska';
    }
    if (lower.endsWith('.heic')) {
      return 'image/heic';
    }
    if (lower.endsWith('.heif')) {
      return 'image/heif';
    }
    return 'image/jpeg';
  }
}
