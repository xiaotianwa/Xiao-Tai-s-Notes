import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/app_data_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_mascot_scene.dart';

const _moneyGreen = Color(0xFF19B66B);
const _moneyRed = Color(0xFFFF4D67);
const _moneyOrange = Color(0xFFFF9A3D);

enum _MoneyView { list, form, picker, summary, filter }

class _MoneyCategoryMeta {
  const _MoneyCategoryMeta({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

const _moneyCategories = <String, _MoneyCategoryMeta>{
  '餐饮': _MoneyCategoryMeta(
    label: '餐饮',
    icon: Icons.restaurant_menu_rounded,
    color: AppColors.primary,
  ),
  '购物': _MoneyCategoryMeta(
    label: '购物',
    icon: Icons.shopping_bag_outlined,
    color: _moneyRed,
  ),
  '交通': _MoneyCategoryMeta(
    label: '交通',
    icon: Icons.directions_bus_filled_outlined,
    color: AppColors.info,
  ),
  '日用': _MoneyCategoryMeta(
    label: '日用',
    icon: Icons.checkroom_outlined,
    color: AppColors.textSecondary,
  ),
  '娱乐': _MoneyCategoryMeta(
    label: '娱乐',
    icon: Icons.sports_esports_outlined,
    color: AppColors.accent,
  ),
  '学习': _MoneyCategoryMeta(
    label: '学习',
    icon: Icons.menu_book_outlined,
    color: AppColors.primary,
  ),
  '医疗': _MoneyCategoryMeta(
    label: '医疗',
    icon: Icons.medical_services_outlined,
    color: _moneyRed,
  ),
  '住房': _MoneyCategoryMeta(
    label: '住房',
    icon: Icons.home_outlined,
    color: _moneyOrange,
  ),
  '工资': _MoneyCategoryMeta(
    label: '工资',
    icon: Icons.account_balance_wallet_outlined,
    color: _moneyGreen,
  ),
  '奖金': _MoneyCategoryMeta(
    label: '奖金',
    icon: Icons.emoji_events_outlined,
    color: AppColors.warning,
  ),
  '兼职': _MoneyCategoryMeta(
    label: '兼职',
    icon: Icons.work_outline_rounded,
    color: Colors.brown,
  ),
  '投资': _MoneyCategoryMeta(
    label: '投资',
    icon: Icons.trending_up_rounded,
    color: _moneyRed,
  ),
};

const _expenseCategoryKeys = ['餐饮', '购物', '交通', '日用', '娱乐', '学习', '医疗', '住房'];
const _incomeCategoryKeys = ['工资', '奖金', '兼职', '投资'];
const _allCategoryKeys = [
  '餐饮',
  '购物',
  '交通',
  '日用',
  '娱乐',
  '学习',
  '医疗',
  '住房',
  '工资',
  '奖金',
  '兼职',
  '投资',
];
const _paymentMethods = ['现金', '微信', '支付宝', '银行卡'];
const _quickNotes = ['午餐', '晚餐', '奶茶', '超市购物', '打车', '电影票'];

class MoneyPage extends StatefulWidget {
  const MoneyPage({super.key});

  @override
  State<MoneyPage> createState() => _MoneyPageState();
}

class _MoneyPageState extends State<MoneyPage> {
  late Future<AppLocalStore> _storeFuture;
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _minAmountController = TextEditingController();
  final _maxAmountController = TextEditingController();
  List<AppMoneyRecord>? _recordsOverride;
  AppMoneyRecord? _editingRecord;
  late DateTime _visibleMonth;
  late DateTime _happenedAt;
  _MoneyView _view = _MoneyView.list;
  String _type = 'expense';
  String _category = '餐饮';
  String _paymentMethod = '现金';
  String _filterTimeRange = 'month';
  String _filterType = 'all';
  String _filterPayment = 'all';
  String _filterCategory = 'all';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _happenedAt = now;
    _storeFuture = AppLocalStore.create();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppLocalStore>(
      future: _storeFuture,
      builder: (context, snapshot) {
        final rawRecords =
            _recordsOverride ??
            snapshot.data?.getMoneyRecords() ??
            const <AppMoneyRecord>[];
        final displayRecords = rawRecords;
        final month = _visibleMonth;
        final monthRecords = _recordsInMonth(displayRecords, month);
        final filteredRecords = _filterRecords(displayRecords, month);
        final summary = summarizeMoneyRecords(displayRecords, month: month);
        return _MoneyFrame(
          child: switch (_view) {
            _MoneyView.form => _MoneyFormScreen(
              editing: _editingRecord != null,
              type: _type,
              category: _category,
              paymentMethod: _paymentMethod,
              happenedAt: _happenedAt,
              amountController: _amountController,
              noteController: _noteController,
              onClose: _goList,
              onSave: _saveRecord,
              onDelete: _editingRecord == null
                  ? null
                  : () => _deleteRecord(_editingRecord!),
              onTypeChanged: _changeRecordType,
              onCategoryChanged: (value) => setState(() => _category = value),
              onPaymentChanged: (value) =>
                  setState(() => _paymentMethod = value),
              onOpenPicker: () => setState(() => _view = _MoneyView.picker),
            ),
            _MoneyView.picker => _MoneyPickerScreen(
              type: _type,
              category: _category,
              happenedAt: _happenedAt,
              noteController: _noteController,
              onClose: () => setState(() => _view = _MoneyView.form),
              onCategoryChanged: (value) => setState(() => _category = value),
              onDateChanged: (value) => setState(() => _happenedAt = value),
              onQuickNote: _applyQuickNote,
              onTimeTap: _showTimePicker,
            ),
            _MoneyView.summary => _MoneySummaryScreen(
              month: month,
              records: monthRecords,
              summary: summary,
              onBack: _goList,
              onMonthTap: _showMonthPicker,
            ),
            _MoneyView.filter => _MoneyFilterScreen(
              month: month,
              timeRange: _filterTimeRange,
              type: _filterType,
              paymentMethod: _filterPayment,
              category: _filterCategory,
              minAmountController: _minAmountController,
              maxAmountController: _maxAmountController,
              onBack: _goList,
              onReset: _resetFilter,
              onTimeRangeChanged: (value) =>
                  setState(() => _filterTimeRange = value),
              onTypeChanged: (value) => setState(() => _filterType = value),
              onPaymentChanged: (value) =>
                  setState(() => _filterPayment = value),
              onCategoryTap: _showCategoryFilter,
              onApply: _goList,
            ),
            _MoneyView.list => _MoneyListScreen(
              month: month,
              records: filteredRecords,
              summary: summary,
              loading: snapshot.connectionState == ConnectionState.waiting,
              onBack: _goBack,
              onAdd: _startAdding,
              onEdit: _startEditing,
              onSummary: () => setState(() => _view = _MoneyView.summary),
              onFilter: () => setState(() => _view = _MoneyView.filter),
              onMonthTap: _showMonthPicker,
            ),
          },
        );
      },
    );
  }

  List<AppMoneyRecord> _recordsInMonth(
    List<AppMoneyRecord> records,
    DateTime month,
  ) {
    return records
        .where(
          (record) =>
              record.happenedAt.year == month.year &&
              record.happenedAt.month == month.month,
        )
        .toList()
      ..sort((a, b) => b.happenedAt.compareTo(a.happenedAt));
  }

  List<AppMoneyRecord> _filterRecords(
    List<AppMoneyRecord> records,
    DateTime month,
  ) {
    final now = DateTime.now();
    Iterable<AppMoneyRecord> result = switch (_filterTimeRange) {
      'all' => records,
      'today' => records.where((record) => _sameDate(record.happenedAt, now)),
      'yesterday' => records.where(
        (record) =>
            _sameDate(record.happenedAt, now.subtract(const Duration(days: 1))),
      ),
      'last7' => records.where(
        (record) => !record.happenedAt.isBefore(
          DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(const Duration(days: 6)),
        ),
      ),
      'lastMonth' => _recordsInMonth(
        records,
        DateTime(month.year, month.month - 1),
      ),
      _ => _recordsInMonth(records, month),
    };
    if (_filterType != 'all') {
      result = result.where((record) => record.type == _filterType);
    }
    if (_filterPayment != 'all') {
      result = result.where((record) => record.paymentMethod == _filterPayment);
    }
    if (_filterCategory != 'all') {
      result = result.where((record) => record.category == _filterCategory);
    }
    final minCents = _parseAmountCents(_minAmountController.text);
    final maxCents = _parseAmountCents(_maxAmountController.text);
    if (minCents != null && minCents > 0) {
      result = result.where((record) => record.amountCents >= minCents);
    }
    if (maxCents != null && maxCents > 0) {
      result = result.where((record) => record.amountCents <= maxCents);
    }
    return result.toList()
      ..sort((a, b) => b.happenedAt.compareTo(a.happenedAt));
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    }
  }

  void _goList() {
    setState(() {
      _view = _MoneyView.list;
      _editingRecord = null;
    });
  }

  void _startAdding() {
    final now = DateTime.now();
    setState(() {
      _view = _MoneyView.form;
      _editingRecord = null;
      _type = 'expense';
      _category = '餐饮';
      _paymentMethod = '现金';
      _happenedAt = now;
      _amountController.clear();
      _noteController.clear();
    });
  }

  void _startEditing(AppMoneyRecord record) {
    setState(() {
      _view = _MoneyView.form;
      _editingRecord = record;
      _type = record.type;
      _category = _moneyCategories.containsKey(record.category)
          ? record.category
          : (record.isIncome ? '工资' : '餐饮');
      _paymentMethod = _paymentMethods.contains(record.paymentMethod)
          ? record.paymentMethod
          : '现金';
      _happenedAt = record.happenedAt;
      _amountController.text = _formatAmountInput(record.amountCents);
      _noteController.text = record.note.isEmpty ? record.title : record.note;
    });
  }

  void _changeRecordType(String value) {
    setState(() {
      _type = value;
      final available = value == 'income'
          ? _incomeCategoryKeys
          : _expenseCategoryKeys;
      if (!available.contains(_category)) {
        _category = available.first;
      }
    });
  }

  Future<void> _saveRecord() async {
    final amountCents = _parseAmountCents(_amountController.text);
    if (amountCents == null || amountCents <= 0) {
      _showTip('请填写正确的金额');
      return;
    }
    final store = await _storeFuture;
    final now = DateTime.now();
    final editing = _editingRecord;
    final note = _noteController.text.trim();
    final title = note.isEmpty ? _category : note;
    final record = AppMoneyRecord(
      id: editing == null ? 'money_${now.microsecondsSinceEpoch}' : editing.id,
      type: _type,
      title: title,
      amountCents: amountCents,
      category: _category,
      happenedAt: _happenedAt,
      createdAt: editing == null ? now : editing.createdAt,
      updatedAt: now,
      note: note,
      owner: 'shared',
      paymentMethod: _paymentMethod,
    );
    await store.upsertMoneyRecord(record);
    if (!mounted) {
      return;
    }
    setState(() {
      _recordsOverride = store.getMoneyRecords();
      _visibleMonth = DateTime(record.happenedAt.year, record.happenedAt.month);
      _storeFuture = Future.value(store);
      _view = _MoneyView.list;
      _editingRecord = null;
    });
    _showTip(editing == null ? '账目已添加' : '账目已保存');
  }

  Future<void> _deleteRecord(AppMoneyRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _MoneyDeleteDialog(record: record),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final store = await _storeFuture;
    await store.deleteMoneyRecord(record.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _recordsOverride = store.getMoneyRecords();
      _storeFuture = Future.value(store);
      _view = _MoneyView.list;
      _editingRecord = null;
    });
    _showTip('账目已删除');
  }

  void _applyQuickNote(String value) {
    setState(() => _noteController.text = value);
  }

  void _resetFilter() {
    setState(() {
      _filterTimeRange = 'month';
      _filterType = 'all';
      _filterPayment = 'all';
      _filterCategory = 'all';
      _minAmountController.clear();
      _maxAmountController.clear();
    });
  }

  Future<void> _showMonthPicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _visibleMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035, 12, 31),
      helpText: '选择月份',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _visibleMonth = DateTime(picked.year, picked.month));
  }

  Future<void> _showTimePicker() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_happenedAt),
      helpText: '选择时间',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _happenedAt = DateTime(
        _happenedAt.year,
        _happenedAt.month,
        _happenedAt.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  Future<void> _showCategoryFilter() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _MoneyCategoryFilterSheet(selected: _filterCategory),
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() => _filterCategory = selected);
  }

  void _showTip(String message) {
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

class _MoneyFrame extends StatelessWidget {
  const _MoneyFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x20FFFFFF), Color(0x10FFF7FC), Color(0x18F8F2FF)],
            stops: [0, .48, 1],
          ),
        ),
        child: SafeArea(bottom: false, child: child),
      ),
    );
  }
}

class _MoneyListScreen extends StatelessWidget {
  const _MoneyListScreen({
    required this.month,
    required this.records,
    required this.summary,
    required this.loading,
    required this.onBack,
    required this.onAdd,
    required this.onEdit,
    required this.onSummary,
    required this.onFilter,
    required this.onMonthTap,
  });

  final DateTime month;
  final List<AppMoneyRecord> records;
  final AppMoneySummary summary;
  final bool loading;
  final VoidCallback onBack;
  final VoidCallback onAdd;
  final ValueChanged<AppMoneyRecord> onEdit;
  final VoidCallback onSummary;
  final VoidCallback onFilter;
  final VoidCallback onMonthTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 112),
          children: [
            _MoneyListTopBar(
              month: month,
              onBack: onBack,
              onMenu: onFilter,
              onAdd: onAdd,
              onMonthTap: onMonthTap,
              onSummary: onSummary,
            ),
            const SizedBox(height: 16),
            _MoneyHeroCard(summary: summary),
            const SizedBox(height: 16),
            if (loading)
              const _MoneyLoadingCard()
            else if (records.isEmpty)
              _MoneyEmptyCard(onAdd: onAdd)
            else
              _MoneyRecordGroups(records: records, onEdit: onEdit),
          ],
        ),
      ],
    );
  }
}

class _MoneyListTopBar extends StatelessWidget {
  const _MoneyListTopBar({
    required this.month,
    required this.onBack,
    required this.onMenu,
    required this.onAdd,
    required this.onMonthTap,
    required this.onSummary,
  });

  final DateTime month;
  final VoidCallback onBack;
  final VoidCallback onMenu;
  final VoidCallback onAdd;
  final VoidCallback onMonthTap;
  final VoidCallback onSummary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: Row(
        children: [
          IconButton(
            tooltip: '返回',
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary,
            ),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onMonthTap,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${month.year}年${month.month}月',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Icon(Icons.expand_more_rounded, size: 18),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: onSummary,
            icon: const Icon(
              Icons.calendar_month_outlined,
              color: AppColors.textPrimary,
            ),
          ),
          IconButton(
            tooltip: '筛选',
            onPressed: onMenu,
            icon: const Icon(Icons.tune_rounded, color: AppColors.textPrimary),
          ),
          IconButton(
            tooltip: '新增记账',
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _MoneyHeroCard extends StatelessWidget {
  const _MoneyHeroCard({required this.summary});

  final AppMoneySummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      padding: const EdgeInsets.fromLTRB(18, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEDE6FF), Color(0xFFF8F5FF)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .12),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -2,
            top: -6,
            width: 70,
            child: Opacity(
              opacity: .88,
              child: AppMascotScene(
                height: 68,
                variant: MascotSceneVariant.reminder,
                showHeart: false,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _MoneyHeroMetric(
                  label: '收入(元)',
                  value: _formatMoneyPlain(summary.incomeCents),
                ),
              ),
              Expanded(
                child: _MoneyHeroMetric(
                  label: '支出(元)',
                  value: _formatMoneyPlain(summary.expenseCents),
                ),
              ),
              Expanded(
                child: _MoneyHeroMetric(
                  label: '结余(元)',
                  value: formatMoneySignedPlain(summary.balanceCents),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoneyHeroMetric extends StatelessWidget {
  const _MoneyHeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyRecordGroups extends StatelessWidget {
  const _MoneyRecordGroups({required this.records, required this.onEdit});

  final List<AppMoneyRecord> records;
  final ValueChanged<AppMoneyRecord> onEdit;

  @override
  Widget build(BuildContext context) {
    final grouped = <DateTime, List<AppMoneyRecord>>{};
    for (final record in records) {
      final key = _dateOnly(record.happenedAt);
      grouped.putIfAbsent(key, () => []).add(record);
    }
    final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return Column(
      children: days.map((day) {
        final dayRecords = grouped[day]!
          ..sort((a, b) => b.happenedAt.compareTo(a.happenedAt));
        final income = dayRecords
            .where((record) => record.isIncome)
            .fold(0, (total, record) => total + record.amountCents);
        final expense = dayRecords
            .where((record) => record.isExpense)
            .fold(0, (total, record) => total + record.amountCents);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MoneyDayHeader(day: day, income: income, expense: expense),
              const SizedBox(height: 4),
              ...dayRecords.map(
                (record) => _MoneyRecordRow(
                  record: record,
                  onTap: () => onEdit(record),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _MoneyDayHeader extends StatelessWidget {
  const _MoneyDayHeader({
    required this.day,
    required this.income,
    required this.expense,
  });

  final DateTime day;
  final int income;
  final int expense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF2EFF8))),
      ),
      child: Row(
        children: [
          Text(
            '${day.month}月${day.day}日  ${_weekdayName(day)}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          Text(
            '收入：+${_formatMoneyPlain(income)}',
            style: const TextStyle(
              color: _moneyGreen,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '支出：-${_formatMoneyPlain(expense)}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyRecordRow extends StatelessWidget {
  const _MoneyRecordRow({required this.record, required this.onTap});

  final AppMoneyRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = _categoryMeta(record.category);
    final color = record.isIncome ? _moneyGreen : _moneyRed;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 62),
        padding: const EdgeInsets.fromLTRB(4, 8, 0, 8),
        child: Row(
          children: [
            _MoneyCategoryIcon(meta: meta, size: 34),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    record.note.isEmpty ? record.category : record.note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  record.isIncome
                      ? '+${_formatMoneyPlain(record.amountCents)}'
                      : '-${_formatMoneyPlain(record.amountCents)}',
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatTime(record.happenedAt),
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
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

class _MoneyFormScreen extends StatelessWidget {
  const _MoneyFormScreen({
    required this.editing,
    required this.type,
    required this.category,
    required this.paymentMethod,
    required this.happenedAt,
    required this.amountController,
    required this.noteController,
    required this.onClose,
    required this.onSave,
    required this.onDelete,
    required this.onTypeChanged,
    required this.onCategoryChanged,
    required this.onPaymentChanged,
    required this.onOpenPicker,
  });

  final bool editing;
  final String type;
  final String category;
  final String paymentMethod;
  final DateTime happenedAt;
  final TextEditingController amountController;
  final TextEditingController noteController;
  final VoidCallback onClose;
  final Future<void> Function() onSave;
  final Future<void> Function()? onDelete;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onPaymentChanged;
  final VoidCallback onOpenPicker;

  @override
  Widget build(BuildContext context) {
    final categoryKeys = type == 'income'
        ? _incomeCategoryKeys
        : _expenseCategoryKeys;
    return Stack(
      children: [
        ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 178),
          children: [
            _MoneyFormTopBar(
              title: editing ? '编辑记账' : '新增记账',
              leadingIcon: editing
                  ? Icons.arrow_back_ios_new_rounded
                  : Icons.close_rounded,
              onClose: onClose,
              onSave: onSave,
              onDelete: onDelete,
            ),
            const SizedBox(height: 18),
            _MoneyTypeSegment(value: type, onChanged: onTypeChanged),
            const SizedBox(height: 24),
            _MoneyAmountField(controller: amountController),
            const SizedBox(height: 22),
            _MoneyCategoryGrid(
              keys: categoryKeys,
              selected: category,
              onChanged: onCategoryChanged,
            ),
            const SizedBox(height: 18),
            _MoneyInlineField(
              label: '备注：',
              value: noteController.text.isEmpty
                  ? '输入备注（可选）'
                  : noteController.text,
              onTap: onOpenPicker,
            ),
            const SizedBox(height: 12),
            _MoneyInlineField(
              label: '日期：',
              value:
                  '${_formatIsoDate(happenedAt)}    ${_formatTime(happenedAt)}',
              onTap: onOpenPicker,
              trailingIcon: Icons.chevron_right_rounded,
            ),
            const SizedBox(height: 18),
            const _MoneySectionLabel('支付方式：'),
            _MoneyPaymentChips(
              value: paymentMethod,
              onChanged: onPaymentChanged,
            ),
            const SizedBox(height: 34),
            _MoneyMascotFooter(type: type),
          ],
        ),
        Positioned(
          left: 22,
          right: 22,
          bottom: 92,
          child: Row(
            children: [
              _MoneyCircleAction(
                icon: Icons.close_rounded,
                color: AppColors.textTertiary,
                onTap: onClose,
              ),
              const Spacer(),
              if (onDelete != null) ...[
                _MoneyCircleAction(
                  icon: Icons.delete_outline_rounded,
                  color: AppColors.danger,
                  onTap: () => onDelete!(),
                ),
                const SizedBox(width: 18),
              ],
              _MoneyCircleAction(
                icon: Icons.check_rounded,
                color: AppColors.primary,
                onTap: onSave,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MoneyFormTopBar extends StatelessWidget {
  const _MoneyFormTopBar({
    required this.title,
    required this.leadingIcon,
    required this.onClose,
    required this.onSave,
    required this.onDelete,
  });

  final String title;
  final IconData leadingIcon;
  final VoidCallback onClose;
  final Future<void> Function() onSave;
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: Icon(leadingIcon, color: AppColors.textPrimary),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            onPressed: onSave,
            icon: const Icon(Icons.check_rounded, color: AppColors.primary),
          ),
          if (onDelete != null)
            IconButton(
              tooltip: '删除账目',
              onPressed: () => onDelete!(),
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.danger,
              ),
            ),
        ],
      ),
    );
  }
}

class _MoneyTypeSegment extends StatelessWidget {
  const _MoneyTypeSegment({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MoneyTypeButton(
            label: '支出',
            selected: value == 'expense',
            color: _moneyRed,
            onTap: () => onChanged('expense'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _MoneyTypeButton(
            label: '收入',
            selected: value == 'income',
            color: _moneyGreen,
            onTap: () => onChanged('income'),
          ),
        ),
      ],
    );
  }
}

class _MoneyTypeButton extends StatelessWidget {
  const _MoneyTypeButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: .16) : AppColors.softGreen,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _MoneyAmountField extends StatelessWidget {
  const _MoneyAmountField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      decoration: const InputDecoration(
        border: InputBorder.none,
        hintText: '0.00',
        prefixText: '¥ ',
        prefixStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
        hintStyle: TextStyle(color: AppColors.textTertiary),
      ),
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 30,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _MoneyCategoryGrid extends StatelessWidget {
  const _MoneyCategoryGrid({
    required this.keys,
    required this.selected,
    required this.onChanged,
  });

  final List<String> keys;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: keys.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 14,
        crossAxisSpacing: 12,
        childAspectRatio: .86,
      ),
      itemBuilder: (context, index) {
        final key = keys[index];
        final meta = _categoryMeta(key);
        return _MoneyCategoryCell(
          meta: meta,
          selected: selected == key,
          onTap: () => onChanged(key),
        );
      },
    );
  }
}

class _MoneyCategoryCell extends StatelessWidget {
  const _MoneyCategoryCell({
    required this.meta,
    required this.selected,
    required this.onTap,
  });

  final _MoneyCategoryMeta meta;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: selected ? .16 : .04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _MoneyCategoryIcon(meta: meta, size: 36),
            const SizedBox(height: 7),
            Text(
              meta.label,
              style: TextStyle(
                color: selected ? AppColors.primary : AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoneyCategoryIcon extends StatelessWidget {
  const _MoneyCategoryIcon({required this.meta, required this.size});

  final _MoneyCategoryMeta meta;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: meta.color.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(size * .34),
      ),
      child: Icon(meta.icon, color: meta.color, size: size * .58),
    );
  }
}

class _MoneyInlineField extends StatelessWidget {
  const _MoneyInlineField({
    required this.label,
    required this.value,
    required this.onTap,
    this.trailingIcon,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 46),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: _moneyInputDecoration(),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (trailingIcon != null)
              Icon(trailingIcon, color: AppColors.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }
}

class _MoneyPaymentChips extends StatelessWidget {
  const _MoneyPaymentChips({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _paymentMethods.map((method) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _MoneyChip(
              label: method,
              selected: value == method,
              onTap: () => onChanged(method),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MoneySectionLabel extends StatelessWidget {
  const _MoneySectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MoneyMascotFooter extends StatelessWidget {
  const _MoneyMascotFooter({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 126,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          const Positioned(
            left: 30,
            bottom: 18,
            child: Icon(Icons.favorite, color: AppColors.accent, size: 18),
          ),
          SizedBox(
            width: 158,
            child: AppMascotScene(
              height: 118,
              variant: type == 'income'
                  ? MascotSceneVariant.flowers
                  : MascotSceneVariant.snack,
              showHeart: false,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyCircleAction extends StatelessWidget {
  const _MoneyCircleAction({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = color == AppColors.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(27),
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: primary ? color : Colors.white,
          shape: BoxShape.circle,
          border: primary ? null : Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: primary ? .28 : .12),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, color: primary ? Colors.white : color),
      ),
    );
  }
}

class _MoneyDeleteDialog extends StatelessWidget {
  const _MoneyDeleteDialog({required this.record});

  final AppMoneyRecord record;

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
          boxShadow: [
            BoxShadow(
              color: AppColors.danger.withValues(alpha: .14),
              blurRadius: 26,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.danger,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '删除这笔记账？',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${record.title} · ${_formatMoneyPlain(record.amountCents)} 元',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
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
                      foregroundColor: Colors.white,
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

class _MoneyPickerScreen extends StatelessWidget {
  const _MoneyPickerScreen({
    required this.type,
    required this.category,
    required this.happenedAt,
    required this.noteController,
    required this.onClose,
    required this.onCategoryChanged,
    required this.onDateChanged,
    required this.onQuickNote,
    required this.onTimeTap,
  });

  final String type;
  final String category;
  final DateTime happenedAt;
  final TextEditingController noteController;
  final VoidCallback onClose;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<String> onQuickNote;
  final VoidCallback onTimeTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 112),
      children: [
        _MoneySimpleTopBar(title: '选择', onBack: onClose),
        const SizedBox(height: 22),
        const _MoneySectionLabel('选择分类'),
        _MoneyCategoryGrid(
          keys: _allCategoryKeys,
          selected: category,
          onChanged: onCategoryChanged,
        ),
        const SizedBox(height: 22),
        const _MoneySectionLabel('备注（可选）'),
        _MoneyNoteBox(controller: noteController),
        const SizedBox(height: 18),
        const _MoneySectionLabel('常用备注'),
        _MoneyQuickNotes(onSelected: onQuickNote),
        const SizedBox(height: 18),
        _MoneyCalendarCard(selectedDate: happenedAt, onChanged: onDateChanged),
        const SizedBox(height: 18),
        const _MoneySectionLabel('选择时间'),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTimeTap,
          child: Container(
            height: 50,
            alignment: Alignment.center,
            decoration: _moneyInputDecoration(),
            child: Text(
              _formatTimeWithSpace(happenedAt),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MoneyNoteBox extends StatelessWidget {
  const _MoneyNoteBox({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: 2,
      decoration: InputDecoration(
        hintText: '输入备注信息...',
        filled: true,
        fillColor: Colors.white,
        suffixIcon: const SizedBox(
          width: 42,
          child: AppMascotScene(
            height: 38,
            variant: MascotSceneVariant.profile,
            showHeart: false,
            fit: BoxFit.cover,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}

class _MoneyQuickNotes extends StatelessWidget {
  const _MoneyQuickNotes({required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _quickNotes
          .map(
            (note) => _MoneyChip(
              label: note,
              selected: false,
              onTap: () => onSelected(note),
            ),
          )
          .toList(),
    );
  }
}

class _MoneyCalendarCard extends StatelessWidget {
  const _MoneyCalendarCard({
    required this.selectedDate,
    required this.onChanged,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final visibleMonth = DateTime(selectedDate.year, selectedDate.month);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: _moneyCardDecoration(radius: 18),
      child: Column(
        children: [
          Row(
            children: [
              const Spacer(),
              Text(
                '${visibleMonth.year}年${visibleMonth.month}月',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Icon(Icons.expand_more_rounded, size: 18),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 14),
          const _MoneyWeekHeader(),
          const SizedBox(height: 8),
          _MoneyCalendarGrid(
            visibleMonth: visibleMonth,
            selectedDate: selectedDate,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _MoneyWeekHeader extends StatelessWidget {
  const _MoneyWeekHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: ['日', '一', '二', '三', '四', '五', '六']
          .map(
            (day) => Expanded(
              child: Center(
                child: Text(
                  day,
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _MoneyCalendarGrid extends StatelessWidget {
  const _MoneyCalendarGrid({
    required this.visibleMonth,
    required this.selectedDate,
    required this.onChanged,
  });

  final DateTime visibleMonth;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(visibleMonth.year, visibleMonth.month);
    final daysInMonth = DateTime(
      visibleMonth.year,
      visibleMonth.month + 1,
      0,
    ).day;
    final leading = firstDay.weekday % 7;
    final cells = ((leading + daysInMonth + 6) ~/ 7) * 7;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cells,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final day = index - leading + 1;
        if (day < 1 || day > daysInMonth) {
          return const SizedBox.shrink();
        }
        final date = DateTime(visibleMonth.year, visibleMonth.month, day);
        final selected = _sameDate(date, selectedDate);
        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => onChanged(
            DateTime(
              date.year,
              date.month,
              date.day,
              selectedDate.hour,
              selectedDate.minute,
            ),
          ),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$day',
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MoneySummaryScreen extends StatelessWidget {
  const _MoneySummaryScreen({
    required this.month,
    required this.records,
    required this.summary,
    required this.onBack,
    required this.onMonthTap,
  });

  final DateTime month;
  final List<AppMoneyRecord> records;
  final AppMoneySummary summary;
  final VoidCallback onBack;
  final VoidCallback onMonthTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 112),
      children: [
        _MoneySimpleTopBar(
          title: '月度总结',
          onBack: onBack,
          rightIcon: Icons.calendar_month_outlined,
          onRight: onMonthTap,
        ),
        const SizedBox(height: 18),
        Center(
          child: _MoneyMonthPill(
            label: '${month.year}年${month.month}月',
            onTap: onMonthTap,
          ),
        ),
        const SizedBox(height: 18),
        _MoneyMonthlySummaryCard(summary: summary, recordCount: records.length),
        const SizedBox(height: 14),
        _MoneyTrendCard(records: records),
        const SizedBox(height: 14),
        _MoneyCategoryShareCard(records: records, summary: summary),
        const SizedBox(height: 14),
        _MoneyDailyAverageCard(
          summary: summary,
          dayCount: DateTime(month.year, month.month + 1, 0).day,
        ),
      ],
    );
  }
}

class _MoneyMonthPill extends StatelessWidget {
  const _MoneyMonthPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Icon(Icons.expand_more_rounded, size: 17),
          ],
        ),
      ),
    );
  }
}

class _MoneyMonthlySummaryCard extends StatelessWidget {
  const _MoneyMonthlySummaryCard({
    required this.summary,
    required this.recordCount,
  });

  final AppMoneySummary summary;
  final int recordCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFFFBF4FF), Color(0xFFF7F2FF)],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MoneySummaryMetric(
                  label: '收入(元)',
                  value: _formatMoneyPlain(summary.incomeCents),
                  color: _moneyGreen,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _MoneySummaryMetric(
                  label: '支出(元)',
                  value: _formatMoneyPlain(summary.expenseCents),
                  color: _moneyRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: _MoneySummaryMetric(
              label: '结余(元)',
              value: formatMoneySignedPlain(summary.balanceCents),
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .82),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.receipt_long_outlined,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 8),
                Text(
                  '本月共 $recordCount 笔记录',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneySummaryMetric extends StatelessWidget {
  const _MoneySummaryMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _MoneyTrendCard extends StatelessWidget {
  const _MoneyTrendCard({required this.records});

  final List<AppMoneyRecord> records;

  @override
  Widget build(BuildContext context) {
    final series = _moneyTrendSeries(records);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: _moneyCardDecoration(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '收支趋势',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '单位：元',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: CustomPaint(
              size: const Size(double.infinity, 150),
              painter: _MoneyTrendPainter(
                incomeCents: series.incomeCents,
                expenseCents: series.expenseCents,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

({List<int> incomeCents, List<int> expenseCents}) _moneyTrendSeries(
  List<AppMoneyRecord> records,
) {
  if (records.isEmpty) {
    return (incomeCents: const <int>[], expenseCents: const <int>[]);
  }
  final month = DateTime(
    records.first.happenedAt.year,
    records.first.happenedAt.month,
  );
  final dayCount = DateTime(month.year, month.month + 1, 0).day;
  final income = List<int>.filled(dayCount, 0);
  final expense = List<int>.filled(dayCount, 0);
  for (final record in records) {
    if (record.happenedAt.year != month.year ||
        record.happenedAt.month != month.month) {
      continue;
    }
    final index = record.happenedAt.day - 1;
    if (record.isIncome) {
      income[index] += record.amountCents;
    } else {
      expense[index] += record.amountCents;
    }
  }
  return (incomeCents: income, expenseCents: expense);
}

class _MoneyTrendPainter extends CustomPainter {
  const _MoneyTrendPainter({
    required this.incomeCents,
    required this.expenseCents,
  });

  final List<int> incomeCents;
  final List<int> expenseCents;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.border.withValues(alpha: .7)
      ..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final maxValue = [
      ...incomeCents,
      ...expenseCents,
    ].fold<int>(0, (max, value) => value > max ? value : max);
    if (maxValue <= 0) {
      return;
    }
    _drawLine(canvas, size, incomeCents, maxValue, _moneyGreen);
    _drawLine(canvas, size, expenseCents, maxValue, _moneyRed);
  }

  void _drawLine(
    Canvas canvas,
    Size size,
    List<int> values,
    int maxValue,
    Color color,
  ) {
    if (values.isEmpty || values.every((value) => value == 0)) {
      return;
    }
    final path = Path();
    final denominator = math.max(1, values.length - 1);
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / denominator;
      final normalized = values[i] / maxValue;
      final y = size.height - size.height * normalized;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MoneyTrendPainter oldDelegate) {
    return oldDelegate.incomeCents != incomeCents ||
        oldDelegate.expenseCents != expenseCents;
  }
}

class _MoneyCategoryShareCard extends StatelessWidget {
  const _MoneyCategoryShareCard({required this.records, required this.summary});

  final List<AppMoneyRecord> records;
  final AppMoneySummary summary;

  @override
  Widget build(BuildContext context) {
    final expenseRecords = records.where((record) => record.isExpense).toList();
    final shares = _categoryShares(expenseRecords);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: _moneyCardDecoration(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '支出分类占比',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 128,
                height: 128,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size.square(128),
                      painter: _MoneyDonutPainter(shares: shares),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '总支出',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          _formatMoneyPlain(summary.expenseCents),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _MoneyShareLegend(shares: shares)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoneyShareLegend extends StatelessWidget {
  const _MoneyShareLegend({required this.shares});

  final List<_MoneyCategoryShare> shares;

  @override
  Widget build(BuildContext context) {
    final items = shares.take(5).toList();
    if (items.isEmpty) {
      return const Text(
        '暂无支出分类',
        style: TextStyle(
          color: AppColors.textTertiary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      );
    }
    return Column(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: item.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.category,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${(item.ratio * 100).round()}%',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatMoneyPlain(item.cents),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _MoneyCategoryShare {
  const _MoneyCategoryShare({
    required this.category,
    required this.cents,
    required this.color,
    required this.ratio,
  });

  final String category;
  final int cents;
  final Color color;
  final double ratio;
}

class _MoneyDonutPainter extends CustomPainter {
  const _MoneyDonutPainter({required this.shares});

  final List<_MoneyCategoryShare> shares;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final background = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.butt
      ..color = AppColors.border.withValues(alpha: .5);
    canvas.drawArc(rect.deflate(12), 0, math.pi * 2, false, background);
    if (shares.isEmpty) {
      return;
    }
    var start = -math.pi / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.butt;
    for (final item in shares) {
      final sweep = math.pi * 2 * item.ratio;
      paint.color = item.color;
      canvas.drawArc(rect.deflate(12), start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _MoneyDonutPainter oldDelegate) {
    return oldDelegate.shares != shares;
  }
}

class _MoneyDailyAverageCard extends StatelessWidget {
  const _MoneyDailyAverageCard({required this.summary, required this.dayCount});

  final AppMoneySummary summary;
  final int dayCount;

  @override
  Widget build(BuildContext context) {
    final safeDayCount = math.max(1, dayCount);
    final income = summary.incomeCents ~/ safeDayCount;
    final expense = summary.expenseCents ~/ safeDayCount;
    final balance = summary.balanceCents ~/ safeDayCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '每日平均',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MoneyAverageTile(
                label: '日均收入',
                value: income,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MoneyAverageTile(
                label: '日均支出',
                value: expense,
                color: _moneyRed,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MoneyAverageTile(
                label: '日均结余',
                value: balance,
                color: AppColors.primary,
                signed: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MoneyAverageTile extends StatelessWidget {
  const _MoneyAverageTile({
    required this.label,
    required this.value,
    required this.color,
    this.signed = false,
  });

  final String label;
  final int value;
  final Color color;
  final bool signed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              signed ? formatMoneySignedPlain(value) : _formatMoneyPlain(value),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyFilterScreen extends StatelessWidget {
  const _MoneyFilterScreen({
    required this.month,
    required this.timeRange,
    required this.type,
    required this.paymentMethod,
    required this.category,
    required this.minAmountController,
    required this.maxAmountController,
    required this.onBack,
    required this.onReset,
    required this.onTimeRangeChanged,
    required this.onTypeChanged,
    required this.onPaymentChanged,
    required this.onCategoryTap,
    required this.onApply,
  });

  final DateTime month;
  final String timeRange;
  final String type;
  final String paymentMethod;
  final String category;
  final TextEditingController minAmountController;
  final TextEditingController maxAmountController;
  final VoidCallback onBack;
  final VoidCallback onReset;
  final ValueChanged<String> onTimeRangeChanged;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onPaymentChanged;
  final VoidCallback onCategoryTap;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 112),
      children: [
        _MoneySimpleTopBar(
          title: '筛选条件',
          onBack: onBack,
          rightText: '重置',
          onRight: onReset,
        ),
        const SizedBox(height: 18),
        _MoneyFilterPanel(
          title: '时间范围',
          child: Column(
            children: [
              _MoneyRadioLine(
                label: '全部时间',
                value: 'all',
                selected: timeRange,
                onChanged: onTimeRangeChanged,
              ),
              _MoneyRadioLine(
                label: '今天',
                value: 'today',
                selected: timeRange,
                onChanged: onTimeRangeChanged,
              ),
              _MoneyRadioLine(
                label: '昨天',
                value: 'yesterday',
                selected: timeRange,
                onChanged: onTimeRangeChanged,
              ),
              _MoneyRadioLine(
                label: '近7天',
                value: 'last7',
                selected: timeRange,
                onChanged: onTimeRangeChanged,
              ),
              _MoneyRadioLine(
                label: '本月',
                value: 'month',
                selected: timeRange,
                onChanged: onTimeRangeChanged,
              ),
              _MoneyRadioLine(
                label: '上月',
                value: 'lastMonth',
                selected: timeRange,
                onChanged: onTimeRangeChanged,
              ),
              _MoneyRadioLine(
                label: '自定义',
                value: 'custom',
                selected: timeRange,
                onChanged: onTimeRangeChanged,
              ),
              const SizedBox(height: 10),
              _MoneyDateRangeBox(month: month),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _MoneyFilterPanel(
          title: '交易类型',
          child: Row(
            children: [
              Expanded(
                child: _MoneyChip(
                  label: '全部',
                  selected: type == 'all',
                  onTap: () => onTypeChanged('all'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MoneyChip(
                  label: '支出',
                  selected: type == 'expense',
                  onTap: () => onTypeChanged('expense'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MoneyChip(
                  label: '收入',
                  selected: type == 'income',
                  onTap: () => onTypeChanged('income'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _MoneyFilterPanel(
          title: '支付方式',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: ['全部', ..._paymentMethods].map((item) {
              final value = item == '全部' ? 'all' : item;
              return _MoneyChip(
                label: item,
                selected: paymentMethod == value,
                onTap: () => onPaymentChanged(value),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        _MoneyFilterPanel(
          title: '金额范围（可选）',
          child: Row(
            children: [
              Expanded(
                child: _MoneyFilterAmountField(
                  controller: minAmountController,
                  hint: '最低金额  0.00',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MoneyFilterAmountField(
                  controller: maxAmountController,
                  hint: '最高金额  无上限',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _MoneyFilterPanel(
          title: '分类',
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onCategoryTap,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: _moneyInputDecoration(),
              child: Row(
                children: [
                  Text(
                    category == 'all' ? '全部分类' : category,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    '选择分类',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _MoneyGradientButton(label: '应用筛选', onTap: onApply),
      ],
    );
  }
}

class _MoneyCategoryFilterSheet extends StatelessWidget {
  const _MoneyCategoryFilterSheet({required this.selected});

  final String selected;

  @override
  Widget build(BuildContext context) {
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '选择分类',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MoneyChip(
                  label: '全部分类',
                  selected: selected == 'all',
                  onTap: () => Navigator.of(context).pop('all'),
                ),
                ..._allCategoryKeys.map((key) {
                  return _MoneyChip(
                    label: key,
                    selected: selected == key,
                    onTap: () => Navigator.of(context).pop(key),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MoneyFilterPanel extends StatelessWidget {
  const _MoneyFilterPanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: _moneyCardDecoration(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _MoneyRadioLine extends StatelessWidget {
  const _MoneyRadioLine({
    required this.label,
    required this.value,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onChanged(value),
      child: SizedBox(
        height: 36,
        child: Row(
          children: [
            Icon(
              selected == value
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected == value
                  ? AppColors.primary
                  : AppColors.textTertiary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoneyDateRangeBox extends StatelessWidget {
  const _MoneyDateRangeBox({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1, 0);
    return Container(
      height: 42,
      alignment: Alignment.center,
      decoration: _moneyInputDecoration(),
      child: Text(
        '${_formatDateYmd(start)}        ~        ${_formatDateYmd(end)}',
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _formatDateYmd(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

class _MoneyFilterAmountField extends StatelessWidget {
  const _MoneyFilterAmountField({required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white.withValues(alpha: .7),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
    );
  }
}

class _MoneyGradientButton extends StatelessWidget {
  const _MoneyGradientButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            colors: [Color(0xFFB99BFF), AppColors.primary],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: .24),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _MoneyChip extends StatelessWidget {
  const _MoneyChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: .12)
              : const Color(0xFFF8F7FB),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.primary : AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _MoneySimpleTopBar extends StatelessWidget {
  const _MoneySimpleTopBar({
    required this.title,
    required this.onBack,
    this.rightIcon,
    this.rightText,
    this.onRight,
  });

  final String title;
  final VoidCallback onBack;
  final IconData? rightIcon;
  final String? rightText;
  final VoidCallback? onRight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary,
              size: 18,
            ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: rightText != null
                ? TextButton(
                    onPressed: onRight,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: AppColors.primary,
                    ),
                    child: Text(
                      rightText!,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  )
                : IconButton(
                    onPressed: onRight,
                    icon: Icon(
                      rightIcon ?? Icons.more_horiz_rounded,
                      color: AppColors.textPrimary,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MoneyLoadingCard extends StatelessWidget {
  const _MoneyLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      alignment: Alignment.center,
      decoration: _moneyCardDecoration(radius: 18),
      child: const CircularProgressIndicator(),
    );
  }
}

class _MoneyEmptyCard extends StatelessWidget {
  const _MoneyEmptyCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onAdd,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: _moneyCardDecoration(radius: 18),
        child: const Column(
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              color: AppColors.primary,
              size: 34,
            ),
            SizedBox(height: 10),
            Text(
              '这个月还没有账目',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6),
            Text(
              '点击添加第一笔收入或支出',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _moneyCardDecoration({double radius = 18}) {
  return BoxDecoration(
    color: Colors.white.withValues(alpha: .92),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.border.withValues(alpha: .75)),
    boxShadow: [
      BoxShadow(
        color: AppColors.primary.withValues(alpha: .07),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

BoxDecoration _moneyInputDecoration() {
  return BoxDecoration(
    color: Colors.white.withValues(alpha: .84),
    borderRadius: BorderRadius.circular(13),
    border: Border.all(color: AppColors.border),
  );
}

_MoneyCategoryMeta _categoryMeta(String category) {
  return _moneyCategories[category] ??
      _moneyCategories['餐饮'] ??
      const _MoneyCategoryMeta(
        label: '餐饮',
        icon: Icons.restaurant_menu_rounded,
        color: AppColors.primary,
      );
}

List<_MoneyCategoryShare> _categoryShares(List<AppMoneyRecord> records) {
  final total = records.fold(0, (sum, record) => sum + record.amountCents);
  if (total <= 0) {
    return const [];
  }
  final values = <String, int>{};
  for (final record in records) {
    values[record.category] =
        (values[record.category] ?? 0) + record.amountCents;
  }
  final items = values.entries.map((entry) {
    final meta = _categoryMeta(entry.key);
    return _MoneyCategoryShare(
      category: entry.key,
      cents: entry.value,
      color: meta.color,
      ratio: entry.value / total,
    );
  }).toList()..sort((a, b) => b.cents.compareTo(a.cents));
  return items;
}

int? _parseAmountCents(String value) {
  final normalized = value
      .trim()
      .replaceAll('¥', '')
      .replaceAll(',', '')
      .replaceAll('，', '');
  if (normalized.isEmpty) {
    return null;
  }
  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(normalized);
  if (match == null) {
    return null;
  }
  final yuan = int.tryParse(match.group(1)!);
  if (yuan == null || yuan > 99999999) {
    return null;
  }
  final centsText = (match.group(2) ?? '').padRight(2, '0');
  final cents = int.tryParse(centsText.isEmpty ? '0' : centsText);
  if (cents == null) {
    return null;
  }
  return yuan * 100 + cents;
}

String _formatAmountInput(int cents) {
  final yuan = cents ~/ 100;
  final cent = cents % 100;
  return cent == 0 ? '$yuan' : '$yuan.${cent.toString().padLeft(2, '0')}';
}

String _formatMoneyPlain(int cents) {
  final absValue = cents.abs();
  final yuan = absValue ~/ 100;
  final cent = absValue % 100;
  return '${_withComma(yuan)}.${cent.toString().padLeft(2, '0')}';
}

String formatMoneySignedPlain(int cents) {
  if (cents == 0) {
    return _formatMoneyPlain(cents);
  }
  final prefix = cents > 0 ? '+' : '-';
  return '$prefix${_formatMoneyPlain(cents)}';
}

String _withComma(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final left = text.length - i;
    buffer.write(text[i]);
    if (left > 1 && left % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}

String _formatIsoDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _formatTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatTimeWithSpace(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour  :  $minute';
}

DateTime _dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

bool _sameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _weekdayName(DateTime date) {
  return switch (date.weekday) {
    DateTime.monday => '星期一',
    DateTime.tuesday => '星期二',
    DateTime.wednesday => '星期三',
    DateTime.thursday => '星期四',
    DateTime.friday => '星期五',
    DateTime.saturday => '星期六',
    _ => '星期日',
  };
}
