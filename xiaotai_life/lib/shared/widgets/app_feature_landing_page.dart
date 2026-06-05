import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'app_mascot_scene.dart';

class AppFeatureLandingPage extends StatelessWidget {
  const AppFeatureLandingPage({
    required this.title,
    required this.subtitle,
    required this.heroIcon,
    required this.heroTitle,
    required this.heroMessage,
    required this.items,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData heroIcon;
  final String heroTitle;
  final String heroMessage;
  final List<AppFeatureItem> items;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.softPink.withValues(alpha: .16),
              Colors.white.withValues(alpha: .08),
              AppColors.softBlue.withValues(alpha: .14),
            ],
            stops: const [0, .56, 1],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              right: -92,
              top: 110,
              child: _FeatureGlow(size: 230, color: AppColors.softBlue),
            ),
            const Positioned(
              left: -72,
              bottom: 130,
              child: _FeatureGlow(size: 210, color: AppColors.softPink),
            ),
            SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xl,
                  118,
                ),
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                children: [
                  _PageHeader(title: title, subtitle: subtitle),
                  const SizedBox(height: AppSpacing.xl),
                  _HeroCard(
                    icon: heroIcon,
                    title: heroTitle,
                    message: heroMessage,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      Text(
                        '即将开放',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppColors.accent,
                        size: 16,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...items.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _FeatureTile(item: entry.value, index: entry.key),
                    ),
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

class AppFeatureItem {
  const AppFeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(child: Text(title, style: textTheme.headlineMedium)),
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.accent,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: .76),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.surface.withValues(alpha: .72)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.10),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(_headerIcon(title), color: AppColors.primary),
        ),
      ],
    );
  }

  IconData _headerIcon(String title) {
    return switch (title) {
      '记录' => Icons.filter_alt_outlined,
      '生活' => Icons.add,
      '设置' => Icons.wb_sunny_outlined,
      _ => Icons.auto_awesome,
    };
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: AppColors.warmSurface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.surface.withValues(alpha: .74)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.10),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.bottomRight,
              child: FractionallySizedBox(
                widthFactor: 0.72,
                alignment: Alignment.bottomRight,
                child: AppMascotScene(height: 146, showHeart: false),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: SizedBox(
              width: 230,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: .78),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: AppColors.surface.withValues(alpha: .70),
                      ),
                    ),
                    child: Icon(icon, color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(title, style: textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    message,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.6,
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

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.item, required this.index});

  final AppFeatureItem item;
  final int index;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: .74),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surface.withValues(alpha: .70)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .07),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _tileColor(index),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: _iconColor(index), size: 22),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  item.description,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: .78),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Color _tileColor(int index) {
    return switch (index % 4) {
      0 => AppColors.softBlue,
      1 => AppColors.softOrange,
      2 => AppColors.softPink,
      _ => AppColors.softGreen,
    };
  }

  Color _iconColor(int index) {
    return switch (index % 4) {
      0 => AppColors.primary,
      1 => AppColors.warning,
      2 => AppColors.accent,
      _ => AppColors.success,
    };
  }
}

class _FeatureGlow extends StatelessWidget {
  const _FeatureGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .52),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
