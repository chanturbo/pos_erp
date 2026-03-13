import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/app_transitions.dart';

// ─────────────────────────────────────────
// 1. Shimmer List Placeholder
//    ใช้ตอน loading แทน CircularProgressIndicator
// ─────────────────────────────────────────
class ShimmerListPlaceholder extends StatelessWidget {
  const ShimmerListPlaceholder({super.key, this.itemCount = 6});
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: itemCount,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ShimmerBox(width: 44, height: 44, borderRadius: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(height: 14, width: double.infinity),
                      const SizedBox(height: 8),
                      ShimmerBox(height: 12, width: 200),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// 2. Error State Widget
// ─────────────────────────────────────────
class ErrorStateWidget extends StatelessWidget {
  const ErrorStateWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.compact = false,
  });

  final Object error;
  final VoidCallback? onRetry;
  /// compact=true สำหรับใส่ใน Card หรือ column ย่อย
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 40.0 : 64.0;
    return Center(
      child: FadeSlideIn(
        child: Padding(
          padding: EdgeInsets.all(compact ? 16 : 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: iconSize,
                color: Theme.of(context).colorScheme.error.withValues(alpha: 0.7),
              ),
              SizedBox(height: compact ? 8 : 16),
              Text(
                'เกิดข้อผิดพลาด',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                _friendlyError(error),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.55),
                    ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (onRetry != null) ...[
                SizedBox(height: compact ? 12 : 20),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('ลองใหม่'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: compact ? VisualDensity.compact : null,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
      return 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้';
    }
    if (msg.contains('TimeoutException')) {
      return 'การเชื่อมต่อหมดเวลา';
    }
    if (msg.contains('401') || msg.contains('Unauthorized')) {
      return 'ไม่มีสิทธิ์เข้าถึงข้อมูล';
    }
    if (msg.contains('404')) {
      return 'ไม่พบข้อมูลที่ร้องขอ';
    }
    if (msg.contains('500')) {
      return 'เซิร์ฟเวอร์เกิดข้อผิดพลาด';
    }
    // ตัด Exception prefix ออก
    return msg
        .replaceAll('Exception: ', '')
        .replaceAll('FormatException: ', '')
        .replaceAll('StateError: ', '');
  }
}

// ─────────────────────────────────────────
// 3. Empty State Widget
// ─────────────────────────────────────────
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FadeSlideIn(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 72,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.2),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.55),
                    ),
                textAlign: TextAlign.center,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.4),
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (onAction != null && actionLabel != null) ...[
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// 4. Inline Loading Widget
// ─────────────────────────────────────────
class LoadingStateWidget extends StatelessWidget {
  const LoadingStateWidget({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FadeIn(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(strokeWidth: 3),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.55),
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// 5. SnackBar Helpers
//    ใช้แทน ScaffoldMessenger.of(context).showSnackBar(...)
// ─────────────────────────────────────────
extension AppSnackBar on BuildContext {
  void showSuccess(String message) => _show(message, _SnackType.success);
  void showError(String message)   => _show(message, _SnackType.error);
  void showWarning(String message) => _show(message, _SnackType.warning);
  void showInfo(String message)    => _show(message, _SnackType.info);

  void _show(String message, _SnackType type) {
    final cs = Theme.of(this).colorScheme;
    final (bg, fg, icon) = switch (type) {
      _SnackType.success => (cs.primaryContainer,    cs.onPrimaryContainer,    Icons.check_circle_outline),
      _SnackType.error   => (cs.errorContainer,      cs.onErrorContainer,      Icons.error_outline),
      _SnackType.warning => (const Color(0xFFFFF3E0), const Color(0xFFE65100), Icons.warning_amber_outlined),
      _SnackType.info    => (cs.secondaryContainer,  cs.onSecondaryContainer,  Icons.info_outline),
    };

    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: bg,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: type == _SnackType.error
              ? const Duration(seconds: 4)
              : const Duration(seconds: 2),
          content: Row(
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: fg, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      );
  }
}

enum _SnackType { success, error, warning, info }

// ─────────────────────────────────────────
// 6. Confirm Dialog Helper
// ─────────────────────────────────────────
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  String confirmLabel = 'ยืนยัน',
  String cancelLabel = 'ยกเลิก',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: destructive
              ? ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                  foregroundColor: Theme.of(ctx).colorScheme.onError,
                )
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

// ─────────────────────────────────────────
// 7. AsyncValue Extension
//    .buildUI() — ใช้แทน .when() boilerplate
// ─────────────────────────────────────────
extension AsyncValueUI<T> on AsyncValue<T> {
  /// Standard UI builder พร้อม shimmer/loading/error/data
  Widget buildUI({
    required Widget Function(T data) data,
    bool useShimmer = true,
    int shimmerCount = 5,
    VoidCallback? onRetry,
  }) {
    return when(
      loading: () => useShimmer
          ? ShimmerListPlaceholder(itemCount: shimmerCount)
          : const LoadingStateWidget(),
      error: (e, _) => ErrorStateWidget(error: e, onRetry: onRetry),
      data: data,
    );
  }

  /// สำหรับ content ที่ไม่ใช่ list (ไม่ต้องการ shimmer)
  Widget buildContent({
    required Widget Function(T data) data,
    String? loadingMessage,
    VoidCallback? onRetry,
  }) {
    return when(
      loading: () => LoadingStateWidget(message: loadingMessage),
      error: (e, _) => ErrorStateWidget(error: e, onRetry: onRetry),
      data: data,
    );
  }
}