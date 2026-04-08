import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EscapePopScope extends StatelessWidget {
  final Widget child;

  const EscapePopScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.escape): const _EscapePopIntent(),
      },
      child: Actions(
        actions: {
          _EscapePopIntent: CallbackAction<_EscapePopIntent>(
            onInvoke: (_) {
              final navigator = Navigator.of(context);
              if (navigator.canPop()) {
                navigator.maybePop();
              }
              return null;
            },
          ),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}

class _EscapePopIntent extends Intent {
  const _EscapePopIntent();
}
