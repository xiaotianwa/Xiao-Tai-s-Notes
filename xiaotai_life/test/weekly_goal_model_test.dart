import 'package:flutter_test/flutter_test.dart';
import 'package:xiaotai_life/core/data/app_models.dart';

void main() {
  test('AppWeeklyGoal serializes daily progress history', () {
    final goal = AppWeeklyGoal(
      id: 'goal_1',
      title: 'Read',
      targetValue: 5,
      currentValue: 2,
      unit: 'times',
      iconName: 'book',
      colorName: 'orange',
      lastCheckInDateKey: '2026-06-03',
      dailyProgress: const {'2026-06-02': 1, '2026-06-03': 2},
    );

    final json = goal.toJson();
    final decoded = AppWeeklyGoal.fromJson(json);

    expect(decoded.dailyProgress, {'2026-06-02': 1, '2026-06-03': 2});
    expect(decoded.progressForDate(DateTime(2026, 6, 3)), 2);
  });

  test('AppWeeklyGoal keeps legacy payloads without daily progress', () {
    final decoded = AppWeeklyGoal.fromJson({
      'id': 'legacy_goal',
      'title': 'Move',
      'targetValue': 3,
      'currentValue': 1,
      'unit': 'times',
      'iconName': 'run',
      'colorName': 'green',
    });

    expect(decoded.dailyProgress, isEmpty);
    expect(decoded.progressForDate(DateTime(2026, 6, 3)), 0);
  });

  test('AppWeeklyGoal records progress for selected date', () {
    final goal = AppWeeklyGoal(
      id: 'goal_2',
      title: 'Walk',
      targetValue: 3,
      currentValue: 0,
      unit: 'times',
      iconName: 'run',
      colorName: 'green',
      dailyProgress: const {'2026-06-02': 1},
    );

    final updated = goal.recordProgressForDate(DateTime(2026, 6, 3), 4);

    expect(updated.dailyProgress['2026-06-02'], 1);
    expect(updated.dailyProgress['2026-06-03'], 3);
  });
}
