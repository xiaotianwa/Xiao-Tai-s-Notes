import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme_tokens.dart';
import 'app_mascot_scene.dart';

class PrototypePage extends StatelessWidget {
  const PrototypePage({
    required this.title,
    required this.subtitle,
    required this.children,
    this.actionIcon = Icons.wb_sunny_outlined,
    this.onActionTap,
    this.leading,
    this.topIllustration,
    this.topIllustrationInHeader = false,
    this.separateHeaderControls = false,
    this.showActionButton = true,
    this.extraActionButtons = const [],
    this.backgroundImageAsset,
    this.titleStyle,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData actionIcon;
  final VoidCallback? onActionTap;
  final Widget? leading;
  final Widget? topIllustration;
  final bool topIllustrationInHeader;
  final bool separateHeaderControls;
  final bool showActionButton;
  final List<Widget> extraActionButtons;
  final String? backgroundImageAsset;
  final TextStyle? titleStyle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeTokens;
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = width < 380 ? 16.0 : 18.0;
    final topPadding = width < 380 ? 12.0 : 16.0;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tokens.surface.withValues(alpha: .06),
              tokens.softPink.withValues(alpha: .04),
              tokens.softBlue.withValues(alpha: .05),
            ],
            stops: const [0, .52, 1],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: -78,
              top: -34,
              child: _PrototypeGlow(
                size: 226,
                color: tokens.accent.withValues(alpha: .08),
              ),
            ),
            Positioned(
              right: -98,
              top: 188,
              child: _PrototypeGlow(
                size: 248,
                color: tokens.primary.withValues(alpha: .06),
              ),
            ),
            Positioned(
              left: -54,
              bottom: 96,
              child: _PrototypeGlow(
                size: 190,
                color: AppColors.info.withValues(alpha: .05),
              ),
            ),
            Positioned.fill(child: _PrototypeSparkles(color: tokens.accent)),
            if (backgroundImageAsset != null || tokens.backdropAsset != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: backgroundImageAsset == null
                        ? tokens.backdropOpacity
                        : 0.035,
                    child: Image.asset(
                      backgroundImageAsset ?? tokens.backdropAsset!,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            SafeArea(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  topPadding,
                  horizontalPadding,
                  118,
                ),
                children: [
                  if (separateHeaderControls) ...[
                    Row(
                      children: [
                        ?leading,
                        const Spacer(),
                        if (showActionButton)
                          PrototypeIconButton(
                            icon: actionIcon,
                            onTap: onActionTap,
                          ),
                        ...extraActionButtons,
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _PrototypeHeaderText(
                            title: title,
                            subtitle: subtitle,
                            titleStyle: titleStyle,
                          ),
                        ),
                        if (topIllustrationInHeader &&
                            topIllustration != null) ...[
                          const SizedBox(width: 12),
                          SizedBox(
                            width: width < 380 ? 96 : 112,
                            child: topIllustration!,
                          ),
                        ],
                      ],
                    ),
                  ] else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (leading != null) ...[
                          leading!,
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: _PrototypeHeaderText(
                            title: title,
                            subtitle: subtitle,
                            titleStyle: titleStyle,
                          ),
                        ),
                        if (topIllustrationInHeader &&
                            topIllustration != null) ...[
                          const SizedBox(width: 8),
                          SizedBox(
                            width: width < 380 ? 82 : 96,
                            child: topIllustration!,
                          ),
                        ],
                        if (showActionButton)
                          PrototypeIconButton(
                            icon: actionIcon,
                            onTap: onActionTap,
                          ),
                        ...extraActionButtons,
                      ],
                    ),
                  if (topIllustration != null && !topIllustrationInHeader) ...[
                    const SizedBox(height: 14),
                    topIllustration!,
                  ],
                  ...children,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrototypeHeaderText extends StatelessWidget {
  const _PrototypeHeaderText({
    required this.title,
    required this.subtitle,
    this.titleStyle,
  });

  final String title;
  final String subtitle;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style:
              titleStyle ??
              Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: tokens.primary,
                fontSize: 25,
                height: 1.16,
              ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: tokens.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class PrototypeIconButton extends StatelessWidget {
  const PrototypeIconButton({
    required this.icon,
    this.color,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeTokens;
    final resolvedColor = color ?? tokens.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: tokens.surface.withValues(alpha: .74),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: tokens.surface.withValues(alpha: .76)),
            boxShadow: softShadowSmallFor(tokens),
          ),
          child: Icon(icon, color: resolvedColor, size: 20),
        ),
      ),
    );
  }
}

class PrototypeBackButton extends StatelessWidget {
  const PrototypeBackButton({this.onTap, super.key});

  final VoidCallback? onTap;

  void _handleTap(BuildContext context) {
    final customTap = onTap;
    if (customTap != null) {
      customTap();
      return;
    }
    if (context.canPop()) {
      context.pop();
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return PrototypeIconButton(
      icon: Icons.chevron_left_rounded,
      color: context.themeTokens.textPrimary,
      onTap: () => _handleTap(context),
    );
  }
}

class SoftCard extends StatelessWidget {
  const SoftCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.color,
    this.borderColor,
    this.radius,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeTokens;
    return GlassCard(
      margin: margin,
      padding: padding,
      radius: radius ?? tokens.shape.cardRadius,
      color: color,
      borderColor: borderColor,
      child: child,
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    this.padding = EdgeInsets.zero,
    this.margin,
    this.radius,
    this.color,
    this.tintColor,
    this.borderColor,
    this.blurSigma = 10,
    this.showSheen = true,
    this.width,
    this.height,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double? radius;
  final Color? color;
  final Color? tintColor;
  final Color? borderColor;
  final double blurSigma;
  final bool showSheen;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeTokens;
    final resolvedRadius = radius ?? tokens.shape.cardRadius;
    final resolvedTint = tintColor ?? tokens.softPink;
    final effectiveBlurSigma = blurSigma.clamp(0, 4).toDouble();
    final baseColor = color ?? tokens.surface.withValues(alpha: .12);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(resolvedRadius),
        boxShadow: [
          BoxShadow(
            color: tokens.primary.withValues(alpha: .14),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: .38),
            blurRadius: 10,
            offset: const Offset(-4, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(resolvedRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: effectiveBlurSigma,
            sigmaY: effectiveBlurSigma,
          ),
          child: Container(
            width: width,
            height: height,
            padding: padding,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(resolvedRadius),
              border: Border.all(
                color: borderColor ?? Colors.white.withValues(alpha: .82),
                width: 1.2,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: .20),
                  resolvedTint.withValues(alpha: .05),
                  tokens.softBlue.withValues(alpha: .04),
                  Colors.white.withValues(alpha: .10),
                ],
                stops: const [0, .36, .72, 1],
              ),
            ),
            child: Stack(
              children: [
                if (showSheen) ...[
                  Positioned(
                    left: 0,
                    top: 0,
                    child: IgnorePointer(
                      child: Container(
                        width: 78,
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withValues(alpha: .72),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    top: 8,
                    child: IgnorePointer(
                      child: Container(
                        width: 34,
                        height: 9,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .48),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ],
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MascotHeroCard extends StatelessWidget {
  const MascotHeroCard({
    this.text,
    this.accentText,
    this.height = 188,
    this.scene = MascotSceneVariant.snack,
    this.showHeart = true,
    super.key,
  });

  final String? text;
  final String? accentText;
  final double height;
  final MascotSceneVariant scene;
  final bool showHeart;

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeTokens;
    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tokens.surface.withValues(alpha: .50),
        borderRadius: BorderRadius.circular(tokens.shape.cardRadius),
        border: Border.all(
          color: tokens.surface.withValues(alpha: .74),
          width: tokens.shape.borderWidth,
        ),
        boxShadow: softShadowFor(tokens),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AppMascotScene(
              height: height,
              variant: scene,
              showHeart: showHeart,
            ),
          ),
          if (text != null)
            Positioned(
              left: 18,
              top: 52,
              width: 150,
              child: RichText(
                text: TextSpan(
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(height: 1.35),
                  children: [
                    TextSpan(text: text),
                    if (accentText != null)
                      TextSpan(
                        text: '\n$accentText',
                        style: TextStyle(color: tokens.accent),
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

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    required this.title,
    this.trailing,
    this.compact = false,
    super.key,
  });

  const SectionTitle.compact({
    required this.title,
    this.trailing,
    required this.compact,
    super.key,
  });

  final String title;
  final Widget? trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(2, compact ? 0 : 20, 2, compact ? 0 : 10),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontSize: compact ? 15.5 : 17),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.pets_rounded,
            color: context.themeTokens.accent.withValues(alpha: .58),
            size: compact ? 13 : 15,
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

class TinyPill extends StatelessWidget {
  const TinyPill({
    required this.label,
    this.icon,
    this.color,
    this.selected = false,
    super.key,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeTokens;
    final resolvedColor = color ?? tokens.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: selected
            ? resolvedColor.withValues(alpha: 0.13)
            : tokens.surface.withValues(alpha: .74),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? resolvedColor.withValues(alpha: 0.26)
              : tokens.border.withValues(alpha: .86),
        ),
        boxShadow: selected ? softShadowSmallFor(tokens) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: resolvedColor, size: 16),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: selected ? resolvedColor : tokens.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class MiniMetric extends StatelessWidget {
  const MiniMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 112;
        final labelText = Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        );
        final valueText = Text(
          value,
          maxLines: compact ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: Theme.of(context).textTheme.titleSmall,
        );
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: compact ? 10 : 12,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: compact
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: color, size: 23),
                    const SizedBox(height: 5),
                    labelText,
                    valueText,
                  ],
                )
              : Row(
                  children: [
                    Icon(icon, color: color, size: 24),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [labelText, valueText],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

List<BoxShadow> get softShadow => [
  BoxShadow(
    color: AppColors.primary.withValues(alpha: 0.10),
    blurRadius: 28,
    offset: const Offset(0, 12),
  ),
];

List<BoxShadow> get softShadowSmall => [
  BoxShadow(
    color: AppColors.primary.withValues(alpha: 0.075),
    blurRadius: 16,
    offset: const Offset(0, 6),
  ),
];

List<BoxShadow> softShadowFor(AppThemeTokens tokens) => [
  BoxShadow(
    color: tokens.primary.withValues(alpha: 0.10),
    blurRadius: 28,
    offset: const Offset(0, 12),
  ),
];

List<BoxShadow> softShadowSmallFor(AppThemeTokens tokens) => [
  BoxShadow(
    color: tokens.primary.withValues(alpha: 0.075),
    blurRadius: 16,
    offset: const Offset(0, 6),
  ),
];

const prototypeGap = SizedBox(height: AppSpacing.md);

class _PrototypeGlow extends StatelessWidget {
  const _PrototypeGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _PrototypeSparkles extends StatelessWidget {
  const _PrototypeSparkles({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _PrototypeSparklePainter(color: color),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _PrototypeSparklePainter extends CustomPainter {
  const _PrototypeSparklePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final specs = <({double x, double y, double r, Color color})>[
      (x: .36, y: .06, r: 4, color: color),
      (x: .88, y: .12, r: 3, color: Colors.white),
      (x: .08, y: .28, r: 4, color: Colors.white),
      (x: .92, y: .44, r: 4, color: color),
      (x: .18, y: .78, r: 3, color: Colors.white),
    ];
    for (final spec in specs) {
      final center = Offset(size.width * spec.x, size.height * spec.y);
      paint.color = spec.color.withValues(alpha: .60);
      final path = Path()
        ..moveTo(center.dx, center.dy - spec.r)
        ..lineTo(center.dx + spec.r, center.dy)
        ..lineTo(center.dx, center.dy + spec.r)
        ..lineTo(center.dx - spec.r, center.dy)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PrototypeSparklePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
