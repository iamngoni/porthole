import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'theme.dart';

/// Frosted glass: the scene behind blurred, a faint fill, and an edge that catches light at the top.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = Metrics.radius,
    this.highlight = false,
    this.shadow = true,
    this.padding = EdgeInsets.zero,
    this.fill = Palette.surface,
    this.shape = BoxShape.rectangle,
  });

  final Widget child;
  final double radius;
  final bool highlight;
  final bool shadow;
  final EdgeInsetsGeometry padding;
  final Color fill;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    final circle = shape == BoxShape.circle;
    final borderRadius = circle ? null : BorderRadius.circular(radius);
    Widget clipped(Widget child) =>
        circle ? ClipOval(child: child) : ClipRRect(borderRadius: borderRadius!, child: child);
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: borderRadius,
        boxShadow: shadow ? [BoxShadow(color: Palette.black(0.35), blurRadius: 24, offset: const Offset(0, 14))] : null,
      ),
      child: clipped(
        BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: CustomPaint(
            foregroundPainter: _EdgePainter(radius: radius, highlight: highlight, circle: circle),
            child: ColoredBox(color: fill, child: Padding(padding: padding, child: child)),
          ),
        ),
      ),
    );
  }
}

/// A one-pixel border that fades from the top edge to the bottom.
class _EdgePainter extends CustomPainter {
  const _EdgePainter({required this.radius, required this.highlight, required this.circle});

  final double radius;
  final bool highlight;
  final bool circle;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.5);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Palette.white(highlight ? 0.24 : 0.13), Palette.white(0.03)],
      ).createShader(rect);
    if (circle) {
      canvas.drawOval(rect, paint);
    } else {
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius - 0.5)), paint);
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) => old.radius != radius || old.highlight != highlight || old.circle != circle;
}
