import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/ns_colors.dart';
import '../../../core/widgets/ns_widgets.dart';
import '../../../data/services/feature_guide_service.dart';

enum SellerGuideTarget { store, home, orders, products, analytics, shop }

class SellerGuideAnchors {
  final store = GlobalKey(debugLabel: 'guide-store');
  final tabs = List.generate(5, (i) => GlobalKey(debugLabel: 'guide-tab-$i'));

  GlobalKey keyFor(SellerGuideTarget target) =>
      target == SellerGuideTarget.store ? store : tabs[target.index - 1];
}

class SellerGuideScope extends InheritedWidget {
  const SellerGuideScope({
    super.key,
    required this.replay,
    required super.child,
  });

  final VoidCallback replay;

  static SellerGuideScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SellerGuideScope>();

  @override
  bool updateShouldNotify(SellerGuideScope oldWidget) =>
      replay != oldWidget.replay;
}

/// Lives with the shell; no tour is launched on auth, onboarding or editor pages.
class SellerFeatureGuide extends StatefulWidget {
  const SellerFeatureGuide({
    super.key,
    required this.userId,
    required this.eligible,
    required this.showAnalytics,
    required this.builder,
    this.service,
  });

  final String? userId;
  final bool eligible;
  final bool showAnalytics;
  final Widget Function(BuildContext, SellerGuideAnchors) builder;
  final FeatureGuideService? service;

  @override
  State<SellerFeatureGuide> createState() => _SellerFeatureGuideState();
}

class _SellerFeatureGuideState extends State<SellerFeatureGuide> {
  final _anchors = SellerGuideAnchors();
  late final FeatureGuideService _service =
      widget.service ?? FeatureGuideService();
  String? _checkedUser;
  RawDialogRoute<bool>? _route;

  @override
  void initState() {
    super.initState();
    _scheduleCheck();
  }

  @override
  void didUpdateWidget(SellerFeatureGuide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _checkedUser = null;
      _removeTour();
    } else if (!widget.eligible) {
      _removeTour();
    }
    _scheduleCheck();
  }

  void _scheduleCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_maybeStart());
    });
  }

  Future<void> _maybeStart() async {
    final userId = widget.userId;
    if (!widget.eligible || userId == null || _checkedUser == userId) return;
    _checkedUser = userId;
    try {
      final seen = await _service.hasSeen(userId);
      if (!seen && mounted && widget.userId == userId && widget.eligible) {
        unawaited(_showTour());
      }
    } catch (_) {
      // Storage failure must never block access to the seller workspace.
    }
  }

  Future<void> _showTour() async {
    final userId = widget.userId;
    if (!mounted || !widget.eligible || userId == null || _route != null)
      return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    final route = RawDialogRoute<bool>(
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      barrierLabel: 'Panduan fitur',
      transitionDuration: Duration.zero,
      pageBuilder: (context, _, __) => SellerGuideOverlay(
        anchors: _anchors,
        showAnalytics: widget.showAnalytics,
      ),
    );
    _route = route;
    try {
      final acknowledged =
          await Navigator.of(context, rootNavigator: true).push<bool>(route);
      if (acknowledged == true) await _service.markSeen(userId);
    } catch (_) {
      // Dismissal remains available if preference persistence is unavailable.
    } finally {
      if (identical(_route, route)) _route = null;
    }
  }

  void _removeTour() {
    final route = _route;
    _route = null;
    if (route == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route.isActive) route.navigator?.removeRoute(route);
    });
  }

  @override
  void dispose() {
    _removeTour();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SellerGuideScope(
        replay: () => unawaited(_showTour()),
        child: Builder(builder: (context) => widget.builder(context, _anchors)),
      );
}

class _GuideStep {
  const _GuideStep(this.target, this.title, this.description);
  final SellerGuideTarget target;
  final String title;
  final String description;
}

/// A modal spotlight blocks accidental taps on the live controls below it.
class SellerGuideOverlay extends StatefulWidget {
  const SellerGuideOverlay({
    super.key,
    required this.anchors,
    required this.showAnalytics,
  });

  final SellerGuideAnchors anchors;
  final bool showAnalytics;

  @override
  State<SellerGuideOverlay> createState() => _SellerGuideOverlayState();
}

class _SellerGuideOverlayState extends State<SellerGuideOverlay> {
  final _root = GlobalKey();
  final _card = GlobalKey();
  final _scroll = ScrollController();
  int _index = 0;
  Rect? _target;
  Rect? _cardRect;
  bool _scheduled = false;
  bool _closing = false;

  List<_GuideStep> get _steps => [
        const _GuideStep(
          SellerGuideTarget.store,
          'Kenali ruang tokomu',
          'Nama di atas menunjukkan toko yang sedang dikelola. Ketuk untuk berpindah toko; produk dan pesanan mengikuti toko aktif.',
        ),
        const _GuideStep(
          SellerGuideTarget.home,
          'Mulai dari Beranda',
          'Lihat ringkasan penjualan, pesanan yang perlu diproses, dan peringatan stok dalam satu halaman.',
        ),
        const _GuideStep(
          SellerGuideTarget.orders,
          'Pantau setiap pesanan',
          'Cari pesanan, periksa pembayaran, lalu lanjutkan proses pengiriman atau pengambilan sesuai statusnya.',
        ),
        const _GuideStep(
          SellerGuideTarget.products,
          'Siapkan produk jualanmu',
          'Tambahkan produk dan foto, atur harga serta varian, lalu perbarui stok melalui menu Produk.',
        ),
        if (widget.showAnalytics)
          const _GuideStep(
            SellerGuideTarget.analytics,
            'Baca perkembangan penjualan',
            'Pilih rentang tanggal untuk melihat tren penjualan dan laporan. Ekspor datanya saat diperlukan.',
          ),
        const _GuideStep(
          SellerGuideTarget.shop,
          'Pengaturan ada di Toko',
          'Buka chat pelanggan, isi penanggung jawab, dan kelola pengaturan sesuai aksesmu. Untuk mengulang panduan ini, buka Toko → Panduan fitur.',
        ),
      ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleMeasure();
  }

  void _scheduleMeasure() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _scheduled = false;
      if (!mounted) return;
      final anchorContext =
          widget.anchors.keyFor(_steps[_index].target).currentContext;
      if (anchorContext != null) {
        await Scrollable.ensureVisible(anchorContext, alignment: .5);
      }
      if (!mounted) return;
      final root = _root.currentContext?.findRenderObject();
      final anchor = anchorContext?.findRenderObject();
      final card = _card.currentContext?.findRenderObject();
      if (root is! RenderBox || !root.hasSize) return;
      Rect? target;
      if (anchor is RenderBox && anchor.attached && anchor.hasSize) {
        target =
            root.globalToLocal(anchor.localToGlobal(Offset.zero)) & anchor.size;
        if (MediaQuery.sizeOf(context).width >= 600 &&
            _steps[_index].target != SellerGuideTarget.store) {
          target = Rect.fromLTRB(
            target.left - 12,
            target.top - 40,
            target.right + 12,
            target.bottom + 10,
          );
        } else {
          target = target.inflate(4);
        }
        target = target.intersect(Offset.zero & root.size);
      }
      final cardRect = card is RenderBox && card.hasSize
          ? root.globalToLocal(card.localToGlobal(Offset.zero)) & card.size
          : null;
      if (_target != target || _cardRect != cardRect) {
        setState(() {
          _target = target;
          _cardRect = cardRect;
        });
      }
    });
  }

  void _move(int direction) {
    if (_closing) return;
    if (_index + direction >= _steps.length) {
      _finish();
      return;
    }
    setState(() {
      _index = (_index + direction).clamp(0, _steps.length - 1).toInt();
      _target = null;
      _cardRect = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _scheduleMeasure();
  }

  void _finish() {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleMeasure();
    final step = _steps[_index];
    final padding = MediaQuery.paddingOf(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Material(
        type: MaterialType.transparency,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final safe = Rect.fromLTRB(
              16,
              padding.top + 64,
              constraints.maxWidth - 16,
              constraints.maxHeight - padding.bottom - 16,
            );
            return SizedBox.expand(
              key: _root,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _GuideSpotlightPainter(_target, _cardRect),
                      ),
                    ),
                  ),
                  Positioned(
                    top: padding.top + 8,
                    right: 16,
                    child: TextButton(
                      onPressed: _finish,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: const Color(0xFF343034),
                        minimumSize: const Size(80, 48),
                      ),
                      child: const Text('Lewati'),
                    ),
                  ),
                  if (_target != null)
                    Positioned.fill(
                      child: CustomSingleChildLayout(
                        delegate: _GuideCardLayout(
                          safe: safe,
                          target: _target!,
                          rail: constraints.maxWidth >= 600 &&
                              step.target != SellerGuideTarget.store,
                        ),
                        child: Semantics(
                          liveRegion: true,
                          namesRoute: true,
                          label:
                              'Panduan fitur, langkah ${_index + 1} dari ${_steps.length}',
                          child: Material(
                            key: _card,
                            color: Colors.white,
                            elevation: 8,
                            shadowColor: const Color(0x33000000),
                            borderRadius: BorderRadius.circular(20),
                            clipBehavior: Clip.antiAlias,
                            child: SingleChildScrollView(
                              controller: _scroll,
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'KENALI FITUR  •  ${_index + 1}/${_steps.length}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: NsColors.brandAction,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    step.title,
                                    style: const TextStyle(
                                      fontFamily: 'Manrope',
                                      fontSize: 22,
                                      height: 1.2,
                                      fontWeight: FontWeight.w800,
                                      color: NsColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    step.description,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.5,
                                      color: NsColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Wrap(
                                    alignment: WrapAlignment.end,
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      if (_index > 0)
                                        TextButton(
                                          onPressed: () => _move(-1),
                                          child: const Text('Kembali'),
                                        ),
                                      FilledButton.icon(
                                        onPressed: () => _move(1),
                                        icon: NsIcon(
                                          _index == _steps.length - 1
                                              ? 'check'
                                              : 'arrow-right',
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        label: Text(
                                          _index == _steps.length - 1
                                              ? 'Selesai'
                                              : 'Lanjut',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GuideCardLayout extends SingleChildLayoutDelegate {
  _GuideCardLayout({
    required this.safe,
    required this.target,
    required this.rail,
  });
  final Rect safe;
  final Rect target;
  final bool rail;

  bool get _onSide => rail && safe.right - target.right > 280;
  bool get _below => target.center.dy < safe.center.dy;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final available = _onSide
        ? safe.height
        : _below
            ? safe.bottom - target.bottom - 24
            : target.top - safe.top - 24;
    return BoxConstraints(
      minWidth: 0,
      maxWidth: math.min(
          360.0, _onSide ? safe.right - target.right - 24 : safe.width),
      maxHeight: math.max(80.0, math.min(safe.height, available)),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final x = _onSide
        ? target.right + 24
        : (target.center.dx - childSize.width / 2)
            .clamp(safe.left, safe.right - childSize.width)
            .toDouble();
    final y = _onSide
        ? (target.center.dy - childSize.height / 2)
            .clamp(safe.top, safe.bottom - childSize.height)
            .toDouble()
        : _below
            ? math.max(safe.top, target.bottom + 24)
            : math.min(target.top - childSize.height - 24,
                safe.bottom - childSize.height);
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_GuideCardLayout oldDelegate) =>
      safe != oldDelegate.safe ||
      target != oldDelegate.target ||
      rail != oldDelegate.rail;
}

class _GuideSpotlightPainter extends CustomPainter {
  const _GuideSpotlightPainter(this.target, this.card);
  final Rect? target;
  final Rect? card;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    final hole = target == null
        ? null
        : RRect.fromRectAndRadius(target!, const Radius.circular(14));
    if (hole != null) path.addRRect(hole);
    canvas.drawPath(path, Paint()..color = const Color(0xB8000000));
    if (hole == null) return;
    canvas.drawRRect(
        hole,
        Paint()
          ..color = const Color(0xFFFF8BAE)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    final panel = card;
    if (panel == null || panel.overlaps(target!)) return;
    final from = target!;
    late Offset start;
    late Offset end;
    if (panel.left > from.right) {
      start = Offset(from.right + 5, from.center.dy);
      end = Offset(panel.left - 5, panel.center.dy);
    } else if (panel.top > from.bottom) {
      start = Offset(from.center.dx, from.bottom + 5);
      end = Offset(
          from.center.dx.clamp(panel.left + 20, panel.right - 20).toDouble(),
          panel.top - 5);
    } else {
      start = Offset(from.center.dx, from.top - 5);
      end = Offset(
          from.center.dx.clamp(panel.left + 20, panel.right - 20).toDouble(),
          panel.bottom + 5);
    }
    final line = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(start.dx, end.dy, end.dx, end.dy);
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final metric in line.computeMetrics()) {
      for (double offset = 0; offset < metric.length; offset += 9) {
        canvas.drawPath(
            metric.extractPath(offset, math.min(offset + 4, metric.length)),
            paint);
      }
    }
  }

  @override
  bool shouldRepaint(_GuideSpotlightPainter oldDelegate) =>
      target != oldDelegate.target || card != oldDelegate.card;
}
