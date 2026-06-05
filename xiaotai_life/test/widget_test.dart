import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaotai_life/core/theme/app_theme.dart';
import 'package:xiaotai_life/features/auth/presentation/login_page.dart';
import 'package:xiaotai_life/features/entries/presentation/entry_editor_page.dart';
import 'package:xiaotai_life/features/life/presentation/anniversary_page.dart';
import 'package:xiaotai_life/features/life/presentation/life_detail_pages.dart';
import 'package:xiaotai_life/features/life/presentation/life_page.dart';
import 'package:xiaotai_life/features/life/presentation/money_page.dart';
import 'package:xiaotai_life/features/memos/presentation/memo_page.dart';
import 'package:xiaotai_life/features/music/presentation/music_player_page.dart';
import 'package:xiaotai_life/features/settings/presentation/settings_page.dart';
import 'package:xiaotai_life/features/stats/presentation/statistics_page.dart';
import 'package:xiaotai_life/features/today/presentation/reminder_page.dart';
import 'package:xiaotai_life/features/today/presentation/today_page.dart';
import 'package:xiaotai_life/features/treasure/presentation/treasure_box_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('xiaotai_widget_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          return tempDir.path;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('Entry editor shows input fields', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: EntryEditorPage()));

    expect(find.text('新建记录'), findsOneWidget);
    expect(find.text('请输入标题...'), findsOneWidget);
  });

  testWidgets('Static pages render on common device sizes without overflow', (
    WidgetTester tester,
  ) async {
    final pages = <({String name, Widget page})>[
      (name: 'TodayPage', page: TodayPage(weatherFuture: Future.value(null))),
      (name: 'LifePage', page: const LifePage()),
      (name: 'CoupleTasksPage', page: const CoupleTasksPage()),
      (name: 'WeeklyGoalsPage', page: const WeeklyGoalsPage()),
      (name: 'AnniversaryPage', page: const AnniversaryPage()),
      (name: 'MoneyPage', page: const MoneyPage()),
      (name: 'MemoPage', page: const MemoPage()),
      (name: 'MusicPlayerPage', page: const MusicPlayerPage()),
      (name: 'StatisticsPage', page: const StatisticsPage()),
      (name: 'SettingsPage', page: const SettingsPage()),
      (name: 'LoginPage', page: const LoginPage()),
      (name: 'EntryEditorPage', page: const EntryEditorPage()),
      (name: 'ReminderPage', page: const ReminderPage()),
      (name: 'TreasureBoxPage', page: const TreasureBoxPage()),
    ];
    final sizes = <Size>[
      const Size(360, 780),
      const Size(390, 844),
      const Size(430, 932),
      const Size(768, 1024),
    ];

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    for (final size in sizes) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      for (final item in pages) {
        await tester.pumpWidget(
          MaterialApp(theme: AppTheme.light(), home: item.page),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          tester.takeException(),
          isNull,
          reason: '${item.name} overflowed at ${size.width}x${size.height}',
        );
      }
    }
  });

  testWidgets('Notification settings rows toggle and memo time updates', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const SettingsPage()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('通知设置').first);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('消息通知'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('notification-main-row')));
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      _statusTextFinder('notification-main-status', '已开启'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('notification-lock-row')));
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      _statusTextFinder('notification-lock-status', '已关闭'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('notification-announcement-row')),
    );
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      _statusTextFinder('notification-announcement-status', '已关闭'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('notification-sound-row')));
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      _statusTextFinder('notification-sound-status', '已开启'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('notification-time-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('memo-hour-plus')));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(find.byKey(const ValueKey('memo-time-save')));
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('21:00'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 600));
  });
}

Finder _statusTextFinder(String key, String text) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Text && widget.key == ValueKey(key) && widget.data == text,
  );
}
