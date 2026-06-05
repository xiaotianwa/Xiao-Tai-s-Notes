import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/data/app_data_store.dart';
import '../../../shared/widgets/prototype_ui.dart';
import 'diary_book_ui.dart';

class EntryListPage extends StatefulWidget {
  const EntryListPage({super.key});

  @override
  State<EntryListPage> createState() => _EntryListPageState();
}

class _EntryListPageState extends State<EntryListPage> {
  late Future<AppLocalStore> _storeFuture;
  final _searchController = TextEditingController();
  StreamSubscription<void>? _storeSubscription;
  String _selectedType = 'diary';
  bool _searchOpen = false;

  @override
  void initState() {
    super.initState();
    _storeFuture = AppLocalStore.create();
    _storeSubscription = AppLocalStore.changes.listen((_) {
      if (mounted) {
        setState(() {
          _storeFuture = AppLocalStore.create();
        });
      }
    });
  }

  @override
  void dispose() {
    _storeSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppLocalStore>(
      future: _storeFuture,
      builder: (context, snapshot) {
        final store = snapshot.data;
        final realEntries = store?.getEntries() ?? const <AppEntry>[];
        final entries = _filteredEntries(realEntries);
        return DiaryBookFrame(
          extendBody: true,
          child: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ListView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 116),
                    children: [
                      DiaryTopBar(
                        title: '日记本',
                        left: const SizedBox(width: 36),
                        right: _DiaryTopActions(
                          onSearch: () =>
                              setState(() => _searchOpen = !_searchOpen),
                          onCreate: () => _openEditor(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DiaryTypeTabs(
                        selected: _selectedType,
                        onChanged: (value) =>
                            setState(() => _selectedType = value),
                      ),
                      if (_searchOpen) ...[
                        const SizedBox(height: 12),
                        _SearchField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                      const SizedBox(height: 18),
                      _FilterTitle(
                        selectedType: _selectedType,
                        onTap: _showTypeSheet,
                      ),
                      const SizedBox(height: 9),
                      if (entries.isEmpty)
                        _EmptyDiaryCard(onTap: () => _openEditor())
                      else
                        for (final entry in entries) ...[
                          _DiaryListCard(
                            entry: entry,
                            onTap: () => _openDetail(entry),
                            onFavorite: store == null
                                ? null
                                : () => _toggleFavorite(entry),
                          ),
                          const SizedBox(height: 10),
                        ],
                    ],
                  ),
                ),
                Positioned(
                  left: -2,
                  bottom: 68,
                  child: IgnorePointer(
                    child: DiaryMascotCorner(size: 62, opacity: .92),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<AppEntry> _filteredEntries(List<AppEntry> entries) {
    final keyword = _searchController.text.trim().toLowerCase();
    return entries.where((entry) {
      final typeMatched = diaryKindForTab(entry.kind) == _selectedType;
      final keywordMatched =
          keyword.isEmpty ||
          entry.title.toLowerCase().contains(keyword) ||
          entry.content.toLowerCase().contains(keyword) ||
          entry.mood.toLowerCase().contains(keyword) ||
          (entry.kindLabel?.toLowerCase().contains(keyword) ?? false) ||
          ((entry.location ?? '').toLowerCase().contains(keyword)) ||
          entry.tags.any((tag) => tag.toLowerCase().contains(keyword)) ||
          (entry.draft && '草稿'.contains(keyword));
      return typeMatched && keywordMatched;
    }).toList();
  }

  Future<void> _showTypeSheet() async {
    final next = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _TypeSheet(selected: _selectedType);
      },
    );
    if (next != null && mounted) {
      setState(() => _selectedType = next);
    }
  }

  Future<void> _openEditor([AppEntry? entry]) async {
    final saved = await context.push<bool>(AppRoutes.entryEditor, extra: entry);
    if (saved == true && mounted) {
      setState(() {
        _storeFuture = AppLocalStore.create();
      });
    }
  }

  Future<void> _openDetail(AppEntry entry) async {
    final changed = await context.push<bool>(
      AppRoutes.entryDetail,
      extra: entry,
    );
    if (changed == true && mounted) {
      setState(() {
        _storeFuture = AppLocalStore.create();
      });
    }
  }

  Future<void> _toggleFavorite(AppEntry entry) async {
    final store = await _storeFuture;
    await store.upsertEntry(entry.copyWith(favorite: !entry.favorite));
    if (mounted) {
      setState(() {
        _storeFuture = AppLocalStore.create();
      });
    }
  }
}

class _FilterTitle extends StatelessWidget {
  const _FilterTitle({required this.selectedType, required this.onTap});

  final String selectedType;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = diaryTypeOptions
        .firstWhere((option) => option.value == selectedType)
        .label;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            selectedType == 'diary' ? '全部日记' : '全部$label',
            style: const TextStyle(
              color: DiaryBookPalette.ink,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 2),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: DiaryBookPalette.ink,
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _DiaryTopActions extends StatelessWidget {
  const _DiaryTopActions({required this.onSearch, required this.onCreate});

  final VoidCallback onSearch;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DiaryIconButton(icon: Icons.search_rounded, onTap: onSearch),
        const SizedBox(width: 4),
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onCreate,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: DiaryBookPalette.purple,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x339C72F4),
                  blurRadius: 12,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_note_rounded, color: Colors.white, size: 17),
                SizedBox(width: 4),
                Text(
                  '写一篇',
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
    );
  }
}

class _DiaryListCard extends StatelessWidget {
  const _DiaryListCard({
    required this.entry,
    required this.onTap,
    required this.onFavorite,
  });

  final AppEntry entry;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    return DiarySectionCard(
      padding: const EdgeInsets.fromLTRB(11, 10, 10, 10),
      radius: 15,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  diaryMonthDay(entry.createdAt),
                  style: const TextStyle(
                    color: DiaryBookPalette.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  diaryWeekday(entry.createdAt),
                  style: const TextStyle(
                    color: DiaryBookPalette.subText,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.title} ${entry.moodEmoji}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: DiaryBookPalette.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  entry.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF5E6070),
                    fontSize: 10,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      color: DiaryBookPalette.purple,
                      size: 13,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      diaryTime(entry.createdAt),
                      style: const TextStyle(
                        color: DiaryBookPalette.subText,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if ((entry.location ?? '').trim().isNotEmpty) ...[
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.location_on_outlined,
                        color: DiaryBookPalette.purple,
                        size: 13,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          entry.location!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: DiaryBookPalette.subText,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (entry.draft || entry.tags.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      if (entry.draft)
                        const _EntryMetaChip(
                          icon: Icons.edit_note_rounded,
                          label: '草稿',
                        ),
                      for (final tag in entry.tags.take(2))
                        _EntryMetaChip(icon: Icons.sell_outlined, label: tag),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 58,
            height: 58,
            child: DiaryImageBox(
              path: entry.imagePaths.isEmpty ? null : entry.imagePaths.first,
              radius: 9,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onFavorite,
            child: SizedBox(
              width: 26,
              height: 70,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Icon(
                  entry.favorite
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: entry.favorite
                      ? DiaryBookPalette.yellow
                      : DiaryBookPalette.paleText,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryMetaChip extends StatelessWidget {
  const _EntryMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 21,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0FF),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFE8DCFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: DiaryBookPalette.deepPurple, size: 11),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              color: DiaryBookPalette.deepPurple,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .48),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .78)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            color: DiaryBookPalette.subText,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: const InputDecoration(
                hintText: '搜索日记内容',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeSheet extends StatelessWidget {
  const _TypeSheet({required this.selected});

  final String selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: GlassCard(
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        radius: 24,
        color: Colors.white.withValues(alpha: .42),
        tintColor: DiaryBookPalette.lavender,
        borderColor: Colors.white.withValues(alpha: .82),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in diaryTypeOptions)
              ListTile(
                title: Text(
                  option.label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                trailing: option.value == selected
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: DiaryBookPalette.purple,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(option.value),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDiaryCard extends StatelessWidget {
  const _EmptyDiaryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DiarySectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const DiaryMascotCorner(size: 78, opacity: .9),
            const SizedBox(height: 8),
            const Text(
              '还没有这类记录',
              style: TextStyle(
                color: DiaryBookPalette.ink,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              '点上方写一篇，记录今天的小事吧',
              style: TextStyle(
                color: DiaryBookPalette.subText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: DiaryBookPalette.purple,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.edit_note_rounded,
                      color: Colors.white,
                      size: 17,
                    ),
                    SizedBox(width: 5),
                    Text(
                      '写一篇',
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
      ),
    );
  }
}
