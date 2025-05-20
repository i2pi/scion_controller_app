// system_overview.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'osc_widget_binding.dart';
import 'labeled_card.dart';
import 'osc_text.dart';
import 'system_overview_tiles.dart';

/// Centralized layout constants
class TileLayout {
  static const double marginPerTile = 8;      // horizontal space between tiles
  static const double tileOuterMargin = 4;    // outer margin on each tile container
  static const double sectionBoxPadding = 8;  // padding inside each section box
  static const double cardPadding = 8;        // padding inside the LabeledCard
  static const double lockColumnWidth = 60;   // fixed width for the lock column
  static const double rowSpacing = 48;        // vertical spacing between rows

  static double totalHorizontalPaddingPerTile() =>
      2 * (tileOuterMargin + sectionBoxPadding);

  static double computeTileSize(double maxWidth) {
    const int tileCount = 5;
    final double spacing = (tileCount - 1) * marginPerTile;
    final double outer = tileCount * totalHorizontalPaddingPerTile();
    return (maxWidth - lockColumnWidth - spacing - outer) / tileCount;
  }
}

enum LabelPosition { top, bottom }

class SystemOverview extends StatefulWidget {
  const SystemOverview({Key? key}) : super(key: key);

  @override
  _SystemOverviewState createState() => _SystemOverviewState();
}

class _SystemOverviewState extends State<SystemOverview>
    with WidgetsBindingObserver {
  final GlobalKey _stackKey = GlobalKey();
  final List<GlobalKey> _inputKeys = List.generate(4, (_) => GlobalKey());
  final List<GlobalKey> _sendKeys = List.generate(4, (_) => GlobalKey());
  final GlobalKey _returnKey = GlobalKey();
  final GlobalKey _outputKey = GlobalKey();

  List<Arrow> _arrows = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrows());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrows());
  }

  Widget _sectionBox({
    required String title,
    required Widget child,
    required LabelPosition labelPosition,
  }) {
    final label = Text(
      title,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    );
    return Container(
      margin: EdgeInsets.all(TileLayout.tileOuterMargin),
      padding: EdgeInsets.all(TileLayout.sectionBoxPadding),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[700]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: labelPosition == LabelPosition.top
            ? [label, const SizedBox(height: 4), child]
            : [
                child,
                const SizedBox(height: 4),
                Align(alignment: Alignment.centerLeft, child: label),
              ],
      ),
    );
  }

  void _updateArrows() {
    final box =
        _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final double tileSize = TileLayout.computeTileSize(box.size.width);
    final List<Arrow> newArrows = [];

    void connect(GlobalKey fromKey, GlobalKey toKey,
        Offset fromOffset, Offset toOffset) {
      final fromBox =
          fromKey.currentContext?.findRenderObject() as RenderBox?;
      final toBox =
          toKey.currentContext?.findRenderObject() as RenderBox?;
      if (fromBox == null || toBox == null) return;

      final fromGlobal = fromBox.localToGlobal(fromOffset);
      final toGlobal = toBox.localToGlobal(toOffset);
      final fromLocal = box.globalToLocal(fromGlobal);
      final toLocal = box.globalToLocal(toGlobal);
      newArrows.add(Arrow(fromLocal, toLocal));
    }

    connect(_inputKeys[0], _sendKeys[0],
        Offset(tileSize / 2, tileSize), Offset(tileSize / 2, 0));
    connect(_inputKeys[1], _sendKeys[1],
        Offset(tileSize / 2, tileSize), Offset(tileSize / 2, 0));
    connect(_inputKeys[1], _sendKeys[2],
        Offset(tileSize / 2, tileSize), Offset(tileSize / 2, 0));
    connect(_inputKeys[2], _sendKeys[3],
        Offset(tileSize / 2, tileSize), Offset(tileSize / 2, 0));
    connect(_inputKeys[2], _sendKeys[3],
        Offset(tileSize / 2, tileSize), Offset(tileSize / 2, 0));

    // Return → Output
    connect(_returnKey, _outputKey,
        Offset(tileSize / 2, 0), Offset(tileSize / 2, tileSize));

    setState(() => _arrows = newArrows);
  }

  @override
  Widget build(BuildContext context) {
    return LabeledCard(
      title: 'System Overview',
      child: Padding(
        padding: EdgeInsets.all(TileLayout.cardPadding),
        child: LayoutBuilder(builder: (context, constraints) {
          final double tileSize =
              TileLayout.computeTileSize(constraints.maxWidth);

          Widget sizedTile(Widget tile, GlobalKey key) => SizedBox(
                key: key,
                width: tileSize,
                height: tileSize,
                child: tile,
              );

          return Stack(
            key: _stackKey,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top row
                  Row(
                    children: [
                      _sectionBox(
                        title: 'HDMI Inputs',
                        labelPosition: LabelPosition.top,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                            4,
                            (i) => Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal:
                                      TileLayout.marginPerTile / 2),
                              child: sizedTile(
                                InputTile(index: i + 1),
                                _inputKeys[i],
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: TileLayout.lockColumnWidth),
                      _sectionBox(
                        title: 'HDMI Out',
                        labelPosition: LabelPosition.top,
                        child: sizedTile(
                          const HDMIOutTile(),
                          _outputKey,
                        ),
                      ),
                    ],
                  ),

                  // Vertical spacing
                  SizedBox(height: TileLayout.rowSpacing),

                  // Bottom row
                  Row(
                    children: [
                      _sectionBox(
                        title: 'Analog Sends',
                        labelPosition: LabelPosition.bottom,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                            4,
                            (i) => Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal:
                                      TileLayout.marginPerTile / 2),
                              child: sizedTile(
                                AnalogSendTile(index: i + 1),
                                _sendKeys[i],
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: TileLayout.lockColumnWidth,
                        child: Center(child: const SyncLock()),
                      ),
                      _sectionBox(
                        title: 'Return',
                        labelPosition: LabelPosition.bottom,
                        child: sizedTile(
                          const ReturnTile(),
                          _returnKey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Arrows overlay
              Positioned.fill(
                child: CustomPaint(painter: _ArrowsPainter(_arrows)),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class Arrow {
  final Offset from, to;
  Arrow(this.from, this.to);
}

class _ArrowsPainter extends CustomPainter {
  final List<Arrow> arrows;
  _ArrowsPainter(this.arrows);

  Color? col = Colors.grey[400];

  @override
  void paint(Canvas canvas, Size size) {
    final shaftPaint = Paint()
      ..color = col!
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    final headFillPaint = Paint()
      ..color = col!
      ..style = PaintingStyle.fill;
    final headStrokePaint = Paint()
      ..color = col!
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (final a in arrows) {
      final angle = (a.to - a.from).direction;
      const headLen = 12.0, headAngle = pi / 6;
      final p1 = a.to -
          Offset(
            headLen * cos(angle - headAngle),
            headLen * sin(angle - headAngle),
          );
      final p2 = a.to -
          Offset(
            headLen * cos(angle + headAngle),
            headLen * sin(angle + headAngle),
          );
      final baseCenter = Offset(
        (p1.dx + p2.dx) / 2,
        (p1.dy + p2.dy) / 2,
      );
      canvas.drawLine(a.from, baseCenter, shaftPaint);

      final path = Path()
        ..moveTo(a.to.dx, a.to.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close();
      canvas.drawPath(path, headFillPaint);
      canvas.drawPath(path, headStrokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ArrowsPainter old) =>
      old.arrows != arrows;
}
