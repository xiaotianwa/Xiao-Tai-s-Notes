import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/app_data_store.dart';
import '../../../core/media_backup/media_backup_service.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../entries/presentation/diary_book_ui.dart';

const _memoPurple = Color(0xFF9B70F1);
const _memoPink = Color(0xFFFF7D98);
const _memoInk = Color(0xFF181A33);
const _memoMuted = Color(0xFF8C90A5);
const _memoBorder = Color(0xFFEDE7F8);

enum _MemoView { list, editor, moodCards }

enum _MemoListFilter { all, memo, pinned }

class MemoPage extends StatefulWidget {
  const MemoPage({super.key});

  @override
  State<MemoPage> createState() => _MemoPageState();
}

class _MemoPageState extends State<MemoPage> {
  static const _mediaPicker = MethodChannel('xiaotai_life/media_picker');

  late Future<AppLocalStore> _storeFuture;
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _selectedTags = <String>{'学习'};
  final List<String> _imagePaths = [];
  _MemoView _view = _MemoView.list;
  _MemoListFilter _listFilter = _MemoListFilter.all;
  AppMemo? _editingMemo;
  int? _moodCardFilter;
  DateTime _selectedDate = DateTime.now();
  DateTime? _remindAt;
  String _memoQuery = '';
  bool _pickingImages = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _storeFuture = AppLocalStore.create();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppLocalStore>(
      future: _storeFuture,
      builder: (context, snapshot) {
        final store = snapshot.data;
        final storedMemos = store?.getMemos() ?? const <AppMemo>[];
        final memos = storedMemos;
        final filteredMemos = _filteredMemos(memos);
        return _MemoFrame(
          child: switch (_view) {
            _MemoView.editor => _MemoEditorScreen(
              storeReady: store != null,
              editing: _editingMemo != null,
              titleController: _titleController,
              contentController: _contentController,
              selectedTags: _selectedTags,
              selectedDate: _selectedDate,
              remindAt: _remindAt,
              imagePaths: _imagePaths,
              pickingImages: _pickingImages,
              saving: _saving,
              onBack: _goList,
              onSave: () => _saveMemo(store),
              onDraft: () => _saveMemo(store, draft: true),
              onDelete: _editingMemo == null
                  ? null
                  : () => _confirmDelete(store, _editingMemo!),
              onTagTap: _toggleTag,
              onReminderTap: _showReservedReminder,
              onDateTap: _pickMemoDate,
              onImageTap: _pickImages,
              onRemoveImage: (path) => setState(() => _imagePaths.remove(path)),
              onReservedAddTag: _addCustomTag,
            ),
            _MemoView.moodCards => _MoodCardsScreen(
              memos: _moodFilteredMemos(memos),
              selectedMoodFilter: _moodCardFilter,
              onBack: _goList,
              onAdd: _startAdding,
              onFilter: () => setState(() => _moodCardFilter = null),
              onMoodFilterChanged: (index) =>
                  setState(() => _moodCardFilter = index),
            ),
            _MemoView.list => _MemoListScreen(
              memos: filteredMemos,
              count: filteredMemos.length,
              searchQuery: _memoQuery,
              selectedFilter: _listFilter,
              onClearSearch: () => setState(() => _memoQuery = ''),
              onAdd: _startAdding,
              onEdit: _startEditing,
              onDelete: (memo) => _confirmDelete(store, memo),
              onTogglePin: (memo) => _togglePin(store, memo),
              onFilterChanged: _setListFilter,
              onSearch: _openMemoSearch,
              onMenu: _showReservedMenu,
            ),
          },
        );
      },
    );
  }

  void _startAdding() {
    setState(() {
      _editingMemo = null;
      _selectedTags
        ..clear()
        ..add('学习');
      _imagePaths.clear();
      _selectedDate = DateTime.now();
      _remindAt = null;
      _titleController.clear();
      _contentController.clear();
      _view = _MemoView.editor;
    });
  }

  void _startEditing(AppMemo memo) {
    setState(() {
      _editingMemo = memo;
      _selectedTags
        ..clear()
        ..addAll(_tagsFor(memo));
      _imagePaths
        ..clear()
        ..addAll(memo.imagePaths.take(3));
      _selectedDate = memo.updatedAt;
      _remindAt = _memoRemindAt(memo);
      _titleController.text = memo.title;
      _contentController.text = _plainMemoContent(memo);
      _view = _MemoView.editor;
    });
  }

  void _goList() {
    setState(() {
      _view = _MemoView.list;
      _editingMemo = null;
      _saving = false;
    });
  }

  Future<void> _saveMemo(AppLocalStore? store, {bool draft = false}) async {
    if (store == null || _saving) {
      return;
    }
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty && content.isEmpty) {
      _showTip('至少写一点内容');
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    final existing = _editingMemo;
    final mediaIds = await _resolveImageMediaIds(
      store: store,
      paths: _imagePaths,
      existing: existing,
    );
    final memo = AppMemo(
      id: existing?.id ?? 'memo_${now.microsecondsSinceEpoch}',
      title: title.isEmpty ? '未命名备忘' : title,
      content: content,
      createdAt: existing?.createdAt ?? _selectedDate,
      updatedAt: DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        now.hour,
        now.minute,
        now.second,
      ),
      mood: null,
      tags: List.unmodifiable(_selectedTags),
      remindAt: _remindAt,
      imagePaths: List.unmodifiable(_imagePaths),
      imageMediaIds: List.unmodifiable(mediaIds),
      draft: draft,
      pinned: existing?.pinned ?? false,
    );
    await store.upsertMemo(memo);
    await _syncMemoReminder(memo);
    if (!mounted) {
      return;
    }
    setState(() {
      _storeFuture = Future.value(store);
      _saving = false;
      _editingMemo = null;
      _view = _MemoView.list;
    });
    _showTip(draft ? '已保存为草稿' : '已保存');
  }

  Future<List<String>> _resolveImageMediaIds({
    required AppLocalStore store,
    required List<String> paths,
    required AppMemo? existing,
  }) async {
    if (paths.isEmpty) {
      return const [];
    }
    final session = store.getAuthSession();
    final pathToId = <String, String>{};
    if (existing != null) {
      for (var i = 0; i < existing.imagePaths.length; i++) {
        final id = i < existing.imageMediaIds.length
            ? existing.imageMediaIds[i]
            : '';
        if (id.isNotEmpty) {
          pathToId[existing.imagePaths[i]] = id;
        }
      }
    }
    final result = <String>[];
    for (final path in paths) {
      final cached = pathToId[path];
      if (cached != null && cached.isNotEmpty) {
        result.add(cached);
        continue;
      }
      if (session == null) {
        result.add('');
        continue;
      }
      final id = await MediaBackupService.instance.uploadOneReturningId(
        path: path,
        deviceId: store.getSyncDeviceId(),
        accessToken: session.accessToken,
      );
      result.add(id ?? '');
    }
    return result;
  }

  Future<void> _syncMemoReminder(AppMemo memo) async {
    if (memo.remindAt == null || memo.draft) {
      await LocalNotificationService.instance.cancelMemoReminder(memo.id);
      return;
    }
    await LocalNotificationService.instance.scheduleMemoReminder(memo);
  }

  Future<void> _togglePin(AppLocalStore? store, AppMemo memo) async {
    if (store == null) {
      return;
    }
    await store.upsertMemo(
      memo.copyWith(pinned: !memo.pinned, updatedAt: DateTime.now()),
    );
    if (mounted) {
      setState(() => _storeFuture = Future.value(store));
    }
  }

  Future<void> _confirmDelete(AppLocalStore? store, AppMemo memo) async {
    if (store == null) {
      _goList();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0xAA201C35),
      builder: (context) => _DeleteMemoDialog(memo: memo),
    );
    if (confirmed != true) {
      return;
    }
    await store.deleteMemo(memo.id);
    await LocalNotificationService.instance.cancelMemoReminder(memo.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _storeFuture = Future.value(store);
      _editingMemo = null;
      _view = _MemoView.list;
    });
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  List<AppMemo> _filteredMemos(List<AppMemo> memos) {
    final base = switch (_listFilter) {
      _MemoListFilter.all => memos,
      _MemoListFilter.memo => memos.where((memo) => !memo.draft).toList(),
      _MemoListFilter.pinned => memos.where((memo) => memo.pinned).toList(),
    };
    final query = _memoQuery.trim();
    if (query.isEmpty) {
      return base;
    }
    return base
        .where(
          (memo) =>
              memo.title.contains(query) ||
              memo.content.contains(query) ||
              (memo.mood ?? '').contains(query) ||
              _tagsFor(memo).any((tag) => tag.contains(query)),
        )
        .toList();
  }

  void _setListFilter(_MemoListFilter filter) {
    setState(() {
      _listFilter = filter;
      _view = _MemoView.list;
    });
  }

  List<AppMemo> _moodFilteredMemos(List<AppMemo> memos) {
    final filter = _moodCardFilter;
    if (filter == null) {
      return memos;
    }
    return memos.where((memo) => _moodIndexFor(memo) == filter).toList();
  }

  Future<void> _pickImages() async {
    final remaining = 3 - _imagePaths.length;
    if (remaining <= 0 || _pickingImages) {
      return;
    }
    setState(() => _pickingImages = true);
    try {
      final picked = await _mediaPicker.invokeListMethod<String>('pickImages', {
        'maxCount': remaining,
      });
      if (!mounted) {
        return;
      }
      final additions = (picked ?? [])
          .where((path) => !_imagePaths.contains(path))
          .take(remaining)
          .toList();
      setState(() => _imagePaths.addAll(additions));
    } on PlatformException catch (error) {
      if (mounted) {
        _showTip(error.message ?? '暂时无法打开图片选择器');
      }
    } finally {
      if (mounted) {
        setState(() => _pickingImages = false);
      }
    }
  }

  Future<void> _openMemoSearch() async {
    final controller = TextEditingController(text: _memoQuery);
    final query = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('搜索备忘'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入标题、内容或标签',
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
    setState(() => _memoQuery = query);
  }

  Future<void> _pickMemoDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
      helpText: '选择备忘日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _selectedDate = picked);
  }

  Future<void> _addCustomTag() async {
    final controller = TextEditingController();
    final tag = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加标签'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 8,
          decoration: const InputDecoration(
            hintText: '输入标签名称',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (tag == null || tag.isEmpty || !mounted) {
      return;
    }
    setState(() => _selectedTags.add(tag));
  }

  void _showReservedMenu() => _showTip('当前按更新时间排序');

  Future<void> _showReservedReminder() async {
    final initial = _remindAt ?? DateTime.now().add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
      helpText: '选择提醒日期',
      cancelText: '取消',
      confirmText: '下一步',
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) {
      return;
    }
    setState(() {
      _remindAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _showTip(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _MemoFrame extends StatelessWidget {
  const _MemoFrame({required this.child});

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
            colors: [Color(0x20FFFFFF), Color(0x12F9F4FF), Color(0x18FFFFFF)],
            stops: [0, .48, 1],
          ),
        ),
        child: SafeArea(bottom: false, child: child),
      ),
    );
  }
}

class _MemoListScreen extends StatelessWidget {
  const _MemoListScreen({
    required this.memos,
    required this.count,
    required this.searchQuery,
    required this.selectedFilter,
    required this.onClearSearch,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePin,
    required this.onFilterChanged,
    required this.onSearch,
    required this.onMenu,
  });

  final List<AppMemo> memos;
  final int count;
  final String searchQuery;
  final _MemoListFilter selectedFilter;
  final VoidCallback onClearSearch;
  final VoidCallback onAdd;
  final ValueChanged<AppMemo> onEdit;
  final ValueChanged<AppMemo> onDelete;
  final ValueChanged<AppMemo> onTogglePin;
  final ValueChanged<_MemoListFilter> onFilterChanged;
  final VoidCallback onSearch;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
          children: [
            _MemoTopBar(
              title: '备忘录',
              onBack: () {
                if (context.canPop()) {
                  context.pop();
                  return;
                }
                Navigator.of(context).maybePop();
              },
              onSearch: onSearch,
              onMenu: onMenu,
              onAdd: onAdd,
            ),
            const SizedBox(height: 14),
            _MemoTabs(
              selectedFilter: selectedFilter,
              onFilterChanged: onFilterChanged,
            ),
            const SizedBox(height: 16),
            if (searchQuery.trim().isNotEmpty) ...[
              _MemoSearchNotice(query: searchQuery, onClear: onClearSearch),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                const Text(
                  '按更新时间',
                  style: TextStyle(
                    color: _memoInk,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: _memoInk,
                ),
                const Spacer(),
                Text(
                  '共 $count 条',
                  style: const TextStyle(
                    color: _memoMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (memos.isEmpty)
              _MemoEmptyCard(onAdd: onAdd)
            else
              ...memos.map(
                (memo) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _MemoListCard(
                    memo: memo,
                    onTap: () => onEdit(memo),
                    onDelete: () => onDelete(memo),
                    onTogglePin: () => onTogglePin(memo),
                  ),
                ),
              ),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _MemoBottomNav(selected: '备忘'),
        ),
      ],
    );
  }
}

class _MemoSearchNotice extends StatelessWidget {
  const _MemoSearchNotice({required this.query, required this.onClear});

  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: _memoPurple.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _memoPurple.withValues(alpha: .14)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: _memoPurple, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '搜索：$query',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _memoPurple,
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

class _MemoEmptyCard extends StatelessWidget {
  const _MemoEmptyCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 34, 18, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _memoBorder),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, color: _memoMuted, size: 34),
          const SizedBox(height: 10),
          const Text(
            '没有找到备忘',
            style: TextStyle(
              color: _memoInk,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '点上方新建，记下需要提醒的小事',
            style: TextStyle(
              color: _memoMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
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
                color: _memoPurple,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_note_rounded, color: Colors.white, size: 17),
                  SizedBox(width: 5),
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
          ),
        ],
      ),
    );
  }
}

class _MemoTopBar extends StatelessWidget {
  const _MemoTopBar({
    required this.title,
    this.onBack,
    this.onSave,
    this.onSearch,
    this.onMenu,
    this.onAdd,
  });

  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onSave;
  final VoidCallback? onSearch;
  final VoidCallback? onMenu;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _memoInk,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          Positioned(
            left: 0,
            child: onBack == null
                ? const SizedBox(width: 40, height: 40)
                : IconButton(
                    onPressed: onBack,
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: _memoInk,
                    ),
                  ),
          ),
          Positioned(
            right: 0,
            child: Row(
              children: [
                if (onSearch != null)
                  IconButton(
                    tooltip: '搜索',
                    onPressed: onSearch,
                    icon: const Icon(Icons.search_rounded, color: _memoInk),
                  ),
                if (onMenu != null)
                  IconButton(
                    tooltip: '菜单',
                    onPressed: onMenu,
                    icon: const Icon(Icons.menu_rounded, color: _memoInk),
                  ),
                if (onAdd != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: _MemoCreateButton(onTap: onAdd!),
                  ),
                if (onSave != null)
                  TextButton(
                    onPressed: onSave,
                    child: Text(
                      '保存',
                      style: const TextStyle(
                        color: _memoPurple,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
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

class _MemoCreateButton extends StatelessWidget {
  const _MemoCreateButton({required this.onTap});

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
          color: _memoPurple,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _memoPurple.withValues(alpha: .22),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_note_rounded, color: Colors.white, size: 17),
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

class _MemoTabs extends StatelessWidget {
  const _MemoTabs({
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  final _MemoListFilter selectedFilter;
  final ValueChanged<_MemoListFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MemoTabChip(
          label: '全部',
          selected: selectedFilter == _MemoListFilter.all,
          onTap: () => onFilterChanged(_MemoListFilter.all),
        ),
        _MemoTabChip(
          label: '备忘',
          selected: selectedFilter == _MemoListFilter.memo,
          onTap: () => onFilterChanged(_MemoListFilter.memo),
        ),
        _MemoTabChip(
          label: '置顶',
          selected: selectedFilter == _MemoListFilter.pinned,
          onTap: () => onFilterChanged(_MemoListFilter.pinned),
        ),
      ],
    );
  }
}

class _MemoTabChip extends StatelessWidget {
  const _MemoTabChip({
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? _memoPurple : const Color(0xFFF3F1F6),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : _memoMuted,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MemoListCard extends StatelessWidget {
  const _MemoListCard({
    required this.memo,
    required this.onTap,
    required this.onDelete,
    required this.onTogglePin,
  });

  final AppMemo memo;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;

  @override
  Widget build(BuildContext context) {
    final tags = _tagsFor(memo).take(2).toList(growable: false);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 86),
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .92),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: memo.pinned
                ? _memoPurple.withValues(alpha: .32)
                : _memoBorder,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F7657AF),
              blurRadius: 14,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (memo.pinned)
                        Container(
                          height: 20,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: _memoPurple.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.push_pin,
                                color: _memoPurple,
                                size: 12,
                              ),
                              SizedBox(width: 3),
                              Text(
                                '置顶',
                                style: TextStyle(
                                  color: _memoPurple,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (memo.pinned) const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          memo.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _memoInk,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _previewText(memo),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF656A7B),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    _formatShortDate(memo.updatedAt),
                    style: const TextStyle(
                      color: _memoMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                  if (tags.isNotEmpty ||
                      memo.remindAt != null ||
                      memo.imagePaths.isNotEmpty ||
                      memo.draft) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (memo.draft)
                          const _MemoMetaChip(
                            icon: Icons.edit_note_rounded,
                            label: '草稿',
                          ),
                        for (final tag in tags)
                          _MemoMetaChip(
                            icon: Icons.local_offer_outlined,
                            label: tag,
                          ),
                        if (memo.remindAt != null)
                          _MemoMetaChip(
                            icon: Icons.notifications_none_rounded,
                            label: _formatShortDate(memo.remindAt!),
                          ),
                        if (memo.imagePaths.isNotEmpty)
                          _MemoMetaChip(
                            icon: Icons.photo_library_outlined,
                            label: '${memo.imagePaths.length} 张图',
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    IconButton(
                      constraints: const BoxConstraints(
                        minWidth: 30,
                        minHeight: 30,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: onTogglePin,
                      icon: Icon(
                        memo.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                        color: memo.pinned
                            ? _memoPurple
                            : AppColors.textTertiary,
                        size: 16,
                      ),
                    ),
                    IconButton(
                      constraints: const BoxConstraints(
                        minWidth: 30,
                        minHeight: 30,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: onDelete,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.textTertiary,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoMetaChip extends StatelessWidget {
  const _MemoMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F4FB),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: _memoMuted),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              color: _memoMuted,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoEditorScreen extends StatelessWidget {
  const _MemoEditorScreen({
    required this.storeReady,
    required this.editing,
    required this.titleController,
    required this.contentController,
    required this.selectedTags,
    required this.selectedDate,
    required this.remindAt,
    required this.imagePaths,
    required this.pickingImages,
    required this.saving,
    required this.onBack,
    required this.onSave,
    required this.onDraft,
    required this.onDelete,
    required this.onTagTap,
    required this.onReminderTap,
    required this.onDateTap,
    required this.onImageTap,
    required this.onRemoveImage,
    required this.onReservedAddTag,
  });

  final bool storeReady;
  final bool editing;
  final TextEditingController titleController;
  final TextEditingController contentController;
  final Set<String> selectedTags;
  final DateTime selectedDate;
  final DateTime? remindAt;
  final List<String> imagePaths;
  final bool pickingImages;
  final bool saving;
  final VoidCallback onBack;
  final VoidCallback onSave;
  final VoidCallback onDraft;
  final VoidCallback? onDelete;
  final ValueChanged<String> onTagTap;
  final VoidCallback onReminderTap;
  final VoidCallback onDateTap;
  final VoidCallback onImageTap;
  final ValueChanged<String> onRemoveImage;
  final VoidCallback onReservedAddTag;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 26),
      children: [
        _MemoTopBar(
          title: editing ? '编辑备忘录' : '新建备忘录',
          onBack: onBack,
          onSave: storeReady && !saving ? onSave : null,
        ),
        const SizedBox(height: 12),
        _MemoTextField(
          controller: titleController,
          hint: '请输入标题...',
          maxLength: 30,
        ),
        const SizedBox(height: 12),
        _MemoTextField(
          controller: contentController,
          hint: '记录一下想做的事或此刻的想法吧~',
          maxLength: 300,
          minHeight: 116,
          maxLines: 5,
        ),
        const SizedBox(height: 18),
        const _EditorSectionLabel('添加标签'),
        const SizedBox(height: 10),
        _TagSelector(
          selectedTags: selectedTags,
          onTagTap: onTagTap,
          onAddTap: onReservedAddTag,
        ),
        const SizedBox(height: 18),
        _EditorInfoRow(
          label: '设置提醒',
          value: remindAt == null
              ? '不提醒'
              : '${_formatDateYmd(remindAt!)} ${_formatTimeHm(remindAt!)}',
          onTap: onReminderTap,
        ),
        _EditorInfoRow(
          label: '选择日期',
          value:
              '${_formatDateYmd(selectedDate)} ${_weekdayText(selectedDate)}',
          onTap: onDateTap,
        ),
        const SizedBox(height: 16),
        const _EditorSectionLabel('添加图片'),
        const SizedBox(height: 10),
        _ImageAttachRow(
          imagePaths: imagePaths,
          picking: pickingImages,
          onAttach: onImageTap,
          onRemove: onRemoveImage,
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            if (editing) ...[
              Expanded(
                child: _OutlineMemoButton(
                  label: '删除',
                  color: _memoPink,
                  onTap: onDelete,
                ),
              ),
              const SizedBox(width: 14),
            ] else ...[
              Expanded(
                child: _OutlineMemoButton(
                  label: '存为草稿',
                  color: _memoPurple,
                  onTap: storeReady && !saving ? onDraft : null,
                ),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: _FilledMemoButton(
                label: saving ? '保存中...' : '保存',
                onTap: storeReady && !saving ? onSave : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Align(
          alignment: Alignment.centerRight,
          child: _EditorFooterMark(),
        ),
      ],
    );
  }
}

class _EditorFooterMark extends StatelessWidget {
  const _EditorFooterMark();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _memoPurple.withValues(alpha: .1),
        shape: BoxShape.circle,
      ),
      child: const SizedBox(
        width: 56,
        height: 56,
        child: Icon(Icons.auto_awesome_rounded, color: _memoPurple, size: 26),
      ),
    );
  }
}

class _MemoTextField extends StatelessWidget {
  const _MemoTextField({
    required this.controller,
    required this.hint,
    required this.maxLength,
    this.minHeight = 52,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLength;
  final double minHeight;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _memoBorder),
      ),
      child: TextField(
        controller: controller,
        maxLength: maxLength,
        maxLines: maxLines,
        style: const TextStyle(
          color: _memoInk,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
        decoration: InputDecoration(
          hintText: hint,
          counterText: '',
          border: InputBorder.none,
          contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          hintStyle: const TextStyle(
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _EditorSectionLabel extends StatelessWidget {
  const _EditorSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: _memoInk,
        fontSize: 13,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );
  }
}

class _TagSelector extends StatelessWidget {
  const _TagSelector({
    required this.selectedTags,
    required this.onTagTap,
    required this.onAddTap,
  });

  final Set<String> selectedTags;
  final ValueChanged<String> onTagTap;
  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    final tags = [
      ..._memoTags,
      ...selectedTags.where((tag) => !_memoTags.contains(tag)),
    ];
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: [
        for (final tag in tags)
          _TagChip(
            label: tag,
            selected: selectedTags.contains(tag),
            onTap: () => onTagTap(tag),
          ),
        _AddChip(onTap: onAddTap),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
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
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? _memoPurple.withValues(alpha: .16)
              : const Color(0xFFF2F1F4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? _memoPurple : const Color(0xFF6E7181),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _AddChip extends StatelessWidget {
  const _AddChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 34,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF2F1F4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.add_rounded, size: 18, color: _memoMuted),
      ),
    );
  }
}

class _EditorInfoRow extends StatelessWidget {
  const _EditorInfoRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _memoBorder)),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: _memoInk,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                color: _memoMuted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: _memoMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageAttachRow extends StatelessWidget {
  const _ImageAttachRow({
    required this.imagePaths,
    required this.picking,
    required this.onAttach,
    required this.onRemove,
  });

  final List<String> imagePaths;
  final bool picking;
  final VoidCallback onAttach;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final path in imagePaths) ...[
          SizedBox(
            width: 78,
            height: 78,
            child: Stack(
              children: [
                Positioned.fill(child: DiaryImageBox(path: path, radius: 12)),
                Positioned(
                  top: 4,
                  right: 4,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onRemove(path),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: _memoInk,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
        ],
        if (imagePaths.length < 3)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: picking ? null : onAttach,
            child: Container(
              width: 78,
              height: 78,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _memoBorder,
                  style: BorderStyle.solid,
                ),
              ),
              child: picking
                  ? const Icon(
                      Icons.hourglass_empty_rounded,
                      color: _memoMuted,
                      size: 24,
                    )
                  : imagePaths.isNotEmpty
                  ? const Icon(Icons.add_rounded, color: _memoMuted, size: 28)
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_camera_outlined,
                          color: AppColors.textTertiary,
                          size: 24,
                        ),
                        SizedBox(height: 6),
                        Text(
                          '点击添加图片',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
      ],
    );
  }
}

class _OutlineMemoButton extends StatelessWidget {
  const _OutlineMemoButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 54),
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: .55)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

class _FilledMemoButton extends StatelessWidget {
  const _FilledMemoButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 54),
        backgroundColor: _memoPurple,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

class _MoodCardsScreen extends StatelessWidget {
  const _MoodCardsScreen({
    required this.memos,
    required this.selectedMoodFilter,
    required this.onBack,
    required this.onAdd,
    required this.onFilter,
    required this.onMoodFilterChanged,
  });

  final List<AppMemo> memos;
  final int? selectedMoodFilter;
  final VoidCallback onBack;
  final VoidCallback onAdd;
  final VoidCallback onFilter;
  final ValueChanged<int> onMoodFilterChanged;

  @override
  Widget build(BuildContext context) {
    final cards = _moodCardItems(memos);
    return RepaintBoundary(
      child: ColoredBox(
        color: const Color(0xFFF9F4FF),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 110),
              children: [
                _MemoTopBar(
                  title: '心情卡片',
                  onBack: onBack,
                  onMenu: onFilter,
                  onAdd: onAdd,
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _MoodFilterChip(
                        label: '全部',
                        selected: selectedMoodFilter == null,
                        onTap: onFilter,
                      ),
                      for (var index = 0; index < _moodOptions.length; index++)
                        _MoodCircleChip(
                          mood: _moodOptions[index],
                          selected: selectedMoodFilter == index,
                          onTap: () => onMoodFilterChanged(index),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: cards.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: .78,
                  ),
                  itemBuilder: (context, index) =>
                      _MoodCard(item: cards[index]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodFilterChip extends StatelessWidget {
  const _MoodFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        margin: const EdgeInsets.only(right: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _memoPurple : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _memoBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _memoMuted,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _MoodCircleChip extends StatelessWidget {
  const _MoodCircleChip({
    required this.mood,
    required this.selected,
    required this.onTap,
  });

  final _MoodOption mood;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.only(right: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: mood.color.withValues(alpha: .14),
          shape: BoxShape.circle,
          border: Border.all(color: selected ? _memoPurple : _memoBorder),
        ),
        child: Icon(mood.icon, color: mood.color, size: 17),
      ),
    );
  }
}

class _MoodCard extends StatelessWidget {
  const _MoodCard({required this.item});

  final _MoodCardItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: .22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: item.color.withValues(alpha: .28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _memoInk,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
              Icon(item.icon, color: item.color, size: 20),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Text(
              item.content,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF646978),
                fontSize: 12,
                height: 1.55,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          Row(
            children: [
              Text(
                item.time,
                style: const TextStyle(
                  color: _memoMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const Spacer(),
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: .22),
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, color: item.color, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemoBottomNav extends StatelessWidget {
  const _MemoBottomNav({required this.selected});

  final String selected;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.home_outlined, '首页'),
      (Icons.pie_chart_outline_rounded, '统计'),
      (Icons.book_outlined, '日记'),
      (Icons.work_outline_rounded, '备忘'),
      (Icons.person_outline_rounded, '我的'),
    ];
    return Container(
      height: 76,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .96),
        boxShadow: const [
          BoxShadow(
            color: Color(0x13765AAF),
            blurRadius: 18,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: Row(
        children: items.map((item) {
          final active = item.$2 == selected;
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  item.$1,
                  color: active ? _memoPurple : AppColors.textTertiary,
                  size: 22,
                ),
                const SizedBox(height: 3),
                Text(
                  item.$2,
                  style: TextStyle(
                    color: active ? _memoPurple : AppColors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _DeleteMemoDialog extends StatelessWidget {
  const _DeleteMemoDialog({required this.memo});

  final AppMemo memo;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 34),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 30,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.translate(
              offset: const Offset(0, -36),
              child: const _DeleteMemoIcon(),
            ),
            Transform.translate(
              offset: const Offset(0, -24),
              child: Column(
                children: [
                  const Text(
                    '删除备忘',
                    style: TextStyle(
                      color: _memoInk,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '确定要删除“${memo.title}”吗？\n删除后将无法恢复。',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF4B5062),
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 46),
                            backgroundColor: const Color(0xFFF5F3F6),
                            foregroundColor: _memoMuted,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 46),
                            backgroundColor: _memoPink,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text('删除'),
                        ),
                      ),
                    ],
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

class _DeleteMemoIcon extends StatelessWidget {
  const _DeleteMemoIcon();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _memoPink.withValues(alpha: .18),
        shape: BoxShape.circle,
      ),
      child: const SizedBox(
        width: 72,
        height: 72,
        child: Icon(Icons.delete_outline_rounded, color: _memoPink, size: 34),
      ),
    );
  }
}

class _MoodOption {
  const _MoodOption({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;
}

class _MoodCardItem {
  const _MoodCardItem({
    required this.title,
    required this.content,
    required this.time,
    required this.color,
    required this.icon,
  });

  final String title;
  final String content;
  final String time;
  final Color color;
  final IconData icon;
}

const _moodOptions = [
  _MoodOption(
    label: '开心',
    color: Color(0xFFFFB246),
    icon: Icons.sentiment_very_satisfied_rounded,
  ),
  _MoodOption(
    label: '平静',
    color: Color(0xFFFFC95F),
    icon: Icons.sentiment_satisfied_rounded,
  ),
  _MoodOption(
    label: '普通',
    color: Color(0xFFE8B95C),
    icon: Icons.sentiment_neutral_rounded,
  ),
  _MoodOption(
    label: '低落',
    color: Color(0xFF70B7F7),
    icon: Icons.sentiment_dissatisfied_rounded,
  ),
  _MoodOption(
    label: '难过',
    color: Color(0xFF8E93F1),
    icon: Icons.mood_bad_rounded,
  ),
  _MoodOption(
    label: '焦虑',
    color: Color(0xFFB997F6),
    icon: Icons.psychology_outlined,
  ),
];

const _memoTags = ['学习', '生活', '工作', '阅读'];

List<_MoodCardItem> _moodCardItems(List<AppMemo> memos) {
  return memos.take(6).map((memo) {
    final mood = _moodFor(memo);
    return _MoodCardItem(
      title: memo.title,
      content: _previewText(memo),
      time: _formatShortDate(memo.updatedAt),
      color: mood.color,
      icon: mood.icon,
    );
  }).toList();
}

_MoodOption _moodFor(AppMemo memo) {
  return _moodOptions[_moodIndexFor(memo)];
}

int _moodIndexFor(AppMemo memo) {
  final moodLabel = memo.mood;
  if (moodLabel != null && moodLabel.trim().isNotEmpty) {
    final index = _moodOptions.indexWhere((mood) => mood.label == moodLabel);
    if (index != -1) {
      return index;
    }
  }
  final source = '${memo.title}${memo.content}${memo.id}';
  final sum = source.codeUnits.fold<int>(0, (value, code) => value + code);
  return sum % _moodOptions.length;
}

List<String> _tagsFor(AppMemo memo) {
  return memo.tags.where((tag) => tag.trim().isNotEmpty).toList();
}

String _previewText(AppMemo memo) {
  return _plainMemoContent(memo).replaceAll(RegExp(r'\s+'), ' ');
}

String _plainMemoContent(AppMemo memo) {
  return memo.content
      .replaceAll('[image]', '')
      .replaceAll('[draft]', '')
      .replaceAll(RegExp(r'\[mood:[^\]]+\]'), '')
      .replaceAll(RegExp(r'\[tags:[^\]]+\]'), '')
      .replaceAll(RegExp(r'\[remindAt:[^\]]+\]'), '')
      .trim()
      .replaceAll(RegExp(r'\n{3,}'), '\n\n');
}

DateTime? _memoRemindAt(AppMemo memo) {
  if (memo.remindAt != null) {
    return memo.remindAt;
  }
  final marker = RegExp(r'\[remindAt:([^\]]+)\]').firstMatch(memo.content);
  final value = marker?.group(1);
  return value == null ? null : DateTime.tryParse(value);
}

String _formatDateYmd(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _weekdayText(DateTime date) {
  const labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  return labels[date.weekday - 1];
}

String _formatTimeHm(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatShortDate(DateTime time) {
  final month = time.month.toString().padLeft(2, '0');
  final day = time.day.toString().padLeft(2, '0');
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$month-$day $hour:$minute';
}
