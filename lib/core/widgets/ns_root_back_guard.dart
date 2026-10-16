import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Detail routes live on the root navigator and pop normally. At a tab root,
/// back first returns home; leaving home requires an explicit user choice.
class NsRootBackGuard extends StatefulWidget {
  const NsRootBackGuard({
    super.key,
    required this.isHome,
    required this.goHome,
    required this.child,
  });
  final bool isHome;
  final VoidCallback goHome;
  final Widget child;
  @override
  State<NsRootBackGuard> createState() => _NsRootBackGuardState();
}

class _NsRootBackGuardState extends State<NsRootBackGuard> {
  bool confirming = false;
  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop || confirming) return;
      if (!widget.isHome) {
        widget.goHome();
        return;
      }
      confirming = true;
      final exit = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Tutup aplikasi?'),
          content: const Text(
            'Akunmu tetap masuk. Kamu dapat melanjutkan saat membuka aplikasi lagi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Tetap di sini'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
      confirming = false;
      if (exit == true && mounted) await SystemNavigator.pop();
    },
    child: widget.child,
  );
}
