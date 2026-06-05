import 'package:flutter/material.dart';

import '../../core/theme/app_theme_tokens.dart';
import 'prototype_ui.dart';

class AppFormPanel extends StatelessWidget {
  const AppFormPanel({
    required this.title,
    required this.children,
    this.color,
    this.icon,
    super.key,
  });

  final String title;
  final List<Widget> children;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeTokens;
    return SoftCard(
      color: color ?? tokens.surface.withValues(alpha: .68),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: tokens.softPink.withValues(alpha: .72),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: tokens.primary, size: 20),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontSize: 21, height: 1.22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}

class AppFormTextField extends StatelessWidget {
  const AppFormTextField({
    required this.controller,
    required this.label,
    this.hintText,
    this.keyboardType,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.suffixIcon,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormLabel(label),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          minLines: maxLines > 1 ? maxLines : null,
          readOnly: readOnly,
          onTap: onTap,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          decoration: appFormInputDecoration(
            context,
            hintText: hintText ?? label,
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}

InputDecoration appFormInputDecoration(
  BuildContext context, {
  String? hintText,
  Widget? suffixIcon,
}) {
  final tokens = context.themeTokens;
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(tokens.shape.controlRadius),
    borderSide: BorderSide(color: tokens.border),
  );
  return InputDecoration(
    hintText: hintText,
    filled: true,
    fillColor: tokens.surface.withValues(alpha: .9),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    suffixIcon: suffixIcon,
    hintStyle: TextStyle(
      color: tokens.textTertiary,
      fontWeight: FontWeight.w500,
    ),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(color: tokens.primary, width: 1.5),
    ),
  );
}

class AppChoiceGroup extends StatelessWidget {
  const AppChoiceGroup({
    required this.label,
    required this.value,
    required this.choices,
    required this.onChanged,
    super.key,
  });

  final String label;
  final String value;
  final Map<String, String> choices;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormLabel(label),
        const SizedBox(height: 9),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: choices.entries.map((entry) {
            final selected = value == entry.key;
            return ChoiceChip(
              label: Text(entry.value),
              selected: selected,
              showCheckmark: true,
              labelStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: selected ? tokens.primary : tokens.textSecondary,
              ),
              selectedColor: tokens.primary.withValues(alpha: .12),
              backgroundColor: tokens.surface.withValues(alpha: .78),
              side: BorderSide(
                color: selected
                    ? tokens.primary.withValues(alpha: .24)
                    : tokens.border,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              onSelected: (_) => onChanged(entry.key),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class AppFormActions extends StatelessWidget {
  const AppFormActions({
    required this.onCancel,
    required this.onSave,
    super.key,
  });

  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(onPressed: onCancel, child: const Text('取消')),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: FilledButton(onPressed: onSave, child: const Text('保存')),
        ),
      ],
    );
  }
}

class _FormLabel extends StatelessWidget {
  const _FormLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.themeTokens;
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: tokens.textPrimary,
        fontWeight: FontWeight.w800,
        height: 1.25,
      ),
    );
  }
}
