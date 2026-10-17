import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/ns_colors.dart';
import '../../state/app_update_controller.dart';

class AppUpdateScope extends InheritedNotifier<AppUpdateController> {
  const AppUpdateScope({
    super.key,
    required AppUpdateController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppUpdateController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppUpdateScope>()?.notifier;
}

class AppUpdateNotice extends StatelessWidget {
  const AppUpdateNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppUpdateScope.maybeOf(context);
    if (controller?.phase != AppUpdatePhase.restartRequired) {
      return const SizedBox.shrink();
    }
    return Semantics(
      liveRegion: true,
      child: Material(
        color: NsColors.statusSuccessBg,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              const Icon(Icons.system_update_alt,
                  color: NsColors.statusSuccessText),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Pembaruan siap untuk pembukaan aplikasi berikutnya.',
                  style: TextStyle(color: NsColors.statusSuccessText),
                ),
              ),
              TextButton(
                onPressed: () => context.push('/app-update'),
                child: const Text('Lihat'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppUpdateScreen extends StatelessWidget {
  const AppUpdateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppUpdateScope.maybeOf(context);
    final phase = controller?.phase ?? AppUpdatePhase.unavailable;
    final (title, description, icon) = switch (phase) {
      AppUpdatePhase.idle => (
          'Tetap dapatkan yang terbaru',
          'Pembaruan kecil diunduh otomatis saat aplikasi dibuka dan koneksi tersedia.',
          Icons.system_update_alt,
        ),
      AppUpdatePhase.checking => (
          'Memeriksa pembaruan',
          'Kamu tetap bisa melanjutkan aktivitas di toko.',
          Icons.sync,
        ),
      AppUpdatePhase.downloading => (
          'Mengunduh pembaruan',
          'Unduhan berjalan di latar belakang. Kamu boleh meninggalkan halaman ini.',
          Icons.downloading,
        ),
      AppUpdatePhase.current => (
          'Aplikasi sudah terbaru',
          'Belum ada pembaruan baru untuk versi aplikasi ini.',
          Icons.check_circle_outline,
        ),
      AppUpdatePhase.restartRequired => (
          'Pembaruan siap digunakan',
          'Selesaikan dan simpan pekerjaanmu dulu. Pembaruan berlaku setelah aplikasi ditutup sepenuhnya lalu dibuka kembali.',
          Icons.task_alt,
        ),
      AppUpdatePhase.unavailable => (
          'Gunakan APK yang mendukung pembaruan otomatis',
          'Versi yang terpasang belum bisa menerima pembaruan otomatis. Pasang APK terbaru yang mendukung fitur ini.',
          Icons.install_mobile,
        ),
      AppUpdatePhase.failed => (
          'Pembaruan belum dapat diperiksa',
          'Periksa koneksi internet lalu coba lagi. Aplikasi tetap bisa digunakan seperti biasa.',
          Icons.wifi_off_outlined,
        ),
    };
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pembaruan aplikasi'),
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/beranda'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Nalaro Seller',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 6),
                Text(
                  'Versi ${AppConfig.appVersion}'
                  '${controller?.currentPatch == null ? '' : ' · Pembaruan ${controller!.currentPatch}'}',
                  style: const TextStyle(color: NsColors.textSecondary),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, color: NsColors.brandAction, size: 32),
                        const SizedBox(height: 16),
                        Text(title,
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 10),
                        Text(description),
                        if (controller?.isBusy ?? false) ...[
                          const SizedBox(height: 20),
                          const LinearProgressIndicator(),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (phase != AppUpdatePhase.unavailable &&
                    phase != AppUpdatePhase.restartRequired)
                  FilledButton.icon(
                    onPressed: controller == null || controller.isBusy
                        ? null
                        : () => controller.checkForUpdates(userInitiated: true),
                    icon: const Icon(Icons.refresh),
                    label: Text(phase == AppUpdatePhase.failed
                        ? 'Coba lagi'
                        : 'Periksa pembaruan'),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'Pembaruan otomatis tidak menutup aplikasi saat kamu bekerja. '
                  'Pembaruan besar tertentu tetap memerlukan APK baru.',
                  style: TextStyle(color: NsColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
