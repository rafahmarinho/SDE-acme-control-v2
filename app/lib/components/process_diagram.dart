import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/models.dart';

/// Water-treatment process diagram: raw-water inlet valve -> raw tank -> transfer pumps ->
/// treated tank -> distribution outlet valve. Shows level, pressure and flow; animates water
/// flowing through pipes that carry flow; pumps spin when actually running; equipment whose
/// actual state differs from the requested state is outlined in amber.
///
/// Layout adapts to the available space: left-to-right on wide screens and top-to-bottom on
/// phones (PRD: "No mobile, adapte o diagrama"). Tanks are drawn as shaded cylinders (2.5D).
/// All labels are painted text from typed values - no HTML rendering (T36).
class ProcessDiagram extends StatefulWidget {
  const ProcessDiagram({super.key, required this.process, this.onSelect, this.selectedId});

  final PlantProcess process;

  /// Called with ('tank' | 'pump' | 'valve', id) when an element is tapped.
  final void Function(String kind, String id)? onSelect;
  final String? selectedId;

  @override
  State<ProcessDiagram> createState() => _ProcessDiagramState();
}

class _ProcessDiagramState extends State<ProcessDiagram> with SingleTickerProviderStateMixin {
  late final AnimationController _flow = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      final vertical = size.width < 600 && size.height > size.width;
      final geo = _Geometry(widget.process, size, vertical);
      final scheme = Theme.of(context).colorScheme;
      return Stack(children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _DiagramPainter(geo: geo, animation: _flow, scheme: scheme, selectedId: widget.selectedId),
            ),
          ),
        ),
        if (widget.onSelect != null)
          for (final hit in geo.hitTargets)
            Positioned.fromRect(
              rect: hit.rect,
              child: Semantics(
                button: true,
                label: hit.label,
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => widget.onSelect!(hit.kind, hit.id),
                    child: Tooltip(message: hit.label, child: const SizedBox.expand()),
                  ),
                ),
              ),
            ),
      ]);
    });
  }
}

class _Hit {
  const _Hit(this.kind, this.id, this.rect, this.label);
  final String kind, id, label;
  final Rect rect;
}

/// Positions are defined in normalised flow coordinates (u along the flow, v across it) and
/// mapped to screen space horizontally or vertically.
class _Geometry {
  _Geometry(this.process, this.size, this.vertical) {
    final tanks = [...process.tanks]..sort((a, b) => a.tag.compareTo(b.tag));
    source = tanks.isNotEmpty ? tanks.first : null;
    dest = tanks.length > 1 ? tanks[1] : null;
    inlets = process.valves.where((v) => v.isInlet).toList();
    outlets = process.valves.where((v) => !v.isInlet).toList();
    pumps = [...process.pumps]..sort((a, b) => a.tag.compareTo(b.tag));
    unit = math.min(size.width, size.height);
    final r = (vertical ? size.width : size.height) * 0.075;
    pumpRadius = r.clamp(14.0, 34.0);
    valveSize = (pumpRadius * 0.9).clamp(12.0, 28.0);
  }

  final PlantProcess process;
  final Size size;
  final bool vertical;
  Tank? source, dest;
  late final List<Valve> inlets, outlets;
  late final List<Pump> pumps;
  late final double unit, pumpRadius, valveSize;

  Offset p(double u, double v) => vertical ? Offset(v * size.width, u * size.height) : Offset(u * size.width, v * size.height);

  Rect tankRect(int index) {
    final (u0, u1) = index == 0 ? (0.17, 0.37) : (0.63, 0.83);
    final a = p(u0, vertical ? 0.22 : 0.16);
    final b = p(u1, vertical ? 0.78 : 0.86);
    return Rect.fromPoints(a, b);
  }

  /// Across-flow position (v) of pump i.
  double pumpV(int i) => pumps.length <= 1 ? 0.5 : 0.32 + i * (0.40 / (pumps.length - 1));
  Offset pumpCenter(int i) => p(0.5, pumpV(i));

  double inletV(int i) => inlets.length <= 1 ? 0.30 : 0.22 + i * 0.16;
  Offset inletCenter(int i) => p(0.085, inletV(i));
  double outletV(int i) => outlets.length <= 1 ? 0.72 : 0.64 + i * 0.16;
  Offset outletCenter(int i) => p(0.915, outletV(i));

  List<_Hit> get hitTargets {
    final hits = <_Hit>[];
    for (final (i, t) in [source, dest].indexed) {
      if (t != null) hits.add(_Hit('tank', t.id, tankRect(i), '${t.tag} ${t.name}, level ${t.levelPct.toStringAsFixed(1)} percent'));
    }
    for (final (i, pump) in pumps.indexed) {
      hits.add(_Hit('pump', pump.id, Rect.fromCircle(center: pumpCenter(i), radius: pumpRadius + 8), '${pump.tag} ${pump.name}, ${pump.actualState}'));
    }
    for (final (i, v) in inlets.indexed) {
      hits.add(_Hit('valve', v.id, Rect.fromCircle(center: inletCenter(i), radius: valveSize + 8), '${v.tag} ${v.name}, ${v.actualState}'));
    }
    for (final (i, v) in outlets.indexed) {
      hits.add(_Hit('valve', v.id, Rect.fromCircle(center: outletCenter(i), radius: valveSize + 8), '${v.tag} ${v.name}, ${v.actualState}'));
    }
    return hits;
  }
}

class _DiagramPainter extends CustomPainter {
  _DiagramPainter({required this.geo, required this.animation, required this.scheme, this.selectedId}) : super(repaint: animation);

  final _Geometry geo;
  final Animation<double> animation;
  final ColorScheme scheme;
  final String? selectedId;

  static const water = Color(0xFF29B6F6);
  static const waterDeep = Color(0xFF0277BD);
  static const running = Color(0xFF43A047);
  static const amber = Color(0xFFFFB300);
  static const idle = Color(0xFF607D8B);

  @override
  void paint(Canvas canvas, Size size) {
    final g = geo;
    _grid(canvas, size);
    final phase = animation.value;

    // --- pipes -------------------------------------------------------------------------
    final pipeWidth = (g.unit * 0.022).clamp(5.0, 10.0);
    for (final (i, v) in g.inlets.indexed) {
      final c = g.inletCenter(i);
      final tank = g.tankRect(0);
      final entry = g.vertical ? Offset(c.dx, tank.top + tank.height * 0.12) : Offset(tank.left, c.dy);
      _pipe(canvas, [g.p(0.0, g.inletV(i)), c, entry], v.flowM3h > 0 && v.isActive, pipeWidth, phase);
    }
    for (final (i, pump) in g.pumps.indexed) {
      final c = g.pumpCenter(i);
      final a = g.tankRect(0), b = g.tankRect(1);
      final from = g.vertical ? Offset(c.dx, a.bottom) : Offset(a.right, c.dy);
      final to = g.vertical ? Offset(c.dx, b.top) : Offset(b.left, c.dy);
      _pipe(canvas, [from, c, to], pump.isActive && pump.flowM3h > 0, pipeWidth, phase);
    }
    for (final (i, v) in g.outlets.indexed) {
      final c = g.outletCenter(i);
      final tank = g.tankRect(1);
      final exit = g.vertical ? Offset(c.dx, tank.bottom) : Offset(tank.right, c.dy);
      _pipe(canvas, [exit, c, g.p(1.0, g.outletV(i))], v.flowM3h > 0 && v.isActive, pipeWidth, phase);
    }

    // --- tanks -------------------------------------------------------------------------
    if (g.source != null) _tank(canvas, g.tankRect(0), g.source!, phase);
    if (g.dest != null) _tank(canvas, g.tankRect(1), g.dest!, phase);

    // --- pumps & valves ----------------------------------------------------------------
    for (final (i, pump) in g.pumps.indexed) {
      _pump(canvas, g.pumpCenter(i), g.pumpRadius, pump, phase);
    }
    for (final (i, v) in g.inlets.indexed) {
      _valve(canvas, g.inletCenter(i), g.valveSize, v, labelBelow: true);
    }
    for (final (i, v) in g.outlets.indexed) {
      _valve(canvas, g.outletCenter(i), g.valveSize, v, labelBelow: true);
    }

    // --- flow endpoints ----------------------------------------------------------------
    _label(canvas, g.vertical ? g.p(0.015, 0.5) : g.p(0.01, 0.10), 'Raw water source', small: true, align: TextAlign.left);
    _label(canvas, g.vertical ? g.p(0.985, 0.5) : g.p(0.99, 0.92), 'Distribution', small: true, align: TextAlign.right, anchorBottom: g.vertical);
  }

  void _grid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = scheme.outlineVariant.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    const step = 32.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  /// Orthogonal pipe through [points]; animated dashes when [flowing].
  void _pipe(Canvas canvas, List<Offset> points, bool flowing, double width, double phase) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1], next = points[i];
      // elbow: travel along the main axis first, then across
      final elbow = geo.vertical ? Offset(next.dx, prev.dy) : Offset(prev.dx, next.dy);
      if (elbow != prev && elbow != next) {
        final mid = geo.vertical ? Offset(prev.dx, (prev.dy + next.dy) / 2) : Offset((prev.dx + next.dx) / 2, prev.dy);
        final mid2 = geo.vertical ? Offset(next.dx, mid.dy) : Offset(mid.dx, next.dy);
        path
          ..lineTo(mid.dx, mid.dy)
          ..lineTo(mid2.dx, mid2.dy);
      }
      path.lineTo(next.dx, next.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width + 4
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF263238),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeJoin = StrokeJoin.round
        ..color = flowing ? waterDeep : const Color(0xFF455A64),
    );
    if (!flowing) return;
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 0.55
      ..strokeCap = StrokeCap.round
      ..color = water;
    const dashLen = 10.0, gap = 12.0;
    for (final metric in path.computeMetrics()) {
      var d = phase * (dashLen + gap) * 2 % (dashLen + gap);
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, math.min(d + dashLen, metric.length)), dash);
        d += dashLen + gap;
      }
    }
  }

  void _tank(Canvas canvas, Rect r, Tank t, double phase) {
    final ry = math.min(r.width * 0.12, 14.0);
    final body = Rect.fromLTRB(r.left, r.top + ry, r.right, r.bottom - ry);
    final shell = Paint()
      ..shader = ui.Gradient.linear(body.centerLeft, body.centerRight, const [Color(0xFF37474F), Color(0xFF78909C), Color(0xFF37474F)], const [0, 0.45, 1]);
    // back + body
    canvas.drawRect(body, shell);
    canvas.drawOval(Rect.fromCenter(center: body.bottomCenter, width: r.width, height: ry * 2), shell);

    // water
    final level = (t.levelPct / 100).clamp(0.0, 1.0);
    final surfaceY = body.bottom - body.height * level;
    if (level > 0.001) {
      final waterPaint = Paint()
        ..shader = ui.Gradient.linear(body.centerLeft, body.centerRight, [waterDeep.withValues(alpha: 0.95), water.withValues(alpha: 0.95), waterDeep.withValues(alpha: 0.95)], const [0, 0.5, 1]);
      canvas.drawRect(Rect.fromLTRB(body.left, surfaceY, body.right, body.bottom), waterPaint);
      canvas.drawOval(Rect.fromCenter(center: body.bottomCenter, width: r.width, height: ry * 2), waterPaint);
      final wave = math.sin(phase * 2 * math.pi) * ry * 0.15;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(body.center.dx, surfaceY + wave), width: r.width, height: ry * 2),
        Paint()..color = const Color(0xFF81D4FA).withValues(alpha: 0.9),
      );
    }
    // limits
    final limitPaint = Paint()
      ..color = amber.withValues(alpha: 0.7)
      ..strokeWidth = 1.2;
    for (final lim in [t.lowLimitPct, t.highLimitPct]) {
      final y = body.bottom - body.height * (lim / 100);
      canvas.drawLine(Offset(body.right - 10, y), Offset(body.right + 4, y), limitPaint);
    }
    // top rim
    canvas.drawOval(
      Rect.fromCenter(center: body.topCenter, width: r.width, height: ry * 2),
      Paint()..color = const Color(0xFF546E7A),
    );
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = selectedId == t.id ? 3 : 1.5
      ..color = selectedId == t.id ? scheme.primary : (t.isLow || t.isHigh ? amber : const Color(0xFF90A4AE));
    canvas.drawPath(
      Path()
        ..moveTo(body.left, body.top)
        ..lineTo(body.left, body.bottom)
        ..arcTo(Rect.fromCenter(center: body.bottomCenter, width: r.width, height: ry * 2), math.pi, -math.pi, false)
        ..lineTo(body.right, body.top),
      outline,
    );
    canvas.drawOval(Rect.fromCenter(center: body.topCenter, width: r.width, height: ry * 2), outline);

    // readouts
    final big = (r.width * 0.16).clamp(12.0, 22.0);
    _label(canvas, Offset(body.center.dx, body.center.dy - big), '${t.levelPct.toStringAsFixed(1)} %', size: big, bold: true);
    _label(canvas, Offset(body.center.dx, body.center.dy + 4), '${t.pressureBar.toStringAsFixed(2)} bar', small: true);
    _label(canvas, Offset(body.center.dx, body.center.dy + 20), '${t.volumeM3.toStringAsFixed(0)} / ${t.capacityM3.toStringAsFixed(0)} m³', small: true);
    _label(canvas, Offset(r.center.dx, r.top - 4), '${t.tag} · ${t.name}', small: true, anchorBottom: true, bold: true);
  }

  void _pump(Canvas canvas, Offset c, double r, Pump pump, double phase) {
    final color = pump.inMaintenance ? amber : (pump.isActive ? running : idle);
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF263238));
    canvas.drawCircle(c, r * 0.86, Paint()..shader = ui.Gradient.radial(c - Offset(r * 0.3, r * 0.3), r * 1.2, [color.withValues(alpha: 0.95), Color.lerp(color, Colors.black, 0.55)!]));
    // impeller
    final angle = pump.isActive ? phase * 2 * math.pi * 2 : 0.0;
    final blade = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = math.max(2, r * 0.12)
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k < 3; k++) {
      final a = angle + k * 2 * math.pi / 3;
      canvas.drawLine(c, c + Offset(math.cos(a), math.sin(a)) * r * 0.6, blade);
    }
    canvas.drawCircle(c, r * 0.14, Paint()..color = Colors.white);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = selectedId == pump.id ? 3.5 : 2
      ..color = selectedId == pump.id ? scheme.primary : (pump.mismatch ? amber : const Color(0xFF90A4AE));
    canvas.drawCircle(c, r, ring);
    if (pump.isAuto) _label(canvas, c + Offset(r * 0.75, -r * 0.95), 'A', small: true, bold: true, color: scheme.primary);
    final info = '${pump.tag} ${pump.actualState.toUpperCase()}${pump.mismatch ? ' (req ${pump.requestedState.toUpperCase()})' : ''}';
    _label(canvas, c + Offset(0, r + 4), info, small: true, bold: true, color: pump.mismatch ? amber : null);
    _label(canvas, c + Offset(0, r + 18), '${pump.flowM3h.toStringAsFixed(1)} m³/h${pump.inMaintenance ? ' · MAINT' : ''}', small: true);
  }

  void _valve(Canvas canvas, Offset c, double s, Valve v, {bool labelBelow = true}) {
    final open = v.isActive;
    final fill = Paint()..color = v.inMaintenance ? amber : (open ? running : idle);
    final rotate = geo.vertical;
    Offset pt(double dx, double dy) => rotate ? c + Offset(dy, dx) : c + Offset(dx, dy);
    final left = Path()
      ..moveTo(pt(-s, -s * 0.65).dx, pt(-s, -s * 0.65).dy)
      ..lineTo(pt(0, 0).dx, pt(0, 0).dy)
      ..lineTo(pt(-s, s * 0.65).dx, pt(-s, s * 0.65).dy)
      ..close();
    final right = Path()
      ..moveTo(pt(s, -s * 0.65).dx, pt(s, -s * 0.65).dy)
      ..lineTo(pt(0, 0).dx, pt(0, 0).dy)
      ..lineTo(pt(s, s * 0.65).dx, pt(s, s * 0.65).dy)
      ..close();
    canvas.drawPath(left, fill);
    canvas.drawPath(right, fill);
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = selectedId == v.id ? 3 : 1.5
      ..color = selectedId == v.id ? scheme.primary : (v.mismatch ? amber : const Color(0xFFCFD8DC));
    canvas.drawPath(left, outline);
    canvas.drawPath(right, outline);
    // actuator stem
    final stemTop = rotate ? c + Offset(-s * 1.1, 0) : c + Offset(0, -s * 1.1);
    canvas.drawLine(c, stemTop, outline..strokeWidth = 2);
    canvas.drawCircle(stemTop, s * 0.25, Paint()..color = const Color(0xFF90A4AE));
    if (v.isAuto) _label(canvas, stemTop + const Offset(10, -6), 'A', small: true, bold: true, color: scheme.primary);
    final info = '${v.tag} ${v.actualState.toUpperCase()}${v.mismatch ? ' (req ${v.requestedState.toUpperCase()})' : ''}';
    final base = rotate ? c + Offset(0, s + 4) : c + Offset(0, s * 0.8 + 4);
    _label(canvas, base, info, small: true, bold: true, color: v.mismatch ? amber : null);
    _label(canvas, base + const Offset(0, 14), '${v.flowM3h.toStringAsFixed(1)} m³/h', small: true);
  }

  void _label(Canvas canvas, Offset at, String text,
      {bool small = false, double? size, bool bold = false, Color? color, TextAlign align = TextAlign.center, bool anchorBottom = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color ?? scheme.onSurface,
          fontSize: size ?? (small ? 11 : 13),
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          shadows: const [Shadow(blurRadius: 3, color: Colors.black)],
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 220);
    final dx = switch (align) {
      TextAlign.left => at.dx,
      TextAlign.right => at.dx - tp.width,
      _ => at.dx - tp.width / 2,
    };
    tp.paint(canvas, Offset(dx, anchorBottom ? at.dy - tp.height : at.dy));
  }

  @override
  bool shouldRepaint(covariant _DiagramPainter old) => old.geo.process != geo.process || old.selectedId != selectedId || old.geo.size != geo.size || old.scheme != scheme;
}
