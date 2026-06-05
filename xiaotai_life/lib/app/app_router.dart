import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/app_auth_notifier.dart';
import '../core/constants/app_routes.dart';
import '../core/data/app_data_store.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/entries/presentation/entry_detail_page.dart';
import '../features/entries/presentation/entry_editor_page.dart';
import '../features/entries/presentation/entry_list_page.dart';
import '../features/life/presentation/anniversary_page.dart';
import '../features/life/presentation/life_detail_pages.dart';
import '../features/life/presentation/life_page.dart';
import '../features/life/presentation/money_page.dart';
import '../features/life/presentation/places_page.dart';
import '../features/memos/presentation/memo_page.dart';
import '../features/music/presentation/music_player_page.dart';
import '../features/search/presentation/global_search_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/shell/presentation/main_shell_page.dart';
import '../features/stats/presentation/statistics_page.dart';
import '../features/today/presentation/daily_comic_page.dart';
import '../features/today/presentation/reminder_page.dart';
import '../features/today/presentation/today_page.dart';
import '../features/treasure/presentation/treasure_box_page.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final _initialRoute = PlatformDispatcher.instance.defaultRouteName;
final _initialLocation = _initialRoute == '/' ? AppRoutes.today : _initialRoute;

String? authRedirectLocation({
  required bool initialized,
  required bool isSignedIn,
  required String matchedLocation,
}) {
  if (!initialized) {
    return null;
  }
  final goingToLogin = matchedLocation == AppRoutes.login;
  if (!isSignedIn && !goingToLogin) {
    return AppRoutes.login;
  }
  if (isSignedIn && goingToLogin) {
    return AppRoutes.today;
  }
  return null;
}

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: _initialLocation,
  refreshListenable: AppAuthNotifier.instance,
  redirect: (context, state) {
    final notifier = AppAuthNotifier.instance;
    return authRedirectLocation(
      initialized: notifier.initialized,
      isSignedIn: notifier.isSignedIn,
      matchedLocation: state.matchedLocation,
    );
  },
  routes: [
    GoRoute(
      path: AppRoutes.login,
      pageBuilder: (context, state) {
        return const NoTransitionPage(child: LoginPage());
      },
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        final hideBottomNavigation =
            state.matchedLocation == AppRoutes.entryEditor ||
            state.matchedLocation == AppRoutes.entryDetail ||
            state.matchedLocation == AppRoutes.music;
        return MainShellPage(
          navigationShell: navigationShell,
          showBottomNavigation: !hideBottomNavigation,
        );
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.today,
              pageBuilder: (context, state) {
                return const NoTransitionPage(child: TodayPage());
              },
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.entries,
              pageBuilder: (context, state) {
                return const NoTransitionPage(child: EntryListPage());
              },
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.treasureBox,
              pageBuilder: (context, state) {
                return const NoTransitionPage(child: TreasureBoxPage());
              },
            ),
            GoRoute(
              path: AppRoutes.search,
              pageBuilder: (context, state) {
                return const NoTransitionPage(child: GlobalSearchPage());
              },
            ),
            GoRoute(
              path: AppRoutes.reminder,
              pageBuilder: (context, state) {
                return const NoTransitionPage(child: ReminderPage());
              },
            ),
            GoRoute(
              path: AppRoutes.dailyComic,
              pageBuilder: (context, state) {
                return const NoTransitionPage(child: DailyComicPage());
              },
            ),
            GoRoute(
              path: AppRoutes.music,
              pageBuilder: (context, state) {
                return const NoTransitionPage(child: MusicPlayerPage());
              },
            ),
            GoRoute(
              path: AppRoutes.memos,
              pageBuilder: (context, state) {
                return const NoTransitionPage(child: MemoPage());
              },
            ),
            GoRoute(
              path: AppRoutes.life,
              pageBuilder: (context, state) {
                return const NoTransitionPage(child: LifePage());
              },
            ),
            GoRoute(
              path: AppRoutes.anniversary,
              pageBuilder: (context, state) {
                return const NoTransitionPage(child: AnniversaryPage());
              },
            ),
            GoRoute(
              path: AppRoutes.places,
              pageBuilder: (context, state) {
                return const NoTransitionPage(child: PlacesPage());
              },
            ),
            GoRoute(
              path: AppRoutes.coupleTasks,
              pageBuilder: (context, state) {
                return const NoTransitionPage(child: CoupleTasksPage());
              },
            ),
            GoRoute(
              path: AppRoutes.weeklyGoals,
              pageBuilder: (context, state) {
                return const NoTransitionPage(child: WeeklyGoalsPage());
              },
            ),
            GoRoute(
              path: AppRoutes.money,
              pageBuilder: (context, state) {
                return const NoTransitionPage(child: MoneyPage());
              },
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.stats,
              pageBuilder: (context, state) {
                return const NoTransitionPage(child: StatisticsPage());
              },
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.settings,
              pageBuilder: (context, state) {
                return const NoTransitionPage(child: SettingsPage());
              },
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: AppRoutes.entryEditor,
      pageBuilder: (context, state) {
        return NoTransitionPage(
          child: EntryEditorPage(initialEntry: state.extra as AppEntry?),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.entryDetail,
      pageBuilder: (context, state) {
        final entry = state.extra as AppEntry?;
        return NoTransitionPage(
          child: entry == null
              ? const EntryListPage()
              : EntryDetailPage(entry: entry),
        );
      },
    ),
  ],
);
