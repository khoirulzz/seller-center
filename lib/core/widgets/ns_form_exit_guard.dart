import 'package:flutter/material.dart';

/// Wait for the updated PopScope to reach the tree before retrying a pop.
/// Prevents overlapping confirmation dialogs from repeated Android back presses.
class NsFormExitGuard extends StatefulWidget {
  const NsFormExitGuard({
    super.key,
    required this.dirty,
    required this.busy,
    required this.confirmExit,
    required this.child,
  });
  final bool dirty, busy;
  final Future<bool> Function() confirmExit;
  final Widget child;
  @override
  State<NsFormExitGuard> createState() => _NsFormExitGuardState();
}

class _NsFormExitGuardState extends State<NsFormExitGuard> {
  bool confirming = false;
  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: !widget.dirty && !widget.busy,
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop || confirming) return;
      if (widget.busy) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tunggu hingga proses selesai.')),
        );
        return;
      }
      confirming = true;
      try {
        final leave = await widget.confirmExit();
        if (!leave || !mounted) return;
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) await Navigator.of(context).maybePop(result);
      } finally {
        confirming = false;
      }
    },
    child: widget.child,
  );
}
