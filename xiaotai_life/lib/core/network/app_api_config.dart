class AppApiConfig {
  const AppApiConfig._();

  static const productionBaseUrl = 'https://api.xthblog.site/api/v1';

  static const defaultBaseUrl = productionBaseUrl;

  static const emulatorDevBaseUrl = 'http://10.0.2.2:3100/api/v1';

  static const localDevBaseUrl = defaultBaseUrl;

  static const baseUrl = String.fromEnvironment(
    'XIAOTAI_API_BASE_URL',
    defaultValue: localDevBaseUrl,
  );

  static String normalizedBaseUrl([String? override]) {
    return (override ?? baseUrl).replaceFirst(RegExp(r'/+$'), '');
  }

  static Uri uri(String path, {String? baseUrl}) {
    final base = Uri.parse(normalizedBaseUrl(baseUrl));
    final basePath = base.path.endsWith('/') ? base.path : '${base.path}/';
    final nextPath = path.replaceFirst(RegExp(r'^/+'), '');
    return base.replace(path: '$basePath$nextPath');
  }

  static String resolveAssetUrl(String path, {String? baseUrl}) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final apiBase = normalizedBaseUrl(baseUrl);
    final serverRoot = apiBase.replaceFirst(RegExp(r'/api/v1$'), '');
    return '$serverRoot$path';
  }

  static const unavailableMessage =
      '手机连不上项目后端，请检查网络、服务器域名和 XIAOTAI_API_BASE_URL 配置。';

  static const timeoutMessage =
      '请求超时，请检查项目后端是否正常运行，或 XIAOTAI_API_BASE_URL 是否配置正确。';
}
