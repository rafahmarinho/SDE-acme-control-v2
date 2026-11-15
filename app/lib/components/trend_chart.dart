import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';
import 'state_views.dart';

/// Lightweight line chart for one trend series (no third-party chart dependency).
/// Tap/drag on the chart to inspect the nearest value.
class TrendChart extends StatefulWidget {
  const TrendChart({super.key, required this.series, this.color});
  final TrendSeries series;
  final Color? color;
  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart> {
  int? _cursor;

  void _pick(Offset local, Size size) {
    final pts = widget.series.points;
    if (pts.length < 2) return;
    final t0 = pts.first.ts.millisecondsSinceEpoch, t1 = pts.last.ts.millisecondsSinceEpoch;
    final x = ((local.dx - _TrendPainter.leftPad) / (size.width - _TrendPainter.leftPad - 8)).clamp(0.0, 1.0);
    final target = t0 + (t1 - t0) * x;
    var best = 0;
    for (var i = 1; i < pts.length; i++) {
      if ((pts[i].ts.millisecondsSinceEpoch - target).abs() < (pts[best].ts.millisecondsSinceEpoch - target).abs()) best = i;
    }
    setState(() => _cursor = best);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    final pts = widget.series.points;
    final cursor = _cursor != null && _cursor! < pts.length ? pts[_cursor!] : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: 20,
        child: cursor == null
            ? Text('Tap the chart to inspect values', style: Theme.of(context).textTheme.bodySmall)
            : Text('${formatTime(cursor.ts)}  ·  ${cursor.value.toStringAsFixed(2)} ${widget.series.unit}', style: Theme.of(context).textTheme.bodyMedium),
      ),
      Expanded(
        child: LayoutBuilder(builder: (context, c) {
          final size = Size(c.maxWidth, c.maxHeight);
          return GestureDetector(
            onTapDown: (d) => _pick(d.localPosition, size),
            onHorizontalDragUpdate: (d) => _pick(d.localPosition, size),
            child: CustomPaint(size: size, painter: _TrendPainter(widget.series, color, Theme.of(context).colorScheme, _cursor)),
          );
        }),
      ),
    ]);
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.series, this.color, this.scheme, this.cursor);
  final TrendSeries series;
  final Color color;
  final ColorScheme scheme;
  final int? cursor;

  static const leftPad = 48.0;
  static const bottomPad = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    final pts = series.points;
    final plot = Rect.fromLTRB(leftPad, 6, size.width - 8, size.height - bottomPad);
    final axis = Paint()
      ..color = scheme.outlineVariant
      ..strokeWidth = 1;
    if (pts.isEmpty) return;
    var lo = pts.map((p) => p.value).reduce(math.min), hi = pts.map((p) => p.value).reduce(math.max);
    if ((hi - lo).abs() < 1e-9) {
      lo -= 1;
      hi += 1;
    }
    final pad = (hi - lo) * 0.08;
    lo -= pad;
    hi += pad;
    final t0 = pts.first.ts.millisecondsSinceEpoch.toDouble();
    final t1 = math.max(pts.last.ts.millisecondsSinceEpoch.toDouble(), t0 + 1);
    Offset map(TrendPoint p) => Offset(
          plot.left + (p.ts.millisecondsSinceEpoch - t0) / (t1 - t0) * plot.width,
          plot.bottom - (p.value - lo) / (hi - lo) * plot.height,
        );

    // grid + y labels
    for (var i = 0; i <= 4; i++) {
      final y = plot.top + plot.height * i / 4;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), axis);
      _text(canvas, Offset(plot.left - 6, y - 7), (hi - (hi - lo) * i / 4).toStringAsFixed(1), right: true);
    }
    // x labels
    for (var i = 0; i <= 3; i++) {
      final t = DateTime.fromMillisecondsSinceEpoch((t0 + (t1 - t0) * i / 3).round());
      _text(canvas, Offset(plot.left + plot.width * i / 3 - 16, plot.bottom + 4), formatShortTime(t));
    }

    final path = Path()..moveTo(map(pts.first).dx, map(pts.first).dy);
    for (final p in pts.skip(1)) {
      final o = map(p);
      path.lineTo(o.dx, o.dy);
    }
    final area = Path.from(path)
      ..lineTo(map(pts.last).dx, plot.bottom)
      ..lineTo(map(pts.first).dx, plot.bottom)
      ..close();
    canvas.drawPath(area, Paint()..color = color.withValues(alpha: 0.15));
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    if (cursor != null && cursor! < pts.length) {
      final o = map(pts[cursor!]);
      canvas.drawLine(Offset(o.dx, plot.top), Offset(o.dx, plot.bottom), axis..color = scheme.outline);
      canvas.drawCircle(o, 4, Paint()..color = color);
    }
  }

  void _text(Canvas canvas, Offset at, String s, {bool right = false}) {
    final tp = TextPainter(text: TextSpan(text: s, style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, right ? at - Offset(tp.width, 0) : at);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => old.series != series || old.cursor != cursor || old.color != color;
}
