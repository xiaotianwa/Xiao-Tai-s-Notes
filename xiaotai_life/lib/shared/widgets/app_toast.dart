import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum AppToastType { success, warning, error, info }

class AppToast {
  const AppToast._();

  static void show(
    BuildContext context,
    String message, {
    AppToastType type = AppToastType.info,
  }) {
    final config = _ToastConfig.fromType(type);
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: MediaQuery.paddingOf(context).top + 14,
          left: 24,
          right: 24,
          child: IgnorePointer(
            child: Material(
              color: Colors.transparent,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: config.backgroundColor,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: config.borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.textPrimary.withValues(alpha: .12),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(config.icon, color: config.iconColor, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(entry);
    Future<void>.delayed(const Duration(milliseconds: 1800), () {
      if (entry.mounted) {
        entry.remove();
      }
    });
  }

  static void success(BuildContext context, String message) {
    show(context, message, type: AppToastType.success);
  }

  static void warning(BuildContext context, String message) {
    show(context, message, type: AppToastType.warning);
  }

  static void error(BuildContext context, String message) {
    show(context, message, type: AppToastType.error);
  }
}

class _ToastConfig {
  const _ToastConfig({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color borderColor;

  factory _ToastConfig.fromType(AppToastType type) {
    return switch (type) {
      AppToastType.success => _ToastConfig(
        icon: Icons.check_circle_outline,
        iconColor: AppColors.success,
        backgroundColor: AppColors.softGreen,
        borderColor: AppColors.success.withValues(alpha: .25),
      ),
      AppToastType.warning => _ToastConfig(
        icon: Icons.info_outline,
        iconColor: AppColors.warning,
        backgroundColor: AppColors.softOrange,
        borderColor: AppColors.warning.withValues(alpha: .28),
      ),
      AppToastType.error => _ToastConfig(
        icon: Icons.error_outline,
        iconColor: AppColors.danger,
        backgroundColor: AppColors.softPink,
        borderColor: AppColors.danger.withValues(alpha: .22),
      ),
      AppToastType.info => _ToastConfig(
        icon: Icons.check_circle_outline,
        iconColor: AppColors.primary,
        backgroundColor: AppColors.softBlue,
        borderColor: AppColors.primary.withValues(alpha: .22),
      ),
    };
  }
}
