import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/data/app_data_store.dart';
import '../../../core/media_backup/media_backup_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_mascot_scene.dart';
import '../../../shared/widgets/prototype_ui.dart';

const _defaultPlaceImage = 'assets/mascot/source/place_default.webp';

const _placeCategories = [
  _PlaceCategory('travel', '旅行', Icons.card_travel_outlined, AppColors.warning),
  _PlaceCategory('date', '约会', Icons.favorite_border, AppColors.accent),
];

class PlacesPage extends StatefulWidget {
  const PlacesPage({super.key});

  @override
  State<PlacesPage> createState() => _PlacesPageState();
}

class _PlacesPageState extends State<PlacesPage> {
  static const _mediaPicker = MethodChannel('xiaotai_life/media_picker');

  late Future<AppLocalStore> _storeFuture;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  AppPlace? _editingPlace;
  bool _showForm = false;
  bool _pickingImage = false;
  String _selectedCategory = 'travel';
  String _formCategory = 'travel';
  String _colorName = 'orange';
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _storeFuture = AppLocalStore.create();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _storeFuture,
      builder: (context, snapshot) {
        final places = snapshot.data?.getPlaces() ?? const <AppPlace>[];
        final visiblePlaces = places
            .where(
              (place) =>
                  _normalizeCategory(place.category) == _selectedCategory,
            )
            .toList();
        return PrototypePage(
          title: '想去地点',
          subtitle: '下一次出发去哪里',
          leading: const PrototypeBackButton(),
          actionIcon: _showForm ? Icons.close : Icons.add,
          onActionTap: _showForm ? _cancelEditing : _startAdding,
          topIllustrationInHeader: true,
          topIllustration: const AppMascotScene(
            height: 72,
            variant: MascotSceneVariant.travel,
            showHeart: false,
          ),
          children: [
            const SizedBox(height: 18),
            _PlaceFilters(
              selectedCategory: _selectedCategory,
              onChanged: (value) => setState(() => _selectedCategory = value),
            ),
            if (_showForm) ...[
              const SizedBox(height: 16),
              _PlaceForm(
                titleController: _titleController,
                descriptionController: _descriptionController,
                editing: _editingPlace != null,
                category: _formCategory,
                imagePath: _imagePath,
                pickingImage: _pickingImage,
                onCategoryChanged: (value) => setState(() {
                  _formCategory = value;
                  _colorName = value == 'date' ? 'pink' : 'orange';
                }),
                onPickImage: _pickImage,
                onRemoveImage: () => setState(() => _imagePath = null),
                onCancel: _cancelEditing,
                onSave: _savePlace,
              ),
            ],
            SectionTitle(
              title: _categoryLabel(_selectedCategory),
              trailing: Text(
                '共 ${visiblePlaces.length} 个',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            _PlaceList(
              places: visiblePlaces,
              onEdit: _startEditing,
              onDelete: _deletePlace,
            ),
          ],
        );
      },
    );
  }

  void _startAdding() {
    setState(() {
      _showForm = true;
      _editingPlace = null;
      _titleController.clear();
      _descriptionController.clear();
      _formCategory = _selectedCategory;
      _colorName = _selectedCategory == 'date' ? 'pink' : 'orange';
      _imagePath = null;
    });
  }

  void _startEditing(AppPlace place) {
    final category = _normalizeCategory(place.category);
    setState(() {
      _showForm = true;
      _editingPlace = place;
      _titleController.text = place.title;
      _descriptionController.text = place.description;
      _formCategory = category;
      _colorName = _colorExists(place.colorName)
          ? place.colorName
          : (category == 'date' ? 'pink' : 'orange');
      _imagePath = place.imagePath;
    });
  }

  void _cancelEditing() {
    setState(() {
      _showForm = false;
      _editingPlace = null;
      _titleController.clear();
      _descriptionController.clear();
      _imagePath = null;
    });
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
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message ?? '暂时无法打开图片选择器')));
    } finally {
      if (mounted) {
        setState(() => _pickingImage = false);
      }
    }
  }

  Future<void> _savePlace() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('先写下地点名称吧')));
      return;
    }
    final store = await _storeFuture;
    final editing = _editingPlace;
    final mediaId = await _resolveImageMediaId(
      store: store,
      path: _imagePath,
      editing: editing,
    );
    await store.upsertPlace(
      AppPlace(
        id: editing?.id ?? 'place_${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        description: description.isEmpty ? '想和你一起去看看' : description,
        category: _formCategory,
        colorName: _colorName,
        imagePath: _imagePath,
        imageMediaId: mediaId,
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedCategory = _formCategory;
      _showForm = false;
      _editingPlace = null;
      _titleController.clear();
      _descriptionController.clear();
      _imagePath = null;
      _storeFuture = AppLocalStore.create();
    });
    _showCenterTip(editing == null ? '地点已添加' : '地点已更新');
  }

  /// 把当前选择的本地图片映射为服务端 mediaId。
  /// - 编辑老地点且图片未变时复用旧的 mediaId，避免重复上传。
  /// - 未登录或上传失败时返回 null，本地仍保留 imagePath，下次同步可重试。
  Future<String?> _resolveImageMediaId({
    required AppLocalStore store,
    required String? path,
    required AppPlace? editing,
  }) async {
    if (path == null || path.trim().isEmpty) {
      return null;
    }
    if (editing != null &&
        editing.imagePath == path &&
        (editing.imageMediaId ?? '').isNotEmpty) {
      return editing.imageMediaId;
    }
    final session = store.getAuthSession();
    if (session == null) {
      return null;
    }
    return MediaBackupService.instance.uploadOneReturningId(
      path: path,
      deviceId: store.getSyncDeviceId(),
      accessToken: session.accessToken,
    );
  }

  Future<void> _deletePlace(AppPlace place) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _DeletePlaceDialog(place: place),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final store = await _storeFuture;
    await store.deletePlace(place.id);
    if (!mounted) {
      return;
    }
    setState(() {
      if (_editingPlace?.id == place.id) {
        _showForm = false;
        _editingPlace = null;
        _titleController.clear();
        _descriptionController.clear();
        _imagePath = null;
      }
      _storeFuture = AppLocalStore.create();
    });
    _showCenterTip('地点已删除');
  }

  void _showCenterTip(String message) {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => IgnorePointer(
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.textPrimary.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(22),
                boxShadow: softShadow,
              ),
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (entry.mounted) {
        entry.remove();
      }
    });
  }
}

class _PlaceFilters extends StatelessWidget {
  const _PlaceFilters({
    required this.selectedCategory,
    required this.onChanged,
  });

  final String selectedCategory;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _placeCategories.map((item) {
        final selected = selectedCategory == item.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: item == _placeCategories.first ? 8 : 0,
              left: item == _placeCategories.last ? 8 : 0,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => onChanged(item.value),
              child: Center(
                child: TinyPill(
                  label: item.label,
                  icon: item.icon,
                  selected: selected,
                  color: selected ? item.color : AppColors.textTertiary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PlaceForm extends StatelessWidget {
  const _PlaceForm({
    required this.titleController,
    required this.descriptionController,
    required this.editing,
    required this.category,
    required this.imagePath,
    required this.pickingImage,
    required this.onCategoryChanged,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.onCancel,
    required this.onSave,
  });

  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final bool editing;
  final String category;
  final String? imagePath;
  final bool pickingImage;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;
  final VoidCallback onCancel;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TinyPill(label: editing ? '编辑地点' : '新的地点', selected: true),
              const Spacer(),
              TextButton(onPressed: onCancel, child: const Text('收起')),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: titleController,
            decoration: _inputDecoration(
              hintText: '例如：海边民宿、城市公园',
              icon: Icons.place_outlined,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descriptionController,
            minLines: 2,
            maxLines: 3,
            decoration: _inputDecoration(
              hintText: '写一句想去这里的理由',
              icon: Icons.notes_outlined,
            ),
          ),
          const SizedBox(height: 14),
          _PlaceImagePicker(
            imagePath: imagePath,
            picking: pickingImage,
            onPick: onPickImage,
            onRemove: onRemoveImage,
          ),
          const SizedBox(height: 14),
          Text('分类', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: _placeCategories.map((item) {
              final selected = item.value == category;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: item == _placeCategories.first ? 8 : 0,
                    left: item == _placeCategories.last ? 8 : 0,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => onCategoryChanged(item.value),
                    child: TinyPill(
                      label: item.label,
                      icon: item.icon,
                      selected: selected,
                      color: selected ? item.color : AppColors.textTertiary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => onSave(),
              icon: const Icon(Icons.check),
              label: Text(editing ? '保存修改' : '保存地点'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceImagePicker extends StatelessWidget {
  const _PlaceImagePicker({
    required this.imagePath,
    required this.picking,
    required this.onPick,
    required this.onRemove,
  });

  final String? imagePath;
  final bool picking;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('地点图片', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 118,
              height: 86,
              child: _PlaceImage(imagePath: imagePath, radius: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasImage ? '已选择 1 张图片' : '未添加时显示默认图片',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: picking ? null : onPick,
                        icon: picking
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add_photo_alternate_outlined),
                        label: Text(hasImage ? '更换图片' : '添加图片'),
                      ),
                      if (hasImage)
                        TextButton(
                          onPressed: onRemove,
                          child: const Text('恢复默认'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PlaceList extends StatelessWidget {
  const _PlaceList({
    required this.places,
    required this.onEdit,
    required this.onDelete,
  });

  final List<AppPlace> places;
  final ValueChanged<AppPlace> onEdit;
  final ValueChanged<AppPlace> onDelete;

  @override
  Widget build(BuildContext context) {
    if (places.isEmpty) {
      return const _EmptyPlaceCard();
    }
    return Column(
      children: places.map((place) {
        final category = _normalizeCategory(place.category);
        final color = _colorOf(place.colorName);
        return SoftCard(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          radius: 18,
          borderColor: color.withValues(alpha: 0.2),
          child: Row(
            children: [
              SizedBox(
                width: 106,
                height: 78,
                child: _PlaceImage(imagePath: place.imagePath, radius: 14),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      place.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TinyPill(
                      label: _categoryLabel(category),
                      icon: _categoryIcon(category),
                      color: _categoryColor(category),
                      selected: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                children: [
                  IconButton(
                    onPressed: () => onEdit(place),
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => onDelete(place),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _PlaceImage extends StatelessWidget {
  const _PlaceImage({required this.imagePath, required this.radius});

  final String? imagePath;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final child = imagePath == null
        ? Image.asset(_defaultPlaceImage, fit: BoxFit.cover)
        : Image.file(
            File(imagePath!),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                Image.asset(_defaultPlaceImage, fit: BoxFit.cover),
          );
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: child);
  }
}

class _EmptyPlaceCard extends StatelessWidget {
  const _EmptyPlaceCard();

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        children: [
          const SizedBox(
            width: 132,
            height: 92,
            child: _PlaceImage(imagePath: null, radius: 20),
          ),
          const SizedBox(height: 12),
          Text('还没有地点', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('点右上角添加一个想去的地方吧', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _DeletePlaceDialog extends StatelessWidget {
  const _DeletePlaceDialog({required this.place});

  final AppPlace place;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border),
          boxShadow: softShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: AppColors.softPink,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.wrong_location_outlined,
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '删除这个地点？',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              place.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '删除后不会再出现在想去地点列表里。',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
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
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: AppColors.surface,
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

class _PlaceCategory {
  const _PlaceCategory(this.value, this.label, this.icon, this.color);

  final String value;
  final String label;
  final IconData icon;
  final Color color;
}

InputDecoration _inputDecoration({
  required String hintText,
  required IconData icon,
}) {
  return InputDecoration(
    hintText: hintText,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: AppColors.background,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppColors.border),
    ),
  );
}

String _normalizeCategory(String value) {
  return _placeCategories.any((item) => item.value == value) ? value : 'travel';
}

String _categoryLabel(String value) {
  return _placeCategories
      .firstWhere(
        (item) => item.value == _normalizeCategory(value),
        orElse: () => _placeCategories.first,
      )
      .label;
}

IconData _categoryIcon(String value) {
  return _placeCategories
      .firstWhere(
        (item) => item.value == _normalizeCategory(value),
        orElse: () => _placeCategories.first,
      )
      .icon;
}

Color _categoryColor(String value) {
  return _placeCategories
      .firstWhere(
        (item) => item.value == _normalizeCategory(value),
        orElse: () => _placeCategories.first,
      )
      .color;
}

Color _colorOf(String value) {
  return switch (value) {
    'pink' => AppColors.accent,
    'green' => AppColors.success,
    _ => AppColors.warning,
  };
}

bool _colorExists(String value) {
  return const ['pink', 'orange', 'green'].contains(value);
}
