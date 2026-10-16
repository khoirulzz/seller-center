import 'package:flutter/material.dart';
import '../../domain/models/seller_models.dart';
import '../config/formatters.dart';
import '../theme/ns_colors.dart';
import '../theme/ns_radius.dart';
import '../theme/ns_spacing.dart';
import '../theme/ns_typography.dart';

/// Grafik penjualan harian interaktif (`NsMetricChart`) dengan tooltip tap/drag dan
/// ringkasan aksesibilitas semantik (`PRD` ANA-02 & `desain.md` Bab 8.10).
class NsMetricChart extends StatefulWidget {
  const NsMetricChart({
    super.key,
    required this.points,
  });

  final List<DailySalesPoint> points;

  @override
  State<NsMetricChart> createState() => _NsMetricChartState();
}

class _NsMetricChartState extends State<NsMetricChart> {
  int _selectedIndex = 0;

  @override
  void didUpdateWidget(covariant NsMetricChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedIndex >= widget.points.length) {
      _selectedIndex = widget.points.isEmpty ? 0 : widget.points.length - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) {
      return Container(
        height: 200,
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(NsSpacing.lg),
        decoration: BoxDecoration(
          color: NsColors.surfaceSubtle,
          borderRadius: NsRadius.card,
          border: Border.all(color: NsColors.borderDefault),
        ),
        child: Text(
          'Belum ada penjualan pada periode ini.',
          style: NsTypography.bodyMd.copyWith(color: NsColors.textSecondary),
        ),
      );
    }

    final safeIndex = _selectedIndex.clamp(0, widget.points.length - 1);
    final selected = widget.points[safeIndex];
    final maxRevenue = widget.points
        .map((p) => p.revenueIdr)
        .fold<int>(1, (a, b) => a > b ? a : b);

    return Semantics(
      label:
          'Grafik penjualan harian. Tanggal terpilih ${selected.day}, ${selected.orders} pesanan, penjualan ${NsFormatters.rupiah(selected.revenueIdr)}',
      child: Container(
        padding: const EdgeInsets.all(NsSpacing.md),
        decoration: BoxDecoration(
          color: NsColors.surfaceCard,
          borderRadius: NsRadius.card,
          border: Border.all(color: NsColors.borderDefault),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: NsSpacing.sm,
                vertical: NsSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: NsColors.surfaceSubtle,
                borderRadius: NsRadius.chip,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${NsFormatters.shortDate(selected.day)} · ${selected.orders} pesanan',
                    style: NsTypography.bodySm.copyWith(
                      color: NsColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    NsFormatters.rupiah(selected.revenueIdr),
                    style: NsTypography.titleSm.copyWith(
                      color: NsColors.brandAction,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: NsSpacing.md),
            SizedBox(
              height: 150,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: widget.points.length > 10 ? widget.points.length * 32.0 : MediaQuery.sizeOf(context).width - 72,
                  child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(widget.points.length, (index) {
                  final point = widget.points[index];
                  final ratio = (point.revenueIdr / maxRevenue).clamp(0.08, 1.0);
                  final isSelected = index == safeIndex;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _selectedIndex = index),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                  heightFactor: ratio,
                                  widthFactor: 0.72,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 160),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? NsColors.brandPrimary
                                          : NsColors.borderDefault,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              point.day.length >= 10
                                  ? point.day.substring(8, 10)
                                  : point.day,
                              style: NsTypography.caption.copyWith(
                                color: isSelected
                                    ? NsColors.textPrimary
                                    : NsColors.textMuted,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
