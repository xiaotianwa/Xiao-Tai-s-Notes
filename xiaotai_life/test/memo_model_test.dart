import 'package:flutter_test/flutter_test.dart';
import 'package:xiaotai_life/core/data/app_models.dart';

void main() {
  test('AppMemo serializes structured fields without content markers', () {
    final memo = AppMemo(
      id: 'memo_1',
      title: '买礼物',
      content: '准备生日礼物',
      createdAt: DateTime(2026, 6, 1, 9),
      updatedAt: DateTime(2026, 6, 1, 10),
      mood: '开心',
      tags: const ['生活', '生日'],
      remindAt: DateTime(2026, 6, 2, 20),
      imagePaths: const ['/tmp/gift.jpg'],
      imageMediaIds: const ['media_1'],
      draft: true,
      pinned: true,
    );

    final json = memo.toJson();
    final decoded = AppMemo.fromJson(json);

    expect(json['content'], '准备生日礼物');
    expect(decoded.mood, '开心');
    expect(decoded.tags, ['生活', '生日']);
    expect(decoded.remindAt, DateTime(2026, 6, 2, 20));
    expect(decoded.imagePaths, ['/tmp/gift.jpg']);
    expect(decoded.imageMediaIds, ['media_1']);
    expect(decoded.draft, isTrue);
    expect(decoded.pinned, isTrue);
  });

  test('AppMemo migrates legacy content markers into structured fields', () {
    final decoded = AppMemo.fromJson({
      'id': 'legacy_memo',
      'title': '复习计划',
      'content': [
        '第三章笔记',
        '[mood:平静]',
        '[tags:学习, 阅读]',
        '[remindAt:2026-06-03T21:30:00.000]',
        '[image]',
        '[draft]',
      ].join('\n'),
      'createdAt': '2026-06-01T08:00:00.000',
      'updatedAt': '2026-06-01T09:00:00.000',
    });

    expect(decoded.content, '第三章笔记');
    expect(decoded.mood, '平静');
    expect(decoded.tags, ['学习', '阅读']);
    expect(decoded.remindAt, DateTime(2026, 6, 3, 21, 30));
    expect(decoded.draft, isTrue);
    expect(decoded.imagePaths, isEmpty);
  });

  test('AppMemo prefers explicit fields over legacy markers', () {
    final decoded = AppMemo.fromJson({
      'id': 'memo_2',
      'title': '显式字段',
      'content': '正文\n[mood:低落]\n[tags:旧标签]',
      'createdAt': '2026-06-01T08:00:00.000',
      'mood': '开心',
      'tags': ['新标签'],
      'draft': false,
    });

    expect(decoded.content, '正文');
    expect(decoded.mood, '开心');
    expect(decoded.tags, ['新标签']);
    expect(decoded.draft, isFalse);
  });
}
