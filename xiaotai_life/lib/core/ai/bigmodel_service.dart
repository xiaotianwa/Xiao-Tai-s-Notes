import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../network/app_api_config.dart';

class BigModelService {
  BigModelService._();

  static final instance = BigModelService._();

  static const projectApiBaseUrl = String.fromEnvironment(
    'XIAOTAI_API_BASE_URL',
    defaultValue: AppApiConfig.localDevBaseUrl,
  );
  static const apiKey = String.fromEnvironment('BIGMODEL_API_KEY');
  static const model = String.fromEnvironment(
    'BIGMODEL_MODEL',
    defaultValue: 'deepseek-v4-pro-202606',
  );
  static const endpoint = String.fromEnvironment(
    'BIGMODEL_ENDPOINT',
    defaultValue: 'https://tokenhub.tencentmaas.com/v1/chat/completions',
  );

  static bool get hasProjectApi => projectApiBaseUrl.trim().isNotEmpty;

  static bool get hasApiKey => hasProjectApi || apiKey.trim().isNotEmpty;

  Future<String> chat(String userMessage) async {
    final trimmed = userMessage.trim();
    if (trimmed.isEmpty) {
      throw StateError('先写一点想问智能布布的内容吧');
    }
    if (hasProjectApi) {
      return _chatWithProjectApi(trimmed);
    }
    if (apiKey.trim().isEmpty) {
      throw StateError('缺少 BIGMODEL_API_KEY');
    }
    final uri = Uri.parse(endpoint);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client
          .postUrl(uri)
          .timeout(const Duration(seconds: 12));
      request.headers.contentType = ContentType.json;
      request.headers.set('Authorization', 'Bearer ${apiKey.trim()}');
      request.write(
        jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'system',
              'content':
                  '你是婷婷小笨笔记里的温柔生活助手。必须优先回答用户原问题，不要改变问题类型。回答要简短、具体、直接；只有当用户明确询问天气、穿衣、出门或城市情况时，才结合天气背景给建议。不要使用横线、下划线或空白占位。',
            },
            {'role': 'user', 'content': trimmed},
          ],
          'thinking': {'type': 'disabled'},
          'max_tokens': 1024,
          'stream': false,
        }),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 18),
      );
      final raw = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(_messageForStatus(response.statusCode, raw));
      }
      final decoded = (jsonDecode(raw) as Map<String, dynamic>)
          .cast<String, Object?>();
      final choices = decoded['choices'] as List<dynamic>? ?? const [];
      if (choices.isEmpty) {
        throw StateError('AI 暂时没有返回有效回复，请稍后再试');
      }
      final choice = (choices.first as Map<dynamic, dynamic>)
          .cast<String, Object?>();
      final content = _extractChoiceContent(choice);
      if (content.trim().isEmpty) {
        throw StateError('AI 暂时没有返回有效回复，请稍后再试');
      }
      return content.trim();
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _chatWithProjectApi(String message) async {
    final uri = _projectUri('/ai/chat');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client
          .postUrl(uri)
          .timeout(const Duration(seconds: 12));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'message': message}));
      final response = await request.close().timeout(
        const Duration(seconds: 18),
      );
      final raw = await response.transform(utf8.decoder).join();
      final decoded = (jsonDecode(raw) as Map<String, dynamic>)
          .cast<String, Object?>();
      final code = (decoded['code'] as num?)?.toInt() ?? -1;
      if (response.statusCode < HttpStatus.ok ||
          response.statusCode >= HttpStatus.multipleChoices ||
          code != 0) {
        throw StateError(decoded['message'] as String? ?? 'AI 服务暂时不可用');
      }
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError('AI 响应格式不正确');
      }
      final answer = data['answer'] as String? ?? '';
      if (answer.trim().isEmpty) {
        throw StateError('AI 暂时没有返回有效回复，请稍后再试');
      }
      return answer.trim();
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

  Uri _projectUri(String path) {
    return AppApiConfig.uri(path, baseUrl: projectApiBaseUrl);
  }

  String _extractChoiceContent(Map<String, Object?> choice) {
    final message = choice['message'];
    if (message is Map<dynamic, dynamic>) {
      final content = message['content'];
      final parsed = _stringifyContent(content);
      if (parsed.isNotEmpty) {
        return parsed;
      }
      final reasoningContent = message['reasoning_content'];
      final reasoning = _stringifyContent(reasoningContent);
      if (reasoning.isNotEmpty) {
        return reasoning;
      }
    }
    final delta = choice['delta'];
    if (delta is Map<dynamic, dynamic>) {
      return _stringifyContent(delta['content']);
    }
    return '';
  }

  String _stringifyContent(Object? content) {
    if (content == null) {
      return '';
    }
    if (content is String) {
      return content.trim();
    }
    if (content is List) {
      return content
          .map((item) {
            if (item is String) {
              return item;
            }
            if (item is Map) {
              return item['text'] ?? item['content'] ?? '';
            }
            return '';
          })
          .join()
          .trim();
    }
    return content.toString().trim();
  }

  String _messageForStatus(int statusCode, String rawBody) {
    final detail = _extractErrorMessage(rawBody);
    final message = switch (statusCode) {
      401 => 'AI 认证失败，请检查 BIGMODEL_API_KEY',
      403 => 'AI 服务无访问权限，请检查模型权限',
      429 => 'AI 请求过于频繁或额度暂不可用，请稍后再试',
      500 || 502 || 503 => 'AI 服务暂时不可用，请稍后再试',
      _ => 'AI 服务暂时不可用：HTTP $statusCode',
    };
    if (detail == null || detail.isEmpty) {
      return message;
    }
    return '$message（$detail）';
  }

  String? _extractErrorMessage(String rawBody) {
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final error = decoded['error'];
      if (error is Map<String, dynamic>) {
        return error['message'] as String?;
      }
      return decoded['message'] as String?;
    } on Object {
      return null;
    }
  }
}
