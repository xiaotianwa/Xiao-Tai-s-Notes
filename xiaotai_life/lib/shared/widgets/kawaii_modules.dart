import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme_tokens.dart';
import 'prototype_ui.dart';

class KawaiiDailyToolbox extends StatelessWidget {
  const KawaiiDailyToolbox({
    required this.date,
    this.locationLabel = '未定位',
    this.noteTitle = '今日便签',
    this.noteSubtitle = '写下今天的小事',
    this.onAdd,
    this.onEdit,
    this.onExport,
    this.onMore,
    super.key,
  });

  final DateTime date;
  final String locationLabel;
  final String noteTitle;
  final String noteSubtitle;
  final VoidCallback? onAdd;
  final VoidCallback? onEdit;
  final VoidCallback? onExport;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeTokens;
    final dateText =
        '${date.year}年${date.month}月${date.day}日  ${_twoDigits(date.hour)}:${_twoDigits(date.minute)}';
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ModuleHeader(
            title: '今日小卡',
            trailing: Icon(
              Icons.favorite_rounded,
              color: tokens.accent,
              size: 18,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = constraints.maxWidth < 360
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: tileWidth,
                    child: _MiniModuleTile(
                      icon: Icons.location_on_rounded,
                      iconColor: AppColors.primary,
                      title: '位置',
                      value: locationLabel,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _MiniModuleTile(
                      icon: Icons.schedule_rounded,
                      iconColor: AppColors.warning,
                      title: '时间',
                      value: dateText,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _MiniModuleTile(
                      icon: Icons.sticky_note_2_rounded,
                      iconColor: AppColors.info,
                      title: noteTitle,
                      value: noteSubtitle,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          const KawaiiStatusTagStrip(),
          const SizedBox(height: 14),
          KawaiiActionButtons(
            onAdd: onAdd,
            onEdit: onEdit,
            onExport: onExport,
            onMore: onMore,
          ),
          const SizedBox(height: 14),
          const KawaiiMoodPalette(),
        ],
      ),
    );
  }
}

class KawaiiRecordTypeModule extends StatelessWidget {
  const KawaiiRecordTypeModule({
    this.onTextTap,
    this.onImageTap,
    this.onStickerTap,
    this.onVoiceTap,
    super.key,
  });

  final VoidCallback? onTextTap;
  final VoidCallback? onImageTap;
  final VoidCallback? onStickerTap;
  final VoidCallback? onVoiceTap;

  @override
  Widget build(BuildContext context) {
    final records = [
      _RecordSpec(
        icon: Icons.edit_note_rounded,
        color: AppColors.primary,
        title: '文字记录',
        subtitle: '记录备忘和日常',
        onTap: onTextTap,
      ),
      _RecordSpec(
        icon: Icons.photo_camera_rounded,
        color: AppColors.warning,
        title: '图片记录',
        subtitle: '收藏今天的画面',
        onTap: onImageTap,
      ),
      _RecordSpec(
        icon: Icons.auto_awesome_rounded,
        color: AppColors.info,
        title: '贴纸记录',
        subtitle: '用素材装点页面',
        onTap: onStickerTap,
      ),
      _RecordSpec(
        icon: Icons.mic_none_rounded,
        color: AppColors.accent,
        title: '语音记录',
        subtitle: '留下一小段声音',
        onTap: onVoiceTap,
      ),
    ];
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ModuleHeader(title: '记录方式'),
          const SizedBox(height: 8),
          ...records.map((record) => _RecordTypeRow(record: record)),
        ],
      ),
    );
  }
}

class KawaiiStickerModule extends StatelessWidget {
  const KawaiiStickerModule({super.key});

  @override
  Widget build(BuildContext context) {
    final stickers = [
      _StickerSpec(Icons.cruelty_free_rounded, AppColors.primary, '兔兔'),
      _StickerSpec(Icons.face_3_rounded, AppColors.accent, '女孩'),
      _StickerSpec(Icons.toys_rounded, AppColors.warning, '小熊'),
      _StickerSpec(Icons.photo_camera_rounded, AppColors.primary, '相机'),
      _StickerSpec(Icons.local_florist_rounded, AppColors.success, '植物'),
      _StickerSpec(Icons.cake_rounded, AppColors.warning, '蛋糕'),
      _StickerSpec(Icons.favorite_rounded, AppColors.primary, '爱心'),
      _StickerSpec(Icons.filter_vintage_rounded, AppColors.accent, '小花'),
    ];
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ModuleHeader(title: '可爱贴纸'),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final sticker in stickers) ...[
                  _StickerTile(sticker: sticker),
                  const SizedBox(width: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class KawaiiWeatherModule extends StatelessWidget {
  const KawaiiWeatherModule({super.key});

  @override
  Widget build(BuildContext context) {
    final weather = [
      _WeatherSpec(Icons.wb_sunny_rounded, AppColors.warning, '晴天'),
      _WeatherSpec(Icons.wb_cloudy_rounded, AppColors.accent, '多云'),
      _WeatherSpec(Icons.cloud_rounded, AppColors.info, '阴天'),
      _WeatherSpec(Icons.water_drop_rounded, AppColors.info, '小雨'),
      _WeatherSpec(Icons.thunderstorm_rounded, AppColors.textSecondary, '大雨'),
      _WeatherSpec(Icons.ac_unit_rounded, AppColors.success, '雪天'),
    ];
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ModuleHeader(title: '天气心情'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [for (final item in weather) _WeatherTile(item: item)],
          ),
        ],
      ),
    );
  }
}

class KawaiiStatusTagStrip extends StatelessWidget {
  const KawaiiStatusTagStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final tags = [
      _TagSpec('工作日', AppColors.success, Icons.work_outline_rounded, true),
      _TagSpec('周末', AppColors.info, Icons.weekend_rounded, true),
      _TagSpec('节日', AppColors.warning, Icons.celebration_rounded, false),
      _TagSpec('旅行', AppColors.primary, Icons.flight_takeoff_rounded, false),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InlineLabel(
          icon: Icons.sell_outlined,
          title: '状态标签',
          color: AppColors.success,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in tags)
              TinyPill(
                label: tag.label,
                icon: tag.icon,
                color: tag.color,
                selected: tag.selected,
              ),
          ],
        ),
      ],
    );
  }
}

class KawaiiActionButtons extends StatelessWidget {
  const KawaiiActionButtons({
    this.onAdd,
    this.onEdit,
    this.onExport,
    this.onMore,
    super.key,
  });

  final VoidCallback? onAdd;
  final VoidCallback? onEdit;
  final VoidCallback? onExport;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionSpec(Icons.add_rounded, AppColors.primary, '新增', onAdd),
      _ActionSpec(Icons.edit_rounded, AppColors.accent, '编辑', onEdit),
      _ActionSpec(Icons.ios_share_rounded, AppColors.warning, '导出', onExport),
      _ActionSpec(
        Icons.more_horiz_rounded,
        AppColors.textSecondary,
        '更多',
        onMore,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InlineLabel(
          icon: Icons.touch_app_outlined,
          title: '快捷操作',
          color: AppColors.primary,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final action in actions) ...[
              _RoundActionButton(action: action),
              const SizedBox(width: 12),
            ],
          ],
        ),
      ],
    );
  }
}

class KawaiiMoodPalette extends StatelessWidget {
  const KawaiiMoodPalette({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = [
      AppColors.primary,
      AppColors.warning,
      AppColors.info,
      AppColors.success,
      AppColors.accent,
      AppColors.textTertiary,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InlineLabel(
          icon: Icons.palette_outlined,
          title: '心情颜色',
          color: AppColors.accent,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final color in colors) ...[
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: softShadowSmall,
                ),
              ),
              const SizedBox(width: 12),
            ],
          ],
        ),
      ],
    );
  }
}

class _ModuleHeader extends StatelessWidget {
  const _ModuleHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeTokens;
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: tokens.primary,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: tokens.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _MiniModuleTile extends StatelessWidget {
  const _MiniModuleTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeTokens;
    return Container(
      constraints: const BoxConstraints(minHeight: 74),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: softShadowSmallFor(tokens),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w900,
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

class _RecordTypeRow extends StatelessWidget {
  const _RecordTypeRow({required this.record});

  final _RecordSpec record;

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeTokens;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: record.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: record.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(record.icon, color: record.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      record.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: tokens.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _StickerTile extends StatelessWidget {
  const _StickerTile({required this.sticker});

  final _StickerSpec sticker;

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeTokens;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: sticker.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: sticker.color.withValues(alpha: 0.22)),
          ),
          child: Icon(sticker.icon, color: sticker.color, size: 25),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 52,
          child: Text(
            sticker.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tokens.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _WeatherTile extends StatelessWidget {
  const _WeatherTile({required this.item});

  final _WeatherSpec item;

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeTokens;
    return SizedBox(
      width: 48,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.icon, color: item.color, size: 28),
          const SizedBox(height: 5),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tokens.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineLabel extends StatelessWidget {
  const _InlineLabel({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeTokens;
    return Row(
      children: [
        Icon(icon, color: color, size: 17),
        const SizedBox(width: 6),
        Text(
          title,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: tokens.textSecondary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({required this.action});

  final _ActionSpec action;

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeTokens;
    return Tooltip(
      message: action.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: action.onTap,
          child: Ink(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: action.color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(color: action.color.withValues(alpha: 0.18)),
              boxShadow: softShadowSmallFor(tokens),
            ),
            child: Icon(action.icon, color: action.color, size: 23),
          ),
        ),
      ),
    );
  }
}

class _RecordSpec {
  const _RecordSpec({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
}

class _StickerSpec {
  const _StickerSpec(this.icon, this.color, this.label);

  final IconData icon;
  final Color color;
  final String label;
}

class _WeatherSpec {
  const _WeatherSpec(this.icon, this.color, this.label);

  final IconData icon;
  final Color color;
  final String label;
}

class _TagSpec {
  const _TagSpec(this.label, this.color, this.icon, this.selected);

  final String label;
  final Color color;
  final IconData icon;
  final bool selected;
}

class _ActionSpec {
  const _ActionSpec(this.icon, this.color, this.label, this.onTap);

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
