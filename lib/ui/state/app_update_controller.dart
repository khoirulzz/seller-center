import 'package:flutter/foundation.dart';

import '../../data/services/app_update_service.dart';

enum AppUpdatePhase {
  idle,
  checking,
  downloading,
  current,
  restartRequired,
  unavailable,
  failed,
}

/// Checks without blocking launch, coalesces requests, and never restarts the app.
class AppUpdateController extends ChangeNotifier {
  AppUpdateController({
    required AppUpdateService service,
    DateTime Function()? now,
    this.checkInterval = const Duration(minutes: 15),
  })  : _service = service,
        _now = now ?? DateTime.now;

  final AppUpdateService _service;
  final DateTime Function() _now;
  final Duration checkInterval;
  AppUpdatePhase _phase = AppUpdatePhase.idle;
  AppUpdatePhase get phase => _phase;
  int? _currentPatch;
  int? get currentPatch => _currentPatch;
  DateTime? _lastAttempt;
  DateTime? _lastChecked;
  DateTime? get lastChecked => _lastChecked;
  Future<void>? _inFlight;
  bool _disposed = false;

  bool get isBusy =>
      _phase == AppUpdatePhase.checking || _phase == AppUpdatePhase.downloading;

  Future<void> checkForUpdates({bool userInitiated = false}) {
    if (_disposed) return Future.value();
    final running = _inFlight;
    if (running != null) return running;
    if (_phase == AppUpdatePhase.restartRequired) return Future.value();
    if (!userInitiated &&
        _lastAttempt != null &&
        _now().difference(_lastAttempt!) < checkInterval) {
      return Future.value();
    }
    _lastAttempt = _now();
    // Store the shared future before listeners can request another check.
    final operation = Future<void>.microtask(_check);
    _inFlight = operation;
    return operation.whenComplete(() {
      if (identical(_inFlight, operation)) _inFlight = null;
    });
  }

  Future<void> _check() async {
    if (_disposed) return;
    try {
      if (!_service.isAvailable) {
        _setPhase(AppUpdatePhase.unavailable);
        return;
      }
      _setPhase(AppUpdatePhase.checking);
      _currentPatch = await _service.currentPatch();
      if (_disposed) return;
      final status = await _service.check();
      if (_disposed) return;
      _lastChecked = _now();
      switch (status) {
        case AppPatchStatus.current:
          _setPhase(AppUpdatePhase.current);
        case AppPatchStatus.restartRequired:
          // Also covers a rollback queued by the native updater.
          _setPhase(AppUpdatePhase.restartRequired);
        case AppPatchStatus.unavailable:
          _setPhase(AppUpdatePhase.unavailable);
        case AppPatchStatus.available:
          _setPhase(AppUpdatePhase.downloading);
          await _service.download();
          if (!_disposed) _setPhase(AppUpdatePhase.restartRequired);
      }
    } catch (_) {
      // An update failure must never interrupt selling or expose SDK details.
      if (!_disposed) _setPhase(AppUpdatePhase.failed);
    }
  }

  void _setPhase(AppUpdatePhase value) {
    if (_disposed) return;
    _phase = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
