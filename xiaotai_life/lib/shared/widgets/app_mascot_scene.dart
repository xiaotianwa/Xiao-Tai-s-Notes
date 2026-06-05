import 'package:flutter/material.dart';

import '../../core/theme/app_theme_tokens.dart';

enum MascotSceneVariant { snack, reading, reminder, travel, flowers, profile }

class AppMascotScene extends StatelessWidget {
  const AppMascotScene({
    this.height = 156,
    this.showHeart = true,
    this.variant = MascotSceneVariant.snack,
    this.fit = BoxFit.cover,
    super.key,
  });

  final double height;
  final bool showHeart;
  final MascotSceneVariant variant;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeTokens;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth / height > 2.2;
          return ClipRRect(
            borderRadius: BorderRadius.circular(tokens.shape.imageRadius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  _assetPath(tokens),
                  fit: isWide ? BoxFit.cover : fit,
                  alignment: _alignment,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0),
                        tokens.background.withValues(alpha: 0.14),
                      ],
                    ),
                  ),
                ),
                if (showHeart)
                  Positioned(
                    top: 12,
                    left: 26,
                    child: Icon(Icons.favorite, color: tokens.accent, size: 20),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _assetPath(AppThemeTokens tokens) {
    return switch (variant) {
      MascotSceneVariant.snack => tokens.assets.snack,
      MascotSceneVariant.reading => tokens.assets.reading,
      MascotSceneVariant.reminder => tokens.assets.reminder,
      MascotSceneVariant.travel => tokens.assets.travel,
      MascotSceneVariant.flowers => tokens.assets.flowers,
      MascotSceneVariant.profile => tokens.assets.profile,
    };
  }

  Alignment get _alignment {
    return switch (variant) {
      MascotSceneVariant.reading => Alignment.center,
      MascotSceneVariant.reminder => Alignment.center,
      MascotSceneVariant.travel => Alignment.center,
      MascotSceneVariant.profile => Alignment.center,
      _ => Alignment.center,
    };
  }
}
