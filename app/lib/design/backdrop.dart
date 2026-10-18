import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'theme.dart';

/// Graphite with a soft light falling from above, drifting slowly enough to feel alive without being noticed.
class Backdrop extends StatefulWidget {
  const Backdrop({super.key, this.intensity = 1});
  final double intensity;

  @override
  State<Backdrop> createState() => _BackdropState();
}

class _BackdropState extends State<Backdrop> with SingleTickerProviderStateMixin {
  late final _drift = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat(reverse: true);

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _BackdropPainter(CurvedAnimation(parent: _drift, curve: Curves.easeInOut), widget.intensity),
            size: Size.infinite,
          ),
        ),
      );
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.drift, this.intensity) : super(repaint: drift);
  final Animation<double> drift;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Palette.canvas);
    final sway = drift.value * 2 - 1;
    _light(canvas,
        center: Offset(size.width / 2 + sway * size.width * 0.06, size.height / 2 - size.height * 0.42),
        width: size.width * 1.3,
        height: size.height * 0.8,
        radius: size.width * 0.6,
        color: Palette.white(0.085 * intensity));
    _light(canvas,
        center: Offset(size.width / 2 - sway * size.width * 0.1, size.height / 2 + size.height * 0.35),
        width: size.width,
        height: size.height * 0.7,
        radius: size.width * 0.5,
        color: Palette.accent.withValues(alpha: 0.05 * intensity));
  }

  void _light(Canvas canvas,
      {required Offset center, required double width, required double height, required double radius, required Color color}) {
    final paint = Paint()..shader = ui.Gradient.radial(center, radius, [color, color.withValues(alpha: 0)]);
    canvas.drawOval(Rect.fromCenter(center: center, width: width, height: height), paint);
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.intensity != intensity || old.drift != drift;
}
