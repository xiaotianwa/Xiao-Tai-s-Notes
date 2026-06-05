import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../core/announcements/announcement_service.dart';
import '../core/auth/app_auth_notifier.dart';
import '../core/auth/app_auth_service.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/app_routes.dart';
import '../core/daily_comics/daily_comic_service.dart';
import '../core/data/app_data_store.dart';
import '../core/notifications/local_notification_service.dart';
import '../core/permissions/app_permission_service.dart';
import '../core/sync/app_sync_service.dart';
import '../core/theme/app_theme_controller.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_theme_tokens.dart';
import '../core/update/app_update_service.dart';
import '../shared/widgets/announcement_dialog.dart';
import 'app_router.dart';

class XiaotaiApp extends StatefulWidget {
  const XiaotaiApp({super.key});

  @override
  State<XiaotaiApp> createState() => _XiaotaiAppState();
}

class _XiaotaiAppState extends State<XiaotaiApp> with WidgetsBindingObserver {
  bool _showSplash = true;
  bool _checkingAnnouncements = false;
  bool _checkingDailyComic = false;
  bool _lastSignedIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppAuthNotifier.instance.addListener(_handleAuthChanged);
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    AppAuthNotifier.instance.removeListener(_handleAuthChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _handleAuthChanged() {
    final signedIn = AppAuthNotifier.instance.isSignedIn;
    if (signedIn && !_lastSignedIn && !_showSplash) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_runSignedInPrompts());
        }
      });
    }
    _lastSignedIn = signedIn;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_showSplash) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_checkAnnouncements());
          unawaited(_checkDailyComicUpdate());
        }
      });
    }
  }

  Future<void> _bootstrap() async {
    // 先把本地登录态加载进内存，路由 redirect 依赖这个标记决定是否拦截到 /login。
    final hydrate = AppAuthNotifier.instance.hydrate();
    final themeHydrate = AppThemeController.instance.hydrate();
    await Future.wait<void>([hydrate, themeHydrate]);
    if (!mounted) {
      return;
    }
    _lastSignedIn = AppAuthNotifier.instance.isSignedIn;
    setState(() => _showSplash = false);
    unawaited(_bootstrapStartupServices());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_runStartupPrompts());
      }
    });
  }

  Future<void> _runStartupPrompts() async {
    if (!mounted) {
      return;
    }
    final promptContext = rootNavigatorKey.currentContext;
    if (promptContext == null) {
      return;
    }
    await AppUpdateService.instance.checkAndPrompt(promptContext);
    await _runSignedInPrompts();
  }

  Future<void> _runSignedInPrompts() async {
    if (!AppAuthNotifier.instance.isSignedIn) {
      return;
    }
    await _checkAnnouncements();
    await _checkDailyComicUpdate();
  }

  Future<void> _checkAnnouncements() async {
    if (!mounted ||
        _checkingAnnouncements ||
        !AppAuthNotifier.instance.isSignedIn) {
      return;
    }
    _checkingAnnouncements = true;
    try {
      final store = await AppLocalStore.create();
      final seenIds = store.getSeenAnnouncementIds();
      final announcements = await AnnouncementService.instance.fetchActive();
      final unseen =
          announcements.where((item) => !seenIds.contains(item.id)).toList()
            ..sort((a, b) {
              final priority = b.priority.compareTo(a.priority);
              if (priority != 0) {
                return priority;
              }
              return b.id.compareTo(a.id);
            });
      final dialogContext = rootNavigatorKey.currentContext;
      if (!mounted ||
          dialogContext == null ||
          !dialogContext.mounted ||
          unseen.isEmpty) {
        return;
      }
      final announcement = unseen.first;
      await showAnnouncementDialog(dialogContext, announcement);
      await store.markAnnouncementSeen(announcement.id);
    } catch (_) {
      // 公告失败不能影响启动和登录主流程。
    } finally {
      _checkingAnnouncements = false;
    }
  }

  Future<void> _checkDailyComicUpdate() async {
    if (!mounted || _checkingDailyComic) {
      return;
    }
    _checkingDailyComic = true;
    try {
      final store = await AppLocalStore.create();
      final comic = await DailyComicService.instance.fetchLatest();
      if (comic == null || store.getSeenDailyComicIds().contains(comic.id)) {
        return;
      }
      await LocalNotificationService.instance.showDailyComicUpdated(
        title: comic.title,
        publishDate: comic.publishDate,
      );
      final dialogContext = rootNavigatorKey.currentContext;
      if (!mounted || dialogContext == null || !dialogContext.mounted) {
        return;
      }
      final openNow = await showDialog<bool>(
        context: dialogContext,
        builder: (context) {
          return AlertDialog(
            title: const Text('小笨漫画更新啦'),
            content: Text(
              '${_formatDailyComicDate(comic.publishDate)} · ${comic.title}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('稍后'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('去看看'),
              ),
            ],
          );
        },
      );
      await store.markDailyComicSeen(comic.id);
      if (openNow == true && dialogContext.mounted) {
        dialogContext.go(AppRoutes.dailyComic);
      }
    } catch (_) {
      // 漫画更新检查不能影响启动主流程。
    } finally {
      _checkingDailyComic = false;
    }
  }

  Future<void> _bootstrapStartupServices() async {
    await AppPermissionService.instance.requestStartupPermissions();
    final store = await AppLocalStore.create();
    await LocalNotificationService.instance.syncPinnedReminders(
      store.getReminders(),
    );
    await LocalNotificationService.instance.syncMemoReminders(store.getMemos());
    await _tryStartupSync(store);
  }

  Future<void> _tryStartupSync(AppLocalStore store) async {
    final session = store.getAuthSession();
    if (session == null) {
      return;
    }
    try {
      await store.markSyncStarted();
      final refreshed = await AppAuthService.instance.refresh(
        session.refreshToken,
      );
      await store.saveAuthSession(refreshed);
      AppAuthNotifier.instance.setSession(refreshed);
      final result = await AppSyncService(
        store,
      ).sync(accessToken: refreshed.accessToken);
      AppThemeController.instance.applySettings(store.getSettings());
      await store.markSyncSucceeded(
        pushed: result.pushed,
        pulled: result.pulled,
        conflicts: result.conflicts,
      );
    } catch (error) {
      await store.markSyncFailed(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppThemeController.instance,
      builder: (context, _) {
        final tokens = AppThemeController.instance.tokens;
        return MaterialApp.router(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(tokens),
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: appRouter,
          builder: (context, child) {
            final content = _showSplash
                ? const _StartupHoldPage()
                : child ?? const SizedBox.shrink();
            if (_showSplash) {
              return content;
            }
            return _ThemedAppBackdrop(child: content);
          },
        );
      },
    );
  }
}

class _ThemedAppBackdrop extends StatelessWidget {
  const _ThemedAppBackdrop({required this.child});

  static const _globalBackgroundAsset =
      'assets/backgrounds/global_background.png';
  static const _eggyBackgroundAsset = 'assets/themes/eggy/background.png';

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeTokens;
    final backgroundAsset = tokens.id == AppThemeId.eggyParty
        ? _eggyBackgroundAsset
        : _globalBackgroundAsset;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          backgroundAsset,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              DecoratedBox(decoration: BoxDecoration(color: tokens.background)),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                tokens.surface.withValues(alpha: .08),
                tokens.softPink.withValues(alpha: .07),
                tokens.surface.withValues(alpha: .12),
              ],
              stops: const [0, .48, 1],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

String _formatDailyComicDate(DateTime date) {
  final local = date.toLocal();
  return '${local.year}年${local.month}月${local.day}日';
}

class _StartupHoldPage extends StatelessWidget {
  const _StartupHoldPage();

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeTokens;
    return ColoredBox(color: tokens.background);
  }
}
