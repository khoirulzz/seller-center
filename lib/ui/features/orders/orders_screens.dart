import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/formatters.dart';
import '../../../core/config/status_dictionary.dart';
import '../../../core/errors/api_exception.dart';
import '../../../domain/models/seller_models.dart';
import '../../state/seller_app_state.dart';

class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key, required this.appState, this.initialFilter = 'all'});
  final SellerAppState appState;
  final String initialFilter;
  @override State<OrdersListScreen> createState() => _OrdersListScreenState();
}
class _OrdersListScreenState extends State<OrdersListScreen> {
  String? storeId, query;
  String filter = 'all';
  int revision = -1, page = 0;
  bool loading = false, hasMore = true;
  String? error;
  List<OrderModel> orders = [];
  DateTimeRange? range;
  final search = TextEditingController();
  @override void initState() { super.initState(); filter = widget.initialFilter; widget.appState.addListener(onState); reset(); }
  @override void didUpdateWidget(covariant OrdersListScreen oldWidget) { super.didUpdateWidget(oldWidget); if (oldWidget.initialFilter != widget.initialFilter) { filter = widget.initialFilter; reset(); } }
  void onState() {
    if (storeId != widget.appState.activeStore?.id || revision != widget.appState.storeDataRevision) {
      reset();
    }
  }
  void reset() {
    storeId = widget.appState.activeStore?.id;
    revision = widget.appState.storeDataRevision;
    // Invalidate in-flight pagination when switching store/filter.
    loading = false;
    page = 0; orders = []; hasMore = true; error = null;
    if (mounted) setState(() {});
    load();
  }
  Future<void> load() async {
    if (loading || !hasMore || storeId == null) return;
    final id = storeId!, token = revision, next = page + 1;
    setState(() { loading = true; error = null; });
    try {
      final result = await widget.appState.repository.fetchOrders(
        storeId: id, status: filter, query: query ?? '', page: next,
        fromDate: range == null ? null : NsFormatters.calendarDate(range!.start),
        toDate: range == null ? null : NsFormatters.calendarDate(range!.end),
      );
      if (!mounted || storeId != id || revision != token) return;
      setState(() {
        orders = [...orders, ...result.orders]; page = next; hasMore = result.hasMore;
      });
    } catch (e) {
      if (mounted && storeId == id && revision == token) setState(() => error = '$e');
    } finally {
      if (mounted && storeId == id && revision == token) setState(() => loading = false);
    }
  }
  @override void dispose() { widget.appState.removeListener(onState); search.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async { reset(); },
    child: ListView(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20), children: [
      Text('Pesanan', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      TextField(controller: search, textInputAction: TextInputAction.search,
        decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Nomor pesanan atau nama pembeli',
          suffixIcon: IconButton(tooltip: 'Cari', icon: const Icon(Icons.arrow_forward), onPressed: () { query = search.text.trim(); reset(); })),
        onSubmitted: (v) { query = v.trim(); reset(); }),
      const SizedBox(height: 10),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
        for (final status in ['all', 'pending', 'unpaid', 'paid', 'packing', 'shipped', 'pickup_ready', 'completed', 'canceled'])
          Padding(padding: const EdgeInsets.only(right: 7), child: ChoiceChip(
            label: Text(status == 'all' ? 'Semua' : NsStatusDictionary.label(status)),
            selected: filter == status, onSelected: (_) { filter = status; reset(); },
          )),
      ])),
      Row(children: [
        TextButton.icon(icon: const Icon(Icons.date_range_outlined), label: Text(range == null ? 'Pilih tanggal' : '${NsFormatters.calendarDate(range!.start)} – ${NsFormatters.calendarDate(range!.end)}'), onPressed: () async {
          final selected = await showDateRangePicker(context: context,
            firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)), initialDateRange: range);
          if (selected != null) { range = selected; reset(); }
        }),
        if (range != null || (query?.isNotEmpty ?? false) || filter != 'all')
          TextButton(onPressed: () { range = null; filter = 'all'; search.clear(); query = ''; reset(); }, child: const Text('Hapus filter')),
      ]),
      if (orders.isEmpty && loading) const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
      if (orders.isEmpty && !loading && error == null) const Padding(padding: EdgeInsets.all(28), child: Text('Belum ada pesanan pada pilihan ini.')),
      for (final order in orders) ...[
        ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 6),
          title: Text(order.orderNumber, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(order.customerName, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('${NsFormatters.shortDate(order.createdAt)} • ${NsStatusDictionary.label(order.paymentStatus)} • ${NsStatusDictionary.label(order.fulfillmentStatus)}'),
          ]),
          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
            Text(NsFormatters.rupiah(order.totalIdr), style: const TextStyle(fontWeight: FontWeight.w600)),
            const Icon(Icons.chevron_right, size: 18),
          ]),
          onTap: () => context.push('/pesanan/${Uri.encodeComponent(order.id)}'),
        ), const Divider(height: 1),
      ],
      if (error != null) ListTile(title: const Text('Pesanan belum berhasil dimuat'), subtitle: Text(error!), trailing: IconButton(icon: const Icon(Icons.refresh), onPressed: load)),
      if (hasMore && orders.isNotEmpty)
        TextButton(onPressed: loading ? null : load, child: Text(loading ? 'Memuat...' : 'Muat pesanan lainnya')),
    ]),
  );
}
class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.appState, required this.orderId});
  final SellerAppState appState;
  final String orderId;
  @override State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}
class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Future<OrderDetailBundle> future;
  String? requestedStore;
  bool submitting = false;
  @override void initState() {
    super.initState();
    requestedStore = widget.appState.activeStore?.id;
    load();
    widget.appState.addListener(storeChanged);
  }
  void storeChanged() {
    if (widget.appState.activeStore?.id != requestedStore) {
      // Never display the previous tenant's order when the active store changes.
      requestedStore = widget.appState.activeStore?.id;
      setState(load);
    }
  }
  void load() {
    final id = requestedStore;
    future = id == null
      ? Future.error(StateError('Pilih toko terlebih dahulu.'))
      : widget.appState.repository.fetchOrderDetail(storeId: id, orderId: widget.orderId);
  }
  @override void dispose() { widget.appState.removeListener(storeChanged); super.dispose(); }
  Future<void> act(OrderModel selected, String action) async {
    if (submitting || requestedStore == null || widget.appState.isOffline) return;
    final note = TextEditingController();
    final tracking = TextEditingController(text: selected.shipmentReference);
    final isPayment = action == 'verified' || action == 'rejected';
    final isCancel = action == 'cancel';
    final accepted = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, showDragHandle: true,
      builder: (sheet) => Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.viewInsetsOf(sheet).bottom + 24),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isPayment ? 'Periksa pembayaran' : isCancel ? 'Batalkan pesanan?' : 'Perbarui status pesanan', style: Theme.of(sheet).textTheme.titleLarge),
          const SizedBox(height: 8), Text(selected.orderNumber),
          Text(NsFormatters.rupiah(selected.totalIdr), style: Theme.of(sheet).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(isPayment ? 'Periksa uang masuk di rekening/QRIS sebelum memverifikasi. Verifikasi akan memengaruhi stok dan status pesanan.' :
            isCancel ? 'Pembatalan memengaruhi reservasi stok. Periksa status pesanan sebelum melanjutkan.' :
            'Status baru: ${NsStatusDictionary.label(action)}'),
          if (isPayment) Padding(padding: const EdgeInsets.only(top: 12), child: TextField(controller: note, maxLines: 2, decoration: InputDecoration(labelText: action == 'rejected' ? 'Alasan penolakan' : 'Catatan (opsional)'))),
          if (action == 'shipped') Padding(padding: const EdgeInsets.only(top: 12), child: TextField(controller: tracking, decoration: const InputDecoration(labelText: 'Referensi pengiriman (opsional)'))),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(sheet, false), child: const Text('Kembali'))),
            const SizedBox(width: 12),
            Expanded(child: FilledButton(onPressed: () => Navigator.pop(sheet, true), child: Text(action == 'verified' ? 'Verifikasi' : action == 'rejected' ? 'Tolak' : isCancel ? 'Batalkan' : 'Simpan'))),
          ]),
        ]))),
      );
    if (accepted != true || !mounted) { note.dispose(); tracking.dispose(); return; }
    setState(() => submitting = true);
    try {
      final id = requestedStore!;
      final current = (await widget.appState.repository.fetchOrderDetail(storeId: id, orderId: widget.orderId)).order;
      if (!mounted || requestedStore != id) return;
      if (isPayment && !current.canVerifyPayment(widget.appState.activeRole)) {
        throw const ApiException(message: 'Status pembayaran sudah berubah. Muat ulang dan periksa kembali.', statusCode: 409);
      }
      if (isCancel && !current.canCancel(widget.appState.activeRole)) {
        throw const ApiException(message: 'Pesanan tidak bisa lagi dibatalkan.', statusCode: 409);
      }
      if (!isPayment && !isCancel && !current.allowedNextFulfillmentStates(widget.appState.activeRole).contains(action)) {
        throw const ApiException(message: 'Status pengiriman sudah berubah.', statusCode: 409);
      }
      if (isPayment) {
        await widget.appState.repository.reviewOrderPayment(storeId: id, orderId: widget.orderId, decision: action, note: note.text, role: widget.appState.activeRole);
      } else if (isCancel) {
        await widget.appState.repository.cancelOrder(storeId: id, orderId: widget.orderId, role: widget.appState.activeRole);
      } else {
        await widget.appState.repository.updateOrderFulfillment(storeId: id, orderId: widget.orderId, nextStatus: action, reference: tracking.text, role: widget.appState.activeRole);
      }
      widget.appState.notifyStoreDataMutated();
      if (mounted) { setState(load); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status pesanan diperbarui.'))); }
    } catch (e) {
      if (mounted) {
        setState(load);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      note.dispose(); tracking.dispose();
      if (mounted) setState(() => submitting = false);
    }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detail pesanan'), actions: [IconButton(tooltip: 'Muat ulang', icon: const Icon(Icons.refresh), onPressed: () => setState(load))]),
    body: FutureBuilder<OrderDetailBundle>(future: future, builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Pesanan tidak dapat dibuka.'),
        const SizedBox(height: 8), Text('${snap.error}'),
        TextButton(onPressed: () => setState(load), child: const Text('Coba lagi')),
      ])));
      final bundle = snap.data!;
      final order = bundle.order;
      final actions = order.allowedNextFulfillmentStates(widget.appState.activeRole);
      return ListView(padding: const EdgeInsets.all(20), children: [
        Text(order.orderNumber, style: Theme.of(context).textTheme.headlineSmall),
        Text('${NsStatusDictionary.label(order.orderStatus)} • ${NsFormatters.dateTime(order.createdAt)}'),
        const SizedBox(height: 18),
        ListTile(title: const Text('Total pesanan'), trailing: Text(NsFormatters.rupiah(order.totalIdr))),
        ListTile(title: const Text('Pembayaran'), trailing: Text(NsStatusDictionary.label(order.paymentStatus))),
        ListTile(title: const Text('Pemenuhan'), trailing: Text(NsStatusDictionary.label(order.fulfillmentStatus))),
        ListTile(title: const Text('Pembeli'), subtitle: Text(order.customerName)),
        if (widget.appState.activeRole.canViewCustomersAndAnalytics) ...[
          if (order.contactPhone.isNotEmpty) SelectableText(order.contactPhone),
          if (order.contactEmail.isNotEmpty) SelectableText(order.contactEmail),
        ],
        ListTile(title: const Text('Metode'), trailing: Text(NsStatusDictionary.label(order.shippingMethod))),
        if (order.shippingAddress.isNotEmpty) ListTile(title: const Text('Alamat tujuan'), subtitle: Text(order.shippingAddress)),
        if (order.shipmentReference.isNotEmpty) ListTile(title: const Text('Referensi pengiriman'), subtitle: SelectableText(order.shipmentReference)),
        const Divider(), Text('Rincian produk', style: Theme.of(context).textTheme.titleLarge),
        for (final item in bundle.items) ListTile(title: Text(item.nameSnapshot), subtitle: Text('${item.variantSnapshot} × ${item.quantity}'), trailing: Text(NsFormatters.rupiah(item.lineTotalIdr))),
        const SizedBox(height: 18),
        if (widget.appState.isOffline) const Text('Tidak ada koneksi. Tindakan pesanan dinonaktifkan.'),
        if (order.canVerifyPayment(widget.appState.activeRole)) ...[
          FilledButton(onPressed: submitting || widget.appState.isOffline ? null : () => act(order, 'verified'), child: const Text('Verifikasi pembayaran')),
          TextButton(onPressed: submitting || widget.appState.isOffline ? null : () => act(order, 'rejected'), child: const Text('Bukti belum sesuai')),
        ],
        for (final action in actions) OutlinedButton(onPressed: submitting || widget.appState.isOffline ? null : () => act(order, action),
          child: Text('Tandai: ${NsStatusDictionary.label(action)}')),
        if (order.canCancel(widget.appState.activeRole))
          TextButton(onPressed: submitting || widget.appState.isOffline ? null : () => act(order, 'cancel'), child: const Text('Batalkan pesanan')),
        const SizedBox(height: 20), Text('Riwayat', style: Theme.of(context).textTheme.titleLarge),
        for (final e in bundle.timeline) ListTile(title: Text(NsStatusDictionary.label(e.action)), subtitle: Text(NsFormatters.dateTime(e.createdAt))),
      ]);
    }),
  );
}
