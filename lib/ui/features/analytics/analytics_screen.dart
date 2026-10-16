import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/formatters.dart';
import '../../../core/widgets/ns_metric_chart.dart';
import '../../../domain/models/seller_models.dart';
import '../../state/seller_app_state.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key, required this.appState});
  final SellerAppState appState;
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Future<SalesAnalyticsBundle>? future;
  String? store;
  int revision = -1, days = 30;
  DateTimeRange? custom;
  bool exporting = false;
  String? error;
  DateTimeRange get range {
    if (custom != null) return custom!;
    final now = DateTime.now();
    return DateTimeRange(
      start: DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: days - 1)),
      end: DateTime(now.year, now.month, now.day),
    );
  }

  void load() {
    store = widget.appState.activeStore?.id;
    revision = widget.appState.storeDataRevision;
    final dates = range;
    future = store == null
        ? null
        : widget.appState.repository.fetchAnalytics(
            storeId: store!,
            fromDate: NsFormatters.calendarDate(dates.start),
            toDate: NsFormatters.calendarDate(dates.end),
          );
  }

  @override
  void initState() {
    super.initState();
    load();
    widget.appState.addListener(changed);
  }

  void changed() {
    if (store != widget.appState.activeStore?.id ||
        revision != widget.appState.storeDataRevision)
      setState(load);
  }

  @override
  void dispose() {
    widget.appState.removeListener(changed);
    super.dispose();
  }

  Future<void> export(String kind) async {
    if (store == null || exporting) return;
    setState(() {
      exporting = true;
      error = null;
    });
    File? file;
    try {
      final data = await widget.appState.repository.exportCsv(
        storeId: store!,
        resource: kind,
        role: widget.appState.activeRole,
      );
      final dir = await getTemporaryDirectory();
      file = File(
        '${dir.path}/nalaro-${kind}-${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      await file.writeAsString(data, flush: true);
      if (!mounted) return;
      await Share.shareXFiles([
        XFile(file.path, mimeType: 'text/csv'),
      ], text: 'Ekspor data Nalaro Seller');
    } catch (e) {
      if (mounted) setState(() => error = 'Ekspor belum berhasil: $e');
    } finally {
      try {
        if (file != null && await file.exists()) await file.delete();
      } catch (_) {}
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async {
      setState(load);
      try {
        await future;
      } catch (_) {}
    },
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Analitik',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            if (widget.appState.activeRole.canViewCustomersAndAnalytics)
              PopupMenuButton<String>(
                tooltip: 'Ekspor CSV',
                enabled: !exporting,
                onSelected: export,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'orders', child: Text('Ekspor pesanan')),
                  PopupMenuItem(
                    value: 'products',
                    child: Text('Ekspor produk'),
                  ),
                  PopupMenuItem(
                    value: 'customers',
                    child: Text('Ekspor pelanggan'),
                  ),
                ],
                icon: const Icon(Icons.file_download_outlined),
              ),
          ],
        ),
        const Text('Lihat penjualan dari pesanan yang sudah dibayar.'),
        const SizedBox(height: 12),
        if (!widget.appState.activeRole.canViewCustomersAndAnalytics)
          const ListTile(
            title: Text('Akses analitik tidak tersedia untuk peran ini.'),
          ),
        if (widget.appState.activeRole.canViewCustomersAndAnalytics) ...[
          Wrap(
            spacing: 8,
            children: [
              for (final value in [7, 30])
                ChoiceChip(
                  label: Text('$value hari'),
                  selected: custom == null && days == value,
                  onSelected: (_) => setState(() {
                    custom = null;
                    days = value;
                    load();
                  }),
                ),
              ActionChip(
                label: Text(
                  custom == null
                      ? 'Rentang khusus'
                      : '${NsFormatters.calendarDate(range.start)} – ${NsFormatters.calendarDate(range.end)}',
                ),
                onPressed: () async {
                  final selected = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (selected != null && mounted)
                    setState(() {
                      custom = selected;
                      load();
                    });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Laporan: ${NsFormatters.calendarDate(range.start)} s.d. ${NsFormatters.calendarDate(range.end)} • tanggal laporan menggunakan UTC.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          FutureBuilder<SalesAnalyticsBundle>(
            future: future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done)
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              if (snap.hasError)
                return ListTile(
                  title: const Text('Analitik belum dapat dimuat'),
                  subtitle: Text('${snap.error}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => setState(load),
                  ),
                );
              final d = snap.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'Omzet terverifikasi',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    NsFormatters.rupiah(d.verifiedRevenueIdr),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text('${d.totalOrders} pesanan')),
                      Chip(label: Text('${d.paidOrders} dibayar')),
                      Chip(label: Text('${d.canceledOrders} dibatalkan')),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Penjualan harian',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  NsMetricChart(points: d.dailyPoints),
                  const SizedBox(height: 8),
                  Text(
                    '${d.dailyPoints.length} hari memiliki aktivitas yang tercatat dalam rentang ini.',
                  ),
                ],
              );
            },
          ),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          if (exporting) const LinearProgressIndicator(),
        ],
      ],
    ),
  );
}
