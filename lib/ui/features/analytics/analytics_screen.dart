import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/formatters.dart';
import '../../../core/theme/ns_colors.dart';
import 'seller_analytics_report.dart';
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
  String timezone = 'Asia/Jakarta';
  DateTimeRange get range {
    if (custom != null) return custom!;
    final now = DateTime.now().toUtc().add(Duration(
        hours: timezone == 'Asia/Makassar'
            ? 8
            : timezone == 'Asia/Jayapura'
                ? 9
                : timezone == 'UTC'
                    ? 0
                    : 7));
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
    future = store == null ||
            !widget.appState.activeRole.canViewCustomersAndAnalytics
        ? null
        : widget.appState.repository.fetchAnalytics(
            storeId: store!,
            fromDate: NsFormatters.calendarDate(dates.start),
            toDate: NsFormatters.calendarDate(dates.end),
            timezone: timezone,
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
        revision != widget.appState.storeDataRevision) setState(load);
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
          key: const PageStorageKey('analytics'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('Analitik',
                              style: Theme.of(context).textTheme.headlineMedium),
                        ),
                        if (widget.appState.activeRole.canViewCustomersAndAnalytics)
                          PopupMenuButton<String>(
                            tooltip: 'Ekspor CSV',
                            enabled: !exporting,
                            onSelected: export,
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                  value: 'orders', child: Text('Ekspor pesanan')),
                              PopupMenuItem(
                                  value: 'products', child: Text('Ekspor produk')),
                              PopupMenuItem(
                                  value: 'customers',
                                  child: Text('Ekspor pelanggan')),
                            ],
                            icon: const Icon(Icons.file_download_outlined),
                          ),
                      ],
                    ),
                    Text(
                      'Pantau performa penjualan dan pelanggan tokomu.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: NsColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 18),
                    if (!widget.appState.activeRole.canViewCustomersAndAnalytics)
                      _card(
                        child: const Text(
                          'Akses analitik tidak tersedia untuk peran ini.',
                        ),
                      )
                    else ...[
                      _card(
                        key: const Key('analytics-filter-card'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Periode laporan',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                for (final count in [7, 30])
                                  ChoiceChip(
                                    label: Text('$count hari'),
                                    selected: custom == null && days == count,
                                    onSelected: (_) => setState(() {
                                      custom = null;
                                      days = count;
                                      load();
                                    }),
                                  ),
                                ActionChip(
                                  avatar: const Icon(
                                      Icons.calendar_today_outlined, size: 16),
                                  label: const Text('Pilih tanggal'),
                                  onPressed: () async {
                                    final selected = await showDateRangePicker(
                                      context: context,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now(),
                                      initialDateRange: custom,
                                    );
                                    if (selected != null && mounted) {
                                      setState(() {
                                        custom = selected;
                                        load();
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text('Zona waktu',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: NsColors.textSecondary)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: timezone,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                              items: const [
                                DropdownMenuItem(
                                    value: 'Asia/Jakarta',
                                    child: Text('WIB (Jakarta)')),
                                DropdownMenuItem(
                                    value: 'Asia/Makassar',
                                    child: Text('WITA (Makassar)')),
                                DropdownMenuItem(
                                    value: 'Asia/Jayapura',
                                    child: Text('WIT (Jayapura)')),
                                DropdownMenuItem(
                                    value: 'UTC', child: Text('UTC')),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  timezone = value;
                                  load();
                                });
                              },
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${NsFormatters.shortDate(NsFormatters.calendarDate(range.start))} – ${NsFormatters.shortDate(NsFormatters.calendarDate(range.end))} · $timezone',
                              key: const Key('analytics-active-period'),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: NsColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      FutureBuilder<SalesAnalyticsBundle>(
                        future: future,
                        builder: (context, snap) {
                          if (snap.connectionState != ConnectionState.done) {
                            return _card(
                              child: const SizedBox(
                                height: 120,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            );
                          }
                          if (snap.hasError || snap.data == null) {
                            return _card(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Analitik belum dapat dimuat.'),
                                  const SizedBox(height: 8),
                                  TextButton.icon(
                                    onPressed: () => setState(load),
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Coba lagi'),
                                  ),
                                ],
                              ),
                            );
                          }
                          return SellerAnalyticsReport(data: snap.data!);
                        },
                      ),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(error!,
                          style: const TextStyle(
                              color: NsColors.statusDangerText)),
                    ],
                    if (exporting) const LinearProgressIndicator(),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _card({required Widget child, Key? key}) => Container(
        key: key,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NsColors.surfaceCard,
          border: Border.all(color: NsColors.borderDefault),
          borderRadius: BorderRadius.circular(18),
        ),
        child: child,
      );
}
