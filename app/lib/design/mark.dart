import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'theme.dart';

/// The Porthole logo: a brushed-metal ring around a small window, like looking through a ship's porthole
/// at your Mac.
class PortholeMark extends StatefulWidget {
  const PortholeMark({super.key, this.size = 56, this.isActive = false, this.hasShadow = true});
  final double size;

  /// The shadow that lifts it off the screen. The app icon goes without: launchers add their own.
  final bool hasShadow;

  /// Turns the ring's sheen slowly, for moments when something is happening.
  final bool isActive;

  @override
  State<PortholeMark> createState() => _PortholeMarkState();
}

class _PortholeMarkState extends State<PortholeMark> with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void initState() {
    super.initState();
    _update();
  }

  @override
  void didUpdateWidget(PortholeMark old) {
    super.didUpdateWidget(old);
    if (old.isActive != widget.isActive) _update();
  }

  void _update() {
    if (widget.isActive) {
      _spin.repeat();
    } else {
      _spin.animateTo(0, duration: const Duration(milliseconds: 600), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            if (widget.hasShadow) BoxShadow(color: Palette.black(0.5), blurRadius: size * 0.18, offset: Offset(0, size * 0.06)),
          ],
        ),
        child: CustomPaint(painter: _MarkPainter(_spin)),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.spin) : super(repaint: spin);
  final Animation<double> spin;

  @override
  void paint(Canvas canvas, Size box) {
    final size = box.width;
    final center = box.center(Offset.zero);
    final radius = size / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()..shader = RadialGradient(colors: [const Color(0xFF212121), Palette.canvas]).createShader(Offset.zero & box),
    );

    // The ring, its sheen turning when active.
    final ringWidth = size * 0.075;
    final ringRect = Rect.fromCircle(center: center, radius: radius - ringWidth / 2);
    canvas.drawCircle(
      center,
      radius - ringWidth / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth
        ..shader = SweepGradient(
          colors: [
            Palette.white(0.95),
            Palette.white(0.3),
            Palette.white(0.75),
            Palette.white(0.22),
            Palette.white(0.95),
          ],
          transform: GradientRotation(spin.value * 2 * math.pi),
        ).createShader(ringRect),
    );
    canvas.drawCircle(
      center,
      radius - size * 0.11 - 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Palette.white(0.08),
    );

    // The little window: a title bar with three dots over an accent-lit body.
    final window = Rect.fromCenter(center: center, width: size * 0.4, height: size * 0.3);
    final corner = Radius.circular(size * 0.05);
    final windowShape = RRect.fromRectAndRadius(window, corner);
    canvas.save();
    canvas.clipRRect(windowShape);
    canvas.drawRect(
      window,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Palette.accent.withValues(alpha: 0.85), Palette.accent.withValues(alpha: 0.45)],
        ).createShader(window),
    );
    final bar = Rect.fromLTWH(window.left, window.top, window.width, window.height * 0.26);
    canvas.drawRect(bar, Paint()..color = const Color(0xFF0A0A0C));
    canvas.drawRect(bar, Paint()..color = Palette.white(0.16));
    final dot = size * 0.033;
    for (final (index, opacity) in [0.75, 0.5, 0.35].indexed) {
      canvas.drawCircle(
        Offset(bar.left + size * 0.03 + dot / 2 + index * (dot + size * 0.022), bar.center.dy),
        dot / 2,
        Paint()..color = Palette.white(opacity),
      );
    }
    canvas.restore();
    canvas.drawRRect(
      windowShape.deflate(0.375),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.75
        ..color = Palette.white(0.3),
    );

    // A glint across the glass.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - size * 0.2),
      0.58 * 2 * math.pi,
      0.12 * 2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.03
        ..strokeCap = StrokeCap.round
        ..color = Palette.white(0.45),
    );
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.spin != spin;
}

/// Rings rippling out from the logo while Porthole looks for, or reaches out to, a Mac.
class RadarRings extends StatefulWidget {
  const RadarRings({super.key, this.size = 220, this.color = const Color(0xFFFFFFFF)});
  final double size;
  final Color color;

  @override
  State<RadarRings> createState() => _RadarRingsState();
}

class _RadarRingsState extends State<RadarRings> with SingleTickerProviderStateMixin {
  final _elapsed = ValueNotifier(Duration.zero);
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) => _elapsed.value = elapsed)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _elapsed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox.square(
            dimension: widget.size,
            child: CustomPaint(painter: _RingsPainter(_elapsed, widget.color)),
          ),
        ),
      );
}

class _RingsPainter extends CustomPainter {
  _RingsPainter(this.elapsed, this.color) : super(repaint: elapsed);
  final ValueNotifier<Duration> elapsed;
  final Color color;

  static const period = 3.2;
  static const stagger = 1.05;

  @override
  void paint(Canvas canvas, Size size) {
    final seconds = elapsed.value.inMicroseconds / 1e6;
    for (var ring = 0; ring < 3; ring++) {
      final since = seconds - ring * stagger;
      if (since < 0) continue;
      final t = Curves.easeOut.transform((since % period) / period);
      canvas.drawCircle(
        size.center(Offset.zero),
        size.width / 2 * (0.3 + 0.7 * t),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = color.withValues(alpha: 0.22 * 0.9 * (1 - t)),
      );
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.color != color || old.elapsed != elapsed;
}
