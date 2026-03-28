import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────
class CartToastData {
  final String id;
  final String message;
  final Color backgroundColor;
  final IconData icon;
  final Duration duration;

  const CartToastData({
    required this.id,
    required this.message,
    this.backgroundColor = AppTheme.successColor,
    this.icon = Icons.check_circle,
    this.duration = const Duration(milliseconds: 1500),
  });
}

// ─────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────
class CartToastNotifier extends Notifier<List<CartToastData>> {
  @override
  List<CartToastData> build() => [];

  void show(
    String message, {
    Color backgroundColor = AppTheme.successColor,
    IconData icon = Icons.check_circle,
    Duration duration = const Duration(milliseconds: 1500),
  }) {
    final toast = CartToastData(
      id: const Uuid().v4(),
      message: message,
      backgroundColor: backgroundColor,
      icon: icon,
      duration: duration,
    );
    // newest first — appears at top of the stack
    state = [toast, ...state];
  }

  void dismiss(String id) {
    state = state.where((t) => t.id != id).toList();
  }
}

final cartToastProvider =
    NotifierProvider<CartToastNotifier, List<CartToastData>>(
  CartToastNotifier.new,
);

// ─────────────────────────────────────────────────────────────────
// Overlay Widget — place inside a Stack (Positioned)
// ─────────────────────────────────────────────────────────────────
class CartToastOverlay extends ConsumerWidget {
  const CartToastOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toasts = ref.watch(cartToastProvider);
    if (toasts.isEmpty) return const SizedBox.shrink();

    return Positioned(
      bottom: 16,
      left: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        // Newest at top: list is already newest-first, so no reversal needed
        children: toasts
            .map((toast) => _CartToastItem(
                  key: ValueKey(toast.id),
                  data: toast,
                  onDismiss: () =>
                      ref.read(cartToastProvider.notifier).dismiss(toast.id),
                ))
            .toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Single Toast Item — self-managed lifecycle
// ─────────────────────────────────────────────────────────────────
class _CartToastItem extends StatefulWidget {
  final CartToastData data;
  final VoidCallback onDismiss;

  const _CartToastItem({super.key, required this.data, required this.onDismiss});

  @override
  State<_CartToastItem> createState() => _CartToastItemState();
}

class _CartToastItemState extends State<_CartToastItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _sizeFactor;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    _sizeFactor = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(-0.25, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _ctrl.forward();
    _timer = Timer(widget.data.duration, _startDismiss);
  }

  void _startDismiss() {
    if (!mounted) return;
    _timer?.cancel();
    _ctrl.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // SizeTransition handles height → 0 on exit, causing items below to shift up
    return SizeTransition(
      sizeFactor: _sizeFactor,
      axisAlignment: -1.0, // anchor at top so collapse goes downward
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: FadeTransition(
          opacity: _opacity,
          child: SlideTransition(
            position: _slide,
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320, minWidth: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: widget.data.backgroundColor,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.20),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.data.icon, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.data.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
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
  }
}
