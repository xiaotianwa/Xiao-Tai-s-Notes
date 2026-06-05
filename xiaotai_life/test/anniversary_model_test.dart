import 'package:flutter_test/flutter_test.dart';
import 'package:xiaotai_life/core/data/app_models.dart';

void main() {
  test('AppAnniversary serializes count type and home pinned tag', () {
    final anniversary = AppAnniversary(
      id: 'anniversary_love',
      title: 'love',
      date: DateTime(2023, 10, 24),
      category: 'love',
      colorName: 'pink',
      mascotVariant: 'heart',
      note: 'important',
      showCountUp: true,
      pinnedOnHome: true,
    );

    final json = anniversary.toJson();
    final decoded = AppAnniversary.fromJson(json);

    expect(json['showCountUp'], isTrue);
    expect(json['pinnedOnHome'], isTrue);
    expect(decoded.showCountUp, isTrue);
    expect(decoded.pinnedOnHome, isTrue);
    expect(decoded.daysPassed(DateTime(2023, 10, 24)), 1);
  });

  test('AppAnniversary migrates legacy data with defaults', () {
    final decoded = AppAnniversary.fromJson({
      'id': 'legacy_anniversary',
      'title': '生日',
      'date': '2026-05-31T00:00:00.000',
      'category': 'birthday',
      'colorName': 'orange',
      'mascotVariant': 'cake',
    });

    expect(decoded.showCountUp, isFalse);
    expect(decoded.pinnedOnHome, isFalse);
  });

  test('selectHomeAnniversary prefers pinned item over nearest item', () {
    final pinned = AppAnniversary(
      id: 'anniversary_pinned',
      title: '固定显示',
      date: DateTime(2023, 10, 24),
      category: 'love',
      colorName: 'pink',
      mascotVariant: 'heart',
      showCountUp: true,
      pinnedOnHome: true,
    );
    final nearest = AppAnniversary(
      id: 'anniversary_nearest',
      title: '最近到来',
      date: DateTime(2026, 6, 4),
      category: 'life',
      colorName: 'blue',
      mascotVariant: 'gift',
    );

    final selected = selectHomeAnniversary([
      nearest,
      pinned,
    ], DateTime(2026, 6, 3));

    expect(selected, pinned);
  });
}
