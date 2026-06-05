import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/data/app_data_store.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_mascot_scene.dart';
import '../../../shared/widgets/app_toast.dart';

const _reminderPurple = Color(0xFF9B70F1);
const _reminderDeep = Color(0xFF25203F);
const _reminderMuted = Color(0xFF8B85A1);
const _reminderLine = Color(0xFFF0EAF8);
const _reminderShadow = Color(0x1A8B6CF6);
const _reminderBg = Colors.transparent;

const _priorityLow = 'low';
const _priorityMedium = 'medium';
const _priorityHigh = 'high';

enum _ReminderTab { all, active, completed }

enum _ReminderPanel { list, form, detail }

enum _OverdueAction { complete, postpone, ignore }

class ReminderPage extends StatefulWidget {
  const ReminderPage({super.key});

  @override
  State<ReminderPage> createState() => _ReminderPageState();
}

class _ReminderPageState extends State<ReminderPage> {
  late Future<AppLocalStore> _storeFuture;
  StreamSubscription<void>? _storeSubscription;

  final _titleController = TextEditingController();
  final _noteController = TextEditingController();

  _ReminderTab _tab = _ReminderTab.active;
  _ReminderPanel _panel = _ReminderPanel.list;
  AppReminder? _editingReminder;
  String? _selectedReminderId;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);
  String _repeatRule = 'daily';
  int _notifyBeforeMinutes = 10;
  bool _pinned = true;
  String _priority = _priorityMedium;
  String _icon = 'water';
  String _searchQuery = '';
  String? _lastStatusBarSyncKey;
  bool _handlingNotificationIntent = false;

  @override
  void initState() {
    super.initState();
    _storeFuture = AppLocalStore.create();
    _storeSubscription = AppLocalStore.changes.listen((_) {
      if (mounted) {
        setState(() {
          _storeFuture = AppLocalStore.create();
          _lastStatusBarSyncKey = null;
        });
      }
    });
    ReminderNotificationIntent.instance.addListener(_onNotificationIntent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ReminderNotificationIntent.instance.hasPending) {
        _consumeNotificationIntent();
      }
    });
  }

  @override
  void dispose() {
    _storeSubscription?.cancel();
    ReminderNotificationIntent.instance.removeListener(_onNotificationIntent);
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppLocalStore>(
      future: _storeFuture,
      builder: (context, snapshot) {
        final store = snapshot.data;
        final actualReminders = [
          ...(store?.getReminders() ?? const <AppReminder>[]),
        ]..sort(_sortReminders);
        final now = DateTime.now();
        final reminders = actualReminders;
        if (store != null) {
          _syncStatusBarReminders(actualReminders);
        }

        final selected = _selectedReminder(reminders);
        if (_panel == _ReminderPanel.form) {
          return _ReminderFormScreen(
            editing: _editingReminder != null,
            controller: _titleController,
            noteController: _noteController,
            selectedDate: _selectedDate,
            selectedTime: _selectedTime,
            repeatRule: _repeatRule,
            notifyBeforeMinutes: _notifyBeforeMinutes,
            pinned: _pinned,
            priority: _priority,
            onBack: _backToList,
            onSave: store == null ? null : _saveReminder,
            onPickDate: _pickDate,
            onPickTime: _pickTime,
            onRepeatChanged: (value) => setState(() => _repeatRule = value),
            onNotifyBeforeChanged: (value) {
              setState(() => _notifyBeforeMinutes = value);
            },
            onPinnedChanged: (value) => setState(() => _pinned = value),
            onPriorityChanged: (value) => setState(() => _priority = value),
          );
        }

        if (_panel == _ReminderPanel.detail && selected != null) {
          return _ReminderDetailScreen(
            reminder: selected,
            completed: _isReminderDone(selected, now),
            onBack: _backToList,
            onEdit: () => _startEditing(selected),
            onComplete: store == null ? null : () => _toggleComplete(selected),
            onPostpone: store == null
                ? null
                : () => _postponeReminder(selected, 15),
          );
        }

        return _ReminderListScreen(
          reminders: reminders,
          tab: _tab,
          searchQuery: _searchQuery,
          onBack: _goBack,
          onSearch: _openSearchDialog,
          onClearSearch: () => setState(() => _searchQuery = ''),
          onTabChanged: (tab) => setState(() => _tab = tab),
          onAdd: _startAdding,
          onOpen: _openDetail,
          onToggleComplete: store == null ? null : _toggleComplete,
          onDelete: store == null ? null : _deleteReminder,
        );
      },
    );
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.treasureBox);
  }

  void _backToList() {
    setState(() {
      _panel = _ReminderPanel.list;
      _editingReminder = null;
    });
  }

  void _startAdding() {
    final now = DateTime.now();
    setState(() {
      _panel = _ReminderPanel.form;
      _editingReminder = null;
      _selectedReminderId = null;
      _titleController.text = '';
      _noteController.text = '';
      _selectedDate = now;
      _selectedTime = const TimeOfDay(hour: 8, minute: 0);
      _repeatRule = 'daily';
      _notifyBeforeMinutes = 10;
      _pinned = true;
      _priority = _priorityMedium;
      _icon = 'water';
    });
  }

  void _startEditing(AppReminder reminder) {
    setState(() {
      _panel = _ReminderPanel.form;
      _editingReminder = reminder;
      _selectedReminderId = reminder.id;
      _titleController.text = reminder.title;
      _noteController.text = '';
      _selectedDate = reminder.scheduledAt;
      _selectedTime = TimeOfDay.fromDateTime(reminder.scheduledAt);
      _repeatRule = reminder.repeatRule;
      _notifyBeforeMinutes = reminder.notifyBeforeMinutes;
      _pinned = reminder.pinned;
      _priority = _normalizePriority(reminder.priority);
      _icon = reminder.icon;
    });
  }

  void _openDetail(AppReminder reminder) {
    setState(() {
      _panel = _ReminderPanel.detail;
      _selectedReminderId = reminder.id;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: _reminderPurple,
              secondary: AppColors.accent,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: _reminderPurple,
              secondary: AppColors.accent,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _selectedTime = picked);
  }

  Future<void> _saveReminder() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showSnack('请先填写提醒内容', AppToastType.warning);
      return;
    }

    final now = DateTime.now();
    final store = await _storeFuture;
    final editingReminder = _editingReminder;
    final scheduledAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    final reminder = AppReminder(
      id: editingReminder?.id ?? 'reminder_${now.microsecondsSinceEpoch}',
      title: title,
      scheduledAt: scheduledAt,
      repeatRule: _repeatRule,
      notifyBeforeMinutes: _notifyBeforeMinutes,
      pinned: _pinned,
      priority: _priority,
      icon: _icon,
      completed: editingReminder?.completed ?? false,
      doneDateKey: editingReminder?.doneDateKey,
    );
    await store.upsertReminder(reminder);
    if (_isReminderDone(reminder, now)) {
      await LocalNotificationService.instance.cancelReminder(reminder.id);
    } else {
      await LocalNotificationService.instance.scheduleReminder(reminder);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _panel = _ReminderPanel.list;
      _editingReminder = null;
      _selectedReminderId = reminder.id;
      _titleController.clear();
      _noteController.clear();
      _storeFuture = AppLocalStore.create();
      _lastStatusBarSyncKey = null;
    });
    _showSnack('提醒已保存', AppToastType.success);
  }

  Future<void> _toggleComplete(AppReminder reminder) async {
    final store = await _storeFuture;
    final now = DateTime.now();
    final done = _isReminderDone(reminder, now);
    final updated = done
        ? reminder.copyWith(completed: false, doneDateKey: '')
        : reminder.copyWith(doneDateKey: AppReminder.dateKey(now));
    await store.upsertReminder(updated);
    if (_isReminderDone(updated, now)) {
      await LocalNotificationService.instance.cancelReminder(updated.id);
    } else {
      await LocalNotificationService.instance.scheduleReminder(updated);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _panel = _ReminderPanel.list;
      _storeFuture = AppLocalStore.create();
      _lastStatusBarSyncKey = null;
    });
    _showSnack(done ? '已恢复为进行中' : '提醒已完成', AppToastType.success);
  }

  Future<void> _postponeReminder(AppReminder reminder, int minutes) async {
    final store = await _storeFuture;
    final updated = reminder.copyWith(
      scheduledAt: DateTime.now().add(Duration(minutes: minutes)),
      completed: false,
      doneDateKey: '',
    );
    await store.upsertReminder(updated);
    await LocalNotificationService.instance.scheduleReminder(updated);
    if (!mounted) {
      return;
    }
    setState(() {
      _panel = _ReminderPanel.list;
      _storeFuture = AppLocalStore.create();
      _lastStatusBarSyncKey = null;
    });
    _showSnack('已延迟 $minutes 分钟', AppToastType.success);
  }

  Future<void> _deleteReminder(AppReminder reminder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteReminderDialog(reminder: reminder),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final store = await _storeFuture;
    await store.deleteReminder(reminder.id);
    await LocalNotificationService.instance.cancelReminder(reminder.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _panel = _ReminderPanel.list;
      _editingReminder = null;
      _selectedReminderId = null;
      _storeFuture = AppLocalStore.create();
      _lastStatusBarSyncKey = null;
    });
    _showSnack('提醒已删除', AppToastType.success);
  }

  void _onNotificationIntent() {
    if (!mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _consumeNotificationIntent();
      }
    });
  }

  Future<void> _consumeNotificationIntent() async {
    if (_handlingNotificationIntent) {
      return;
    }
    final request = ReminderNotificationIntent.instance.take();
    if (request == null) {
      return;
    }
    _handlingNotificationIntent = true;
    try {
      final store = await AppLocalStore.create();
      final reminders = store.getReminders();
      final now = DateTime.now();
      if (request.confirmFirstDueReminder) {
        final due = _dueReminders(reminders, now);
        if (due.isEmpty) {
          await LocalNotificationService.instance.showOverdueReminders(
            reminders,
          );
          if (mounted) {
            _showSnack('当前没有待确认提醒', AppToastType.warning);
          }
          return;
        }
        if (due.length > 1) {
          await _confirmDueReminderGroup(due);
        } else {
          await _confirmReminderFromNotification(due.first);
        }
        return;
      }

      final reminderId = request.reminderId;
      AppReminder? reminder;
      for (final item in reminders) {
        if (item.id == reminderId) {
          reminder = item;
          break;
        }
      }
      if (reminder == null || _isReminderDone(reminder, now)) {
        if (reminderId != null) {
          await LocalNotificationService.instance.cancelReminder(reminderId);
        }
        await LocalNotificationService.instance.showOverdueReminders(reminders);
        _refreshStore();
        return;
      }
      await _confirmReminderFromNotification(reminder);
    } finally {
      _handlingNotificationIntent = false;
      if (ReminderNotificationIntent.instance.hasPending) {
        unawaited(_consumeNotificationIntent());
      }
    }
  }

  Future<void> _confirmReminderFromNotification(AppReminder reminder) async {
    if (!mounted) {
      return;
    }
    final action = await showDialog<_OverdueAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ReminderOverdueDialog(reminder: reminder),
    );
    if (action == null) {
      return;
    }
    if (action == _OverdueAction.complete) {
      await LocalNotificationService.instance.confirmReminder(reminder.id);
      _refreshStore();
      _showSnack('提醒已确认完成', AppToastType.success);
      return;
    }
    if (action == _OverdueAction.postpone) {
      await _postponeReminder(reminder, 15);
      return;
    }
    await LocalNotificationService.instance.cancelReminder(reminder.id);
    _refreshStore();
  }

  Future<void> _confirmDueReminderGroup(List<AppReminder> reminders) async {
    if (!mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DueRemindersDialog(reminders: reminders),
    );
    if (confirmed != true) {
      return;
    }
    await LocalNotificationService.instance.confirmAllDueReminders();
    _refreshStore();
    _showSnack('待确认提醒已完成', AppToastType.success);
  }

  List<AppReminder> _dueReminders(List<AppReminder> reminders, DateTime now) {
    return reminders
        .where(
          (reminder) =>
              !reminder.completed &&
              reminder.pinned &&
              !reminder.scheduledAt.isAfter(now) &&
              !reminder.isDoneForDate(now),
        )
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  void _syncStatusBarReminders(List<AppReminder> reminders) {
    final now = DateTime.now();
    final pinnedActive = reminders
        .where((reminder) => reminder.pinned && !_isReminderDone(reminder, now))
        .toList();
    final syncKey = pinnedActive
        .map(
          (reminder) =>
              '${reminder.id}:${reminder.scheduledAt.millisecondsSinceEpoch}:${reminder.doneDateKey}',
        )
        .join(',');
    if (_lastStatusBarSyncKey == syncKey) {
      return;
    }
    _lastStatusBarSyncKey = syncKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      LocalNotificationService.instance.syncPinnedReminders(reminders);
    });
  }

  void _refreshStore() {
    if (!mounted) {
      return;
    }
    setState(() {
      _storeFuture = AppLocalStore.create();
      _lastStatusBarSyncKey = null;
    });
  }

  AppReminder? _selectedReminder(List<AppReminder> reminders) {
    final selectedId = _selectedReminderId;
    if (selectedId == null) {
      return null;
    }
    for (final reminder in reminders) {
      if (reminder.id == selectedId) {
        return reminder;
      }
    }
    return reminders.isEmpty ? null : reminders.first;
  }

  Future<void> _openSearchDialog() async {
    final controller = TextEditingController(text: _searchQuery);
    final query = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('搜索提醒'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入提醒名称',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text('清除'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (query == null || !mounted) {
      return;
    }
    setState(() => _searchQuery = query);
  }

  int _sortReminders(AppReminder a, AppReminder b) {
    final now = DateTime.now();
    final aDone = _isReminderDone(a, now);
    final bDone = _isReminderDone(b, now);
    if (aDone != bDone) {
      return aDone ? 1 : -1;
    }
    return a.scheduledAt.compareTo(b.scheduledAt);
  }

  bool _isReminderDone(AppReminder reminder, DateTime date) {
    return reminder.completed || reminder.isDoneForDate(date);
  }

  void _showSnack(String message, [AppToastType type = AppToastType.info]) {
    if (!mounted) {
      return;
    }
    AppToast.show(context, message, type: type);
  }
}

class _ReminderListScreen extends StatelessWidget {
  const _ReminderListScreen({
    required this.reminders,
    required this.tab,
    required this.searchQuery,
    required this.onBack,
    required this.onSearch,
    required this.onClearSearch,
    required this.onTabChanged,
    required this.onAdd,
    required this.onOpen,
    required this.onToggleComplete,
    required this.onDelete,
  });

  final List<AppReminder> reminders;
  final _ReminderTab tab;
  final String searchQuery;
  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback onClearSearch;
  final ValueChanged<_ReminderTab> onTabChanged;
  final VoidCallback onAdd;
  final ValueChanged<AppReminder> onOpen;
  final ValueChanged<AppReminder>? onToggleComplete;
  final ValueChanged<AppReminder>? onDelete;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final active = reminders.where((item) => !_isDone(item, now)).toList();
    final completed = reminders.where((item) => _isDone(item, now)).toList();
    final visible = switch (tab) {
      _ReminderTab.all => reminders,
      _ReminderTab.active => active,
      _ReminderTab.completed => completed,
    };
    final query = searchQuery.trim();
    bool matchesQuery(AppReminder item) {
      return query.isEmpty ||
          item.title.contains(query) ||
          _priorityText(item.priority).contains(query);
    }

    final filteredVisible = visible.where(matchesQuery).toList();
    final filteredActive = active.where(matchesQuery).toList();
    final filteredCompleted = completed.where(matchesQuery).toList();

    return Scaffold(
      backgroundColor: _reminderBg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0x20FFFFFF), Color(0x14FFF7FC), Color(0x18FFFFFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0, .48, 1],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                      child: Column(
                        children: [
                          _ReminderTopBar(
                            onBack: onBack,
                            onSearch: onSearch,
                            onAdd: onAdd,
                          ),
                          const SizedBox(height: 8),
                          _ReminderTabs(selected: tab, onChanged: onTabChanged),
                          const SizedBox(height: 16),
                          if (query.isNotEmpty) ...[
                            _ReminderSearchNotice(
                              query: query,
                              onClear: onClearSearch,
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (tab == _ReminderTab.all)
                            _AllReminderGroups(
                              activeReminders: filteredActive,
                              completedReminders: filteredCompleted,
                              onAdd: onAdd,
                              onOpen: onOpen,
                              onToggleComplete: onToggleComplete,
                              onDelete: onDelete,
                            )
                          else if (tab == _ReminderTab.completed)
                            _CompletedReminderGroups(
                              reminders: filteredVisible,
                              onAdd: onAdd,
                              onOpen: onOpen,
                              onToggleComplete: onToggleComplete,
                              onDelete: onDelete,
                            )
                          else
                            _ReminderListCard(
                              reminders: filteredVisible,
                              onAdd: onAdd,
                              onOpen: onOpen,
                              onToggleComplete: onToggleComplete,
                              onDelete: onDelete,
                            ),
                          const SizedBox(height: 18),
                          _ReminderMascotTipV2(
                            completedMode:
                                tab == _ReminderTab.completed ||
                                (tab == _ReminderTab.all &&
                                    filteredActive.isEmpty &&
                                    filteredCompleted.isNotEmpty),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReminderTopBar extends StatelessWidget {
  const _ReminderTopBar({
    required this.onBack,
    required this.onSearch,
    required this.onAdd,
  });

  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          _RoundIconButton(
            icon: Icons.brightness_5_rounded,
            color: _reminderPurple,
            onTap: onBack,
          ),
          const Expanded(
            child: Text(
              '提醒',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _reminderDeep,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          _RoundIconButton(
            icon: Icons.search_rounded,
            color: _reminderMuted,
            onTap: onSearch,
          ),
          const SizedBox(width: 2),
          _ReminderCreateButton(onTap: onAdd),
        ],
      ),
    );
  }
}

class _ReminderCreateButton extends StatelessWidget {
  const _ReminderCreateButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _reminderPurple,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _reminderPurple.withValues(alpha: .24),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.alarm_add_rounded, color: Colors.white, size: 17),
            SizedBox(width: 4),
            Text(
              '新建',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderSearchNotice extends StatelessWidget {
  const _ReminderSearchNotice({required this.query, required this.onClear});

  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _reminderLine),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: _reminderPurple, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '搜索：$query',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _reminderDeep,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          TextButton(onPressed: onClear, child: const Text('清除')),
        ],
      ),
    );
  }
}

class _ReminderTabs extends StatelessWidget {
  const _ReminderTabs({required this.selected, required this.onChanged});

  final _ReminderTab selected;
  final ValueChanged<_ReminderTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _reminderLine),
      ),
      child: Row(
        children: [
          _TabButton(
            label: '全部',
            selected: selected == _ReminderTab.all,
            onTap: () => onChanged(_ReminderTab.all),
          ),
          _TabButton(
            label: '进行中',
            selected: selected == _ReminderTab.active,
            onTap: () => onChanged(_ReminderTab.active),
          ),
          _TabButton(
            label: '已完成',
            selected: selected == _ReminderTab.completed,
            onTap: () => onChanged(_ReminderTab.completed),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEADBFF) : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? _reminderPurple : _reminderMuted,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReminderListCard extends StatelessWidget {
  const _ReminderListCard({
    required this.reminders,
    required this.onAdd,
    required this.onOpen,
    required this.onToggleComplete,
    required this.onDelete,
  });

  final List<AppReminder> reminders;
  final VoidCallback onAdd;
  final ValueChanged<AppReminder> onOpen;
  final ValueChanged<AppReminder>? onToggleComplete;
  final ValueChanged<AppReminder>? onDelete;

  @override
  Widget build(BuildContext context) {
    if (reminders.isEmpty) {
      return _EmptyReminderCard(onAdd: onAdd);
    }
    return Column(
      children: [
        for (var index = 0; index < reminders.length; index++) ...[
          _ReminderTile(
            reminder: reminders[index],
            highlighted: index == 0,
            completed: false,
            onOpen: () => onOpen(reminders[index]),
            onToggleComplete: onToggleComplete == null
                ? null
                : () => onToggleComplete!(reminders[index]),
            onDelete: onDelete == null
                ? null
                : () => onDelete!(reminders[index]),
          ),
          if (index != reminders.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _AllReminderGroups extends StatelessWidget {
  const _AllReminderGroups({
    required this.activeReminders,
    required this.completedReminders,
    required this.onAdd,
    required this.onOpen,
    required this.onToggleComplete,
    required this.onDelete,
  });

  final List<AppReminder> activeReminders;
  final List<AppReminder> completedReminders;
  final VoidCallback onAdd;
  final ValueChanged<AppReminder> onOpen;
  final ValueChanged<AppReminder>? onToggleComplete;
  final ValueChanged<AppReminder>? onDelete;

  @override
  Widget build(BuildContext context) {
    if (activeReminders.isEmpty && completedReminders.isEmpty) {
      return _EmptyReminderCard(onAdd: onAdd);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (activeReminders.isNotEmpty)
          _ReminderStatusGroup(
            label: '进行中',
            reminders: activeReminders,
            completed: false,
            onOpen: onOpen,
            onToggleComplete: onToggleComplete,
            onDelete: onDelete,
          ),
        if (completedReminders.isNotEmpty)
          _ReminderStatusGroup(
            label: '已完成',
            reminders: completedReminders,
            completed: true,
            onOpen: onOpen,
            onToggleComplete: onToggleComplete,
            onDelete: onDelete,
          ),
      ],
    );
  }
}

class _ReminderStatusGroup extends StatelessWidget {
  const _ReminderStatusGroup({
    required this.label,
    required this.reminders,
    required this.completed,
    required this.onOpen,
    required this.onToggleComplete,
    required this.onDelete,
  });

  final String label;
  final List<AppReminder> reminders;
  final bool completed;
  final ValueChanged<AppReminder> onOpen;
  final ValueChanged<AppReminder>? onToggleComplete;
  final ValueChanged<AppReminder>? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 0, 8),
            child: Text(
              label,
              style: const TextStyle(
                color: _reminderPurple,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          for (var index = 0; index < reminders.length; index++) ...[
            _ReminderTile(
              reminder: reminders[index],
              highlighted: !completed && index == 0,
              completed: completed,
              onOpen: () => onOpen(reminders[index]),
              onToggleComplete: onToggleComplete == null
                  ? null
                  : () => onToggleComplete!(reminders[index]),
              onDelete: onDelete == null
                  ? null
                  : () => onDelete!(reminders[index]),
            ),
            if (index != reminders.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _CompletedReminderGroups extends StatelessWidget {
  const _CompletedReminderGroups({
    required this.reminders,
    required this.onAdd,
    required this.onOpen,
    required this.onToggleComplete,
    required this.onDelete,
  });

  final List<AppReminder> reminders;
  final VoidCallback onAdd;
  final ValueChanged<AppReminder> onOpen;
  final ValueChanged<AppReminder>? onToggleComplete;
  final ValueChanged<AppReminder>? onDelete;

  @override
  Widget build(BuildContext context) {
    if (reminders.isEmpty) {
      return _EmptyReminderCard(title: '今天还没有完成项', onAdd: onAdd);
    }
    final today = <AppReminder>[];
    final yesterday = <AppReminder>[];
    final earlier = <AppReminder>[];
    final now = DateTime.now();
    for (final reminder in reminders) {
      final date = reminder.scheduledAt;
      if (_sameDay(date, now)) {
        today.add(reminder);
      } else if (_sameDay(date, now.subtract(const Duration(days: 1)))) {
        yesterday.add(reminder);
      } else {
        earlier.add(reminder);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (today.isNotEmpty)
          _CompletedGroup(
            label: '今天',
            reminders: today,
            onOpen: onOpen,
            onToggleComplete: onToggleComplete,
            onDelete: onDelete,
          ),
        if (yesterday.isNotEmpty)
          _CompletedGroup(
            label: '昨天',
            reminders: yesterday,
            onOpen: onOpen,
            onToggleComplete: onToggleComplete,
            onDelete: onDelete,
          ),
        if (earlier.isNotEmpty)
          _CompletedGroup(
            label: '更早',
            reminders: earlier,
            onOpen: onOpen,
            onToggleComplete: onToggleComplete,
            onDelete: onDelete,
          ),
      ],
    );
  }
}

class _CompletedGroup extends StatelessWidget {
  const _CompletedGroup({
    required this.label,
    required this.reminders,
    required this.onOpen,
    required this.onToggleComplete,
    required this.onDelete,
  });

  final String label;
  final List<AppReminder> reminders;
  final ValueChanged<AppReminder> onOpen;
  final ValueChanged<AppReminder>? onToggleComplete;
  final ValueChanged<AppReminder>? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 0, 8),
            child: Text(
              label,
              style: const TextStyle(
                color: _reminderPurple,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          for (var index = 0; index < reminders.length; index++) ...[
            _ReminderTile(
              reminder: reminders[index],
              highlighted: false,
              completed: true,
              onOpen: () => onOpen(reminders[index]),
              onToggleComplete: onToggleComplete == null
                  ? null
                  : () => onToggleComplete!(reminders[index]),
              onDelete: onDelete == null
                  ? null
                  : () => onDelete!(reminders[index]),
            ),
            if (index != reminders.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({
    required this.reminder,
    required this.highlighted,
    required this.completed,
    required this.onOpen,
    required this.onToggleComplete,
    required this.onDelete,
  });

  final AppReminder reminder;
  final bool highlighted;
  final bool completed;
  final VoidCallback onOpen;
  final VoidCallback? onToggleComplete;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final priorityColor = completed
        ? AppColors.success
        : _priorityColor(reminder.priority);
    return InkWell(
      onTap: onOpen,
      onLongPress: onDelete,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          color: highlighted ? const Color(0xFFFFFAF0) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: highlighted ? const Color(0xFFFFE8C7) : _reminderLine,
          ),
          boxShadow: const [
            BoxShadow(
              color: _reminderShadow,
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggleComplete,
              child: _ReminderIcon(
                icon: completed ? Icons.check_rounded : _iconFor(reminder.icon),
                color: priorityColor,
                completed: completed,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminder.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: completed
                          ? const Color(0xFF6E6880)
                          : _reminderDeep,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatRelativeSchedule(reminder.scheduledAt),
                    style: const TextStyle(
                      color: _reminderMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onOpen,
              icon: Icon(
                completed
                    ? Icons.notifications_none_rounded
                    : Icons.notifications_active_outlined,
                size: 20,
                color: completed ? const Color(0xFFC6C0D2) : priorityColor,
              ),
            ),
            IconButton(
              tooltip: '删除提醒',
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: Color(0xFFC6C0D2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderIcon extends StatelessWidget {
  const _ReminderIcon({
    required this.icon,
    required this.color,
    required this.completed,
  });

  final IconData icon;
  final Color color;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: completed ? .2 : .14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

class _ReminderMascotTipV2 extends StatelessWidget {
  const _ReminderMascotTipV2({required this.completedMode});

  final bool completedMode;

  @override
  Widget build(BuildContext context) {
    final title = completedMode ? '太棒啦！' : '今天也要加油';
    final message = completedMode ? '继续保持鸭~' : '慢慢来，一件件完成就很好';
    final icon = completedMode
        ? Icons.check_circle_outline_rounded
        : Icons.alarm_on_rounded;
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageWidth = math.min(174.0, constraints.maxWidth * .38);
        return Container(
          width: double.infinity,
          height: 132,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: _reminderPurple.withValues(alpha: .14),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .26),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .72),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -26,
                      top: -34,
                      child: _ReminderTipGlow(
                        size: 116,
                        color: AppColors.softPink.withValues(alpha: .72),
                      ),
                    ),
                    Positioned(
                      left: 112,
                      bottom: -38,
                      child: _ReminderTipGlow(
                        size: 138,
                        color: AppColors.softBlue.withValues(alpha: .62),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: imageWidth,
                            child: AppMascotScene(
                              height: 108,
                              variant: completedMode
                                  ? MascotSceneVariant.snack
                                  : MascotSceneVariant.reminder,
                              showHeart: false,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Container(
                              height: double.infinity,
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                12,
                                14,
                                12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .66),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: .82),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: _reminderPurple.withValues(
                                        alpha: .13,
                                      ),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Icon(
                                      icon,
                                      color: _reminderPurple,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: _reminderDeep,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          message,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: _reminderMuted,
                                            fontSize: 12,
                                            height: 1.25,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ReminderTipGlow extends StatelessWidget {
  const _ReminderTipGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

class ReminderMascotTipLegacy extends StatelessWidget {
  const ReminderMascotTipLegacy({required this.completedMode, super.key});

  final bool completedMode;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 118,
      child: Stack(
        children: [
          Positioned(
            left: 8,
            bottom: 0,
            width: 132,
            child: AppMascotScene(
              height: 118,
              variant: completedMode
                  ? MascotSceneVariant.snack
                  : MascotSceneVariant.reminder,
              showHeart: false,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            left: 138,
            top: 26,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF6EEFF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                completedMode ? '太棒啦！继续保持鸭~' : '今天也要加油鸭~',
                style: const TextStyle(
                  color: _reminderMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyReminderCard extends StatelessWidget {
  const _EmptyReminderCard({required this.onAdd, this.title = '还没有提醒'});

  final String title;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 34, 22, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _reminderLine),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.alarm_add_outlined,
            color: _reminderPurple,
            size: 38,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: _reminderDeep,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '点上方新建提醒，安排下一件小事。',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _reminderMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onAdd,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _reminderPurple,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.alarm_add_rounded, color: Colors.white, size: 17),
                  SizedBox(width: 5),
                  Text(
                    '新建提醒',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderFormScreen extends StatelessWidget {
  const _ReminderFormScreen({
    required this.editing,
    required this.controller,
    required this.noteController,
    required this.selectedDate,
    required this.selectedTime,
    required this.repeatRule,
    required this.notifyBeforeMinutes,
    required this.pinned,
    required this.priority,
    required this.onBack,
    required this.onSave,
    required this.onPickDate,
    required this.onPickTime,
    required this.onRepeatChanged,
    required this.onNotifyBeforeChanged,
    required this.onPinnedChanged,
    required this.onPriorityChanged,
  });

  final bool editing;
  final TextEditingController controller;
  final TextEditingController noteController;
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final String repeatRule;
  final int notifyBeforeMinutes;
  final bool pinned;
  final String priority;
  final VoidCallback onBack;
  final Future<void> Function()? onSave;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final ValueChanged<String> onRepeatChanged;
  final ValueChanged<int> onNotifyBeforeChanged;
  final ValueChanged<bool> onPinnedChanged;
  final ValueChanged<String> onPriorityChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _reminderBg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0x20FFFFFF), Color(0x14FFF7FC), Color(0x18FFFFFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0, .48, 1],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _EditTopBar(
                title: editing ? '编辑提醒' : '新建提醒',
                onBack: onBack,
                onSave: onSave,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: Column(
                        children: [
                          _TitleInputCard(controller: controller),
                          const SizedBox(height: 16),
                          _FormSection(
                            children: [
                              _FormRow(
                                icon: Icons.calendar_month_outlined,
                                label: _formatDateCn(selectedDate),
                                onTap: onPickDate,
                              ),
                              _FormRow(
                                icon: Icons.access_time_rounded,
                                label: _formatTime(selectedTime),
                                onTap: onPickTime,
                                last: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _PrioritySection(
                            selected: priority,
                            onChanged: onPriorityChanged,
                          ),
                          const SizedBox(height: 16),
                          _FormSection(
                            children: [
                              _ChoiceRow(
                                icon: Icons.autorenew_rounded,
                                title: '重复规则',
                                value: _repeatLabel(repeatRule),
                                onTap: () => _showRepeatSheet(
                                  context,
                                  repeatRule,
                                  onRepeatChanged,
                                ),
                              ),
                              _ChoiceRow(
                                icon: Icons.notifications_none_rounded,
                                title: '提前通知',
                                value: notifyBeforeMinutes == 0
                                    ? '准时提醒'
                                    : '$notifyBeforeMinutes 分钟前',
                                onTap: () => _showNotifySheet(
                                  context,
                                  notifyBeforeMinutes,
                                  onNotifyBeforeChanged,
                                ),
                              ),
                              _SwitchRow(
                                icon: Icons.alarm_on_outlined,
                                title: '状态栏提醒',
                                value: pinned,
                                onChanged: onPinnedChanged,
                                last: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _NoteCard(controller: noteController),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditTopBar extends StatelessWidget {
  const _EditTopBar({
    required this.title,
    required this.onBack,
    required this.onSave,
  });

  final String title;
  final VoidCallback onBack;
  final Future<void> Function()? onSave;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            _RoundIconButton(
              icon: Icons.chevron_left_rounded,
              color: _reminderDeep,
              onTap: onBack,
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _reminderDeep,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton(
              onPressed: onSave,
              child: const Text(
                '保存',
                style: TextStyle(
                  color: _reminderPurple,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleInputCard extends StatelessWidget {
  const _TitleInputCard({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: _cardDecoration(radius: 18),
      child: Row(
        children: [
          _ReminderIcon(
            icon: Icons.local_drink_outlined,
            color: const Color(0xFF8CB4FF),
            completed: false,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: '喝水 8 杯',
                border: InputBorder.none,
                counterText: '',
              ),
              maxLength: 30,
              style: const TextStyle(
                color: _reminderDeep,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            onPressed: controller.clear,
            icon: const Icon(
              Icons.cancel_rounded,
              color: Color(0xFFC4BED0),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: _cardDecoration(radius: 18),
      child: Column(children: children),
    );
  }
}

class _FormRow extends StatelessWidget {
  const _FormRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: _reminderLine)),
        ),
        child: Row(
          children: [
            Icon(icon, color: _reminderMuted, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: _reminderMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _reminderMuted),
          ],
        ),
      ),
    );
  }
}

class _PrioritySection extends StatelessWidget {
  const _PrioritySection({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: _cardDecoration(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '优先级',
            style: TextStyle(
              color: _reminderDeep,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _PriorityPill(
                label: '低',
                icon: Icons.eco_outlined,
                color: AppColors.success,
                selected: selected == _priorityLow,
                onTap: () => onChanged(_priorityLow),
              ),
              const SizedBox(width: 10),
              _PriorityPill(
                label: '中',
                icon: Icons.star_border_rounded,
                color: AppColors.warning,
                selected: selected == _priorityMedium,
                onTap: () => onChanged(_priorityMedium),
              ),
              const SizedBox(width: 10),
              _PriorityPill(
                label: '高',
                icon: Icons.star_rounded,
                color: AppColors.danger,
                selected: selected == _priorityHigh,
                onTap: () => onChanged(_priorityHigh),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriorityPill extends StatelessWidget {
  const _PriorityPill({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: selected ? .18 : .08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: .45)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 17),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
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

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SettingRowShell(
      icon: icon,
      title: title,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: _reminderDeep,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: _reminderMuted),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return _SettingRowShell(
      icon: icon,
      title: title,
      last: last,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.white,
        activeTrackColor: _reminderPurple,
        inactiveThumbColor: Colors.white,
        inactiveTrackColor: const Color(0xFFE8E6EF),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }
}

class _SettingRowShell extends StatelessWidget {
  const _SettingRowShell({
    required this.icon,
    required this.title,
    required this.trailing,
    this.onTap,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final Widget trailing;
  final VoidCallback? onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: _reminderLine)),
        ),
        child: Row(
          children: [
            Icon(icon, color: _reminderPurple, size: 19),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: _reminderDeep,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: _cardDecoration(radius: 18),
      child: TextField(
        controller: controller,
        minLines: 3,
        maxLines: 4,
        decoration: const InputDecoration(
          labelText: '备注（可选）',
          hintText: '输入备注内容...',
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _ReminderDetailScreen extends StatelessWidget {
  const _ReminderDetailScreen({
    required this.reminder,
    required this.completed,
    required this.onBack,
    required this.onEdit,
    required this.onComplete,
    required this.onPostpone,
  });

  final AppReminder reminder;
  final bool completed;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback? onComplete;
  final VoidCallback? onPostpone;

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor(reminder.priority);
    return Scaffold(
      backgroundColor: _reminderBg,
      body: SafeArea(
        child: Column(
          children: [
            _DetailTopBar(onBack: onBack, onEdit: onEdit),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Column(
                      children: [
                        Container(
                          width: 114,
                          height: 114,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: .14),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Icon(
                            _iconFor(reminder.icon),
                            color: color,
                            size: 62,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          reminder.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _reminderDeep,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '该喝水啦！记得补充水分哦',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _reminderMuted,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 22),
                        _DetailInfoCard(reminder: reminder),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _BottomActionButton(
                        label: completed ? '已完成' : '已完成',
                        color: const Color(0xFFE4E2EA),
                        textColor: _reminderMuted,
                        onTap: onComplete,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _BottomActionButton(
                        label: '延迟 15 分钟',
                        color: _reminderPurple,
                        textColor: Colors.white,
                        onTap: onPostpone,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailTopBar extends StatelessWidget {
  const _DetailTopBar({required this.onBack, required this.onEdit});

  final VoidCallback onBack;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            _RoundIconButton(
              icon: Icons.chevron_left_rounded,
              color: _reminderDeep,
              onTap: onBack,
            ),
            const Expanded(
              child: Text(
                '提醒详情',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _reminderDeep,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton(
              onPressed: onEdit,
              child: const Text(
                '编辑',
                style: TextStyle(
                  color: _reminderPurple,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailInfoCard extends StatelessWidget {
  const _DetailInfoCard({required this.reminder});

  final AppReminder reminder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(radius: 20),
      child: Column(
        children: [
          _DetailLine(
            icon: Icons.calendar_month_outlined,
            label: _formatDateCn(reminder.scheduledAt),
          ),
          _DetailLine(
            icon: Icons.access_time_rounded,
            label: _formatClock(reminder.scheduledAt),
          ),
          _DetailLine(
            icon: Icons.star_rounded,
            label: _priorityText(reminder.priority),
            color: _priorityColor(reminder.priority),
          ),
          _DetailLine(
            icon: Icons.autorenew_rounded,
            label: _repeatLabel(reminder.repeatRule),
          ),
          _DetailLine(
            icon: Icons.notifications_none_rounded,
            label: reminder.notifyBeforeMinutes == 0
                ? '准时通知'
                : '${reminder.notifyBeforeMinutes} 分钟前',
          ),
          const _DetailLine(
            icon: Icons.notes_outlined,
            label: '保持每天喝水的好习惯！',
            last: true,
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.icon,
    required this.label,
    this.color = _reminderMuted,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 38),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: _reminderLine)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _reminderMuted,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomActionButton extends StatelessWidget {
  const _BottomActionButton({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          disabledBackgroundColor: color.withValues(alpha: .55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _ReminderOverdueDialog extends StatelessWidget {
  const _ReminderOverdueDialog({required this.reminder});

  final AppReminder reminder;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 74),
            padding: const EdgeInsets.fromLTRB(24, 64, 24, 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 30,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '提醒已逾期',
                  style: TextStyle(
                    color: _reminderDeep,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '“${reminder.title}” 已逾期\n要现在标记完成吗？',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _reminderMuted,
                    fontSize: 15,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                _DialogButton(
                  label: '标记为完成',
                  color: _reminderPurple,
                  textColor: Colors.white,
                  onTap: () =>
                      Navigator.of(context).pop(_OverdueAction.complete),
                ),
                const SizedBox(height: 12),
                _DialogButton(
                  label: '延迟 15 分钟',
                  color: AppColors.danger,
                  textColor: Colors.white,
                  onTap: () =>
                      Navigator.of(context).pop(_OverdueAction.postpone),
                ),
                const SizedBox(height: 12),
                _DialogButton(
                  label: '忽略此次',
                  color: Colors.white,
                  textColor: _reminderMuted,
                  border: _reminderLine,
                  onTap: () => Navigator.of(context).pop(_OverdueAction.ignore),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            width: 150,
            height: 130,
            child: AppMascotScene(
              height: 130,
              variant: MascotSceneVariant.reminder,
              showHeart: false,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}

class _DueRemindersDialog extends StatelessWidget {
  const _DueRemindersDialog({required this.reminders});

  final List<AppReminder> reminders;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.notifications_active_outlined,
              color: _reminderPurple,
              size: 42,
            ),
            const SizedBox(height: 14),
            const Text(
              '确认全部待确认提醒？',
              style: TextStyle(
                color: _reminderDeep,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            ...reminders
                .take(3)
                .map(
                  (reminder) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${_formatClock(reminder.scheduledAt)}  ${reminder.title}',
                      style: const TextStyle(
                        color: _reminderMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: _reminderPurple,
                    ),
                    child: const Text('完成'),
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

class _DeleteReminderDialog extends StatelessWidget {
  const _DeleteReminderDialog({required this.reminder});

  final AppReminder reminder;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 30),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.danger,
              size: 42,
            ),
            const SizedBox(height: 14),
            const Text(
              '删除这个提醒？',
              style: TextStyle(
                color: _reminderDeep,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              reminder.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _reminderMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                    ),
                    child: const Text('删除'),
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

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
    this.border,
  });

  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: border ?? Colors.transparent),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}

void _showRepeatSheet(
  BuildContext context,
  String selected,
  ValueChanged<String> onChanged,
) {
  _showChoiceSheet<String>(
    context: context,
    title: '重复规则',
    selected: selected,
    options: const [
      ('none', '不重复'),
      ('daily', '每天'),
      ('weekly', '每周'),
      ('monthly', '每月'),
    ],
    onChanged: onChanged,
  );
}

void _showNotifySheet(
  BuildContext context,
  int selected,
  ValueChanged<int> onChanged,
) {
  _showChoiceSheet<int>(
    context: context,
    title: '提前通知',
    selected: selected,
    options: const [
      (0, '准时提醒'),
      (10, '10 分钟前'),
      (15, '15 分钟前'),
      (30, '30 分钟前'),
    ],
    onChanged: onChanged,
  );
}

void _showChoiceSheet<T>({
  required BuildContext context,
  required String title,
  required T selected,
  required List<(T, String)> options,
  required ValueChanged<T> onChanged,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: _reminderLine,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  color: _reminderDeep,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              ...options.map((option) {
                final isSelected = option.$1 == selected;
                return ListTile(
                  onTap: () {
                    onChanged(option.$1);
                    Navigator.of(context).pop();
                  },
                  title: Text(option.$2),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: _reminderPurple)
                      : null,
                );
              }),
            ],
          ),
        ),
      );
    },
  );
}

BoxDecoration _cardDecoration({double radius = 20}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: _reminderLine),
    boxShadow: const [
      BoxShadow(color: _reminderShadow, blurRadius: 20, offset: Offset(0, 8)),
    ],
  );
}

bool _isDone(AppReminder reminder, DateTime now) {
  return reminder.completed || reminder.isDoneForDate(now);
}

bool _sameDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

String _normalizePriority(String value) {
  if (value == _priorityHigh || value.contains('高')) {
    return _priorityHigh;
  }
  if (value == _priorityLow || value.contains('低')) {
    return _priorityLow;
  }
  return _priorityMedium;
}

String _priorityText(String value) {
  return switch (_normalizePriority(value)) {
    _priorityHigh => '高',
    _priorityLow => '低',
    _ => '中',
  };
}

Color _priorityColor(String value) {
  return switch (_normalizePriority(value)) {
    _priorityHigh => AppColors.danger,
    _priorityLow => AppColors.success,
    _ => AppColors.warning,
  };
}

IconData _iconFor(String value) {
  return switch (value) {
    'water' => Icons.local_drink_outlined,
    'bear' => Icons.self_improvement_rounded,
    'book' => Icons.menu_book_outlined,
    'word' => Icons.spellcheck_rounded,
    'library' => Icons.account_balance_outlined,
    'phone' => Icons.favorite_border_rounded,
    'cake' => Icons.cake_outlined,
    _ => Icons.notifications_none_rounded,
  };
}

String _repeatLabel(String value) {
  return switch (value) {
    'daily' => '每天',
    'weekly' => '每周',
    'monthly' => '每月',
    _ => '不重复',
  };
}

String _formatRelativeSchedule(DateTime date) {
  final now = DateTime.now();
  final clock = _formatClock(date);
  if (_sameDay(date, now)) {
    return '今天 $clock';
  }
  if (_sameDay(date, now.add(const Duration(days: 1)))) {
    return '明天 $clock';
  }
  if (_sameDay(date, now.subtract(const Duration(days: 1)))) {
    return '昨天 $clock';
  }
  return '${date.month}月${date.day}日 $clock';
}

String _formatDateCn(DateTime date) {
  final weekday = const [
    '周一',
    '周二',
    '周三',
    '周四',
    '周五',
    '周六',
    '周日',
  ][date.weekday - 1];
  return '${date.year}年${date.month}月${date.day}日 $weekday';
}

String _formatClock(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatTime(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
