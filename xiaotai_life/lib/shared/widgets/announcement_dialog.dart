import 'package:flutter/material.dart';

import '../../core/announcements/announcement_service.dart';
import '../../core/theme/app_colors.dart';

Future<void> showAnnouncementDialog(
  BuildContext context,
  AppAnnouncement announcement,
) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: '公告',
    barrierColor: Colors.black.withValues(alpha: 0.42),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, _, _) {
      return Center(child: _AnnouncementDialogCard(announcement: announcement));
    },
    transitionBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _AnnouncementDialogCard extends StatelessWidget {
  const _AnnouncementDialogCard({required this.announcement});

  final AppAnnouncement announcement;

  @override
  Widget build(BuildContext context) {
    final style = _AnnouncementStyle.fromType(announcement.type);
    final textTheme = Theme.of(context).textTheme;
    final imageUrl = announcement.imageUrl?.trim();

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        minimum: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: .86),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: AppColors.surface.withValues(alpha: .78),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  blurRadius: 38,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    _AnnouncementCover(
                      imageUrl: AnnouncementService.instance.resolveAssetUrl(
                        imageUrl,
                      ),
                    ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        26,
                        imageUrl == null || imageUrl.isEmpty ? 28 : 22,
                        26,
                        0,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _AnnouncementIcon(style: style),
                          const SizedBox(height: 14),
                          _AnnouncementTypePill(style: style),
                          const SizedBox(height: 14),
                          Text(
                            announcement.title,
                            textAlign: TextAlign.center,
                            style: textTheme.titleLarge?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w900,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              announcement.content,
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(26, 22, 26, 26),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: style.color,
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('知道了'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnnouncementCover extends StatelessWidget {
  const _AnnouncementCover({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            return child;
          }
          return const ColoredBox(
            color: AppColors.warmSurface,
            child: Center(
              child: SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          );
        },
        errorBuilder: (context, _, _) {
          return const ColoredBox(
            color: AppColors.warmSurface,
            child: Center(
              child: Icon(
                Icons.image_not_supported_outlined,
                color: AppColors.textTertiary,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AnnouncementIcon extends StatelessWidget {
  const _AnnouncementIcon({required this.style});

  final _AnnouncementStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(shape: BoxShape.circle, color: style.softColor),
      child: Icon(style.icon, color: style.color, size: 30),
    );
  }
}

class _AnnouncementTypePill extends StatelessWidget {
  const _AnnouncementTypePill({required this.style});

  final _AnnouncementStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: style.softColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        style.label,
        style: TextStyle(
          color: style.color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AnnouncementStyle {
  const _AnnouncementStyle({
    required this.color,
    required this.softColor,
    required this.icon,
    required this.label,
  });

  factory _AnnouncementStyle.fromType(String type) {
    return switch (type) {
      'warning' => const _AnnouncementStyle(
        color: AppColors.warning,
        softColor: AppColors.softOrange,
        icon: Icons.warning_amber_rounded,
        label: '重要提醒',
      ),
      'success' => const _AnnouncementStyle(
        color: AppColors.success,
        softColor: AppColors.softGreen,
        icon: Icons.check_circle_outline_rounded,
        label: '好消息',
      ),
      'error' => const _AnnouncementStyle(
        color: AppColors.danger,
        softColor: AppColors.softPink,
        icon: Icons.error_outline_rounded,
        label: '需要注意',
      ),
      _ => const _AnnouncementStyle(
        color: AppColors.primary,
        softColor: AppColors.softBlue,
        icon: Icons.campaign_outlined,
        label: '公告',
      ),
    };
  }

  final Color color;
  final Color softColor;
  final IconData icon;
  final String label;
}
