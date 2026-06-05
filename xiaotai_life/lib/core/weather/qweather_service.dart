import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:geolocator/geolocator.dart';

import '../network/app_api_config.dart';

class QWeatherService {
  QWeatherService._();

  static final instance = QWeatherService._();

  static const projectApiBaseUrl = String.fromEnvironment(
    'XIAOTAI_API_BASE_URL',
    defaultValue: AppApiConfig.localDevBaseUrl,
  );
  static const apiKey = String.fromEnvironment('QWEATHER_API_KEY');
  static const jwt = String.fromEnvironment('QWEATHER_JWT');
  static const cityName = String.fromEnvironment(
    'QWEATHER_CITY_NAME',
    defaultValue: '重庆',
  );
  static const location = String.fromEnvironment(
    'QWEATHER_LOCATION',
    defaultValue: '101040100',
  );
  static const useDeviceLocation = bool.fromEnvironment(
    'QWEATHER_USE_DEVICE_LOCATION',
    defaultValue: true,
  );
  static const host = String.fromEnvironment(
    'QWEATHER_HOST',
    defaultValue: 'p72tupd6nv.re.qweatherapi.com',
  );

  static bool get _hasProjectApi => projectApiBaseUrl.trim().isNotEmpty;

  static bool get _hasAuth => apiKey.trim().isNotEmpty || jwt.trim().isNotEmpty;

  static bool get hasDirectRequiredConfig => _hasAuth && host.trim().isNotEmpty;

  static bool get hasRequiredConfig =>
      _hasProjectApi || hasDirectRequiredConfig;

  AppWeatherLocation? _cachedLocation;
  DateTime? _cachedLocationUntil;

  static String? get configurationTip {
    if (_hasProjectApi) {
      return null;
    }
    final missing = <String>[
      if (!_hasAuth) 'QWEATHER_API_KEY 或 QWEATHER_JWT',
      if (host.trim().isEmpty) 'QWEATHER_HOST',
    ];
    if (missing.isEmpty) {
      return null;
    }
    return '缺少 ${missing.join('、')}';
  }

  Future<AppWeatherNow?> fetchNow({bool forceLocationRefresh = false}) async {
    if (!hasRequiredConfig) {
      return null;
    }
    final resolvedLocation = await _resolveLocation(
      forceRefresh: forceLocationRefresh,
    );
    if (_hasProjectApi) {
      try {
        return await _fetchProjectNow(resolvedLocation);
      } catch (_) {
        if (!hasDirectRequiredConfig) {
          rethrow;
        }
      }
    }
    if (!hasDirectRequiredConfig) {
      return null;
    }
    final uri = Uri.https(_normalizedHost(), '/v7/weather/now', {
      'location': resolvedLocation.query,
      'lang': 'zh',
    });
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 8));
      _setAuthHeader(request);
      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      final raw = await response.transform(utf8.decoder).join();
      if (response.statusCode != HttpStatus.ok) {
        throw StateError('天气服务暂时不可用：HTTP ${response.statusCode}');
      }
      final decoded = (jsonDecode(raw) as Map<String, dynamic>)
          .cast<String, Object?>();
      final code = decoded['code'] as String?;
      if (code != '200') {
        throw StateError(_messageForCode(code));
      }
      final now = (decoded['now'] as Map<dynamic, dynamic>)
          .cast<String, Object?>();
      return AppWeatherNow.fromJson(
        now,
        cityName: resolvedLocation.cityName,
        locationQuery: resolvedLocation.query,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<List<AppWeatherIndex>> fetchTodayIndices({
    String? locationQuery,
  }) async {
    if (!hasRequiredConfig) {
      return const [];
    }
    if (_hasProjectApi) {
      try {
        final resolvedLocation =
            locationQuery ??
            (await _resolveLocation(forceRefresh: false)).query;
        return await _fetchProjectIndices(resolvedLocation);
      } catch (_) {
        if (!hasDirectRequiredConfig) {
          rethrow;
        }
      }
    }
    if (!hasDirectRequiredConfig) {
      return const [];
    }
    final resolvedLocation =
        locationQuery ?? (await _resolveLocation(forceRefresh: false)).query;
    final uri = Uri.https(_normalizedHost(), '/v7/indices/1d', {
      'location': resolvedLocation,
      'type': '3,9,7',
      'lang': 'zh',
    });
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 8));
      _setAuthHeader(request);
      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      final raw = await response.transform(utf8.decoder).join();
      if (response.statusCode != HttpStatus.ok) {
        throw StateError('天气指数暂时不可用：HTTP ${response.statusCode}');
      }
      final decoded = (jsonDecode(raw) as Map<String, dynamic>)
          .cast<String, Object?>();
      final code = decoded['code'] as String?;
      if (code != '200') {
        throw StateError(_messageForCode(code));
      }
      final daily = decoded['daily'] as List<dynamic>? ?? const [];
      return daily
          .map(
            (item) => AppWeatherIndex.fromJson(
              (item as Map<dynamic, dynamic>).cast<String, Object?>(),
            ),
          )
          .toList()
        ..sort((a, b) => _indexOrder(a.type).compareTo(_indexOrder(b.type)));
    } finally {
      client.close(force: true);
    }
  }

  Future<AppWeatherNow?> fetchNowForCity(String city) async {
    final trimmed = city.trim();
    if (!hasRequiredConfig || trimmed.isEmpty) {
      return null;
    }
    if (_hasProjectApi) {
      return _fetchProjectNow(
        AppWeatherLocation(query: trimmed, cityName: trimmed),
      );
    }
    if (!hasDirectRequiredConfig) {
      return null;
    }
    final location = await _lookupCity(trimmed);
    if (location == null) {
      throw StateError('没有找到“$trimmed”的天气位置');
    }
    final uri = Uri.https(_normalizedHost(), '/v7/weather/now', {
      'location': location.query,
      'lang': 'zh',
    });
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 8));
      _setAuthHeader(request);
      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      final raw = await response.transform(utf8.decoder).join();
      if (response.statusCode != HttpStatus.ok) {
        throw StateError('天气服务暂时不可用：HTTP ${response.statusCode}');
      }
      final decoded = (jsonDecode(raw) as Map<String, dynamic>)
          .cast<String, Object?>();
      final code = decoded['code'] as String?;
      if (code != '200') {
        throw StateError(_messageForCode(code));
      }
      final now = (decoded['now'] as Map<dynamic, dynamic>)
          .cast<String, Object?>();
      return AppWeatherNow.fromJson(
        now,
        cityName: location.cityName,
        locationQuery: location.query,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<AppWeatherNow> _fetchProjectNow(AppWeatherLocation location) async {
    final data = await _fetchProjectData(
      _projectUri('/weather/now', {'location': location.query}),
      '天气服务',
    );
    if (data is! Map<String, dynamic>) {
      throw StateError('天气响应格式不正确');
    }
    return AppWeatherNow.fromProjectJson(
      data.cast<String, Object?>(),
      fallbackCityName: location.cityName,
      fallbackLocationQuery: location.query,
    );
  }

  Future<List<AppWeatherIndex>> _fetchProjectIndices(
    String locationQuery,
  ) async {
    final data = await _fetchProjectData(
      _projectUri('/weather/indices', {'location': locationQuery}),
      '天气指数',
    );
    if (data is! List<dynamic>) {
      return const [];
    }
    return data
        .whereType<Map<dynamic, dynamic>>()
        .map((item) => AppWeatherIndex.fromJson(item.cast<String, Object?>()))
        .toList()
      ..sort((a, b) => _indexOrder(a.type).compareTo(_indexOrder(b.type)));
  }

  Future<Object?> _fetchProjectData(Uri uri, String label) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 8));
      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      final raw = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw StateError('$label响应格式不正确');
      }
      final code = (decoded['code'] as num?)?.toInt() ?? -1;
      if (response.statusCode < HttpStatus.ok ||
          response.statusCode >= HttpStatus.multipleChoices ||
          code != 0) {
        throw StateError(decoded['message'] as String? ?? '$label暂时不可用');
      }
      return decoded['data'];
    } on TimeoutException {
      throw StateError(_projectApiUnavailableMessage);
    } on SocketException {
      throw StateError(_projectApiUnavailableMessage);
    } finally {
      client.close(force: true);
    }
  }

  static const String _projectApiUnavailableMessage =
      AppApiConfig.unavailableMessage;

  Uri _projectUri(String path, Map<String, String> queryParameters) {
    final base = Uri.parse(projectApiBaseUrl.replaceFirst(RegExp(r'/+$'), ''));
    final basePath = base.path.endsWith('/') ? base.path : '${base.path}/';
    final nextPath = path.replaceFirst(RegExp(r'^/+'), '');
    return base.replace(
      path: '$basePath$nextPath',
      queryParameters: queryParameters,
    );
  }

  void _setAuthHeader(HttpClientRequest request) {
    if (jwt.trim().isNotEmpty) {
      request.headers.set('Authorization', 'Bearer ${jwt.trim()}');
    } else {
      request.headers.set('X-QW-Api-Key', apiKey.trim());
    }
  }

  int _indexOrder(String type) {
    return switch (type) {
      '3' => 0,
      '9' => 1,
      '7' => 2,
      _ => 99,
    };
  }

  String _normalizedHost() {
    return host.trim().replaceFirst(RegExp(r'^https?://'), '').split('/').first;
  }

  Future<AppWeatherLocation> _resolveLocation({
    required bool forceRefresh,
  }) async {
    if (!useDeviceLocation) {
      return _fallbackLocation();
    }
    final cachedLocation = _cachedLocation;
    final cachedUntil = _cachedLocationUntil;
    if (!forceRefresh &&
        cachedLocation != null &&
        cachedUntil != null &&
        cachedUntil.isAfter(DateTime.now())) {
      return cachedLocation;
    }
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled()
          .timeout(const Duration(seconds: 2));
      if (!serviceEnabled) {
        return _fallbackLocation();
      }
      var permission = await Geolocator.checkPermission().timeout(
        const Duration(seconds: 2),
      );
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission().timeout(
          const Duration(seconds: 6),
        );
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        return _fallbackLocation();
      }
      final lastKnown = await Geolocator.getLastKnownPosition().timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );
      if (lastKnown != null && !forceRefresh) {
        return await _cacheDeviceLocation(lastKnown);
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return await _cacheDeviceLocation(position);
    } on Object {
      return _fallbackLocation();
    }
  }

  Future<AppWeatherLocation> _cacheDeviceLocation(Position position) async {
    final query =
        '${position.longitude.toStringAsFixed(6)},${position.latitude.toStringAsFixed(6)}';
    final resolved = AppWeatherLocation(
      query: query,
      cityName: hasDirectRequiredConfig
          ? await _lookupCityName(query) ?? '当前位置'
          : '当前位置',
    );
    _cachedLocation = resolved;
    _cachedLocationUntil = DateTime.now().add(const Duration(minutes: 10));
    return resolved;
  }

  Future<String?> _lookupCityName(String query) async {
    final location = await _lookupCity(query);
    return location?.cityName;
  }

  Future<AppWeatherLocation?> _lookupCity(String query) async {
    final uri = Uri.https(_normalizedHost(), '/geo/v2/city/lookup', {
      'location': query,
      'range': 'cn',
      'lang': 'zh',
    });
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 5));
      _setAuthHeader(request);
      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );
      final raw = await response.transform(utf8.decoder).join();
      if (response.statusCode != HttpStatus.ok) {
        return null;
      }
      final decoded = (jsonDecode(raw) as Map<String, dynamic>)
          .cast<String, Object?>();
      if (decoded['code'] != '200') {
        return null;
      }
      final locations = decoded['location'] as List<dynamic>? ?? const [];
      if (locations.isEmpty) {
        return null;
      }
      final first = (locations.first as Map<dynamic, dynamic>)
          .cast<String, Object?>();
      final id = first['id'] as String?;
      final name = first['name'] as String?;
      final adm2 = first['adm2'] as String?;
      if (id == null || id.isEmpty) {
        return null;
      }
      if (name == null || name.isEmpty) {
        return AppWeatherLocation(query: id, cityName: adm2 ?? query);
      }
      if (adm2 == null || adm2.isEmpty || adm2 == name) {
        return AppWeatherLocation(query: id, cityName: name);
      }
      return AppWeatherLocation(query: id, cityName: '$adm2$name');
    } on Object {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  AppWeatherLocation _fallbackLocation() {
    if (location.isNotEmpty) {
      return const AppWeatherLocation(query: location, cityName: cityName);
    }
    throw StateError('请开启定位权限，或检查默认城市配置');
  }

  String _messageForCode(String? code) {
    return switch (code) {
      '204' => '天气服务没有找到当前位置',
      '400' => '天气请求参数不正确',
      '401' => '天气认证失败，请检查 Key 和 API Host',
      '402' => '天气服务配额不足或已欠费',
      '403' => '天气服务无访问权限，请检查项目订阅',
      '404' => '天气接口地址不存在，请检查 API Host',
      '429' => '天气请求过于频繁，请稍后再试',
      '500' || '502' || '503' => '天气服务暂时不可用',
      _ => '天气服务返回异常：${code ?? '未知错误'}',
    };
  }
}

class AppWeatherLocation {
  const AppWeatherLocation({required this.query, required this.cityName});

  final String query;
  final String cityName;
}

class AppWeatherIndex {
  const AppWeatherIndex({
    required this.type,
    required this.name,
    required this.level,
    required this.category,
    required this.text,
  });

  final String type;
  final String name;
  final String level;
  final String category;
  final String text;

  static AppWeatherIndex fromJson(Map<String, Object?> json) {
    return AppWeatherIndex(
      type: json['type'] as String? ?? '',
      name: json['name'] as String? ?? '生活指数',
      level: json['level'] as String? ?? '--',
      category: json['category'] as String? ?? '--',
      text: json['text'] as String? ?? '暂无建议',
    );
  }
}

class AppWeatherNow {
  const AppWeatherNow({
    required this.cityName,
    required this.locationQuery,
    required this.observedAt,
    required this.temp,
    required this.feelsLike,
    required this.text,
    required this.windDir,
    required this.windScale,
    required this.humidity,
  });

  final String cityName;
  final String locationQuery;
  final DateTime observedAt;
  final String temp;
  final String feelsLike;
  final String text;
  final String windDir;
  final String windScale;
  final String humidity;

  static AppWeatherNow fromJson(
    Map<String, Object?> json, {
    required String cityName,
    required String locationQuery,
  }) {
    final observedAtText = json['obsTime'] as String?;
    return AppWeatherNow(
      cityName: cityName,
      locationQuery: locationQuery,
      observedAt: DateTime.tryParse(observedAtText ?? '') ?? DateTime.now(),
      temp: json['temp'] as String? ?? '--',
      feelsLike: json['feelsLike'] as String? ?? '--',
      text: json['text'] as String? ?? '未知',
      windDir: json['windDir'] as String? ?? '未知风向',
      windScale: json['windScale'] as String? ?? '--',
      humidity: json['humidity'] as String? ?? '--',
    );
  }

  static AppWeatherNow fromProjectJson(
    Map<String, Object?> json, {
    required String fallbackCityName,
    required String fallbackLocationQuery,
  }) {
    final observedAtText = json['observedAt'] as String?;
    return AppWeatherNow(
      cityName: json['cityName'] as String? ?? fallbackCityName,
      locationQuery: json['locationQuery'] as String? ?? fallbackLocationQuery,
      observedAt: DateTime.tryParse(observedAtText ?? '') ?? DateTime.now(),
      temp: json['temp'] as String? ?? '--',
      feelsLike: json['feelsLike'] as String? ?? '--',
      text: json['text'] as String? ?? '未知',
      windDir: json['windDir'] as String? ?? '未知风向',
      windScale: json['windScale'] as String? ?? '--',
      humidity: json['humidity'] as String? ?? '--',
    );
  }
}
