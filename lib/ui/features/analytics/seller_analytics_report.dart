import 'package:flutter/material.dart';

import '../../../core/config/formatters.dart';
import '../../../core/theme/ns_colors.dart';
import '../../../core/widgets/ns_metric_chart.dart';
import '../../../domain/models/seller_models.dart';

/// Visual-only report: same backend values, clearer hierarchy on phone/tablet.
class SellerAnalyticsReport extends StatelessWidget {
  const SellerAnalyticsReport({super.key, required this.data});

  final SalesAnalyticsBundle data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _surface(
          key: const Key('analytics-revenue-card'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PENJUALAN TERVERIFIKASI',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: NsColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      )),
              const SizedBox(height: 8),
              FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(NsFormatters.rupiah(d.verifiedRevenueIdr),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 32,
                          color: NsColors.textPrimary,
                        )),
              ),
              const SizedBox(height: 6),
              const Text('Produk dibayar · tidak termasuk ongkir',
                  style: TextStyle(color: NsColors.textSecondary)),
              const Divider(height: 28),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 4,
                children: [
                  const Text('Periode sebelumnya',
                      style: TextStyle(color: NsColors.textSecondary)),
                  Text(NsFormatters.rupiah(d.previousRevenueIdr),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (d.previousRevenueIdr > 0)
                    Text(
                      '${(100 * (d.verifiedRevenueIdr / d.previousRevenueIdr - 1)).toStringAsFixed(1)}%',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: NsColors.brandAction),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, limits) {
          final columns = limits.maxWidth >= 720 ? 4 : 2;
          const gap = 10.0;
          final tileWidth = (limits.maxWidth - gap * (columns - 1)) / columns;
          final stats = [
            ('Pesanan', d.totalOrders, Icons.receipt_long_outlined),
            ('Dibayar', d.paidOrders, Icons.check_circle_outline),
            ('Dibatalkan', d.canceledOrders, Icons.cancel_outlined),
            ('Unit terjual', d.unitsSold, Icons.inventory_2_outlined),
          ];
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final stat in stats)
                SizedBox(
                  width: tileWidth,
                  child: _surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(stat.$3, size: 21, color: NsColors.brandAction),
                        const SizedBox(height: 11),
                        Text(NsFormatters.number(stat.$2),
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(stat.$1,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: NsColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
            ],
          );
        }),
        const SizedBox(height: 24),
        Text('Penjualan harian',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 5),
        Text('Pilih hari untuk melihat omzet dan jumlah pesanan.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: NsColors.textSecondary,
                )),
        const SizedBox(height: 12),
        NsMetricChart(points: d.dailyPoints),
        const SizedBox(height: 24),
        Text('Rincian penjualan',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        _surface(
          key: const Key('analytics-details-card'),
          child: Column(
            children: [
              _detail(context, 'Rata-rata pesanan',
                  NsFormatters.rupiah(d.averagePaidOrderIdr)),
              const Divider(height: 20),
              _detail(context, 'Ongkir dibayar',
                  NsFormatters.rupiah(d.shippingRevenueIdr)),
              const Divider(height: 20),
              _detail(context, 'Total pembayaran diterima',
                  NsFormatters.rupiah(d.totalCollectedIdr)),
              const Divider(height: 20),
              _detail(context, 'Pelanggan kembali',
                  '${d.returningCustomers} dari ${d.purchasingCustomers} pembeli'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Produk terlaris',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        _ranking(
          context,
          d.topProducts,
          emptyLabel: 'Belum ada produk terjual di periode ini.',
        ),
        if (d.topVariants.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Varian terlaris',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _ranking(context, d.topVariants, showVariants: true),
        ],
        const SizedBox(height: 16),
        Text(
          'Penjualan mengikuti tanggal pesanan yang sudah dibayar dan tidak dibatalkan atau kedaluwarsa. Pembeli tamu dikenali dari nomor telepon. Laba dan konversi belum dihitung.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: NsColors.textSecondary,
                height: 1.4,
              ),
        ),
      ],
    );
  }

  Widget _ranking(BuildContext context, List<SalesRanking> entries,
      {String emptyLabel = '', bool showVariants = false}) {
    return _surface(
      child: entries.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined,
                      size: 24, color: NsColors.textMuted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(emptyLabel,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: NsColors.textSecondary)),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < entries.length && i < 5; i++) ...[
                  if (i > 0) const Divider(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 30,
                        child: Text('${i + 1}.',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: NsColors.brandAction,
                            )),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entries[i].name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 3),
                            Text(
                              showVariants
                                  ? '${entries[i].variant} · ${entries[i].units} unit'
                                  : '${entries[i].units} unit terjual',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: NsColors.textSecondary),
                            ),
                            const SizedBox(height: 3),
                            Text(NsFormatters.rupiah(entries[i].revenueIdr),
                                style: const TextStyle(
                                    color: NsColors.brandAction,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }

  Widget _detail(BuildContext context, String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: NsColors.textSecondary,
                    )),
          ),
          const SizedBox(width: 12),
          Flexible(
            flex: 3,
            child: Text(value,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    )),
          ),
        ],
      );

  Widget _surface({required Widget child, Key? key}) => Container(
        key: key,
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NsColors.surfaceCard,
          border: Border.all(color: NsColors.borderDefault),
          borderRadius: BorderRadius.circular(18),
        ),
        child: child,
      );
}
