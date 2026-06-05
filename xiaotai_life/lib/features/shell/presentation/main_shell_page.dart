import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../core/theme/app_theme_tokens.dart';
import '../../../shared/widgets/app_loading_view.dart';
import '../../ai/presentation/ai_assistant_sheet.dart';
import '../../onboarding/welcome_permissions_sheet.dart';

class MainShellPage extends StatefulWidget {
  const MainShellPage({
    required this.navigationShell,
    this.showBottomNavigation = true,
    super.key,
  });

  final StatefulNavigationShell navigationShell;
  final bool showBottomNavigation;

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage>
    with WidgetsBindingObserver {
  bool _permissionsChecked = false;
  bool _permissionsReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ReminderNotificationIntent.instance.addListener(
      _openReminderPageFromNotification,
    );
    MemoNotificationIntent.instance.addListener(_openMemoPageFromNotification);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ReminderNotificationIntent.instance.hasPending) {
        _openReminderPageFromNotification();
      }
      if (MemoNotificationIntent.instance.hasPending) {
        _openMemoPageFromNotification();
      }
    });
    unawaited(_checkPermissionGuide());
  }

  @override
  void dispose() {
    ReminderNotificationIntent.instance.removeListener(
      _openReminderPageFromNotification,
    );
    MemoNotificationIntent.instance.removeListener(
      _openMemoPageFromNotification,
    );
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {}

  @override
  Widget build(BuildContext context) {
    if (!_permissionsChecked) {
      return const AppLoadingView();
    }
    if (!_permissionsReady) {
      return RequiredPermissionsGate(
        onReady: () {
          if (mounted) {
            setState(() {
              _permissionsChecked = true;
              _permissionsReady = true;
            });
            if (ReminderNotificationIntent.instance.hasPending) {
              _openReminderPageFromNotification();
            }
            if (MemoNotificationIntent.instance.hasPending) {
              _openMemoPageFromNotification();
            }
          }
        },
      );
    }
    final navigationShell = widget.navigationShell;
    final tabSpecs = _tabSpecsFor();
    final tokens = context.themeTokens;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(child: navigationShell),
          Positioned(
            right: 18,
            bottom: widget.showBottomNavigation
                ? safeBottom + 86
                : safeBottom + 22,
            child: _AiAssistantEntry(
              accent: tokens.primary,
              onTap: () => showAiAssistantSheet(context),
            ),
          ),
        ],
      ),
      bottomNavigationBar: widget.showBottomNavigation
          ? SafeArea(
              top: false,
              child: SizedBox(
                height: 76,
                child: Row(
                  children: [
                    _ThemeTabItem(
                      selected: navigationShell.currentIndex == 0,
                      spec: tabSpecs[0],
                      accent: tokens.primary,
                      onTap: () => _go(0),
                    ),
                    _ThemeTabItem(
                      selected: navigationShell.currentIndex == 1,
                      spec: tabSpecs[1],
                      accent: tokens.primary,
                      onTap: () => _go(1),
                    ),
                    _ThemeTabItem(
                      selected: navigationShell.currentIndex == 2,
                      spec: tabSpecs[2],
                      accent: tokens.primary,
                      onTap: () => _go(2),
                    ),
                    _ThemeTabItem(
                      selected: navigationShell.currentIndex == 3,
                      spec: tabSpecs[3],
                      accent: tokens.primary,
                      onTap: () => _go(3),
                    ),
                    _ThemeTabItem(
                      selected: navigationShell.currentIndex == 4,
                      spec: tabSpecs[4],
                      accent: tokens.primary,
                      onTap: () => _go(4),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  void _go(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  Future<void> _checkPermissionGuide() async {
    final shouldShow = await RequiredPermissionsGate.shouldShow();
    if (!mounted) {
      return;
    }
    setState(() {
      _permissionsChecked = true;
      _permissionsReady = !shouldShow;
    });
  }

  void _openReminderPageFromNotification() {
    if (!mounted || !_permissionsReady) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.go(AppRoutes.reminder);
      }
    });
  }

  void _openMemoPageFromNotification() {
    if (!mounted ||
        !_permissionsReady ||
        !MemoNotificationIntent.instance.take()) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.go(AppRoutes.memos);
      }
    });
  }
}

class _AiAssistantEntry extends StatelessWidget {
  const _AiAssistantEntry({required this.accent, required this.onTap});

  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(27),
        onTap: onTap,
        child: Container(
          width: 54,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .88),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: .82)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: .18),
                blurRadius: 20,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Icon(Icons.auto_awesome_rounded, color: accent, size: 25),
        ),
      ),
    );
  }
}

class _ThemeTabSpec {
  const _ThemeTabSpec({required this.label, required this.assetName});

  final String label;
  final String assetName;
}

List<_ThemeTabSpec> _tabSpecsFor() {
  return const [
    _ThemeTabSpec(label: '首页', assetName: 'home'),
    _ThemeTabSpec(label: '日记', assetName: 'diary'),
    _ThemeTabSpec(label: '百宝箱', assetName: 'treasure'),
    _ThemeTabSpec(label: '统计', assetName: 'stats'),
    _ThemeTabSpec(label: '我的', assetName: 'profile'),
  ];
}

class _ThemeTabItem extends StatelessWidget {
  const _ThemeTabItem({
    required this.selected,
    required this.spec,
    required this.accent,
    required this.onTap,
  });

  final bool selected;
  final _ThemeTabSpec spec;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeTokens;
    final folder = tokens.id == AppThemeId.eggyParty ? 'eggy' : 'default';
    final state = selected ? 'selected' : 'normal';
    final asset = 'assets/themes/$folder/tab_${spec.assetName}_$state.png';
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 64,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: const BoxDecoration(color: Colors.transparent),
          child: Semantics(
            label: spec.label,
            selected: selected,
            child: Image.asset(
              asset,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.circle_outlined,
                  color: selected ? accent : const Color(0xFFB8B8BE),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
