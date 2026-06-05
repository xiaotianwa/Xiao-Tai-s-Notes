import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme_tokens.dart';
import '../../../features/ai/presentation/ai_assistant_sheet.dart';
import '../../../shared/widgets/prototype_ui.dart';

class TreasureBoxPage extends StatelessWidget {
  const TreasureBoxPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeTokens;
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = width < 380 ? 14.0 : 18.0;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tokens.surface.withValues(alpha: .06),
                tokens.softPink.withValues(alpha: .04),
                tokens.softBlue.withValues(alpha: .05),
              ],
              stops: const [0, .54, 1],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(child: _TreasureSparkles(color: tokens.primary)),
              SafeArea(
                child: ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    12,
                    horizontalPadding,
                    118,
                  ),
                  children: [
                    _TreasureHeader(
                      onSearch: () => context.push(AppRoutes.search),
                    ),
                    const SizedBox(height: 14),
                    const _TreasureHero(),
                    const SizedBox(height: 18),
                    _PinnedEntries(entries: _pinnedEntries),
                    const SizedBox(height: 18),
                    _TreasureSectionHeader(
                      title: '日常记录',
                      count: _dailyEntries.length,
                    ),
                    const SizedBox(height: 10),
                    _TreasureGrid(entries: _dailyEntries),
                    const SizedBox(height: 18),
                    _TreasureSectionHeader(
                      title: '生活工具',
                      count: _lifeEntries.length,
                    ),
                    const SizedBox(height: 10),
                    _TreasureGrid(entries: _lifeEntries),
                    const SizedBox(height: 18),
                    _TreasureSectionHeader(
                      title: '放松探索',
                      count: _playEntries.length,
                    ),
                    const SizedBox(height: 10),
                    _TreasureGrid(entries: _playEntries),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TreasureHeader extends StatelessWidget {
  const _TreasureHeader({required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeTokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        '百宝箱',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.primary,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          height: 1.12,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.pets_rounded, color: tokens.accent, size: 18),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: tokens.accent,
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '漫画、记账、纪念日和小工具都在这里',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        _GlassIconButton(icon: Icons.search_rounded, onTap: onSearch),
      ],
    );
  }
}

class _TreasureEntry {
  const _TreasureEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.route,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? route;
  final void Function(BuildContext context)? onTap;

  void open(BuildContext context) {
    final customTap = onTap;
    if (customTap != null) {
      customTap(context);
      return;
    }
    final targetRoute = route;
    if (targetRoute != null) {
      context.push(targetRoute);
    }
  }
}

const _blue = Color(0xFF5EA7FF);
const _pink = Color(0xFFFF7FB0);
const _green = Color(0xFF62C987);
const _orange = Color(0xFFFFA65B);
const _purple = Color(0xFF9B70F1);
const _yellow = Color(0xFFFFC857);
const _mint = Color(0xFF56CFC2);
const _coral = Color(0xFFFF7B7B);

const _pinnedEntries = [
  _TreasureEntry(
    title: '今日提醒',
    subtitle: '查看安排',
    icon: Icons.notifications_active_outlined,
    color: _orange,
    route: AppRoutes.reminder,
  ),
  _TreasureEntry(
    title: '记账',
    subtitle: '收支明细',
    icon: Icons.account_balance_wallet_outlined,
    color: _green,
    route: AppRoutes.money,
  ),
  _TreasureEntry(
    title: '小笨漫画',
    subtitle: '每日更新',
    icon: Icons.auto_stories_outlined,
    color: _blue,
    route: AppRoutes.dailyComic,
  ),
  _TreasureEntry(
    title: '纪念日',
    subtitle: '重要日子',
    icon: Icons.event_available_outlined,
    color: _pink,
    route: AppRoutes.anniversary,
  ),
];

const _dailyEntries = [
  _TreasureEntry(
    title: '写日记',
    subtitle: '记录今天',
    icon: Icons.edit_note_rounded,
    color: _purple,
    route: AppRoutes.entryEditor,
  ),
  _TreasureEntry(
    title: '备忘录',
    subtitle: '随手记录',
    icon: Icons.sticky_note_2_outlined,
    color: _pink,
    route: AppRoutes.memos,
  ),
  _TreasureEntry(
    title: '提醒',
    subtitle: '待办与通知',
    icon: Icons.alarm_add_outlined,
    color: _orange,
    route: AppRoutes.reminder,
  ),
  _TreasureEntry(
    title: '小目标',
    subtitle: '推进计划',
    icon: Icons.flag_outlined,
    color: _green,
    route: AppRoutes.weeklyGoals,
  ),
];

const _lifeEntries = [
  _TreasureEntry(
    title: '记账本',
    subtitle: '收入支出',
    icon: Icons.payments_outlined,
    color: _green,
    route: AppRoutes.money,
  ),
  _TreasureEntry(
    title: '情侣100件事',
    subtitle: '一起完成',
    icon: Icons.favorite_outline_rounded,
    color: _coral,
    route: AppRoutes.coupleTasks,
  ),
  _TreasureEntry(
    title: '纪念日',
    subtitle: '倒数与纪念',
    icon: Icons.calendar_month_outlined,
    color: _pink,
    route: AppRoutes.anniversary,
  ),
  _TreasureEntry(
    title: '想去地点',
    subtitle: '旅行清单',
    icon: Icons.place_outlined,
    color: _yellow,
    route: AppRoutes.places,
  ),
];

final _playEntries = [
  const _TreasureEntry(
    title: '小笨漫画',
    subtitle: '看看新漫画',
    icon: Icons.menu_book_outlined,
    color: _blue,
    route: AppRoutes.dailyComic,
  ),
  const _TreasureEntry(
    title: '音乐播放器',
    subtitle: '歌单与播放',
    icon: Icons.library_music_outlined,
    color: _mint,
    route: AppRoutes.music,
  ),
  _TreasureEntry(
    title: 'AI 助手',
    subtitle: '语音和问答',
    icon: Icons.auto_awesome_outlined,
    color: _purple,
    onTap: showAiAssistantSheet,
  ),
  const _TreasureEntry(
    title: '全局搜索',
    subtitle: '快速查找',
    icon: Icons.manage_search_outlined,
    color: _orange,
    route: AppRoutes.search,
  ),
];

class _TreasureHero extends StatelessWidget {
  const _TreasureHero();

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeTokens;
    return GlassCard(
      height: 118,
      radius: 24,
      tintColor: tokens.softPink,
      padding: EdgeInsets.zero,
      showSheen: false,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    tokens.softPink.withValues(alpha: .58),
                    Colors.white.withValues(alpha: .20),
                    tokens.softBlue.withValues(alpha: .30),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Positioned(
            right: 18,
            bottom: 14,
            child: Container(
              width: 104,
              height: 78,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .68),
                borderRadius: BorderRadius.circular(34),
                border: Border.all(color: Colors.white.withValues(alpha: .72)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_rounded,
                    color: tokens.primary.withValues(alpha: .84),
                    size: 46,
                  ),
                  Positioned(
                    bottom: 22,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _TinyDot(color: tokens.primary),
                        const SizedBox(width: 18),
                        _TinyDot(color: tokens.primary),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 18,
            top: 14,
            width: 164,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .74),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .66),
                    ),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: tokens.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '常用功能一点即达',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '已收纳 12 个入口',
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 18,
            top: 18,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: tokens.accent,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _PinnedEntries extends StatelessWidget {
  const _PinnedEntries({required this.entries});

  final List<_TreasureEntry> entries;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = math.max(0.0, (constraints.maxWidth - 24) / 4);
        return Row(
          children: [
            for (final entry in entries) ...[
              SizedBox(
                width: itemWidth,
                child: _PinnedEntryButton(entry: entry),
              ),
              if (entry != entries.last) const SizedBox(width: 8),
            ],
          ],
        );
      },
    );
  }
}

class _PinnedEntryButton extends StatelessWidget {
  const _PinnedEntryButton({required this.entry});

  final _TreasureEntry entry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeTokens;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => entry.open(context),
        child: GlassCard(
          height: 88,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
          radius: 18,
          tintColor: entry.color.withValues(alpha: .42),
          blurSigma: 16,
          showSheen: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: entry.color.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(entry.icon, color: entry.color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                entry.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: tokens.textPrimary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TreasureSectionHeader extends StatelessWidget {
  const _TreasureSectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeTokens;
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w900,
            height: 1.2,
          ),
        ),
        const SizedBox(width: 6),
        Icon(
          Icons.pets_rounded,
          color: tokens.accent.withValues(alpha: .62),
          size: 14,
        ),
        const Spacer(),
        Text(
          '$count 个入口',
          style: TextStyle(
            color: tokens.primary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _TreasureGrid extends StatelessWidget {
  const _TreasureGrid({required this.entries});

  final List<_TreasureEntry> entries;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 370;
        return GridView.builder(
          itemCount: entries.length,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: compact ? 8 : 10,
            mainAxisSpacing: compact ? 8 : 10,
            mainAxisExtent: compact ? 104 : 108,
          ),
          itemBuilder: (context, index) {
            return _TreasureCard(entry: entries[index], index: index);
          },
        );
      },
    );
  }
}

class _TreasureCard extends StatelessWidget {
  const _TreasureCard({required this.entry, required this.index});

  final _TreasureEntry entry;
  final int index;

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeTokens;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.shape.controlRadius),
        onTap: () => entry.open(context),
        child: GlassCard(
          padding: const EdgeInsets.all(10),
          radius: tokens.shape.controlRadius,
          tintColor: entry.color.withValues(alpha: .36),
          blurSigma: 18,
          showSheen: false,
          child: Stack(
            children: [
              Positioned(
                right: -10,
                bottom: -10,
                child: _CornerBloom(
                  color: entry.color.withValues(alpha: .16),
                  flipped: index.isOdd,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: entry.color.withValues(alpha: .15),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: entry.color.withValues(alpha: .10),
                          ),
                        ),
                        child: Icon(entry.icon, color: entry.color, size: 22),
                      ),
                      const Spacer(),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .80),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: entry.color.withValues(alpha: .70),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    entry.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeTokens;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: Ink(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .78),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: Colors.white.withValues(alpha: .66)),
            boxShadow: _softEntryShadow(tokens),
          ),
          child: Icon(icon, color: tokens.primary, size: 24),
        ),
      ),
    );
  }
}

class _TreasureSparkles extends StatelessWidget {
  const _TreasureSparkles({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _SparklePainter(color: color),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SparklePainter extends CustomPainter {
  const _SparklePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final specs = <({double x, double y, double r, Color color})>[
      (x: .38, y: .06, r: 4, color: AppColors.accent),
      (x: .55, y: .09, r: 3, color: Colors.white),
      (x: .93, y: .19, r: 5, color: Colors.white),
      (x: .04, y: .31, r: 4, color: Colors.white),
      (x: .88, y: .56, r: 4, color: AppColors.accent),
      (x: .12, y: .80, r: 3, color: Colors.white),
    ];
    for (final spec in specs) {
      final center = Offset(size.width * spec.x, size.height * spec.y);
      paint.color = spec.color.withValues(alpha: .62);
      _drawDiamond(canvas, paint, center, spec.r);
    }
  }

  void _drawDiamond(Canvas canvas, Paint paint, Offset center, double radius) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius, center.dy)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - radius, center.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _TinyDot extends StatelessWidget {
  const _TinyDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .82),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _CornerBloom extends StatelessWidget {
  const _CornerBloom({required this.color, required this.flipped});

  final Color color;
  final bool flipped;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: flipped ? math.pi / 5 : -math.pi / 7,
      child: Icon(Icons.local_florist_rounded, color: color, size: 42),
    );
  }
}

List<BoxShadow> _softEntryShadow(AppThemeTokens tokens) {
  return [
    BoxShadow(
      color: tokens.primary.withValues(alpha: .08),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];
}
