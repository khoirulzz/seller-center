import 'package:shorebird_code_push/shorebird_code_push.dart';

enum AppPatchStatus { current, available, restartRequired, unavailable }

/// Boundary between the app and the native Shorebird runtime.
abstract interface class AppUpdateService {
  bool get isAvailable;
  Future<int?> currentPatch();
  Future<AppPatchStatus> check();
  Future<void> download();
}

class ShorebirdAppUpdateService implements AppUpdateService {
  ShorebirdAppUpdateService({ShorebirdUpdater? updater})
      : _updater = updater ?? ShorebirdUpdater();

  final ShorebirdUpdater _updater;

  @override
  bool get isAvailable => _updater.isAvailable;

  @override
  Future<int?> currentPatch() async =>
      (await _updater.readCurrentPatch())?.number;

  @override
  Future<AppPatchStatus> check() async =>
      switch (await _updater.checkForUpdate()) {
        UpdateStatus.upToDate => AppPatchStatus.current,
        UpdateStatus.outdated => AppPatchStatus.available,
        UpdateStatus.restartRequired => AppPatchStatus.restartRequired,
        UpdateStatus.unavailable => AppPatchStatus.unavailable,
      };

  @override
  Future<void> download() => _updater.update();
}
