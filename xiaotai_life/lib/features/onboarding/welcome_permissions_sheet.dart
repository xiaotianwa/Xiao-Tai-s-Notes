import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/data/app_data_store.dart';
import '../../core/monitor/device_monitor_service.dart';
import '../../core/notifications/local_notification_service.dart';
import '../../core/theme/app_theme_tokens.dart';
import '../../shared/widgets/app_loading_view.dart';

class RequiredPermissionsGate extends StatefulWidget {
  const RequiredPermissionsGate({required this.onReady, super.key});

  final VoidCallback onReady;

  static Future<bool> hasRequiredPermissions() async {
    return (await _RequiredPermissionState.load()).allGranted;
  }

  static Future<bool> shouldShow() async {
    final store = await AppLocalStore.create();
    final settings = store.getSettings();
    final permissions = await _RequiredPermissionState.load();
    if (permissions.allGranted) {
      await store.saveSettings(
        settings.copyWith(
          notificationsEnabled: permissions.notificationsGranted,
          firstLaunchPromptShown: true,
          updatedAt: DateTime.now(),
        ),
      );
      return false;
    }
    return true;
  }

  @override
  State<RequiredPermissionsGate> createState() =>
      _RequiredPermissionsGateState();
}

class _RequiredPermissionsGateState extends State<RequiredPermissionsGate>
    with WidgetsBindingObserver {
  _RequiredPermissionState? _state;
  bool _busy = false;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refresh(advanceIfCurrentGranted: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    if (state == null) {
      return const AppLoadingView();
    }

    final tokens = context.themeTokens;
    final specs = _guideSpecs(tokens, state);
    final spec = specs[_step.clamp(0, specs.length - 1)];
    final isGranted = spec.isGranted;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              tokens.surface,
              tokens.warmSurface.withValues(alpha: .9),
              tokens.background,
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
                children: [
                  _GuideHeader(
                    step: _step,
                    total: specs.length,
                    color: tokens.primary,
                  ),
                  const SizedBox(height: 18),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 96,
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: _PermissionGuidePanel(
                        key: ValueKey(spec.kind),
                        spec: spec,
                        primary: tokens.primary,
                        textPrimary: tokens.textPrimary,
                        textSecondary: tokens.textSecondary,
                        border: tokens.border,
                        surface: tokens.surface,
                        softSurface: tokens.warmSurface,
                        busy: _busy,
                        onEnable: _requestCurrent,
                        onSkip: _skipCurrent,
                        isLast: _step == specs.length - 1,
                        isGranted: isGranted,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<_PermissionGuideSpec> _guideSpecs(
    AppThemeTokens tokens,
    _RequiredPermissionState state,
  ) {
    return [
      _PermissionGuideSpec(
        kind: _PermissionKind.location,
        title: '开启定位权限',
        description: '获取当前位置和天气信息，为你提供更贴心的本地化服务~',
        imageAsset: tokens.assets.travel,
        isGranted: state.locationGranted,
        problem: state.locationProblem,
        privacyNote: '我们不会收集你的位置轨迹，仅用于天气和本地提醒。',
        benefits: const [
          _PermissionBenefit(
            icon: Icons.cloud_queue_rounded,
            color: Color(0xFF65A8FF),
            title: '精准天气预报',
            description: '根据位置获取准确天气信息',
          ),
          _PermissionBenefit(
            icon: Icons.place_rounded,
            color: Color(0xFF7B9BFF),
            title: '附近提醒服务',
            description: '智能推荐附近的纪念日和活动',
          ),
          _PermissionBenefit(
            icon: Icons.flag_circle_rounded,
            color: Color(0xFFFF7EA8),
            title: '小目标打卡',
            description: '基于位置的打卡和习惯养成',
          ),
        ],
      ),
      _PermissionGuideSpec(
        kind: _PermissionKind.notifications,
        title: '开启通知权限',
        description: '不错过重要提醒和纪念日，让每个时刻都更有意义~',
        imageAsset: tokens.assets.reminder,
        isGranted: state.notificationsGranted,
        problem: state.notificationProblem,
        privacyNote: '我们不会发送任何广告通知，你可以随时在设置中关闭。',
        benefits: const [
          _PermissionBenefit(
            icon: Icons.notifications_active_rounded,
            color: Color(0xFFFF7EA8),
            title: '重要提醒',
            description: '日程提醒、纪念日提醒',
          ),
          _PermissionBenefit(
            icon: Icons.event_available_rounded,
            color: Color(0xFF9B7BFF),
            title: '打卡提醒',
            description: '小目标打卡时间提醒',
          ),
          _PermissionBenefit(
            icon: Icons.chat_bubble_rounded,
            color: Color(0xFFFFBF56),
            title: '互动消息',
            description: '评论、点赞等互动通知',
          ),
        ],
      ),
      _PermissionGuideSpec(
        kind: _PermissionKind.overlay,
        title: '开启悬浮窗权限',
        description: '方便快速记录和查看，让操作更高效便捷~',
        imageAsset: tokens.assets.homeMascot,
        isGranted: state.overlayGranted,
        problem: state.overlayProblem,
        privacyNote: '悬浮窗仅用于功能展示，不会获取你的隐私信息。',
        benefits: const [
          _PermissionBenefit(
            icon: Icons.note_alt_rounded,
            color: Color(0xFF9B7BFF),
            title: '快速记录',
            description: '悬浮窗一键记录灵感和心情',
          ),
          _PermissionBenefit(
            icon: Icons.favorite_rounded,
            color: Color(0xFFFF7EA8),
            title: '便捷查看',
            description: '快速查看待办和提醒',
          ),
          _PermissionBenefit(
            icon: Icons.bolt_rounded,
            color: Color(0xFFFFBF56),
            title: '操作高效',
            description: '无需切换应用，提升效率',
          ),
        ],
      ),
    ];
  }

  Future<void> _refresh({bool advanceIfCurrentGranted = false}) async {
    final next = await _RequiredPermissionState.load();
    if (!mounted) {
      return;
    }
    setState(() => _state = next);
    if (next.allGranted) {
      await _finishPrompt();
      return;
    }
    if (advanceIfCurrentGranted && _isStepGranted(next, _step)) {
      await _goNext();
    }
  }

  Future<void> _requestCurrent() async {
    final state = _state;
    if (state == null || _busy) {
      return;
    }
    if (_isStepGranted(state, _step)) {
      await _goNext();
      return;
    }

    setState(() => _busy = true);
    try {
      switch (_step) {
        case 0:
          await _requestLocation();
          break;
        case 1:
          await _requestNotifications();
          break;
        case 2:
          await _openOverlaySettings();
          break;
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _requestLocation() async {
    try {
      var permission = await Geolocator.checkPermission().timeout(
        const Duration(seconds: 4),
      );
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission().timeout(
          const Duration(seconds: 12),
        );
      }
      if (permission == LocationPermission.deniedForever) {
        _showSnack('定位权限已被永久拒绝，请在系统设置里打开');
        unawaited(Geolocator.openAppSettings());
        return;
      }
      final granted =
          permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
      if (granted) {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled()
            .timeout(const Duration(seconds: 2), onTimeout: () => true);
        if (!serviceEnabled) {
          _showSnack('定位权限已开启，若天气无法更新，请再打开系统定位服务');
        }
      }
      await _refresh(advanceIfCurrentGranted: true);
    } catch (_) {
      _showSnack('定位权限请求失败，请稍后重试');
    }
  }

  Future<void> _requestNotifications() async {
    try {
      final granted = await LocalNotificationService.instance
          .requestNotificationsPermission()
          .timeout(const Duration(seconds: 12), onTimeout: () => false);
      if (!granted) {
        _showSnack('请先在系统弹窗或系统设置中允许通知权限');
      }
      await _refresh(advanceIfCurrentGranted: true);
    } catch (_) {
      _showSnack('通知权限请求失败，请稍后重试');
    }
  }

  Future<void> _openOverlaySettings() async {
    await DeviceMonitorService.instance.openOverlaySettings();
    _showSnack('请在系统设置中允许“显示在其他应用上层”，完成后返回');
  }

  Future<void> _skipCurrent() async {
    final state = _state;
    if (state != null && _isStepGranted(state, _step)) {
      await _goNext();
      return;
    }
    _showSnack('需要完成系统权限授权后才能进入首页');
  }

  Future<void> _goNext({bool forceFinish = false}) async {
    if (!mounted) {
      return;
    }
    if (forceFinish || _step >= 2) {
      await _finishPrompt();
      return;
    }
    setState(() => _step += 1);
  }

  bool _isStepGranted(_RequiredPermissionState state, int step) {
    return switch (step) {
      0 => state.locationGranted,
      1 => state.notificationsGranted,
      _ => state.overlayGranted,
    };
  }

  Future<void> _finishPrompt() async {
    final store = await AppLocalStore.create();
    final state = _state ?? await _RequiredPermissionState.load();
    final settings = store.getSettings();
    await store.saveSettings(
      settings.copyWith(
        notificationsEnabled: state.notificationsGranted,
        firstLaunchPromptShown: true,
        updatedAt: DateTime.now(),
      ),
    );
    if (state.overlayGranted) {
      await DeviceMonitorService.instance.enable();
    }
    if (mounted) {
      widget.onReady();
    }
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(message, textAlign: TextAlign.center),
        ),
      );
  }
}

enum _PermissionKind { location, notifications, overlay }

class _PermissionGuideSpec {
  const _PermissionGuideSpec({
    required this.kind,
    required this.title,
    required this.description,
    required this.imageAsset,
    required this.benefits,
    required this.privacyNote,
    required this.isGranted,
    this.problem,
  });

  final _PermissionKind kind;
  final String title;
  final String description;
  final String imageAsset;
  final List<_PermissionBenefit> benefits;
  final String privacyNote;
  final bool isGranted;
  final String? problem;
}

class _PermissionBenefit {
  const _PermissionBenefit({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
}

class _RequiredPermissionState {
  const _RequiredPermissionState({
    required this.locationGranted,
    required this.notificationsGranted,
    required this.overlayGranted,
    this.locationProblem,
    this.notificationProblem,
    this.overlayProblem,
  });

  final bool locationGranted;
  final bool notificationsGranted;
  final bool overlayGranted;
  final String? locationProblem;
  final String? notificationProblem;
  final String? overlayProblem;

  bool get allGranted =>
      locationGranted && notificationsGranted && overlayGranted;

  static Future<_RequiredPermissionState> load() async {
    final locationPermission = await Geolocator.checkPermission().timeout(
      const Duration(seconds: 3),
      onTimeout: () => LocationPermission.unableToDetermine,
    );
    final locationGranted =
        (locationPermission == LocationPermission.whileInUse ||
        locationPermission == LocationPermission.always);

    final notificationsGranted = await LocalNotificationService.instance
        .areNotificationsEnabled()
        .timeout(const Duration(seconds: 4), onTimeout: () => false);

    final monitorPermissions = await DeviceMonitorService.instance
        .loadPermissions()
        .timeout(
          const Duration(seconds: 4),
          onTimeout: () => const DeviceMonitorPermissions(
            overlay: false,
            batteryWhitelisted: false,
          ),
        );

    return _RequiredPermissionState(
      locationGranted: locationGranted,
      notificationsGranted: notificationsGranted,
      overlayGranted: monitorPermissions.overlay,
      locationProblem: locationGranted
          ? null
          : locationPermission == LocationPermission.deniedForever
          ? '权限已永久拒绝'
          : '等待授权',
      notificationProblem: notificationsGranted ? null : '等待授权',
      overlayProblem: monitorPermissions.overlay ? null : '等待授权',
    );
  }
}

class _GuideHeader extends StatelessWidget {
  const _GuideHeader({
    required this.step,
    required this.total,
    required this.color,
  });

  final int step;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '首次权限引导',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
        Row(
          children: [
            for (var i = 0; i < total; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: i == step ? 22 : 8,
                height: 8,
                margin: const EdgeInsets.only(left: 6),
                decoration: BoxDecoration(
                  color: i == step ? color : color.withValues(alpha: .22),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PermissionGuidePanel extends StatelessWidget {
  const _PermissionGuidePanel({
    required this.spec,
    required this.primary,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.surface,
    required this.softSurface,
    required this.busy,
    required this.onEnable,
    required this.onSkip,
    required this.isLast,
    required this.isGranted,
    super.key,
  });

  final _PermissionGuideSpec spec;
  final Color primary;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color surface;
  final Color softSurface;
  final bool busy;
  final VoidCallback onEnable;
  final VoidCallback onSkip;
  final bool isLast;
  final bool isGranted;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surface.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: primary.withValues(alpha: .22)),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: .10),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PermissionHero(
              spec: spec,
              primary: primary,
              softSurface: softSurface,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            const SizedBox(height: 20),
            _BenefitCard(
              benefits: spec.benefits,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              border: border,
            ),
            const SizedBox(height: 22),
            _PrivacyNote(text: spec.privacyNote, color: primary),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: FilledButton(
                onPressed: busy ? null : onEnable,
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isGranted ? (isLast ? '已开启，进入首页' : '已开启，继续') : '去开启',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: busy ? null : onSkip,
                child: Text(
                  isGranted ? '继续下一步' : '完成授权后才能进入首页',
                  style: TextStyle(
                    color: primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionHero extends StatelessWidget {
  const _PermissionHero({
    required this.spec,
    required this.primary,
    required this.softSurface,
    required this.textPrimary,
    required this.textSecondary,
  });

  final _PermissionGuideSpec spec;
  final Color primary;
  final Color softSurface;
  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final heroSize = constraints.maxWidth < 330 ? 112.0 : 128.0;
        final titleSize = constraints.maxWidth < 330 ? 20.0 : 22.0;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: softSurface.withValues(alpha: .55),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 14, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spec.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: textPrimary,
                          fontSize: titleSize,
                          fontWeight: FontWeight.w900,
                          height: 1.18,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        spec.description,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: textSecondary,
                          height: 1.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (!spec.isGranted && spec.problem != null) ...[
                        const SizedBox(height: 12),
                        _ProblemPill(text: spec.problem!, color: primary),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: heroSize,
                  height: heroSize,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: _HeroImage(
                          path: spec.imageAsset,
                          size: heroSize,
                        ),
                      ),
                      Positioned(
                        left: -8,
                        top: 8,
                        child: Icon(
                          Icons.star_rounded,
                          size: 18,
                          color: const Color(0xFFFFCF65).withValues(alpha: .9),
                        ),
                      ),
                      Positioned(
                        right: 6,
                        top: -4,
                        child: Icon(
                          Icons.favorite_rounded,
                          size: 20,
                          color: const Color(0xFFFF93B7).withValues(alpha: .85),
                        ),
                      ),
                      Positioned(
                        left: 4,
                        bottom: 4,
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          size: 16,
                          color: primary.withValues(alpha: .35),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.path, required this.size});

  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Image.asset(
        path,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .72),
            borderRadius: BorderRadius.circular(28),
          ),
          child: const Icon(Icons.verified_user_outlined, size: 54),
        ),
      ),
    );
  }
}

class _ProblemPill extends StatelessWidget {
  const _ProblemPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({
    required this.benefits,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
  });

  final List<_PermissionBenefit> benefits;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border.withValues(alpha: .62)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Column(
          children: [
            for (final benefit in benefits)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: benefit.color.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: Icon(
                          benefit.icon,
                          color: benefit.color,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            benefit.title,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            benefit.description,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_rounded, color: color.withValues(alpha: .72), size: 15),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF85849A),
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
