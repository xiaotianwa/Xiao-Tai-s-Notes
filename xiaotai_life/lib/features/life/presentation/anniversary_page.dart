import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/data/app_data_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme_tokens.dart';
import '../../../shared/widgets/app_mascot_scene.dart';
import '../../../shared/widgets/prototype_ui.dart';

enum _AnniversaryView { list, form, detail, manage }

enum _AnniversaryFilter { all, upcoming, passed }

const _anniversaryCategories = [
  _AnniversaryCategory('love', '爱情', Icons.favorite_rounded),
  _AnniversaryCategory('birthday', '生日', Icons.cake_outlined),
  _AnniversaryCategory('life', '生活', Icons.weekend_outlined),
  _AnniversaryCategory('travel', '旅行', Icons.luggage_outlined),
  _AnniversaryCategory('study', '学习', Icons.menu_book_outlined),
  _AnniversaryCategory('other', '其他', Icons.card_giftcard_outlined),
];

const _anniversaryColors = [
  _AnniversaryColor('pink', Color(0xFFFF7397)),
  _AnniversaryColor('purple', Color(0xFF8E67E8)),
  _AnniversaryColor('orange', Color(0xFFFF9B64)),
  _AnniversaryColor('yellow', Color(0xFFFFCC64)),
  _AnniversaryColor('green', Color(0xFF8ED6A4)),
  _AnniversaryColor('blue', Color(0xFF86B4F8)),
  _AnniversaryColor('lavender', Color(0xFFC5A5F8)),
];

class AnniversaryPage extends StatefulWidget {
  const AnniversaryPage({super.key});

  @override
  State<AnniversaryPage> createState() => _AnniversaryPageState();
}

class _AnniversaryPageState extends State<AnniversaryPage> {
  static const _mediaPicker = MethodChannel('xiaotai_life/media_picker');

  late Future<AppLocalStore> _storeFuture;
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  _AnniversaryView _view = _AnniversaryView.list;
  _AnniversaryFilter _filter = _AnniversaryFilter.upcoming;
  AppAnniversary? _editingAnniversary;
  AppAnniversary? _selectedAnniversary;
  final Set<String> _selectedForDelete = {};
  String? _categoryFilter;
  String _searchQuery = '';
  bool _pickingImage = false;
  DateTime _selectedDate = DateTime.now();
  String _category = 'love';
  String _colorName = 'pink';
  String? _imagePath;
  bool _countUp = false;
  bool _pinnedOnHome = false;

  @override
  void initState() {
    super.initState();
    _storeFuture = AppLocalStore.create();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: FutureBuilder<AppLocalStore>(
        future: _storeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _AnniversaryFrame(child: _AnniversaryLoading());
          }
          final store = snapshot.data;
          final rawItems =
              store?.getAnniversaries() ?? const <AppAnniversary>[];
          final items = _sortedAnniversaries(rawItems);
          return _AnniversaryFrame(child: _bodyFor(store, items));
        },
      ),
    );
  }

  Widget _bodyFor(AppLocalStore? store, List<AppAnniversary> items) {
    final listItems = _extraFilteredItems(items);
    final selected =
        _selectedAnniversary ?? (items.isEmpty ? null : items.first);
    return switch (_view) {
      _AnniversaryView.form => _AnniversaryFormScreen(
        titleController: _titleController,
        noteController: _noteController,
        editing: _editingAnniversary != null,
        date: _selectedDate,
        category: _category,
        colorName: _colorName,
        imagePath: _imagePath,
        countUp: _countUp,
        pinnedOnHome: _pinnedOnHome,
        pickingImage: _pickingImage,
        onCancel: _goList,
        onSave: _saveAnniversary,
        onPickDate: _pickDate,
        onPickImage: _pickImage,
        onRemoveImage: () => setState(() => _imagePath = null),
        onCategoryChanged: (value) => setState(() => _category = value),
        onColorChanged: (value) => setState(() => _colorName = value),
        onCountTypeChanged: (value) => setState(() => _countUp = value),
        onPinnedOnHomeChanged: (value) => setState(() => _pinnedOnHome = value),
      ),
      _AnniversaryView.detail =>
        selected == null
            ? _AnniversaryListScreen(
                items: listItems,
                filter: _filter,
                extraFilterLabel: _extraFilterLabel(),
                onFilterChanged: (value) => setState(() => _filter = value),
                onClearExtraFilter: _clearExtraFilter,
                onAdd: _startAdding,
                onEdit: _startEditing,
                onOpen: _openDetail,
                onBack: _goHome,
                onManage: _openManage,
                onSearch: _openSearchDialog,
              )
            : _AnniversaryDetailScreen(
                anniversary: selected,
                onBack: _goHome,
                onAdd: _startAdding,
                onEdit: () => _startEditing(selected),
                onDelete: () => _deleteAnniversary(selected),
              ),
      _AnniversaryView.manage => _AnniversaryManageScreen(
        items: items,
        selectedIds: _selectedForDelete,
        onBack: _goList,
        onToggle: _toggleManageSelection,
        onDeleteSelected: () => _deleteSelected(store, items),
        onReorderHint: _showReservedReorder,
      ),
      _AnniversaryView.list => _AnniversaryListScreen(
        items: listItems,
        filter: _filter,
        extraFilterLabel: _extraFilterLabel(),
        onFilterChanged: (value) => setState(() => _filter = value),
        onClearExtraFilter: _clearExtraFilter,
        onAdd: _startAdding,
        onEdit: _startEditing,
        onOpen: _openDetail,
        onBack: _goHome,
        onManage: _openManage,
        onSearch: _openSearchDialog,
      ),
    };
  }

  List<AppAnniversary> _extraFilteredItems(List<AppAnniversary> items) {
    final category = _categoryFilter;
    final query = _searchQuery.trim();
    return items.where((item) {
      final matchesCategory =
          category == null || _normalizeCategory(item.category) == category;
      final matchesQuery = query.isEmpty || item.title.contains(query);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  String? _extraFilterLabel() {
    final parts = <String>[];
    final category = _categoryFilter;
    if (category != null) {
      parts.add(_categoryLabel(category));
    }
    if (_searchQuery.trim().isNotEmpty) {
      parts.add('搜索：$_searchQuery');
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  void _clearExtraFilter() {
    setState(() {
      _categoryFilter = null;
      _searchQuery = '';
    });
  }

  void _startAdding() {
    setState(() {
      _view = _AnniversaryView.form;
      _editingAnniversary = null;
      _titleController.clear();
      _noteController.clear();
      _selectedDate = DateTime.now();
      _category = 'love';
      _colorName = 'pink';
      _imagePath = null;
      _countUp = false;
      _pinnedOnHome = false;
    });
  }

  void _startEditing(AppAnniversary anniversary) {
    setState(() {
      _view = _AnniversaryView.form;
      _editingAnniversary = anniversary;
      _titleController.text = anniversary.title;
      _noteController.text = anniversary.note;
      _selectedDate = anniversary.date;
      _category = _categoryExists(anniversary.category)
          ? anniversary.category
          : 'other';
      _colorName = _colorExists(anniversary.colorName)
          ? anniversary.colorName
          : 'pink';
      _imagePath = anniversary.imagePath;
      _countUp = anniversary.showCountUp;
      _pinnedOnHome = anniversary.pinnedOnHome;
    });
  }

  void _openDetail(AppAnniversary anniversary) {
    setState(() {
      _selectedAnniversary = anniversary;
      _view = _AnniversaryView.detail;
    });
  }

  void _openManage() {
    setState(() {
      _selectedForDelete.clear();
      _view = _AnniversaryView.manage;
    });
  }

  void _goList() {
    setState(() {
      _view = _AnniversaryView.list;
      _editingAnniversary = null;
      _selectedAnniversary = null;
      _selectedForDelete.clear();
    });
  }

  void _goHome() {
    context.go(AppRoutes.today);
  }

  void _toggleManageSelection(String id) {
    setState(() {
      if (_selectedForDelete.contains(id)) {
        _selectedForDelete.remove(id);
      } else {
        _selectedForDelete.add(id);
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
      helpText: '选择纪念日日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _selectedDate = picked);
  }

  Future<void> _pickImage() async {
    if (_pickingImage) {
      return;
    }
    setState(() => _pickingImage = true);
    try {
      final picked = await _mediaPicker.invokeListMethod<String>('pickImages', {
        'maxCount': 1,
      });
      if (!mounted) {
        return;
      }
      final path = (picked ?? []).isEmpty ? null : picked!.first;
      if (path != null) {
        setState(() => _imagePath = path);
      }
    } on PlatformException catch (error) {
      if (mounted) {
        _showSnack(error.message ?? '图片选择接口暂不可用');
      }
    } finally {
      if (mounted) {
        setState(() => _pickingImage = false);
      }
    }
  }

  Future<void> _saveAnniversary() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showSnack('请先填写纪念日名称');
      return;
    }
    final store = await _storeFuture;
    final editing = _editingAnniversary;
    final anniversary = AppAnniversary(
      id: editing?.id ?? 'anniversary_${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      date: DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      ),
      category: _category,
      colorName: _colorName,
      mascotVariant: _variantFor(_category),
      imagePath: _imagePath,
      note: _noteController.text.trim(),
      showCountUp: _countUp,
      pinnedOnHome: _pinnedOnHome,
    );
    await store.upsertAnniversary(anniversary);
    if (!mounted) {
      return;
    }
    setState(() {
      _storeFuture = AppLocalStore.create();
      _selectedAnniversary = anniversary;
      _editingAnniversary = null;
      _view = _AnniversaryView.detail;
    });
    _showSnack(editing == null ? '纪念日已添加' : '纪念日已保存');
  }

  Future<void> _deleteAnniversary(AppAnniversary anniversary) async {
    final confirmed = await _confirmDelete(count: 1);
    if (confirmed != true || !mounted) {
      return;
    }
    final store = await _storeFuture;
    await store.deleteAnniversary(anniversary.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _storeFuture = AppLocalStore.create();
      _selectedAnniversary = null;
      _editingAnniversary = null;
      _view = _AnniversaryView.list;
    });
    _showSnack('纪念日已删除');
  }

  Future<void> _deleteSelected(
    AppLocalStore? store,
    List<AppAnniversary> items,
  ) async {
    if (_selectedForDelete.isEmpty) {
      _showSnack('请先选择要删除的纪念日');
      return;
    }
    if (store == null) {
      _showSnack('数据暂未加载完成，请稍后再试');
      return;
    }
    final confirmed = await _confirmDelete(count: _selectedForDelete.length);
    if (confirmed != true || !mounted) {
      return;
    }
    for (final id in _selectedForDelete) {
      await store.deleteAnniversary(id);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedForDelete.clear();
      _storeFuture = AppLocalStore.create();
      _view = _AnniversaryView.list;
    });
    _showSnack('已删除所选纪念日');
  }

  Future<bool?> _confirmDelete({required int count}) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .42),
      builder: (context) => _AnniversaryDeleteDialog(count: count),
    );
  }

  Future<void> _openSearchDialog() async {
    final query = await showDialog<String>(
      context: context,
      builder: (context) =>
          _AnniversarySearchDialog(initialQuery: _searchQuery),
    );
    if (query == null || !mounted) {
      return;
    }
    setState(() {
      _searchQuery = query;
      _view = _AnniversaryView.list;
    });
  }

  void _showReservedReorder() {
    _showSnack('当前按日期自动排序');
  }

  void _showSnack(String message) {
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

class _AnniversaryFrame extends StatelessWidget {
  const _AnniversaryFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeTokens;
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    tokens.softPink.withValues(alpha: .14),
                    Colors.white.withValues(alpha: .08),
                    tokens.softBlue.withValues(alpha: .10),
                  ],
                  stops: const [0, .36, 1],
                ),
              ),
            ),
          ),
          Positioned(
            top: -80,
            right: -70,
            child: _Glow(size: 210, color: tokens.softPink),
          ),
          Positioned(
            top: 290,
            left: -110,
            child: _Glow(size: 260, color: tokens.softBlue),
          ),
          SafeArea(bottom: false, child: child),
        ],
      ),
    );
  }
}

class _AnniversaryListScreen extends StatelessWidget {
  const _AnniversaryListScreen({
    required this.items,
    required this.filter,
    required this.extraFilterLabel,
    required this.onFilterChanged,
    required this.onClearExtraFilter,
    required this.onAdd,
    required this.onEdit,
    required this.onOpen,
    required this.onBack,
    required this.onManage,
    required this.onSearch,
  });

  final List<AppAnniversary> items;
  final _AnniversaryFilter filter;
  final String? extraFilterLabel;
  final ValueChanged<_AnniversaryFilter> onFilterChanged;
  final VoidCallback onClearExtraFilter;
  final VoidCallback onAdd;
  final ValueChanged<AppAnniversary> onEdit;
  final ValueChanged<AppAnniversary> onOpen;
  final VoidCallback onBack;
  final VoidCallback onManage;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final visibleItems = _filteredItems(items, filter);
    return Stack(
      children: [
        ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 118),
          children: [
            _TopBar(
              title: '纪念日',
              leadingIcon: Icons.chevron_left_rounded,
              onLeading: onBack,
              actions: [
                _RoundIconButton(icon: Icons.search_rounded, onTap: onSearch),
                const SizedBox(width: 8),
                _RoundIconButton(icon: Icons.add_rounded, onTap: onAdd),
                const SizedBox(width: 8),
                _RoundIconButton(icon: Icons.tune_rounded, onTap: onManage),
              ],
            ),
            const SizedBox(height: 12),
            _SegmentedTabs(filter: filter, onChanged: onFilterChanged),
            const SizedBox(height: 18),
            if (extraFilterLabel != null) ...[
              _AnniversaryFilterNotice(
                label: extraFilterLabel!,
                onClear: onClearExtraFilter,
              ),
              const SizedBox(height: 12),
            ],
            _InlineAddCard(onTap: onAdd),
            const SizedBox(height: 12),
            for (final item in visibleItems) ...[
              _AnniversaryListCard(
                anniversary: item,
                onTap: () => onOpen(item),
                onEdit: () => onEdit(item),
              ),
              const SizedBox(height: 12),
            ],
            if (visibleItems.isEmpty) const _AnniversaryEmptyCard(),
          ],
        ),
      ],
    );
  }
}

class _AnniversaryFormScreen extends StatelessWidget {
  const _AnniversaryFormScreen({
    required this.titleController,
    required this.noteController,
    required this.editing,
    required this.date,
    required this.category,
    required this.colorName,
    required this.imagePath,
    required this.countUp,
    required this.pinnedOnHome,
    required this.pickingImage,
    required this.onCancel,
    required this.onSave,
    required this.onPickDate,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.onCategoryChanged,
    required this.onColorChanged,
    required this.onCountTypeChanged,
    required this.onPinnedOnHomeChanged,
  });

  final TextEditingController titleController;
  final TextEditingController noteController;
  final bool editing;
  final DateTime date;
  final String category;
  final String colorName;
  final String? imagePath;
  final bool countUp;
  final bool pinnedOnHome;
  final bool pickingImage;
  final VoidCallback onCancel;
  final Future<void> Function() onSave;
  final VoidCallback onPickDate;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onColorChanged;
  final ValueChanged<bool> onCountTypeChanged;
  final ValueChanged<bool> onPinnedOnHomeChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
      children: [
        _TextTopBar(
          title: editing ? '编辑纪念日' : '添加纪念日',
          leftText: '取消',
          rightText: '保存',
          onLeft: onCancel,
          onRight: onSave,
        ),
        const SizedBox(height: 20),
        _FormLabel('纪念日名称'),
        _TextInput(
          controller: titleController,
          hintText: '我们在一起',
          suffixIcon: Icons.cancel_rounded,
        ),
        const SizedBox(height: 18),
        _FormLabel('日期'),
        _PickerRow(
          text: '${_formatDateCn(date)} ${_weekdayLabel(date)}',
          onTap: onPickDate,
        ),
        const SizedBox(height: 18),
        _FormLabel('类型'),
        _CountTypeSwitch(countUp: countUp, onChanged: onCountTypeChanged),
        const SizedBox(height: 18),
        _FormLabel('首页标签'),
        _HomePinnedSwitch(
          pinned: pinnedOnHome,
          onChanged: onPinnedOnHomeChanged,
        ),
        const SizedBox(height: 18),
        _FormLabel('分类'),
        _CategoryPicker(selected: category, onChanged: onCategoryChanged),
        const SizedBox(height: 18),
        _FormLabel('颜色'),
        _ColorPicker(selected: colorName, onChanged: onColorChanged),
        const SizedBox(height: 18),
        _FormLabel('图片'),
        _ImagePickerRow(
          imagePath: imagePath,
          category: category,
          picking: pickingImage,
          onPick: onPickImage,
          onRemove: onRemoveImage,
        ),
        const SizedBox(height: 18),
        _FormLabel('备注（可选）'),
        _NoteInput(controller: noteController),
      ],
    );
  }
}

class _AnniversaryDetailScreen extends StatelessWidget {
  const _AnniversaryDetailScreen({
    required this.anniversary,
    required this.onBack,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final AppAnniversary anniversary;
  final VoidCallback onBack;
  final VoidCallback onAdd;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final progress = _anniversaryProgress(anniversary, DateTime.now());
    final color = _colorOf(anniversary.colorName);
    final days = anniversary.showCountUp
        ? anniversary.daysPassed(DateTime.now())
        : anniversary.daysLeft(DateTime.now());
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 118),
      children: [
        _TopBar(
          title: '纪念日详情',
          leadingIcon: Icons.chevron_left_rounded,
          onLeading: onBack,
          actions: [
            _RoundIconButton(icon: Icons.add_rounded, onTap: onAdd),
            const SizedBox(width: 8),
            _RoundIconButton(icon: Icons.edit_outlined, onTap: onEdit),
          ],
        ),
        const SizedBox(height: 16),
        _DetailHero(anniversary: anniversary, days: days, color: color),
        const SizedBox(height: 14),
        _LoveLine(color: color, countUp: anniversary.showCountUp),
        const SizedBox(height: 14),
        _ProgressCard(
          progress: progress,
          color: color,
          countUp: anniversary.showCountUp,
          totalDays: days,
        ),
        const SizedBox(height: 14),
        _DetailInfoCard(anniversary: anniversary),
        const SizedBox(height: 18),
        _OutlineActionButton(
          label: '删除',
          icon: Icons.delete_outline,
          color: AppColors.danger,
          onTap: onDelete,
        ),
      ],
    );
  }
}

class _AnniversaryManageScreen extends StatelessWidget {
  const _AnniversaryManageScreen({
    required this.items,
    required this.selectedIds,
    required this.onBack,
    required this.onToggle,
    required this.onDeleteSelected,
    required this.onReorderHint,
  });

  final List<AppAnniversary> items;
  final Set<String> selectedIds;
  final VoidCallback onBack;
  final ValueChanged<String> onToggle;
  final VoidCallback onDeleteSelected;
  final VoidCallback onReorderHint;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 118),
      children: [
        _TextTopBar(
          title: '管理纪念日',
          leftText: '',
          rightText: '完成',
          onLeft: onBack,
          onRight: onBack,
          leadingIcon: Icons.chevron_left_rounded,
        ),
        const SizedBox(height: 18),
        Text(
          '长按拖动可调整顺序',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        for (final item in items) ...[
          _ManageRow(
            anniversary: item,
            selected: selectedIds.contains(item.id),
            onToggle: () => onToggle(item.id),
            onReorderHint: onReorderHint,
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 18),
        _DeleteSelectedPanel(
          count: selectedIds.length,
          onTap: onDeleteSelected,
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.leadingIcon,
    required this.onLeading,
    this.actions = const [],
  });

  final String title;
  final IconData leadingIcon;
  final VoidCallback onLeading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          _RoundIconButton(icon: leadingIcon, onTap: onLeading, minimal: true),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (actions.isEmpty)
            const SizedBox(width: 42)
          else
            Row(children: actions),
        ],
      ),
    );
  }
}

class _TextTopBar extends StatelessWidget {
  const _TextTopBar({
    required this.title,
    required this.leftText,
    required this.rightText,
    required this.onLeft,
    required this.onRight,
    this.leadingIcon,
  });

  final String title;
  final String leftText;
  final String rightText;
  final VoidCallback onLeft;
  final VoidCallback onRight;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: leadingIcon == null
                ? TextButton(onPressed: onLeft, child: Text(leftText))
                : Align(
                    alignment: Alignment.centerLeft,
                    child: _RoundIconButton(
                      icon: leadingIcon!,
                      onTap: onLeft,
                      minimal: true,
                    ),
                  ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(
            width: 70,
            child: TextButton(
              onPressed: onRight,
              child: Text(
                rightText,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({required this.filter, required this.onChanged});

  final _AnniversaryFilter filter;
  final ValueChanged<_AnniversaryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .68),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _TabItem(
            label: '全部',
            selected: filter == _AnniversaryFilter.all,
            onTap: () => onChanged(_AnniversaryFilter.all),
          ),
          _TabItem(
            label: '即将到来',
            selected: filter == _AnniversaryFilter.upcoming,
            onTap: () => onChanged(_AnniversaryFilter.upcoming),
          ),
          _TabItem(
            label: '已过去',
            selected: filter == _AnniversaryFilter.passed,
            onTap: () => onChanged(_AnniversaryFilter.passed),
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
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
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: selected ? softShadowSmall : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _AnniversaryListCard extends StatelessWidget {
  const _AnniversaryListCard({
    required this.anniversary,
    required this.onTap,
    required this.onEdit,
  });

  final AppAnniversary anniversary;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final color = _colorOf(anniversary.colorName);
    final now = DateTime.now();
    final days = anniversary.showCountUp
        ? anniversary.daysPassed(now)
        : anniversary.daysLeft(now);
    final typeLabel = anniversary.showCountUp ? '正数' : '倒数';
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: .16)),
        ),
        child: Row(
          children: [
            _IllustrationBox(anniversary: anniversary, size: 68),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    anniversary.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$days',
                        style: TextStyle(
                          color: color,
                          fontSize: 25,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          '天',
                          style: TextStyle(
                            color: color,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatDateDot(anniversary.date)} ${_weekdayLabel(anniversary.date)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (anniversary.pinnedOnHome) ...[
                    const SizedBox(height: 6),
                    _InlineTag(
                      label: '首页固定',
                      icon: Icons.push_pin_rounded,
                      color: AppColors.primary,
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(
              height: 68,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onEdit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .72),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        typeLabel,
                        style: TextStyle(
                          color: anniversary.showCountUp
                              ? AppColors.primary
                              : AppColors.danger,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.favorite_rounded,
                    color: color.withValues(alpha: .18),
                    size: 20,
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

class _AnniversaryFilterNotice extends StatelessWidget {
  const _AnniversaryFilterNotice({required this.label, required this.onClear});

  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: .16)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.filter_alt_rounded,
            color: AppColors.primary.withValues(alpha: .9),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          TextButton(onPressed: onClear, child: const Text('清除')),
        ],
      ),
    );
  }
}

class _InlineAddCard extends StatelessWidget {
  const _InlineAddCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .84),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.primary.withValues(alpha: .16)),
          boxShadow: softShadowSmall,
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: AppColors.primary,
                size: 32,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '添加新的纪念日',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '记录值得被记住的重要时刻',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailHero extends StatelessWidget {
  const _DetailHero({
    required this.anniversary,
    required this.days,
    required this.color,
  });

  final AppAnniversary anniversary;
  final int days;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: .16)),
      ),
      child: Column(
        children: [
          Expanded(
            child: _IllustrationBox(anniversary: anniversary, size: 130),
          ),
          const SizedBox(height: 8),
          Text(
            anniversary.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              _SmallPill(
                label: anniversary.showCountUp ? '正数日' : '倒数日',
                color: color,
              ),
              if (anniversary.pinnedOnHome)
                _SmallPill(label: '首页固定', color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$days',
                style: TextStyle(
                  color: color,
                  fontSize: 44,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '天',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${anniversary.showCountUp ? '开始日' : '目标日'}： ${_formatDateCn(anniversary.date)} ${_weekdayLabel(anniversary.date)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoveLine extends StatelessWidget {
  const _LoveLine({required this.color, required this.countUp});

  final Color color;
  final bool countUp;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .14)),
      ),
      child: Text(
        countUp ? '一起走过的每一天都值得记住' : '每一天都在靠近你',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.progress,
    required this.color,
    required this.countUp,
    required this.totalDays,
  });

  final _AnniversaryProgress progress;
  final Color color;
  final bool countUp;
  final int totalDays;

  @override
  Widget build(BuildContext context) {
    return _SoftPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('时间进度', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: progress.ratio,
              minHeight: 8,
              color: color,
              backgroundColor: AppColors.border.withValues(alpha: .7),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                countUp ? '已记录 $totalDays 天' : '已过 ${progress.passedDays} 天',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              Text(
                countUp
                    ? '下次纪念 ${progress.leftDays} 天'
                    : '距目标日 ${progress.leftDays} 天',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailInfoCard extends StatelessWidget {
  const _DetailInfoCard({required this.anniversary});

  final AppAnniversary anniversary;

  @override
  Widget build(BuildContext context) {
    return _SoftPanel(
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.calendar_today_outlined,
            label: '开始日期',
            value:
                '${_formatDateCn(anniversary.date)} ${_weekdayLabel(anniversary.date)}',
          ),
          _InfoRow(
            icon: Icons.repeat_rounded,
            label: '重复',
            value: '每年（${anniversary.date.month}月${anniversary.date.day}日）',
          ),
          _InfoRow(
            icon: Icons.favorite_border_rounded,
            label: '分类',
            value: _categoryLabel(anniversary.category),
          ),
          _InfoRow(
            icon: Icons.circle,
            label: '颜色',
            value: _colorLabel(anniversary.colorName),
          ),
          _InfoRow(
            icon: Icons.push_pin_outlined,
            label: '首页展示',
            value: anniversary.pinnedOnHome ? '固定显示' : '自动排序',
          ),
          _InfoRow(
            icon: Icons.edit_outlined,
            label: '备注',
            value: anniversary.note.isEmpty ? '未填写' : anniversary.note,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 17),
          const SizedBox(width: 10),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          Flexible(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManageRow extends StatelessWidget {
  const _ManageRow({
    required this.anniversary,
    required this.selected,
    required this.onToggle,
    required this.onReorderHint,
  });

  final AppAnniversary anniversary;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onReorderHint;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onToggle,
      onLongPress: onReorderHint,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .78),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected ? AppColors.primary : AppColors.textTertiary,
            ),
            const SizedBox(width: 10),
            _IllustrationBox(anniversary: anniversary, size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    anniversary.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_formatDateDot(anniversary.date)} ${_weekdayLabel(anniversary.date)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onReorderHint,
              icon: const Icon(
                Icons.drag_handle_rounded,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteSelectedPanel extends StatelessWidget {
  const _DeleteSelectedPanel({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.softPink.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.danger.withValues(alpha: .12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '删除所选纪念日（$count 个）',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '删除后将无法恢复，确定要删除吗？',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              minimumSize: const Size(92, 44),
            ),
            onPressed: onTap,
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _AnniversarySearchDialog extends StatefulWidget {
  const _AnniversarySearchDialog({required this.initialQuery});

  final String initialQuery;

  @override
  State<_AnniversarySearchDialog> createState() =>
      _AnniversarySearchDialogState();
}

class _AnniversarySearchDialogState extends State<_AnniversarySearchDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('搜索纪念日'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: '输入名称关键词',
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
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('确定'),
        ),
      ],
    );
  }
}

class _AnniversaryDeleteDialog extends StatelessWidget {
  const _AnniversaryDeleteDialog({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 34),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: softShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 94,
              child: AppMascotScene(
                variant: MascotSceneVariant.flowers,
                showHeart: false,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              count > 1 ? '确定要删除这些纪念日吗？' : '确定要删除该纪念日吗？',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text('删除后将无法恢复哦', style: Theme.of(context).textTheme.bodySmall),
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
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
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

class _FormLabel extends StatelessWidget {
  const _FormLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.controller,
    required this.hintText,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        suffixIcon: suffixIcon == null
            ? null
            : IconButton(
                onPressed: controller.clear,
                icon: Icon(suffixIcon, color: AppColors.textTertiary),
              ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: .82),
        border: _inputBorder(),
        enabledBorder: _inputBorder(),
        focusedBorder: _inputBorder(AppColors.primary),
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .82),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _CountTypeSwitch extends StatelessWidget {
  const _CountTypeSwitch({required this.countUp, required this.onChanged});

  final bool countUp;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .7),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _SwitchHalf(
            label: '倒数日',
            selected: !countUp,
            onTap: () => onChanged(false),
          ),
          _SwitchHalf(
            label: '正数日',
            selected: countUp,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _HomePinnedSwitch extends StatelessWidget {
  const _HomePinnedSwitch({required this.pinned, required this.onChanged});

  final bool pinned;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => onChanged(!pinned),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: pinned
              ? AppColors.primary.withValues(alpha: .12)
              : Colors.white.withValues(alpha: .78),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: pinned
                ? AppColors.primary.withValues(alpha: .36)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: pinned
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.push_pin_rounded,
                color: pinned ? Colors.white : AppColors.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '固定显示在首页',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    pinned ? '首页纪念日卡片将优先显示它' : '未固定时按最近日期自动显示',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IgnorePointer(
              child: Switch(
                value: pinned,
                onChanged: onChanged,
                activeThumbColor: AppColors.primary,
                activeTrackColor: AppColors.primary.withValues(alpha: .28),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchHalf extends StatelessWidget {
  const _SwitchHalf({
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
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final item in _anniversaryCategories.take(5))
          _FormCategoryIcon(
            item: item,
            selected: selected == item.value,
            onTap: () => onChanged(item.value),
          ),
      ],
    );
  }
}

class _FormCategoryIcon extends StatelessWidget {
  const _FormCategoryIcon({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _AnniversaryCategory item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(item.value);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: selected ? color : color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              item.icon,
              color: selected ? Colors.white : color,
              size: 20,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.label,
            style: TextStyle(
              color: selected ? color : AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final item in _anniversaryColors) ...[
          _ColorDot(
            item: item,
            selected: selected == item.value,
            onTap: () => onChanged(item.value),
          ),
          const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _AnniversaryColor item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
        child: selected
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
            : null,
      ),
    );
  }
}

class _ImagePickerRow extends StatelessWidget {
  const _ImagePickerRow({
    required this.imagePath,
    required this.category,
    required this.picking,
    required this.onPick,
    required this.onRemove,
  });

  final String? imagePath;
  final String category;
  final bool picking;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final preview = AppAnniversary(
      id: 'preview',
      title: 'preview',
      date: DateTime.now(),
      category: category,
      colorName: 'pink',
      mascotVariant: _variantFor(category),
      imagePath: imagePath,
    );
    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            _IllustrationBox(anniversary: preview, size: 76),
            if (imagePath != null)
              Positioned(
                top: -8,
                right: -8,
                child: InkWell(
                  onTap: onRemove,
                  child: const CircleAvatar(
                    radius: 11,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.close_rounded, size: 15),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: picking ? null : onPick,
          child: Container(
            width: 76,
            height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .72),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(
              picking ? Icons.hourglass_empty_rounded : Icons.add_rounded,
              color: AppColors.textSecondary,
              size: 28,
            ),
          ),
        ),
      ],
    );
  }
}

class _NoteInput extends StatelessWidget {
  const _NoteInput({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: 4,
      maxLines: 4,
      decoration: InputDecoration(
        hintText: '遇见你，是我最美的意外',
        filled: true,
        fillColor: Colors.white.withValues(alpha: .82),
        border: _inputBorder(),
        enabledBorder: _inputBorder(),
        focusedBorder: _inputBorder(AppColors.primary),
      ),
    );
  }
}

class _IllustrationBox extends StatelessWidget {
  const _IllustrationBox({required this.anniversary, required this.size});

  final AppAnniversary anniversary;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(anniversary.category);
    if (anniversary.imagePath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * .22),
        child: Image.file(
          File(anniversary.imagePath!),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _GeneratedIllustration(
            anniversary: anniversary,
            color: color,
            size: size,
          ),
        ),
      );
    }
    return _GeneratedIllustration(
      anniversary: anniversary,
      color: color,
      size: size,
    );
  }
}

class _GeneratedIllustration extends StatelessWidget {
  const _GeneratedIllustration({
    required this.anniversary,
    required this.color,
    required this.size,
  });

  final AppAnniversary anniversary;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(size * .22),
      ),
      child: size > 90
          ? AppMascotScene(
              variant: _variantOf(_variantFor(anniversary.category)),
              showHeart: false,
              fit: BoxFit.cover,
            )
          : Icon(
              _categoryIcon(anniversary.category),
              color: color,
              size: size * .48,
            ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.minimal = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool minimal;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: minimal
              ? Colors.transparent
              : Colors.white.withValues(alpha: .8),
          borderRadius: BorderRadius.circular(16),
          boxShadow: minimal ? null : softShadowSmall,
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 22),
      ),
    );
  }
}

class _OutlineActionButton extends StatelessWidget {
  const _OutlineActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: .28)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InlineTag extends StatelessWidget {
  const _InlineTag({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftPanel extends StatelessWidget {
  const _SoftPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _AnniversaryLoading extends StatelessWidget {
  const _AnniversaryLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _AnniversaryEmptyCard extends StatelessWidget {
  const _AnniversaryEmptyCard();

  @override
  Widget build(BuildContext context) {
    return _SoftPanel(
      child: Column(
        children: [
          const Icon(
            Icons.event_available_outlined,
            color: AppColors.textTertiary,
            size: 42,
          ),
          const SizedBox(height: 10),
          Text('还没有纪念日', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('添加一个值得珍藏的重要时刻', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: .32),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .24),
            blurRadius: 80,
            spreadRadius: 20,
          ),
        ],
      ),
    );
  }
}

class _AnniversaryCategory {
  const _AnniversaryCategory(this.value, this.label, this.icon);

  final String value;
  final String label;
  final IconData icon;
}

class _AnniversaryColor {
  const _AnniversaryColor(this.value, this.color);

  final String value;
  final Color color;
}

class _AnniversaryProgress {
  const _AnniversaryProgress({
    required this.ratio,
    required this.passedDays,
    required this.leftDays,
  });

  final double ratio;
  final int passedDays;
  final int leftDays;
}

OutlineInputBorder _inputBorder([Color color = AppColors.border]) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: color),
  );
}

List<AppAnniversary> _sortedAnniversaries(List<AppAnniversary> items) {
  final now = DateTime.now();
  return [...items]..sort((a, b) => a.daysLeft(now).compareTo(b.daysLeft(now)));
}

List<AppAnniversary> _filteredItems(
  List<AppAnniversary> items,
  _AnniversaryFilter filter,
) {
  final today = DateTime.now();
  return switch (filter) {
    _AnniversaryFilter.all => items,
    _AnniversaryFilter.upcoming =>
      items
          .where(
            (item) => item.daysLeft(today) >= 0 && item.daysLeft(today) <= 365,
          )
          .toList(),
    _AnniversaryFilter.passed =>
      items
          .where(
            (item) => DateTime(
              today.year,
              item.date.month,
              item.date.day,
            ).isBefore(DateTime(today.year, today.month, today.day)),
          )
          .toList(),
  };
}

_AnniversaryProgress _anniversaryProgress(
  AppAnniversary anniversary,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  var next = DateTime(today.year, anniversary.date.month, anniversary.date.day);
  if (next.isBefore(today)) {
    next = DateTime(
      today.year + 1,
      anniversary.date.month,
      anniversary.date.day,
    );
  }
  final previous = DateTime(
    next.year - 1,
    anniversary.date.month,
    anniversary.date.day,
  );
  final passed = today.difference(previous).inDays.clamp(0, 366).toInt();
  final left = next.difference(today).inDays.clamp(0, 366).toInt();
  final total = passed + left;
  return _AnniversaryProgress(
    ratio: total == 0 ? 1 : passed / total,
    passedDays: passed,
    leftDays: left,
  );
}

Color _colorOf(String value) {
  return _anniversaryColors
      .firstWhere(
        (item) => item.value == value,
        orElse: () => _anniversaryColors.first,
      )
      .color;
}

Color _categoryColor(String value) {
  return switch (_normalizeCategory(value)) {
    'love' => const Color(0xFFFF7397),
    'birthday' => const Color(0xFFFFA65B),
    'life' => const Color(0xFFFFBD5F),
    'travel' => const Color(0xFF82D69A),
    'study' => const Color(0xFF86B4F8),
    _ => const Color(0xFFC5A5F8),
  };
}

IconData _categoryIcon(String value) {
  return _anniversaryCategories
      .firstWhere(
        (item) => item.value == _normalizeCategory(value),
        orElse: () => _anniversaryCategories.last,
      )
      .icon;
}

String _categoryLabel(String value) {
  return _anniversaryCategories
      .firstWhere(
        (item) => item.value == _normalizeCategory(value),
        orElse: () => _anniversaryCategories.last,
      )
      .label;
}

String _normalizeCategory(String value) {
  return switch (value) {
    'family' => 'life',
    'custom' => 'other',
    _ => value,
  };
}

String _variantFor(String category) {
  return switch (_normalizeCategory(category)) {
    'birthday' => 'reminder',
    'life' => 'reading',
    'travel' => 'travel',
    'study' => 'reading',
    'other' => 'flowers',
    _ => 'flowers',
  };
}

MascotSceneVariant _variantOf(String value) {
  return switch (value) {
    'reading' => MascotSceneVariant.reading,
    'reminder' => MascotSceneVariant.reminder,
    'travel' => MascotSceneVariant.travel,
    'flowers' => MascotSceneVariant.flowers,
    _ => MascotSceneVariant.snack,
  };
}

String _formatDateCn(DateTime value) {
  return '${value.year}年${value.month.toString().padLeft(2, '0')}月${value.day.toString().padLeft(2, '0')}日';
}

String _formatDateDot(DateTime value) {
  return '${value.year}.${value.month.toString().padLeft(2, '0')}.${value.day.toString().padLeft(2, '0')}';
}

String _weekdayLabel(DateTime date) {
  return switch (date.weekday) {
    DateTime.monday => '周一',
    DateTime.tuesday => '周二',
    DateTime.wednesday => '周三',
    DateTime.thursday => '周四',
    DateTime.friday => '周五',
    DateTime.saturday => '周六',
    _ => '周日',
  };
}

String _colorLabel(String value) {
  return switch (value) {
    'purple' => '紫色',
    'orange' => '橙色',
    'yellow' => '黄色',
    'green' => '绿色',
    'blue' => '蓝色',
    'lavender' => '淡紫',
    _ => '粉色',
  };
}

bool _categoryExists(String value) {
  final normalized = _normalizeCategory(value);
  return _anniversaryCategories.any((item) => item.value == normalized);
}

bool _colorExists(String value) {
  return _anniversaryColors.any((item) => item.value == value);
}
