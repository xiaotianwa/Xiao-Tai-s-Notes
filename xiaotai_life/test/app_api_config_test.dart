import 'package:flutter_test/flutter_test.dart';
import 'package:xiaotai_life/core/network/app_api_config.dart';

void main() {
  test('test_api_config_defaultBaseUrl_usesProductionServer', () {
    expect(AppApiConfig.localDevBaseUrl, AppApiConfig.productionBaseUrl);
    expect(AppApiConfig.baseUrl, 'https://api.xthblog.site/api/v1');
  });

  test('test_api_config_uri_normalizesSlashes', () {
    final uri = AppApiConfig.uri('/auth/login');

    expect(uri.toString(), 'https://api.xthblog.site/api/v1/auth/login');
  });

  test('test_api_config_resolveAssetUrl_usesServerRoot', () {
    final url = AppApiConfig.resolveAssetUrl('/uploads/avatar.png');

    expect(url, 'https://api.xthblog.site/uploads/avatar.png');
  });
}
