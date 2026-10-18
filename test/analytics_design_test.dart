import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nalaro_seller_center/core/theme/ns_colors.dart';
import 'package:nalaro_seller_center/core/theme/ns_theme.dart';
import 'package:nalaro_seller_center/core/widgets/ns_metric_chart.dart';
import 'package:nalaro_seller_center/domain/models/seller_models.dart';
import 'package:nalaro_seller_center/ui/features/analytics/seller_analytics_report.dart';

List<DailySalesPoint> days({bool allZero = false}) => List.generate(21, (i) {
      final day = DateTime(2026, 10, i + 1).toIso8601String().substring(0, 10);
      return DailySalesPoint(
        day: day,
        orders: allZero ? 0 : i + 1,
        revenueIdr: allZero ? 0 : (i + 1) * 10000,
      );
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('zero revenue renders short empty state, not a 30-day blank chart',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: NsTheme.light,
      home: Scaffold(body: SingleChildScrollView(
        child: NsMetricChart(points: days(allZero: true)),
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('daily-sales-empty-state')), findsOneWidget);
    expect(find.byKey(const Key('chart-newer')), findsOneWidget);
    expect(find.byKey(const Key('chart-older')), findsOneWidget);
    expect(find.byKey(const Key('chart-day-0')), findsNothing);
    await tester.tap(find.byKey(const Key('chart-older')));
    await tester.pumpAndSettle();
    expect(find.textContaining('minggu ini'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('seven-day chart paging and day selection are responsive',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 700);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: NsTheme.light,
      home: Scaffold(body: SingleChildScrollView(
        child: NsMetricChart(points: days()),
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chart-day-6')), findsOneWidget);
    expect(find.byKey(const Key('chart-day-7')), findsNothing);
    expect(find.text('Rp210.000'), findsOneWidget);
    await tester.tap(find.byKey(const Key('chart-older')));
    await tester.pumpAndSettle();
    expect(find.text('Rp140.000'), findsOneWidget);
    await tester.tap(find.byKey(const Key('chart-day-0')));
    await tester.pumpAndSettle();
    expect(find.text('Rp80.000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0, 600.0]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('analytics report $width dp at text scale $scale',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final data = SalesAnalyticsBundle(
          totalOrders: 9,
          paidOrders: 5,
          canceledOrders: 2,
          verifiedRevenueIdr: 200000,
          shippingRevenueIdr: 30000,
          totalCollectedIdr: 230000,
          purchasingCustomers: 5,
          returningCustomers: 1,
          dailyPoints: days(),
        );
        await tester.pumpWidget(MaterialApp(
          theme: NsTheme.light,
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 900),
                textScaler: TextScaler.linear(scale),
              ),
              child: SingleChildScrollView(
                child: SellerAnalyticsReport(data: data),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('analytics-revenue-card')),
            findsOneWidget);
        expect(find.byKey(const Key('analytics-details-card')),
            findsOneWidget);
        final revenue =
            tester.widget<Container>(find.byKey(const Key('analytics-revenue-card')));
        final decoration = revenue.decoration! as BoxDecoration;
        expect(decoration.color, NsColors.surfaceCard);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
