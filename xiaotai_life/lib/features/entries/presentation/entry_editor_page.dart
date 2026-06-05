import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/app_data_store.dart';
import '../../../core/media_backup/media_backup_service.dart';
import 'diary_book_ui.dart';

class EntryEditorPage extends StatefulWidget {
  const EntryEditorPage({this.initialEntry, super.key});

  final AppEntry? initialEntry;

  @override
  State<EntryEditorPage> createState() => _EntryEditorPageState();
}

class _EntryEditorPageState extends State<EntryEditorPage> {
  static const _mediaPicker = MethodChannel('xiaotai_life/media_picker');

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final List<String> _imagePaths = [];
  String _kind = 'diary';
  String _mood = '开心';
  String _moodEmoji = '😊';
  String _tag = '日常';
  final Set<String> _extraTags = {};
  String? _location;
  bool _favorite = false;
  bool _saving = false;
  bool _pickingImages = false;

  bool get _editing => widget.initialEntry != null;

  @override
  void initState() {
    super.initState();
    final entry = widget.initialEntry;
    if (entry != null) {
      _titleController.text = entry.title;
      _contentController.text = _plainEntryContent(entry);
      _kind = diaryKindForTab(entry.kind);
      DiaryMoodOption? knownMood;
      for (final option in diaryMoodOptions) {
        if (option.label == entry.mood) {
          knownMood = option;
          break;
        }
      }
      if (knownMood != null) {
        _mood = knownMood.label;
        _moodEmoji = knownMood.emoji;
      } else {
        _mood = entry.mood.isEmpty ? '开心' : entry.mood;
        _moodEmoji = entry.moodEmoji;
      }
      final label = entry.kindLabel?.trim();
      if (label != null && diaryTagOptions.contains(label)) {
        _tag = label;
      }
      _extraTags.addAll(_entryTags(entry));
      _location = _entryLocation(entry);
      _favorite = entry.favorite;
      _imagePaths.addAll(entry.imagePaths.take(3));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DiaryBookFrame(
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  DiaryTopBar(
                    title: _editing ? '编辑记录' : '新建记录',
                    left: _editing
                        ? DiaryIconButton(
                            icon: Icons.chevron_left_rounded,
                            onTap: () => context.pop(false),
                          )
                        : InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => context.pop(false),
                            child: const SizedBox(
                              width: 44,
                              height: 36,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '取消',
                                  style: TextStyle(
                                    color: DiaryBookPalette.ink,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                    right: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _saving ? null : () => _saveEntry(draft: true),
                      child: const SizedBox(
                        width: 56,
                        height: 36,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '存草稿',
                            style: TextStyle(
                              color: DiaryBookPalette.deepPurple,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DiaryTypeTabs(
                    selected: _kind,
                    onChanged: (value) => setState(() => _kind = value),
                  ),
                  const SizedBox(height: 22),
                  DiaryTextFieldBox(
                    controller: _titleController,
                    hint: '请输入标题...',
                    counter: '${_titleController.text.length}/30',
                    height: 46,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  DiaryTextFieldBox(
                    controller: _contentController,
                    hint: '今天发生了什么呢...',
                    counter: '${_contentController.text.length}/1000',
                    minLines: 6,
                    maxLines: 7,
                    height: _editing ? 128 : 150,
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_imagePaths.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _ImageStrip(
                      imagePaths: _imagePaths,
                      picking: _pickingImages,
                      onAdd: _pickImages,
                      onRemove: (path) =>
                          setState(() => _imagePaths.remove(path)),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      DiaryActionPill(
                        icon: Icons.image_outlined,
                        label: '添加图片',
                        onTap: _pickImages,
                      ),
                      const SizedBox(width: 8),
                      DiaryActionPill(
                        icon: Icons.location_on_outlined,
                        label: '添加位置',
                        onTap: _editLocation,
                      ),
                      const SizedBox(width: 8),
                      DiaryActionPill(
                        icon: Icons.sell_outlined,
                        label: '添加标签',
                        onTap: _addExtraTag,
                      ),
                    ],
                  ),
                  if (_location != null) ...[
                    const SizedBox(height: 12),
                    _LocationBar(
                      location: _location!,
                      onClear: () => setState(() => _location = null),
                    ),
                  ],
                  if (_extraTags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _ExtraTagBar(
                      tags: _extraTags.toList(growable: false),
                      onRemove: (tag) => setState(() => _extraTags.remove(tag)),
                    ),
                  ],
                  const SizedBox(height: 22),
                  const _SectionLabel('今日心情'),
                  const SizedBox(height: 10),
                  DiaryMoodSelector(
                    selected: _mood,
                    onChanged: (option) {
                      setState(() {
                        _mood = option.label;
                        _moodEmoji = option.emoji;
                      });
                    },
                  ),
                  const SizedBox(height: 18),
                  const _SectionLabel('添加标签'),
                  const SizedBox(height: 10),
                  DiaryTagRow(
                    selected: _tag,
                    onChanged: (tag) => setState(() => _tag = tag),
                  ),
                ],
              ),
            ),
            Positioned(
              right: -4,
              bottom: 42,
              child: IgnorePointer(child: DiaryMascotCorner(size: 72)),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: DiaryPrimaryButton(
                label: _saving ? '保存中' : '保存',
                enabled: !_saving,
                onTap: () => _saveEntry(),
              ),
            ),
          ],
        ),
      ),
    );
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
        _showReservedTip(error.message ?? '暂时无法打开图片选择器');
      }
    } finally {
      if (mounted) {
        setState(() => _pickingImages = false);
      }
    }
  }

  Future<void> _saveEntry({bool draft = false}) async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (!draft && title.isEmpty) {
      _showReservedTip('先写一个标题吧');
      return;
    }
    if (draft && title.isEmpty && content.isEmpty && _imagePaths.isEmpty) {
      _showReservedTip('至少写一点内容再存草稿');
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    final initialEntry = widget.initialEntry;
    final store = await AppLocalStore.create();
    final mediaIds = await _resolveImageMediaIds(
      store: store,
      paths: _imagePaths,
      initialEntry: initialEntry,
    );
    await store.upsertEntry(
      AppEntry(
        id: initialEntry?.id ?? 'entry_${now.microsecondsSinceEpoch}',
        kind: _kind,
        kindLabel: _tag,
        title: title.isEmpty ? '未命名草稿' : title,
        content: content.isEmpty && !draft ? '今天也有值得记录的小事。' : content,
        mood: _mood,
        moodEmoji: _moodEmoji,
        location: _location,
        tags: List.unmodifiable(_extraTags),
        draft: draft,
        imagePaths: List.unmodifiable(_imagePaths),
        imageMediaIds: List.unmodifiable(mediaIds),
        createdAt: initialEntry?.createdAt ?? now,
        favorite: _favorite,
        mascotVariant: _variantFor(_kind),
      ),
    );
    if (mounted) {
      context.pop(true);
    }
  }

  Future<List<String>> _resolveImageMediaIds({
    required AppLocalStore store,
    required List<String> paths,
    required AppEntry? initialEntry,
  }) async {
    if (paths.isEmpty) {
      return const [];
    }
    final session = store.getAuthSession();
    final deviceId = store.getSyncDeviceId();
    final pathToId = <String, String>{};
    if (initialEntry != null) {
      for (var i = 0; i < initialEntry.imagePaths.length; i++) {
        final id = i < initialEntry.imageMediaIds.length
            ? initialEntry.imageMediaIds[i]
            : '';
        if (id.isNotEmpty) {
          pathToId[initialEntry.imagePaths[i]] = id;
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
        deviceId: deviceId,
        accessToken: session.accessToken,
      );
      result.add(id ?? '');
    }
    return result;
  }

  Future<void> _editLocation() async {
    _showReservedTip('正在获取当前位置...');
    try {
      var permission = await Geolocator.checkPermission().timeout(
        const Duration(seconds: 3),
        onTimeout: () => LocationPermission.unableToDetermine,
      );
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission().timeout(
          const Duration(seconds: 8),
          onTimeout: () => LocationPermission.denied,
        );
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        _showReservedTip('请先允许定位权限后再添加位置');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _location =
            '当前位置 ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      });
    } catch (_) {
      if (mounted) {
        _showReservedTip('定位失败，请检查系统定位服务');
      }
    }
  }

  Future<void> _addExtraTag() async {
    final value = await _showEntryTextSheet(
      title: '添加标签',
      hintText: '输入自定义标签',
      maxLength: 10,
    );
    if (value == null || value.isEmpty || !mounted) {
      return;
    }
    setState(() => _extraTags.add(value));
  }

  Future<String?> _showEntryTextSheet({
    required String title,
    required String hintText,
    required int maxLength,
  }) {
    final controller = TextEditingController();
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(18, 0, 18, bottomInset + 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: DiaryBookPalette.deepPurple.withValues(alpha: .16),
                  blurRadius: 28,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: DiaryBookPalette.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLength: maxLength,
                    decoration: InputDecoration(
                      hintText: hintText,
                      filled: true,
                      fillColor: const Color(0xFFF8F5FF),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(
                          color: DiaryBookPalette.lavenderLine,
                        ),
                      ),
                    ),
                    onSubmitted: (text) =>
                        Navigator.of(context).pop(text.trim()),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: () =>
                              Navigator.of(context).pop(controller.text.trim()),
                          child: const Text('添加'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).whenComplete(controller.dispose);
  }

  void _showReservedTip(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _variantFor(String kind) {
    return switch (kind) {
      'list' => 'reminder',
      'mood' => 'flowers',
      _ => 'travel',
    };
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: DiaryBookPalette.ink,
        fontSize: 13,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _ImageStrip extends StatelessWidget {
  const _ImageStrip({
    required this.imagePaths,
    required this.picking,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> imagePaths;
  final bool picking;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 70,
      child: Row(
        children: [
          for (final path in imagePaths) ...[
            SizedBox(
              width: 70,
              height: 70,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(child: DiaryImageBox(path: path, radius: 10)),
                  Positioned(
                    top: -6,
                    right: -6,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onRemove(path),
                      child: Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: DiaryBookPalette.ink,
                          size: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (imagePaths.length < 3)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: picking ? null : onAdd,
              child: Container(
                width: 44,
                height: 70,
                alignment: Alignment.center,
                child: Icon(
                  picking ? Icons.hourglass_empty_rounded : Icons.add_rounded,
                  color: DiaryBookPalette.purple,
                  size: 25,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LocationBar extends StatelessWidget {
  const _LocationBar({required this.location, required this.onClear});

  final String location;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F5FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.location_on_outlined,
            color: DiaryBookPalette.purple,
            size: 17,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              location,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: DiaryBookPalette.subText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onClear,
            child: const Icon(
              Icons.close_rounded,
              color: DiaryBookPalette.subText,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExtraTagBar extends StatelessWidget {
  const _ExtraTagBar({required this.tags, required this.onRemove});

  final List<String> tags;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags
          .map(
            (tag) => InputChip(
              label: Text(tag),
              onDeleted: () => onRemove(tag),
              deleteIcon: const Icon(Icons.close_rounded, size: 15),
              backgroundColor: const Color(0xFFF2ECFF),
              side: const BorderSide(color: Color(0xFFE1D4FF)),
              labelStyle: const TextStyle(
                color: DiaryBookPalette.deepPurple,
                fontWeight: FontWeight.w800,
              ),
            ),
          )
          .toList(),
    );
  }
}

String _plainEntryContent(AppEntry entry) {
  return entry.content
      .replaceAll(RegExp(r'\[location:[^\]]+\]'), '')
      .replaceAll(RegExp(r'\[tags:[^\]]+\]'), '')
      .trim()
      .replaceAll(RegExp(r'\n{3,}'), '\n\n');
}

String? _entryLocation(AppEntry entry) {
  final location = entry.location?.trim();
  if (location != null && location.isNotEmpty) {
    return location;
  }
  return RegExp(
    r'\[location:([^\]]+)\]',
  ).firstMatch(entry.content)?.group(1)?.trim();
}

List<String> _entryTags(AppEntry entry) {
  if (entry.tags.isNotEmpty) {
    return entry.tags;
  }
  final marker = RegExp(r'\[tags:([^\]]+)\]').firstMatch(entry.content);
  if (marker == null) {
    return const [];
  }
  return marker
      .group(1)!
      .split(',')
      .map((tag) => tag.trim())
      .where((tag) => tag.isNotEmpty)
      .toList();
}
