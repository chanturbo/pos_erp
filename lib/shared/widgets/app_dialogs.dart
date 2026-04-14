import 'package:flutter/material.dart';
import 'package:pos_erp/shared/theme/app_theme.dart';
import 'package:pos_erp/shared/widgets/mobile_home_button.dart';

class AppDialog extends StatelessWidget {
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? titlePadding;
  final EdgeInsetsGeometry? contentPadding;
  final EdgeInsetsGeometry? actionsPadding;
  final MainAxisAlignment actionsAlignment;
  final Color? backgroundColor;
  final ShapeBorder? shape;
  final EdgeInsets insetPadding;

  const AppDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.titlePadding,
    this.contentPadding,
    this.actionsPadding,
    this.actionsAlignment = MainAxisAlignment.end,
    this.backgroundColor,
    this.shape,
    this.insetPadding = const EdgeInsets.symmetric(
      horizontal: 40,
      vertical: 24,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final effectiveShape =
        shape ??
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));

    return Dialog(
      backgroundColor:
          backgroundColor ??
          Theme.of(context).dialogTheme.backgroundColor ??
          Theme.of(context).colorScheme.surface,
      shape: effectiveShape,
      insetPadding: insetPadding,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding:
                  titlePadding ?? const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: title!,
            ),
          if (content != null)
            Padding(
              padding:
                  contentPadding ?? const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: content!,
            ),
          if (actions != null && actions!.isNotEmpty)
            Padding(
              padding:
                  actionsPadding ?? const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: OverflowBar(
                alignment: actionsAlignment,
                spacing: 8,
                overflowAlignment: OverflowBarAlignment.end,
                children: actions!,
              ),
            ),
        ],
        ),
      ),
    );
  }
}

Widget buildAppDialogTitle(
  BuildContext context, {
  required String title,
  IconData? icon,
  Color? iconColor,
  bool showClose = true,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final resolvedIconColor = iconColor ?? AppTheme.primaryColor;

  return Row(
    children: [
      if (icon != null) ...[
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: resolvedIconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: resolvedIconColor),
        ),
        const SizedBox(width: 10),
      ] else ...[
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: resolvedIconColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
      ],
      Expanded(
        child: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
          ),
        ),
      ),
      if (showClose) ...[
        const SizedBox(width: 8),
        buildMobileCloseCompactButton(context, isDark: isDark),
      ],
    ],
  );
}

Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  IconData? icon,
  Color? iconColor,
  String confirmLabel = 'ยืนยัน',
  String cancelLabel = 'ยกเลิก',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AppDialog(
      title: buildAppDialogTitle(
        ctx,
        title: title,
        icon: icon,
        iconColor: iconColor ?? (destructive ? AppTheme.errorColor : AppTheme.primaryColor),
      ),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: destructive
                ? Theme.of(ctx).colorScheme.error
                : (iconColor ?? AppTheme.primaryColor),
            foregroundColor: destructive
                ? Theme.of(ctx).colorScheme.onError
                : Colors.white,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
