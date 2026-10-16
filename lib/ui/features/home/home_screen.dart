import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/formatters.dart';
import '../../../core/theme/ns_colors.dart';
import '../../../core/widgets/ns_widgets.dart';
import '../../../domain/models/seller_models.dart';
import '../../state/seller_app_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.appState});
  final SellerAppState appState;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<StoreOverview>? future;
  StoreOverview? cached;
  String? storeId;
  int revision = -1;
  DateTime? updated;
  void load({bool clear = false}) {
    final newId = widget.appState.activeStore?.id;
    if (newId != storeId) clear = true;
    storeId = newId;
    revision = widget.appState.storeDataRevision;
    if (clear) {
      cached = null;
      updated = null;
    }
    final id = storeId;
    future = id == null ? null : widget.appState.repository.fetchOverview(id);
    final request = future;
    if (request != null) {
      request
          .then((result) {
            if (mounted && storeId == id && future == request)
              setState(() {
                cached = result;
                updated = DateTime.now();
              });
          })
          .catchError((Object _) {});
    }
  }

  @override
  void initState() {
    super.initState();
    load();
    widget.appState.addListener(changed);
  }

  void changed() {
    if (widget.appState.activeStore?.id != storeId ||
        widget.appState.storeDataRevision != revision) {
      setState(load);
    }
  }

  @override
  void dispose() {
    widget.appState.removeListener(changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.appState.activeStore;
    return RefreshIndicator(
      onRefresh: () async {
        setState(load);
        try {
          await future;
        } catch (_) {}
      },
      child: ListView(
        key: const PageStorageKey('home'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                'Beranda',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              NsStatusLabel(statusCode: store?.status ?? 'draft'),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Pantau penjualan dan pekerjaan tokomu.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: NsColors.textSecondary),
          ),
          if (store != null &&
              !store.isPublished &&
              widget.appState.activeRole.canManageSettings) ...[
            const SizedBox(height: 20),
            panel(
              color: NsColors.surfacePressed,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      NsIcon('store', color: NsColors.brandAction),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Siapkan tokomu untuk pembeli',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Lengkapi produk, pembayaran, dan pengiriman sebelum toko diterbitkan.',
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: () => context.push('/toko/readiness'),
                    icon: const NsIcon(
                      'arrow-right',
                      size: 18,
                      color: NsColors.brandAction,
                    ),
                    label: const Text('Periksa kesiapan toko'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Ringkasan penjualan',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          const Text(
            '30 hari terakhir',
            style: TextStyle(color: NsColors.textSecondary),
          ),
          const SizedBox(height: 14),
          FutureBuilder<StoreOverview>(
            future: future,
            builder: (ctx, snap) {
              final data = cached ?? snap.data;
              if (data == null && snap.connectionState != ConnectionState.done)
                return const NsSkeleton(height: 180);
              if (data == null && snap.hasError)
                return NsInlineError(
                  message: 'Ringkasan belum dapat dimuat. Periksa koneksi lalu coba lagi.',
                  onRetry: () => setState(load),
                );
              if (data == null) return const Text('Ringkasan belum tersedia.');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (snap.connectionState != ConnectionState.done)
                    const LinearProgressIndicator(minHeight: 2),
                  if (snap.hasError)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Belum dapat memperbarui data. Ringkasan terakhir tetap ditampilkan.',
                      ),
                    ),
                  panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            NsIcon('chart', color: NsColors.brandAction),
                            SizedBox(width: 10),
                            Text('Omzet terverifikasi'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          NsFormatters.rupiah(data.verifiedRevenueIdr),
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Dari pesanan yang sudah dibayar',
                          style: TextStyle(color: NsColors.textSecondary),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(),
                        ),
                        LayoutBuilder(
                          builder: (context, size) {
                            final tiles = [
                              value(
                                'Pesanan',
                                NsFormatters.number(data.ordersCount),
                                'orders',
                                () => context.go('/pesanan'),
                              ),
                              value(
                                'Menunggu',
                                NsFormatters.number(data.pendingOrdersCount),
                                'clock',
                                () => context.go('/pesanan?status=pending'),
                              ),
                            ];
                            if (size.maxWidth < 280 ||
                                MediaQuery.textScalerOf(context).scale(1) > 1.4)
                              return Column(children: tiles);
                            return Row(
                              children: [
                                Expanded(child: tiles[0]),
                                const SizedBox(width: 12),
                                Expanded(child: tiles[1]),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  if (updated != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Diperbarui ${NsFormatters.dateTime(updated!.toIso8601String())}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  const SizedBox(height: 26),
                  Text(
                    'Perlu ditangani',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (data.pendingOrdersCount > 0)
                    task(
                      'orders',
                      '${data.pendingOrdersCount} pesanan menunggu',
                      'Periksa pembayaran dan proses pesanan',
                      () => context.go('/pesanan?status=pending'),
                    ),
                  if (data.lowStockAlerts.isNotEmpty)
                    task(
                      'box',
                      '${data.lowStockAlerts.length} varian stok menipis',
                      'Perbarui stok sebelum barang habis',
                      () => context.go('/produk?tab=stock'),
                    ),
                  if (data.pendingOrdersCount == 0 &&
                      data.lowStockAlerts.isEmpty)
                    panel(
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          NsIcon('check', color: NsColors.statusSuccessText),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Semua tertangani',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Belum ada pesanan atau stok yang perlu ditangani.',
                                  style: TextStyle(
                                    color: NsColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  for (final alert in data.lowStockAlerts.take(3))
                    ListTile(
                      contentPadding: const EdgeInsets.only(left: 12),
                      title: Text(alert.name),
                      subtitle: Text(
                        '${alert.optionLabel} • ${alert.availableStock} tersedia',
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 26),
          Text('Kelola toko', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          task(
            'orders',
            'Daftar pesanan',
            'Lihat dan proses pesanan pembeli',
            () => context.go('/pesanan'),
          ),
          task(
            'box',
            'Produk dan stok',
            'Kelola katalog, foto, dan ketersediaan',
            () => context.go('/produk'),
          ),
        ],
      ),
    );
  }

  Widget panel({required Widget child, Color color = NsColors.surfaceCanvas}) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: NsColors.borderDefault),
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      );
  Widget value(String title, String amount, String icon, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              NsIcon(icon, size: 18, color: NsColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: NsColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      amount,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  Widget task(
    String icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: NsColors.surfaceSubtle,
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: NsIcon(icon, color: NsColors.brandAction),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const NsIcon('chevron-right', size: 18),
        onTap: onTap,
      ),
    ),
  );
}
