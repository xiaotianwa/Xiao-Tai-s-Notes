import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/data/app_data_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme_tokens.dart';
import '../../../shared/widgets/app_mascot_scene.dart';
import '../../../shared/widgets/prototype_ui.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  late Future<AppLocalStore> _storeFuture;
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _storeFuture = AppLocalStore.create();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppLocalStore>(
      future: _storeFuture,
      builder: (context, snapshot) {
        final store = snapshot.data;
        final entries = store?.getEntries() ?? const <AppEntry>[];
        final goals = store?.getWeeklyGoals() ?? const <AppWeeklyGoal>[];
        final moneyRecords =
            store?.getMoneyRecords() ?? const <AppMoneyRecord>[];
        final monthEntries = _entriesInMonth(entries, _visibleMonth);
        final summary = _StatsSummary(
          allEntries: entries,
          monthEntries: monthEntries,
          goals: goals,
          moneySummary: summarizeMoneyRecords(
            moneyRecords,
            month: _visibleMonth,
          ),
          visibleMonth: _visibleMonth,
        );
        return PrototypePage(
          title: '统计',
          subtitle: '多维度记录与分析，陪你看见成长的每一步',
          showActionButton: false,
          topIllustrationInHeader: true,
          topIllustration: const AppMascotScene(
            height: 82,
            variant: MascotSceneVariant.flowers,
            showHeart: true,
          ),
          children: [
            const SizedBox(height: 18),
            _MonthSwitcher(
              month: _visibleMonth,
              onPrevious: () => _changeMonth(-1),
              onNext: () => _changeMonth(1),
            ),
            const SizedBox(height: 14),
            _OverviewCard(summary: summary),
            const SizedBox(height: 14),
            _RecordDaysCard(summary: summary),
            const SizedBox(height: 14),
            _GoalAnalysisCard(
              goals: goals,
              onOpenGoals: () => context.push(AppRoutes.weeklyGoals),
            ),
            const SizedBox(height: 14),
            _MoneySnapshotCard(
              summary: summary.moneySummary,
              onOpenMoney: () => context.push(AppRoutes.money),
            ),
          ],
        );
      },
    );
  }

  List<AppEntry> _entriesInMonth(List<AppEntry> entries, DateTime month) {
    return entries
        .where(
          (entry) =>
              entry.createdAt.year == month.year &&
              entry.createdAt.month == month.month,
        )
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }
}

class _StatsSummary {
  const _StatsSummary({
    required this.allEntries,
    required this.monthEntries,
    required this.goals,
    required this.moneySummary,
    required this.visibleMonth,
  });

  final List<AppEntry> allEntries;
  final List<AppEntry> monthEntries;
  final List<AppWeeklyGoal> goals;
  final AppMoneySummary moneySummary;
  final DateTime visibleMonth;

  int get monthRecordDays {
    return monthEntries
        .map(
          (entry) => DateTime(
            entry.createdAt.year,
            entry.createdAt.month,
            entry.createdAt.day,
          ),
        )
        .toSet()
        .length;
  }

  int get continuousDays {
    if (allEntries.isEmpty) {
      return 0;
    }
    final days = allEntries
        .map(
          (entry) => DateTime(
            entry.createdAt.year,
            entry.createdAt.month,
            entry.createdAt.day,
          ),
        )
        .toSet();
    var cursor = DateTime.now();
    var count = 0;
    while (days.contains(DateTime(cursor.year, cursor.month, cursor.day))) {
      count += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  int get completedGoals {
    return goals.where((goal) => goal.progress >= 1).length;
  }

  double get goalCompletion {
    if (goals.isEmpty) {
      return 0;
    }
    return completedGoals / goals.length;
  }
}

class _MonthSwitcher extends StatelessWidget {
  const _MonthSwitcher({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      radius: 20,
      child: Row(
        children: [
          _RoundToolButton(icon: Icons.chevron_left, onTap: onPrevious),
          Expanded(
            child: Text(
              '${month.year}年${month.month}月',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          _RoundToolButton(icon: Icons.chevron_right, onTap: onNext),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.summary});

  final _StatsSummary summary;

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeTokens;
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      color: tokens.softPink.withValues(alpha: .52),
      borderColor: tokens.primary.withValues(alpha: .12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .82),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const AppMascotScene(
                  height: 58,
                  variant: MascotSceneVariant.snack,
                  showHeart: false,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.monthEntries.isEmpty ? '本月还在等待第一条记录' : '本月记录概览',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tokens.textSecondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summary.monthEntries.isEmpty
                          ? '写下今天吧'
                          : '${summary.monthEntries.length} 篇记录',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: tokens.primary,
                        fontSize: 21,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: '记录天数',
                  value: '${summary.monthRecordDays}天',
                  color: tokens.primary,
                  icon: Icons.calendar_month_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: '总记录数',
                  value: '${summary.monthEntries.length}篇',
                  color: tokens.accent,
                  icon: Icons.edit_note_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .14)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordDaysCard extends StatelessWidget {
  const _RecordDaysCard({required this.summary});

  final _StatsSummary summary;

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeTokens;
    final daysInMonth = DateUtils.getDaysInMonth(
      summary.visibleMonth.year,
      summary.visibleMonth.month,
    );
    final value = daysInMonth == 0
        ? 0.0
        : summary.monthRecordDays / daysInMonth;
    return SoftCard(
      padding: const EdgeInsets.all(16),
      color: tokens.softBlue.withValues(alpha: .5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            title: '记录天数',
            icon: Icons.event_available_outlined,
            color: AppColors.info,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${summary.monthRecordDays}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 42,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              Text(
                '连续 ${summary.continuousDays} 天',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(color: tokens.primary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: value.clamp(0, 1),
              minHeight: 10,
              backgroundColor: tokens.surface.withValues(alpha: .72),
              valueColor: AlwaysStoppedAnimation<Color>(tokens.primary),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            '本月还有 ${math.max(daysInMonth - summary.monthRecordDays, 0)} 天可以被好好记录',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _GoalAnalysisCard extends StatelessWidget {
  const _GoalAnalysisCard({required this.goals, required this.onOpenGoals});

  final List<AppWeeklyGoal> goals;
  final VoidCallback onOpenGoals;

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeTokens;
    final completed = goals.where((goal) => goal.progress >= 1).length;
    final rate = goals.isEmpty ? 0.0 : completed / goals.length;
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            title: '目标完成分析',
            icon: Icons.flag_outlined,
            color: tokens.success,
            action: TextButton(onPressed: onOpenGoals, child: const Text('管理')),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: '目标总数',
                  value: '${goals.length}',
                  color: tokens.primary,
                  icon: Icons.track_changes_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: '完成率',
                  value: '${(rate * 100).round()}%',
                  color: tokens.success,
                  icon: Icons.verified_outlined,
                ),
              ),
            ],
          ),
          if (goals.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final goal in goals.take(3)) _GoalRow(goal: goal),
          ],
        ],
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.goal});

  final AppWeeklyGoal goal;

  @override
  Widget build(BuildContext context) {
    final color = _goalColor(goal.colorName);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(_goalIcon(goal.iconName), color: color, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              goal.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 72,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: goal.progress,
                minHeight: 7,
                backgroundColor: color.withValues(alpha: .12),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneySnapshotCard extends StatelessWidget {
  const _MoneySnapshotCard({required this.summary, required this.onOpenMoney});

  final AppMoneySummary summary;
  final VoidCallback onOpenMoney;

  @override
  Widget build(BuildContext context) {
    final balanceColor = summary.balanceCents >= 0
        ? AppColors.success
        : AppColors.danger;
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            title: '账目快照',
            icon: Icons.account_balance_wallet_outlined,
            color: balanceColor,
            action: TextButton(onPressed: onOpenMoney, child: const Text('查看')),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: '收入',
                  value: _formatMoney(summary.incomeCents),
                  color: AppColors.success,
                  icon: Icons.savings_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: '支出',
                  value: _formatMoney(summary.expenseCents),
                  color: AppColors.danger,
                  icon: Icons.payments_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _MetricTile(
            label: '本月结余',
            value: _formatSignedMoney(summary.balanceCents),
            color: balanceColor,
            icon: Icons.paid_outlined,
          ),
        ],
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.title,
    required this.icon,
    required this.color,
    this.action,
  });

  final String title;
  final IconData icon;
  final Color color;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        ?action,
      ],
    );
  }
}

class _RoundToolButton extends StatelessWidget {
  const _RoundToolButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeTokens;
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: tokens.primary),
      style: IconButton.styleFrom(
        backgroundColor: tokens.primary.withValues(alpha: .08),
        minimumSize: const Size.square(36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

Color _goalColor(String value) {
  return switch (value) {
    'pink' => AppColors.accent,
    'orange' => AppColors.warning,
    'blue' => AppColors.info,
    'green' => AppColors.success,
    _ => AppColors.primary,
  };
}

IconData _goalIcon(String value) {
  return switch (value) {
    'book' => Icons.menu_book_outlined,
    'food' => Icons.restaurant_outlined,
    'heart' => Icons.favorite_border,
    'water' => Icons.water_drop_outlined,
    'sleep' => Icons.bedtime_outlined,
    _ => Icons.directions_run_outlined,
  };
}

String _formatMoney(int cents) {
  final yuan = cents ~/ 100;
  final cent = cents % 100;
  return '¥$yuan.${cent.toString().padLeft(2, '0')}';
}

String _formatSignedMoney(int cents) {
  if (cents == 0) {
    return '¥0.00';
  }
  final prefix = cents > 0 ? '+' : '-';
  return '$prefix${_formatMoney(cents.abs())}';
}
