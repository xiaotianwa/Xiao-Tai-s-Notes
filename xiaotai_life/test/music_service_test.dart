import 'package:flutter_test/flutter_test.dart';
import 'package:xiaotai_life/core/music/music_service.dart';

void main() {
  test('AppMusicTrack parses duration seconds from backend payload', () {
    final track = AppMusicTrack.fromJson({
      'id': 'track_1',
      'title': '那天下雨了',
      'audioUrl': '/api/v1/music/tracks/track_1/audio',
      'originalName': 'rain.mp3',
      'mimeType': 'audio/mpeg',
      'size': 1024,
      'enabled': true,
      'sortOrder': 1,
      'durationSeconds': 255,
    });

    expect(track.isValid, isTrue);
    expect(track.durationSeconds, 255);
  });

  test('MusicService resolves relative asset urls against server root', () {
    final service = MusicService(baseUrl: 'https://api.xthblog.site/api/v1');

    expect(
      service.resolveAssetUrl('/api/v1/music/tracks/track_1/audio'),
      'https://api.xthblog.site/api/v1/music/tracks/track_1/audio',
    );
  });
}
