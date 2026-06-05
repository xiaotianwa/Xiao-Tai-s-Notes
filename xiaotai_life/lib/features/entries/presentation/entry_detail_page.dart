import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/data/app_data_store.dart';
import 'diary_book_ui.dart';

class EntryDetailPage extends StatefulWidget {
  const EntryDetailPage({required this.entry, super.key});

  final AppEntry entry;

  @override
  State<EntryDetailPage> createState() => _EntryDetailPageState();
}

class _EntryDetailPageState extends State<EntryDetailPage> {
  late AppEntry _entry;
  AppLocalStore? _store;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    AppLocalStore.create().then((store) {
      if (mounted) {
        setState(() => _store = store);
      }
    });
  }

  Future<void> _toggleFavorite() async {
    final store = _store;
    if (store == null) {
      return;
    }
    final next = _entry.copyWith(favorite: !_entry.favorite);
    await store.upsertEntry(next);
    if (mounted) {
      setState(() {
        _entry = next;
        _changed = true;
      });
    }
  }

  Future<void> _edit() async {
    final saved = await context.push<bool>(
      AppRoutes.entryEditor,
      extra: _entry,
    );
    if (saved == true) {
      final store = await AppLocalStore.create();
      AppEntry? latest;
      for (final item in store.getEntries()) {
        if (item.id == _entry.id) {
          latest = item;
          break;
        }
      }
      if (mounted) {
        setState(() {
          _entry = latest ?? _entry;
          _store = store;
          _changed = true;
        });
      }
    }
  }

  Future<void> _delete() async {
    final store = _store;
    if (store == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .62),
      builder: (context) => _DeleteEntryConfirmDialog(entry: _entry),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await store.deleteEntry(_entry.id);
    if (mounted) {
      context.pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.pop(_changed);
        }
      },
      child: DiaryBookFrame(
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
                  children: [
                    DiaryTopBar(
                      title: '',
                      left: DiaryIconButton(
                        icon: Icons.chevron_left_rounded,
                        onTap: () => context.pop(_changed),
                      ),
                      right: Row(
                        children: [
                          DiaryIconButton(
                            icon: _entry.favorite
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: DiaryBookPalette.yellow,
                            onTap: _store == null ? null : _toggleFavorite,
                          ),
                          DiaryIconButton(
                            icon: Icons.more_horiz_rounded,
                            onTap: _store == null ? null : _delete,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${_entry.title} \u00b7 ${_entry.moodEmoji}',
                      style: const TextStyle(
                        color: DiaryBookPalette.ink,
                        fontSize: 20,
                        height: 1.25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${diaryDate(_entry.createdAt)}  ${diaryTime(_entry.createdAt)}',
                      style: const TextStyle(
                        color: DiaryBookPalette.subText,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if ((_entry.location ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            color: DiaryBookPalette.purple,
                            size: 15,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _entry.location!.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: DiaryBookPalette.subText,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    _DetailGallery(paths: _entry.imagePaths),
                    const SizedBox(height: 16),
                    Text(
                      _entry.content.isEmpty
                          ? '\u4eca\u5929\u4e5f\u6709\u503c\u5f97\u8bb0\u5f55\u7684\u5c0f\u4e8b\u3002'
                          : _entry.content,
                      style: const TextStyle(
                        color: DiaryBookPalette.ink,
                        fontSize: 14,
                        height: 1.75,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (_entry.draft)
                          const DiaryTagChip(
                            label: '\u8349\u7a3f',
                            selected: true,
                          ),
                        DiaryTagChip(
                          label: _entry.kindLabel?.trim().isNotEmpty == true
                              ? _entry.kindLabel!.trim()
                              : '\u65e5\u5e38',
                          selected: true,
                        ),
                        for (final tag in _entry.tags)
                          DiaryTagChip(label: tag, selected: false),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: DiaryMascotCorner(size: 86),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Row(
                  children: [
                    Expanded(
                      child: _BottomActionButton(
                        icon: Icons.favorite_rounded,
                        label: _entry.favorite
                            ? '\u5df2\u6536\u85cf'
                            : '\u6536\u85cf',
                        selected: _entry.favorite,
                        onTap: _store == null ? null : _toggleFavorite,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _BottomActionButton(
                        icon: Icons.edit_outlined,
                        label: '\u7f16\u8f91',
                        selected: false,
                        onTap: _store == null ? null : _edit,
                      ),
                    ),
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

class _DetailGallery extends StatelessWidget {
  const _DetailGallery({required this.paths});

  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) {
      return const SizedBox.shrink();
    }
    final visibleCount = paths.length > 3 ? 3 : paths.length;
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < visibleCount; i++) ...[
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(11),
                  onTap: () => _openImagePreview(context, i),
                  child: SizedBox(
                    height: 70,
                    child: DiaryImageBox(
                      path: paths[i],
                      radius: 11,
                      overlay: i == 2 && paths.length > 3
                          ? Container(
                              color: Colors.black.withValues(alpha: .35),
                              alignment: Alignment.center,
                              child: Text(
                                '+${paths.length - 2}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              if (i != visibleCount - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }

  void _openImagePreview(BuildContext context, int initialIndex) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .82),
      builder: (context) => _EntryImagePreview(
        paths: paths,
        initialIndex: initialIndex.clamp(0, paths.length - 1),
      ),
    );
  }
}

class _EntryImagePreview extends StatefulWidget {
  const _EntryImagePreview({required this.paths, required this.initialIndex});

  final List<String> paths;
  final int initialIndex;

  @override
  State<_EntryImagePreview> createState() => _EntryImagePreviewState();
}

class _EntryImagePreviewState extends State<_EntryImagePreview> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.paths.length,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (context, index) {
                return Center(
                  child: InteractiveViewer(
                    minScale: .8,
                    maxScale: 4,
                    child: Image.file(
                      File(widget.paths[index]),
                      key: ValueKey(widget.paths[index]),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white70,
                        size: 48,
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton.filled(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .42),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_index + 1} / ${widget.paths.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
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

class _BottomActionButton extends StatelessWidget {
  const _BottomActionButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? DiaryBookPalette.pink.withValues(alpha: .34)
                : const Color(0xFFF0EEF5),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 14,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? DiaryBookPalette.pink : DiaryBookPalette.purple,
              size: 18,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? DiaryBookPalette.pink
                    : DiaryBookPalette.purple,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteEntryConfirmDialog extends StatelessWidget {
  const _DeleteEntryConfirmDialog({required this.entry});

  final AppEntry entry;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      backgroundColor: Colors.transparent,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 58),
            padding: const EdgeInsets.fromLTRB(22, 76, 22, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 30,
                  offset: Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '\u786e\u5b9a\u8981\u5220\u9664\u8fd9\u7bc7\u65e5\u8bb0\u5417\uff1f',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: DiaryBookPalette.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '\u5220\u9664\u540e\u4f1a\u4ece\u672c\u5730\u548c\u540c\u6b65\u961f\u5217\u4e2d\u79fb\u9664\uff0c\u65e0\u6cd5\u6062\u590d\u3002',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: DiaryBookPalette.subText,
                    fontSize: 13,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: _DialogButton(
                        label: '\u53d6\u6d88',
                        color: const Color(0xFFF7F5FA),
                        textColor: DiaryBookPalette.ink,
                        onTap: () => Navigator.of(context).pop(false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DialogButton(
                        label: '\u5220\u9664',
                        color: DiaryBookPalette.pink,
                        textColor: Colors.white,
                        onTap: () => Navigator.of(context).pop(true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            child: Container(
              width: 132,
              height: 104,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF4E9), Color(0xFFFFF8FF)],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A8B5CF6),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: const DiaryMascotCorner(size: 92),
            ),
          ),
        ],
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
  });

  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
