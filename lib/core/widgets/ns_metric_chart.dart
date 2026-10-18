import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models/seller_models.dart';
import '../config/formatters.dart';
import '../theme/ns_colors.dart';

/// A responsive seven-day window. Never renders a clipped thirty-bar strip;
/// earlier days remain accessible with explicit pagination.
class NsMetricChart extends StatefulWidget {
  const NsMetricChart({super.key, required this.points});
  final List<DailySalesPoint> points;

  @override
  State<NsMetricChart> createState() => _NsMetricChartState();
}

class _NsMetricChartState extends State<NsMetricChart> {
  int _pageOffset = 0;
  int? _selectedIndex;

  @override
  void didUpdateWidget(covariant NsMetricChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.points, widget.points)) {
      _pageOffset = 0;
      _selectedIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    if (points.isEmpty) {
      return _surface(
        child: const _ChartEmpty(
          title: 'Belum ada data harian',
          description: 'Coba pilih periode laporan lain.',
        ),
      );
    }

    final end = math.max(0, points.length - _pageOffset * 7);
    final start = math.max(0, end - 7);
    final week = points.sublist(start, end);
    final selectedIndex = _selectedIndex != null &&
            _selectedIndex! >= start &&
            _selectedIndex! < end
        ? _selectedIndex!
        : end - 1;
    final selected = points[selectedIndex];
    final maxValue = week.fold<int>(
      0,
      (max, point) => math.max(max, point.revenueIdr),
    );
    final firstLabel = NsFormatters.shortDate(week.first.day);
    final lastLabel = NsFormatters.shortDate(week.last.day);

    return Semantics(
      label:
          'Grafik penjualan harian. ${points.length} hari tersedia. Tanggal ${selected.day}, ${selected.orders} pesanan, ${NsFormatters.rupiah(selected.revenueIdr)}.',
      child: _surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Periode $firstLabel – $lastLabel',
                    maxLines: 2,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                IconButton(
                  key: const Key('chart-older'),
                  tooltip: '7 hari sebelumnya',
                  onPressed: start == 0
                      ? null
                      : () => setState(() {
                            _pageOffset++;
                            _selectedIndex = null;
                          }),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                IconButton(
                  key: const Key('chart-newer'),
                  tooltip: '7 hari berikutnya',
                  onPressed: _pageOffset == 0
                      ? null
                      : () => setState(() {
                            _pageOffset--;
                            _selectedIndex = null;
                          }),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const Divider(height: 20),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  '${NsFormatters.shortDate(selected.day)} · ${selected.orders} pesanan',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: NsColors.textSecondary,
                      ),
                ),
                Text(
                  NsFormatters.rupiah(selected.revenueIdr),
                  key: const Key('chart-selected-revenue'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: NsColors.brandAction,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (maxValue == 0)
              const _ChartEmpty(
                title: 'Belum ada penjualan pada minggu ini',
                description: 'Gunakan panah untuk memeriksa minggu sebelumnya.',
              )
            else
              SizedBox(
                height: 136,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < week.length; i++)
                      Expanded(
                        child: Semantics(
                          button: true,
                          label:
                              '${week[i].day}, ${week[i].orders} pesanan, ${NsFormatters.rupiah(week[i].revenueIdr)}',
                          child: InkWell(
                            key: Key('chart-day-$i'),
                            borderRadius: BorderRadius.circular(8),
                            onTap: () =>
                                setState(() => _selectedIndex = start + i),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: FractionallySizedBox(
                                        widthFactor: 0.72,
                                        heightFactor: week[i].revenueIdr == 0
                                            ? 0.025
                                            : (week[i].revenueIdr / maxValue)
                                                .clamp(0.07, 1.0),
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: selectedIndex == start + i
                                                ? NsColors.brandAction
                                                : NsColors.brandPrimary
                                                    .withValues(alpha: 0.33),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    week[i].day.length >= 10
                                        ? week[i].day.substring(8, 10)
                                        : week[i].day,
                                    maxLines: 1,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: selectedIndex == start + i
                                              ? NsColors.brandAction
                                              : NsColors.textSecondary,
                                          fontWeight:
                                              selectedIndex == start + i
                                                  ? FontWeight.w800
                                                  : FontWeight.w500,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Text(
              'Menampilkan ${week.length} dari ${points.length} hari · pilih tanggal untuk melihat detail.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: NsColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _surface({required Widget child}) => Container(
        key: const Key('daily-sales-chart-card'),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NsColors.surfaceCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: NsColors.borderDefault),
        ),
        child: child,
      );
}

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty({required this.title, required this.description});
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('daily-sales-empty-state'),
        constraints: const BoxConstraints(minHeight: 92),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: NsColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bar_chart_outlined,
                color: NsColors.textMuted, size: 23),
            const SizedBox(height: 6),
            Text(title, textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 3),
            Text(description, textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: NsColors.textSecondary,
                )),
          ],
        ),
      );
}
