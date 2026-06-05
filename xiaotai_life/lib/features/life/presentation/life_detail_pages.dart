import 'package:flutter/material.dart';

import '../../../core/data/app_data_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/prototype_ui.dart';

class CoupleTasksPage extends StatefulWidget {
  const CoupleTasksPage({super.key});

  @override
  State<CoupleTasksPage> createState() => _CoupleTasksPageState();
}

class _CoupleTasksPageState extends State<CoupleTasksPage> {
  late Future<AppLocalStore> _storeFuture;
  String _filter = 'all';

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
        final stored = store?.getCoupleTasks() ?? const <AppCoupleTask>[];
        final tasks = stored;
        final visible = _filteredTasks(tasks);
        final completed = tasks.where((task) => task.completed).length;
        return PrototypePage(
          title: '情侣 100 件事',
          subtitle: '$completed / ${tasks.length} \u5df2\u5b8c\u6210',
          leading: const PrototypeBackButton(),
          showActionButton: false,
          separateHeaderControls: true,
          children: [
            const SizedBox(height: 14),
            _SegmentedFilter(
              value: _filter,
              items: const [
                _FilterItem('all', '\u5168\u90e8'),
                _FilterItem('todo', '\u672a\u5b8c\u6210'),
                _FilterItem('done', '\u5df2\u5b8c\u6210'),
              ],
              onChanged: (value) => setState(() => _filter = value),
            ),
            const SizedBox(height: 16),
            if (visible.isEmpty)
              _CoupleEmptyCard(
                onAdd: store == null ? null : () => _openTaskEditor(store),
              )
            else
              for (final task in visible)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CoupleTaskCard(
                    task: task,
                    onToggle: store == null
                        ? null
                        : () => _toggleTask(store, task),
                    onEdit: store == null
                        ? null
                        : () => _openTaskEditor(store, task: task),
                    onDelete: store == null
                        ? null
                        : () => _deleteTask(store, task),
                  ),
                ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  List<AppCoupleTask> _filteredTasks(List<AppCoupleTask> tasks) {
    return switch (_filter) {
      'todo' => tasks.where((task) => !task.completed).toList(),
      'done' => tasks.where((task) => task.completed).toList(),
      _ => tasks,
    };
  }

  Future<void> _toggleTask(AppLocalStore store, AppCoupleTask task) async {
    final completed = !task.completed;
    await store.upsertCoupleTask(
      task.copyWith(
        completed: completed,
        completedAt: completed ? DateTime.now() : null,
      ),
    );
    _refresh(store);
  }

  Future<void> _openTaskEditor(
    AppLocalStore store, {
    AppCoupleTask? task,
  }) async {
    final result = await showDialog<_TaskEditResult>(
      context: context,
      builder: (context) => _TaskEditDialog(task: task),
    );
    if (result == null) {
      return;
    }
    final tasks = store.getCoupleTasks();
    if (task == null) {
      final nextIndex = tasks.isEmpty
          ? 1
          : tasks.map((item) => item.index).reduce((a, b) => a > b ? a : b) + 1;
      await store.upsertCoupleTask(
        AppCoupleTask(
          id: 'couple_custom_${DateTime.now().microsecondsSinceEpoch}',
          index: nextIndex,
          title: result.title,
        ),
      );
    } else {
      await store.upsertCoupleTask(task.copyWith(title: result.title));
    }
    _refresh(store);
  }

  Future<void> _deleteTask(AppLocalStore store, AppCoupleTask task) async {
    final confirmed = await _confirm(
      context,
      title: '删除事项',
      message: '\u786e\u5b9a\u5220\u9664\u300c${task.title}\u300d\u5417\uff1f',
    );
    if (!confirmed) {
      return;
    }
    await store.deleteCoupleTask(task.id);
    _refresh(store);
  }

  void _refresh(AppLocalStore store) {
    if (!mounted) {
      return;
    }
    setState(() => _storeFuture = Future.value(store));
  }
}

class _CoupleEmptyCard extends StatelessWidget {
  const _CoupleEmptyCard({required this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 26),
      child: Column(
        children: [
          Container(
            width: 78,
            height: 78,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: .16),
              ),
            ),
            child: Icon(
              Icons.favorite_border_rounded,
              color: AppColors.accent.withValues(alpha: .72),
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '这里暂时没有事项',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '换一个筛选条件，或者添加一件只属于你们的小事。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('添加事项'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.surface,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WeeklyGoalsPage extends StatefulWidget {
  const WeeklyGoalsPage({super.key});

  @override
  State<WeeklyGoalsPage> createState() => _WeeklyGoalsPageState();
}

class _WeeklyGoalsPageState extends State<WeeklyGoalsPage> {
  late Future<AppLocalStore> _storeFuture;
  List<AppWeeklyGoal>? _goalsOverride;

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
        final stored =
            _goalsOverride ??
            store?.getWeeklyGoals() ??
            const <AppWeeklyGoal>[];
        final goals = stored;
        return PrototypePage(
          title: '小目标',
          subtitle:
              '${goals.where((goal) => _goalPeriodProgress(goal, DateTime.now()) >= 1).length} 个已完成',
          leading: const PrototypeBackButton(),
          actionIcon: Icons.add_rounded,
          onActionTap: store == null ? null : () => _openGoalEditor(store),
          separateHeaderControls: true,
          children: [
            const SizedBox(height: 14),
            if (goals.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: store == null
                      ? null
                      : () => _openGoalEditor(store),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('添加目标'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (goals.isEmpty)
              AppEmptyState(
                icon: Icons.flag_outlined,
                title: '还没有小目标',
                message: '添加一个今日、本周或本月目标，让生活更有具体的期待。',
                actionLabel: '添加目标',
                onAction: store == null ? null : () => _openGoalEditor(store),
              )
            else
              for (final goal in goals)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _WeeklyGoalCard(
                    goal: goal,
                    onMinus: store == null
                        ? null
                        : () => _adjustGoal(store, goal, -1),
                    onPlus: store == null
                        ? null
                        : () => _adjustGoal(store, goal, 1),
                    onEdit: store == null
                        ? null
                        : () => _openGoalEditor(store, goal: goal),
                    onTrend: () => _showTrend(goal),
                    onDelete: store == null
                        ? null
                        : () => _deleteGoal(store, goal),
                  ),
                ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Future<void> _adjustGoal(
    AppLocalStore store,
    AppWeeklyGoal goal,
    double delta,
  ) async {
    final now = DateTime.now();
    final source = _storedGoal(store, goal);
    final todayValue = source.progressForDate(now);
    final nextTodayValue = (todayValue + delta).clamp(0, source.targetValue);
    final nextCurrent = (source.currentValue + delta).clamp(
      0,
      source.targetValue,
    );
    final updated = source
        .copyWith(
          id: source.id,
          currentValue: nextCurrent.toDouble(),
          lastCheckInDateKey: AppWeeklyGoal.dateKey(now),
        )
        .recordProgressForDate(now, nextTodayValue.toDouble());
    await store.upsertWeeklyGoal(updated);
    _refresh(store);
  }

  AppWeeklyGoal _storedGoal(AppLocalStore store, AppWeeklyGoal goal) {
    final stored = store.getWeeklyGoals();
    final index = stored.indexWhere((item) => item.id == goal.id);
    return index == -1 ? goal : stored[index];
  }

  Future<void> _openGoalEditor(
    AppLocalStore store, {
    AppWeeklyGoal? goal,
  }) async {
    final result = await showDialog<_GoalEditResult>(
      context: context,
      builder: (context) => _GoalEditDialog(goal: goal),
    );
    if (result == null) {
      return;
    }
    final now = DateTime.now();
    final id = goal?.id ?? 'goal_${now.microsecondsSinceEpoch}';
    final updated = AppWeeklyGoal(
      id: id,
      title: result.title,
      targetValue: result.targetValue,
      currentValue: (goal?.currentValue ?? 0)
          .clamp(0, result.targetValue)
          .toDouble(),
      unit: result.unit,
      period: result.period,
      iconName: goal?.iconName ?? 'run',
      colorName: goal?.colorName ?? 'green',
      lastCheckInDateKey: goal?.lastCheckInDateKey,
      dailyProgress: goal?.dailyProgress ?? const <String, double>{},
    );
    await store.upsertWeeklyGoal(updated);
    _refresh(store);
  }

  Future<void> _deleteGoal(AppLocalStore store, AppWeeklyGoal goal) async {
    final confirmed = await _confirm(
      context,
      title: '删除目标',
      message: '\u786e\u5b9a\u5220\u9664\u300c${goal.title}\u300d\u5417\uff1f',
    );
    if (!confirmed) {
      return;
    }
    await store.deleteWeeklyGoal(goal.id);
    _refresh(store);
  }

  void _showTrend(AppWeeklyGoal goal) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _WeeklyGoalTrendSheet(goal: goal),
    );
  }

  void _refresh([AppLocalStore? store]) {
    if (!mounted) {
      return;
    }
    setState(() {
      if (store == null) {
        _goalsOverride = null;
        _storeFuture = AppLocalStore.create();
      } else {
        _goalsOverride = store.getWeeklyGoals();
        _storeFuture = Future.value(store);
      }
    });
  }
}

class _SegmentedFilter extends StatelessWidget {
  const _SegmentedFilter({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final List<_FilterItem> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          ChoiceChip(
            label: Text(item.label),
            selected: value == item.value,
            onSelected: (_) => onChanged(item.value),
          ),
      ],
    );
  }
}

class _FilterItem {
  const _FilterItem(this.value, this.label);

  final String value;
  final String label;
}

class _CoupleTaskCard extends StatelessWidget {
  const _CoupleTaskCard({
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final AppCoupleTask task;
  final VoidCallback? onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          Checkbox(value: task.completed, onChanged: (_) => onToggle?.call()),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${task.index}. ${task.title}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    decoration: task.completed
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  task.completed ? '\u5df2\u5b8c\u6210' : '\u8fdb\u884c\u4e2d',
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '编辑',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: '删除',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _WeeklyGoalCard extends StatelessWidget {
  const _WeeklyGoalCard({
    required this.goal,
    required this.onMinus,
    required this.onPlus,
    required this.onEdit,
    required this.onTrend,
    required this.onDelete,
  });

  final AppWeeklyGoal goal;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final VoidCallback? onEdit;
  final VoidCallback onTrend;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final color = _goalColor(goal.colorName);
    final now = DateTime.now();
    final periodValue = _goalPeriodValue(goal, now);
    final periodProgress = _goalPeriodProgress(goal, now);
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_goalIcon(goal.iconName), color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  goal.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _goalPeriodLabel(goal.period),
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: '趋势',
                onPressed: onTrend,
                icon: const Icon(Icons.bar_chart_rounded),
              ),
              IconButton(
                tooltip: '编辑',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: '删除',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: periodProgress,
              minHeight: 9,
              backgroundColor: color.withValues(alpha: .14),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_formatNumber(periodValue)} / ${_formatNumber(goal.targetValue)} ${goal.unit}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: '减少',
                onPressed: onMinus,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              IconButton(
                tooltip: '\u5b8c\u6210\u4e00\u6b21',
                onPressed: onPlus,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _GoalPeriodChart(goal: goal),
        ],
      ),
    );
  }
}

class _GoalPeriodChart extends StatelessWidget {
  const _GoalPeriodChart({required this.goal});

  final AppWeeklyGoal goal;

  @override
  Widget build(BuildContext context) {
    if (goal.period == 'day') {
      final now = DateTime.now();
      final value = goal.progressForDate(now);
      final progress = goal.targetValue <= 0
          ? 0.0
          : (value / goal.targetValue).clamp(0, 1).toDouble();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: .56),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border.withValues(alpha: .72)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.today_outlined,
              color: AppColors.primary,
              size: 18,
            ),
            const SizedBox(width: 8),
            const Text(
              '今日进度',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${_formatNumber(value)}/${_formatNumber(goal.targetValue)}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
    }
    final dates = _goalRecentDates();
    return SizedBox(
      height: 56,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final date in dates)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 10,
                    height: _barHeight(goal, date),
                    decoration: BoxDecoration(
                      color: goal.progressForDate(date) <= 0
                          ? AppColors.border
                          : AppColors.primary.withValues(alpha: .78),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _weekdayLabel(date),
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  double _barHeight(AppWeeklyGoal goal, DateTime date) {
    if (goal.targetValue <= 0) {
      return 6;
    }
    final progress = (goal.progressForDate(date) / goal.targetValue).clamp(
      0,
      1,
    );
    return (5 + (34 * progress)).toDouble();
  }
}

class _WeeklyGoalTrendSheet extends StatelessWidget {
  const _WeeklyGoalTrendSheet({required this.goal});

  final AppWeeklyGoal goal;

  @override
  Widget build(BuildContext context) {
    final dates = goal.period == 'day'
        ? [DateTime.now()]
        : _goalRecentDates().reversed.toList(growable: false);
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              goal.period == 'day' ? '今日进度' : '\u8fd1 7 \u5929\u8fdb\u5ea6',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            for (final date in dates)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(width: 52, child: Text(_goalTrendDateLabel(date))),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: goal.targetValue <= 0
                              ? 0
                              : (goal.progressForDate(date) / goal.targetValue)
                                    .clamp(0, 1)
                                    .toDouble(),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 74,
                      child: Text(
                        '${_formatNumber(goal.progressForDate(date))}/${_formatNumber(goal.targetValue)}',
                        textAlign: TextAlign.right,
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

class _TaskEditResult {
  const _TaskEditResult(this.title);

  final String title;
}

class _TaskEditDialog extends StatefulWidget {
  const _TaskEditDialog({this.task});

  final AppCoupleTask? task;

  @override
  State<_TaskEditDialog> createState() => _TaskEditDialogState();
}

class _TaskEditDialogState extends State<_TaskEditDialog> {
  late final TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.task == null ? '添加事项' : '编辑事项'),
      content: TextField(
        controller: _titleController,
        autofocus: true,
        decoration: const InputDecoration(labelText: '事项内容'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final title = _titleController.text.trim();
            if (title.isEmpty) {
              return;
            }
            Navigator.of(context).pop(_TaskEditResult(title));
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _GoalEditResult {
  const _GoalEditResult({
    required this.title,
    required this.targetValue,
    required this.unit,
    required this.period,
  });

  final String title;
  final double targetValue;
  final String unit;
  final String period;
}

class _GoalEditDialog extends StatefulWidget {
  const _GoalEditDialog({this.goal});

  final AppWeeklyGoal? goal;

  @override
  State<_GoalEditDialog> createState() => _GoalEditDialogState();
}

class _GoalEditDialogState extends State<_GoalEditDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _targetController;
  late final TextEditingController _unitController;
  late String _period;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    _titleController = TextEditingController(text: goal?.title ?? '');
    _targetController = TextEditingController(
      text: _formatNumber(goal?.targetValue ?? 3),
    );
    _unitController = TextEditingController(text: goal?.unit ?? '\u6b21');
    _period = goal?.period ?? 'week';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: .18),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.flag_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.goal == null ? '添加目标' : '编辑目标',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '设一个小目标，每天轻轻推进一点点',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _GoalDialogField(
                  controller: _titleController,
                  label: '目标名称',
                  hintText: '填写目标名称',
                  autofocus: widget.goal == null,
                ),
                const SizedBox(height: 12),
                _GoalPeriodSelector(
                  selected: _period,
                  onChanged: (value) => setState(() => _period = value),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _GoalDialogField(
                        controller: _targetController,
                        label: '目标值',
                        hintText: '3',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _GoalDialogField(
                        controller: _unitController,
                        label: '单位',
                        hintText: '次、小时、杯、页',
                      ),
                    ),
                  ],
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorText!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: BorderSide(
                            color: AppColors.border.withValues(alpha: .95),
                          ),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.surface,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text('保存'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _save() {
    final title = _titleController.text.trim();
    final target = double.tryParse(_targetController.text.trim());
    final unit = _unitController.text.trim();
    if (title.isEmpty || target == null || target <= 0 || unit.isEmpty) {
      setState(() {
        _errorText = '请填写目标名称、有效目标值和单位';
      });
      return;
    }
    Navigator.of(context).pop(
      _GoalEditResult(
        title: title,
        targetValue: target,
        unit: unit,
        period: _period,
      ),
    );
  }
}

class _GoalPeriodSelector extends StatelessWidget {
  const _GoalPeriodSelector({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const items = [('day', '今日'), ('week', '本周'), ('month', '本月')];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          ChoiceChip(
            label: Text(item.$2),
            selected: selected == item.$1,
            onSelected: (_) => onChanged(item.$1),
            selectedColor: AppColors.primary.withValues(alpha: .16),
            labelStyle: TextStyle(
              color: selected == item.$1
                  ? AppColors.primary
                  : AppColors.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
      ],
    );
  }
}

class _GoalDialogField extends StatelessWidget {
  const _GoalDialogField({
    required this.controller,
    required this.label,
    required this.hintText,
    this.keyboardType,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final TextInputType? keyboardType;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      autofocus: autofocus,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        labelStyle: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: const TextStyle(
          color: AppColors.textTertiary,
          fontWeight: FontWeight.w600,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  return await showDialog<bool>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: .58),
        builder: (context) => _SoftDeleteDialog(title: title, message: message),
      ) ??
      false;
}

class _SoftDeleteDialog extends StatelessWidget {
  const _SoftDeleteDialog({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: .96),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.surface.withValues(alpha: .7)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: .16),
              blurRadius: 30,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.danger,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: .18),
                      ),
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      '取消',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: AppColors.surface,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      '删除',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

List<DateTime> _goalRecentDates() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return List<DateTime>.generate(
    7,
    (index) => today.subtract(Duration(days: 6 - index)),
  );
}

String _weekdayLabel(DateTime date) {
  return switch (date.weekday) {
    DateTime.monday => '\u4e00',
    DateTime.tuesday => '\u4e8c',
    DateTime.wednesday => '\u4e09',
    DateTime.thursday => '\u56db',
    DateTime.friday => '\u4e94',
    DateTime.saturday => '\u516d',
    _ => '\u65e5',
  };
}

String _goalTrendDateLabel(DateTime date) {
  final now = DateTime.now();
  if (date.year == now.year && date.month == now.month && date.day == now.day) {
    return '今天';
  }
  return '${date.month}/${date.day}';
}

String _goalPeriodLabel(String period) {
  return switch (period) {
    'day' => '今日',
    'month' => '本月',
    _ => '本周',
  };
}

double _goalPeriodValue(AppWeeklyGoal goal, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final entries = goal.dailyProgress.entries;
  double sumWhere(bool Function(DateTime date) test) {
    var total = 0.0;
    for (final entry in entries) {
      final date = DateTime.tryParse(entry.key);
      if (date != null && test(date)) {
        total += entry.value;
      }
    }
    return total;
  }

  final value = switch (goal.period) {
    'day' => goal.progressForDate(today),
    'month' => sumWhere(
      (date) => date.year == today.year && date.month == today.month,
    ),
    _ => sumWhere((date) {
      final normalized = DateTime(date.year, date.month, date.day);
      final diff = today.difference(normalized).inDays;
      return diff >= 0 && diff < 7;
    }),
  };
  return value <= 0 && goal.dailyProgress.isEmpty ? goal.currentValue : value;
}

double _goalPeriodProgress(AppWeeklyGoal goal, DateTime now) {
  if (goal.targetValue <= 0) {
    return 0;
  }
  return (_goalPeriodValue(goal, now) / goal.targetValue)
      .clamp(0, 1)
      .toDouble();
}

IconData _goalIcon(String name) {
  return switch (name) {
    'book' || 'read' => Icons.menu_book_outlined,
    'food' => Icons.restaurant_outlined,
    'heart' => Icons.favorite_border,
    'water' => Icons.water_drop_outlined,
    _ => Icons.directions_run_rounded,
  };
}

Color _goalColor(String name) {
  return switch (name) {
    'orange' => AppColors.warning,
    'pink' => AppColors.accent,
    'blue' => AppColors.primary,
    _ => AppColors.success,
  };
}

String _formatNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(1);
}
