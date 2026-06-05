import 'package:flutter_test/flutter_test.dart';
import 'package:xiaotai_life/core/daily_comics/daily_comic_service.dart';

void main() {
  test('AppDailyComic parses images in display order', () {
    final comic = AppDailyComic.fromJson({
      'id': 'comic_1',
      'title': '小笨漫画',
      'description': '今天的小漫画',
      'publishDate': '2026-05-27T00:00:00.000Z',
      'images': [
        {
          'id': 'image_2',
          'imageUrl': '/api/v1/daily-comics/images/2.webp',
          'sortOrder': 1,
        },
        {
          'id': 'image_1',
          'imageUrl': '/api/v1/daily-comics/images/1.webp',
          'sortOrder': 0,
        },
      ],
    });

    expect(comic.isValid, isTrue);
    expect(comic.images.map((image) => image.id), ['image_1', 'image_2']);
  });

  test(
    'DailyComicService resolves relative image urls against server root',
    () {
      final service = DailyComicService(
        baseUrl: 'http://192.168.1.8:3100/api/v1',
      );

      expect(
        service.resolveAssetUrl('/api/v1/daily-comics/images/a.webp'),
        'http://192.168.1.8:3100/api/v1/daily-comics/images/a.webp',
      );
    },
  );
}
