import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class KeyboardShortcuts extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPosShortcut;
  final VoidCallback? onProductShortcut;
  final VoidCallback? onCustomerShortcut;
  final VoidCallback? onSalesHistoryShortcut;
  final VoidCallback? onDashboardShortcut;
  final VoidCallback? onInventoryShortcut;
  final VoidCallback? onReportsShortcut;
  
  const KeyboardShortcuts({
    super.key,
    required this.child,
    this.onPosShortcut,
    this.onProductShortcut,
    this.onCustomerShortcut,
    this.onSalesHistoryShortcut,
    this.onDashboardShortcut,
    this.onInventoryShortcut,
    this.onReportsShortcut,
  });

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.f1): const _PosIntent(),
        LogicalKeySet(LogicalKeyboardKey.f2): const _ProductIntent(),
        LogicalKeySet(LogicalKeyboardKey.f3): const _CustomerIntent(),
        LogicalKeySet(LogicalKeyboardKey.f4): const _SalesHistoryIntent(),
        LogicalKeySet(LogicalKeyboardKey.f5): const _RefreshIntent(),
        LogicalKeySet(LogicalKeyboardKey.f10): const _DashboardIntent(),
        LogicalKeySet(LogicalKeyboardKey.f6): const _InventoryIntent(),
        LogicalKeySet(LogicalKeyboardKey.f7): const _ReportsIntent(),
      },
      child: Actions(
        actions: {
          _PosIntent: CallbackAction<_PosIntent>(
            onInvoke: (_) => onPosShortcut?.call(),
          ),
          _ProductIntent: CallbackAction<_ProductIntent>(
            onInvoke: (_) => onProductShortcut?.call(),
          ),
          _CustomerIntent: CallbackAction<_CustomerIntent>(
            onInvoke: (_) => onCustomerShortcut?.call(),
          ),
          _SalesHistoryIntent: CallbackAction<_SalesHistoryIntent>(
            onInvoke: (_) => onSalesHistoryShortcut?.call(),
          ),
          _RefreshIntent: CallbackAction<_RefreshIntent>(
            onInvoke: (_) {
              // F5 = Refresh page (handled by individual pages)
              return null;
            },
          ),
          _DashboardIntent: CallbackAction<_DashboardIntent>(
            onInvoke: (_) => onDashboardShortcut?.call(),
          ),
          _InventoryIntent: CallbackAction<_InventoryIntent>(
            onInvoke: (_) => onInventoryShortcut?.call(),
          ),
          _ReportsIntent: CallbackAction<_ReportsIntent>(
            onInvoke: (_) => onReportsShortcut?.call(),
          ),
        },
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );
  }
}

// Intent Classes
class _PosIntent extends Intent {
  const _PosIntent();
}

class _ProductIntent extends Intent {
  const _ProductIntent();
}

class _CustomerIntent extends Intent {
  const _CustomerIntent();
}

class _SalesHistoryIntent extends Intent {
  const _SalesHistoryIntent();
}

class _RefreshIntent extends Intent {
  const _RefreshIntent();
}

class _DashboardIntent extends Intent {
  const _DashboardIntent();
}

class _InventoryIntent extends Intent {
  const _InventoryIntent();
}

class _ReportsIntent extends Intent {
  const _ReportsIntent();
}