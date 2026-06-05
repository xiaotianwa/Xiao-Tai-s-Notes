import 'package:flutter_test/flutter_test.dart';
import 'package:xiaotai_life/core/data/app_models.dart';

void main() {
  test(
    'AppEntry serializes structured edit fields without content markers',
    () {
      final entry = AppEntry(
        id: 'entry_1',
        kind: 'diary',
        kindLabel: '日记',
        title: '散步',
        content: '今天在公园散步。',
        mood: '开心',
        createdAt: DateTime(2026, 6, 1, 20),
        favorite: true,
        mascotVariant: 'bubu',
        location: '世纪公园',
        tags: const ['散步', '晚风'],
        draft: true,
        imagePaths: const ['/tmp/walk.jpg'],
        imageMediaIds: const ['media_1'],
      );

      final json = entry.toJson();
      final decoded = AppEntry.fromJson(json);

      expect(json['content'], '今天在公园散步。');
      expect(decoded.location, '世纪公园');
      expect(decoded.tags, ['散步', '晚风']);
      expect(decoded.draft, isTrue);
      expect(decoded.imagePaths, ['/tmp/walk.jpg']);
      expect(decoded.imageMediaIds, ['media_1']);
    },
  );

  test('AppEntry migrates legacy location and tag markers', () {
    final decoded = AppEntry.fromJson({
      'id': 'entry_legacy',
      'kind': 'diary',
      'kindLabel': '日记',
      'title': '旧日记',
      'content': '正文第一行\n[location:上海]\n[tags:旅行, 美好]',
      'mood': '平静',
      'createdAt': '2026-06-01T20:00:00.000',
      'favorite': false,
      'mascotVariant': 'bubu',
    });

    expect(decoded.content, '正文第一行');
    expect(decoded.location, '上海');
    expect(decoded.tags, ['旅行', '美好']);
    expect(decoded.draft, isFalse);
  });

  test('AppEntry prefers explicit fields over legacy markers', () {
    final decoded = AppEntry.fromJson({
      'id': 'entry_explicit',
      'kind': 'diary',
      'kindLabel': '日记',
      'title': '新日记',
      'content': '正文\n[location:旧位置]\n[tags:旧标签]',
      'mood': '开心',
      'location': '新位置',
      'tags': ['新标签'],
      'draft': true,
      'createdAt': '2026-06-01T20:00:00.000',
      'favorite': false,
      'mascotVariant': 'bubu',
    });

    expect(decoded.content, '正文');
    expect(decoded.location, '新位置');
    expect(decoded.tags, ['新标签']);
    expect(decoded.draft, isTrue);
  });
}
