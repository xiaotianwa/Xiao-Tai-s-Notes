import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme_tokens.dart';
import '../../../shared/widgets/prototype_ui.dart';

class DiaryBookPalette {
  const DiaryBookPalette._();

  static const ink = Color(0xFF17172A);
  static const deepPurple = Color(0xFF6F50DD);
  static const purple = Color(0xFF9C72F4);
  static const lavender = Color(0xFFF5F0FF);
  static const lavenderLine = Color(0xFFE9DFFF);
  static const subText = Color(0xFF8B8D9B);
  static const paleText = Color(0xFFB8BAC6);
  static const pink = Color(0xFFFF6E9E);
  static const yellow = Color(0xFFFFC543);
  static const blue = Color(0xFF6B8CFF);
  static const surface = Color(0xFFFFFFFF);
  static const pageTop = Color(0xFFF8F2FF);
  static const pageBottom = Color(0xFFFFFBFF);
}

class DiaryTypeOption {
  const DiaryTypeOption(this.value, this.label);

  final String value;
  final String label;
}

const diaryTypeOptions = [
  DiaryTypeOption('diary', '日记'),
  DiaryTypeOption('list', '清单'),
  DiaryTypeOption('mood', '心情'),
  DiaryTypeOption('custom', '其他'),
];

const diaryMoodOptions = [
  DiaryMoodOption('开心', '😊'),
  DiaryMoodOption('平静', '🙂'),
  DiaryMoodOption('难过', '😭'),
  DiaryMoodOption('疲惫', '😔'),
  DiaryMoodOption('生气', '😡'),
];

const diaryTagOptions = ['日常', '学习', '工作', '旅行', '生活'];

class DiaryMoodOption {
  const DiaryMoodOption(this.label, this.emoji);

  final String label;
  final String emoji;
}

class DiaryBookFrame extends StatelessWidget {
  const DiaryBookFrame({
    required this.child,
    this.extendBody = false,
    super.key,
  });

  final Widget child;
  final bool extendBody;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: TextScaler.noScaling),
      child: Scaffold(
        extendBody: extendBody,
        backgroundColor: Colors.transparent,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x10FFFFFF), Color(0x08FFF7FC), Color(0x0AF8F2FF)],
              stops: [0, .48, 1],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class DiaryTopBar extends StatelessWidget {
  const DiaryTopBar({
    required this.title,
    this.left,
    this.right,
    this.height = 42,
    super.key,
  });

  final String title;
  final Widget? left;
  final Widget? right;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(left: 0, child: left ?? const SizedBox(width: 44)),
          Text(
            title,
            style: const TextStyle(
              color: DiaryBookPalette.ink,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          Positioned(right: 0, child: right ?? const SizedBox(width: 44)),
        ],
      ),
    );
  }
}

class DiaryIconButton extends StatelessWidget {
  const DiaryIconButton({
    required this.icon,
    required this.onTap,
    this.color = DiaryBookPalette.ink,
    this.size = 23,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(icon, color: color, size: size),
      ),
    );
  }
}

class DiaryTypeTabs extends StatelessWidget {
  const DiaryTypeTabs({
    required this.selected,
    required this.onChanged,
    this.horizontalPadding = 0,
    super.key,
  });

  final String selected;
  final ValueChanged<String> onChanged;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Row(
        children: [
          for (final option in diaryTypeOptions) ...[
            Expanded(
              child: _DiaryTypeChip(
                label: option.label,
                selected: selected == option.value,
                onTap: () => onChanged(option.value),
              ),
            ),
            if (option != diaryTypeOptions.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _DiaryTypeChip extends StatelessWidget {
  const _DiaryTypeChip({
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
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? DiaryBookPalette.purple : const Color(0xFFF7F5FA),
          borderRadius: BorderRadius.circular(18),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x339C72F4),
                    blurRadius: 13,
                    offset: Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? Colors.white : DiaryBookPalette.ink,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class DiarySectionCard extends StatelessWidget {
  const DiarySectionCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 18,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = GlassCard(
      padding: padding,
      radius: radius,
      color: Colors.white.withValues(alpha: .18),
      tintColor: DiaryBookPalette.lavender,
      borderColor: Colors.white.withValues(alpha: .82),
      blurSigma: 8,
      child: child,
    );
    if (onTap == null) {
      return card;
    }
    return InkWell(
      borderRadius: BorderRadius.circular(radius),
      onTap: onTap,
      child: card,
    );
  }
}

class DiaryTextFieldBox extends StatelessWidget {
  const DiaryTextFieldBox({
    required this.controller,
    required this.hint,
    required this.counter,
    this.minLines = 1,
    this.maxLines = 1,
    this.height,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String hint;
  final String counter;
  final int minLines;
  final int maxLines;
  final double? height;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .88)),
        boxShadow: [
          BoxShadow(
            color: DiaryBookPalette.deepPurple.withValues(alpha: .08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          TextField(
            controller: controller,
            minLines: minLines,
            maxLines: maxLines,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: DiaryBookPalette.paleText,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            style: const TextStyle(
              color: DiaryBookPalette.ink,
              fontSize: 15,
              height: 1.55,
              fontWeight: FontWeight.w800,
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Text(
              counter,
              style: const TextStyle(
                color: DiaryBookPalette.subText,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DiaryMoodSelector extends StatelessWidget {
  const DiaryMoodSelector({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final String selected;
  final ValueChanged<DiaryMoodOption> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final option in diaryMoodOptions) ...[
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onChanged(option),
              child: Column(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F7FA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected == option.label
                            ? DiaryBookPalette.purple
                            : const Color(0xFFF0EEF5),
                        width: selected == option.label ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      option.emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    option.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected == option.label
                          ? DiaryBookPalette.purple
                          : DiaryBookPalette.ink,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (option != diaryMoodOptions.last) const SizedBox(width: 7),
        ],
      ],
    );
  }
}

class DiaryTagRow extends StatelessWidget {
  const DiaryTagRow({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tag in diaryTagOptions)
          DiaryTagChip(
            label: tag,
            selected: selected == tag,
            onTap: () => onChanged(tag),
          ),
      ],
    );
  }
}

class DiaryTagChip extends StatelessWidget {
  const DiaryTagChip({
    required this.label,
    required this.selected,
    this.icon,
    this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(
          minWidth: icon == null ? 46 : 28,
          minHeight: 28,
        ),
        padding: EdgeInsets.symmetric(horizontal: icon == null ? 13 : 8),
        decoration: BoxDecoration(
          color: selected ? DiaryBookPalette.purple : const Color(0xFFF6F4FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? DiaryBookPalette.purple : const Color(0xFFF0EEF5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon == null)
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : DiaryBookPalette.ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              )
            else
              Icon(icon, color: DiaryBookPalette.purple, size: 18),
          ],
        ),
      ),
    );
  }
}

class DiaryActionPill extends StatelessWidget {
  const DiaryActionPill({
    required this.icon,
    required this.label,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF0EEF5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: DiaryBookPalette.purple, size: 17),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: DiaryBookPalette.ink,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DiaryPrimaryButton extends StatelessWidget {
  const DiaryPrimaryButton({
    required this.label,
    required this.onTap,
    this.enabled = true,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: enabled ? onTap : null,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: enabled
              ? const LinearGradient(
                  colors: [Color(0xFFB986FF), Color(0xFF8B5CF6)],
                )
              : null,
          color: enabled ? null : const Color(0xFFD8D2E6),
          boxShadow: enabled
              ? const [
                  BoxShadow(
                    color: Color(0x3A8B5CF6),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
          ),
        ),
      ),
    );
  }
}

class DiaryImageBox extends StatelessWidget {
  const DiaryImageBox({
    this.path,
    this.assetPath = 'assets/mascot/source/place_default.webp',
    this.radius = 12,
    this.overlay,
    super.key,
  });

  final String? path;
  final String assetPath;
  final double radius;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final image = path == null || path!.isEmpty
        ? Image.asset(assetPath, fit: BoxFit.cover)
        : Image.file(
            File(path!),
            key: ValueKey(path),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                Image.asset(assetPath, fit: BoxFit.cover),
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(fit: StackFit.expand, children: [image, ?overlay]),
    );
  }
}

class DiaryMascotCorner extends StatelessWidget {
  const DiaryMascotCorner({this.size = 72, this.opacity = 1, super.key});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeTokens;
    return Opacity(
      opacity: opacity,
      child: Image.asset(
        tokens.assets.homeMascot,
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}

String diaryTypeLabel(String kind, String? kindLabel) {
  final label = kindLabel?.trim();
  if (label != null && label.isNotEmpty) {
    return label;
  }
  return switch (kind) {
    'diary' => '日记',
    'list' => '清单',
    'mood' => '心情',
    'custom' => '其他',
    'food' => '日记',
    'travel' => '日记',
    'idea' => '日记',
    _ => kind,
  };
}

String diaryKindForTab(String kind) {
  return switch (kind) {
    'list' => 'list',
    'mood' => 'mood',
    'custom' => 'custom',
    _ => 'diary',
  };
}

String diaryDate(DateTime value) {
  return '${value.year}.${value.month.toString().padLeft(2, '0')}.${value.day.toString().padLeft(2, '0')}';
}

String diaryTime(DateTime value) {
  return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

String diaryMonthDay(DateTime value) {
  return '${value.month.toString().padLeft(2, '0')}.${value.day.toString().padLeft(2, '0')}';
}

String diaryWeekday(DateTime value) {
  const labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  return labels[value.weekday - 1];
}
