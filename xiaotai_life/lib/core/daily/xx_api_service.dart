import 'dart:async';
import 'dart:convert';
import 'dart:io';

class XxApiService {
  XxApiService._();

  static final instance = XxApiService._();

  static const _host = String.fromEnvironment(
    'XXAPI_HOST',
    defaultValue: 'v2.xxapi.cn',
  );
  static const _timeout = Duration(seconds: 8);

  Future<List<WeiboHotItem>> fetchWeiboHot({int limit = 8}) async {
    final data = await _getApiData('/api/weibohot', label: '微博热搜');
    if (data is! List<dynamic>) {
      throw StateError('微博热搜响应格式不正确');
    }
    return data
        .whereType<Map<dynamic, dynamic>>()
        .map((item) => WeiboHotItem.fromJson(item.cast<String, Object?>()))
        .take(limit)
        .toList();
  }

  Future<HoroscopeResult> fetchHoroscope({
    required String type,
    String time = 'today',
  }) async {
    final data = await _getApiData(
      '/api/horoscope',
      query: {'type': type, 'time': time},
      label: '星座运势',
    );
    if (data is! Map<dynamic, dynamic>) {
      throw StateError('星座运势响应格式不正确');
    }
    return HoroscopeResult.fromJson(data.cast<String, Object?>());
  }

  Future<BmiResult> calculateBmi({
    required double heightCm,
    required double weightKg,
  }) async {
    final data = await _getApiData(
      '/api/bmi',
      query: {
        'height': _formatNumber(heightCm),
        'weight': _formatNumber(weightKg),
      },
      label: 'BMI 指数',
    );
    if (data is! Map<dynamic, dynamic>) {
      throw StateError('BMI 响应格式不正确');
    }
    return BmiResult.fromJson(data.cast<String, Object?>());
  }

  Future<Object?> _getApiData(
    String path, {
    Map<String, String>? query,
    required String label,
  }) async {
    final uri = Uri.https(_host, path, query);
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final request = await client.getUrl(uri).timeout(_timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(_timeout);
      final raw = await response.transform(utf8.decoder).join();
      if (response.statusCode != HttpStatus.ok) {
        throw StateError('$label暂时不可用：HTTP ${response.statusCode}');
      }
      final decoded = (jsonDecode(raw) as Map<String, dynamic>)
          .cast<String, Object?>();
      final code = decoded['code'];
      if (!_isSuccessCode(code)) {
        final message =
            decoded['msg'] as String? ??
            decoded['message'] as String? ??
            '$label请求失败';
        throw StateError(message);
      }
      return decoded['data'];
    } on TimeoutException {
      throw StateError('$label请求超时，请稍后重试');
    } finally {
      client.close(force: true);
    }
  }

  static bool _isSuccessCode(Object? code) {
    return code == 200 || code == '200' || code == 0 || code == '0';
  }
}

class WeiboHotItem {
  const WeiboHotItem({
    required this.index,
    required this.title,
    required this.hot,
    required this.url,
  });

  final int index;
  final String title;
  final String hot;
  final String url;

  static WeiboHotItem fromJson(Map<String, Object?> json) {
    return WeiboHotItem(
      index: _readInt(json['index']),
      title: json['title'] as String? ?? '',
      hot: json['hot'] as String? ?? '',
      url: json['url'] as String? ?? '',
    );
  }
}

class HoroscopeResult {
  const HoroscopeResult({
    required this.title,
    required this.type,
    required this.time,
    required this.shortComment,
    required this.luckyColor,
    required this.luckyNumber,
    required this.luckyConstellation,
    required this.todoYi,
    required this.todoJi,
    required this.index,
    required this.fortuneText,
  });

  final String title;
  final String type;
  final String time;
  final String shortComment;
  final String luckyColor;
  final String luckyNumber;
  final String luckyConstellation;
  final String todoYi;
  final String todoJi;
  final Map<String, String> index;
  final Map<String, String> fortuneText;

  String get overallIndex => index['all'] ?? '--';

  String get overallText => fortuneText['all'] ?? shortComment;

  static HoroscopeResult fromJson(Map<String, Object?> json) {
    final index = (json['index'] as Map<dynamic, dynamic>? ?? const {}).map(
      (key, value) => MapEntry('$key', '$value'),
    );
    final fortuneText =
        (json['fortunetext'] as Map<dynamic, dynamic>? ?? const {}).map(
          (key, value) => MapEntry('$key', '$value'),
        );
    final todo = (json['todo'] as Map<dynamic, dynamic>? ?? const {})
        .cast<Object?, Object?>();
    return HoroscopeResult(
      title: json['title'] as String? ?? '',
      type: json['type'] as String? ?? '',
      time: json['time'] as String? ?? '',
      shortComment: json['shortcomment'] as String? ?? '',
      luckyColor: json['luckycolor'] as String? ?? '',
      luckyNumber: json['luckynumber'] as String? ?? '',
      luckyConstellation: json['luckyconstellation'] as String? ?? '',
      todoYi: todo['yi'] as String? ?? '',
      todoJi: todo['ji'] as String? ?? '',
      index: index,
      fortuneText: fortuneText,
    );
  }
}

class BmiResult {
  const BmiResult({required this.bmi, required this.message});

  final double bmi;
  final String message;

  String get formattedBmi => bmi.toStringAsFixed(1);

  static BmiResult fromJson(Map<String, Object?> json) {
    final rawBmi = json['bmi'];
    return BmiResult(
      bmi: rawBmi is num ? rawBmi.toDouble() : double.parse('$rawBmi'),
      message: json['msg'] as String? ?? '',
    );
  }
}

int _readInt(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse('$value') ?? 0;
}

String _formatNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(1);
}
