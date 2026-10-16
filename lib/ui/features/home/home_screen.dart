import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/formatters.dart';
import '../../../core/config/status_dictionary.dart';
import '../../../core/theme/ns_colors.dart';
import '../../../domain/models/seller_models.dart';
import '../../state/seller_app_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.appState});
  final SellerAppState appState;
  @override State<HomeScreen> createState() => _HomeScreenState();
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
    if (clear) { cached = null; updated = null; }
    final id = storeId;
    future = id == null ? null : widget.appState.repository.fetchOverview(id);
    final request = future;
    if (request != null) {
      request.then((result) {
        if (mounted && storeId == id && future == request) setState(() {
          cached = result; updated = DateTime.now();
        });
      }).catchError((Object _) {});
    }
  }
  @override void initState() { super.initState(); load(); widget.appState.addListener(changed); }
  void changed() {
    if (widget.appState.activeStore?.id != storeId || widget.appState.storeDataRevision != revision) {
      setState(load);
    }
  }
  @override void dispose() { widget.appState.removeListener(changed); super.dispose(); }
  @override Widget build(BuildContext context) {
    final store = widget.appState.activeStore;
    return RefreshIndicator(
      onRefresh: () async { setState(load); try { await future; } catch (_) {} },
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 36), children: [
        Text('Beranda', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 5),
        Text(store?.name ?? 'Pilih toko', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text('Status toko: ${NsStatusDictionary.label(store?.status)}',
          style: Theme.of(context).textTheme.bodyMedium),
        if (store != null && !store.isPublished) ...[
          const SizedBox(height: 18),
          DecoratedBox(decoration: BoxDecoration(color: NsColors.surfaceSubtle, border: Border.all(color: NsColors.borderDefault),
            borderRadius: BorderRadius.circular(14)), child: Padding(padding: const EdgeInsets.all(16), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Tokomu belum terbit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 6), const Text('Lengkapi produk, pembayaran dan pengiriman agar pembeli bisa memesan.'),
                const SizedBox(height: 10),
                TextButton(onPressed: () => context.push('/toko/readiness'), child: const Text('Periksa kesiapan toko')),
              ],
            ))),
        ],
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: Text('Ringkasan penjualan', style: Theme.of(context).textTheme.titleLarge)),
          const Text('30 hari terakhir'),
        ]),
        const SizedBox(height: 4),
        if (updated != null) Text('Diperbarui ${NsFormatters.dateTime(updated!.toIso8601String())}', style: Theme.of(context).textTheme.bodySmall),
        FutureBuilder<StoreOverview>(future: future, builder: (ctx, snap) {
          final data = snap.data ?? cached;
          if (data == null && snap.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator()));
          if (data == null && snap.hasError) return ListTile(title: const Text('Ringkasan belum dapat dimuat.'), subtitle: Text('${snap.error}'),
            trailing: IconButton(tooltip: 'Coba lagi', icon: const Icon(Icons.refresh), onPressed: () => setState(load)));
          if (data == null) return const Text('Ringkasan belum tersedia.');
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (snap.connectionState != ConnectionState.done) const LinearProgressIndicator(minHeight: 2),
            if (snap.hasError) const Text('Belum dapat memperbarui data. Ringkasan sebelumnya tetap ditampilkan.'),
            const SizedBox(height: 16),
            Text(NsFormatters.rupiah(data.verifiedRevenueIdr),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
            const Text('Total omzet dari pembayaran terverifikasi'),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _value('Pesanan', NsFormatters.number(data.ordersCount))),
              const SizedBox(width: 12),
              Expanded(child: _value('Menunggu', NsFormatters.number(data.pendingOrdersCount))),
            ]),
            const SizedBox(height: 28),
            Text('Perlu ditangani', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (data.pendingOrdersCount > 0)
              ListTile(contentPadding: EdgeInsets.zero,
                title: Text('${data.pendingOrdersCount} pesanan menunggu'),
                subtitle: const Text('Periksa pembayaran dan status pesanan'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/pesanan?status=pending')),
            if (data.lowStockAlerts.isNotEmpty)
              ListTile(contentPadding: EdgeInsets.zero,
                title: Text('${data.lowStockAlerts.length} varian stok menipis'),
                subtitle: const Text('Periksa stok yang masih tersedia'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/produk?tab=stock')),
            if (data.pendingOrdersCount == 0 && data.lowStockAlerts.isEmpty)
              const ListTile(contentPadding: EdgeInsets.zero, title: Text('Tidak ada prioritas mendesak.')),
            for (final alert in data.lowStockAlerts.take(4))
              ListTile(contentPadding: const EdgeInsets.only(left: 8), dense: true,
                title: Text(alert.name), subtitle: Text(alert.optionLabel),
                trailing: Text('${alert.availableStock} tersedia')),
          ]);
        }),
        const SizedBox(height: 24),
        Text('Kelola toko', style: Theme.of(context).textTheme.titleLarge),
        ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.receipt_long_outlined),
          title: const Text('Daftar pesanan'), trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/pesanan')),
        const Divider(height: 1),
        ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.inventory_2_outlined),
          title: const Text('Produk dan stok'), trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/produk')),
      ]),
    );
  }
  Widget _value(String title, String value) => DecoratedBox(
    decoration: BoxDecoration(border: Border.all(color: NsColors.borderDefault), borderRadius: BorderRadius.circular(12)),
    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 13)),
      const SizedBox(height: 6),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w750, fontSize: 22)),
    ])));
}
