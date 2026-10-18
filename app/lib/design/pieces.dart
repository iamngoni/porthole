import 'package:flutter/widgets.dart';

import 'theme.dart';

/// A small dot for live or connected, with a ring that pulses outward.
class StatusDot extends StatefulWidget {
  const StatusDot({super.key, required this.color, this.pulsing = false});
  final Color color;
  final bool pulsing;

  @override
  State<StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<StatusDot> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    if (widget.pulsing) _pulse.repeat();
  }

  @override
  void didUpdateWidget(StatusDot old) {
    super.didUpdateWidget(old);
    if (widget.pulsing && !_pulse.isAnimating) _pulse.repeat();
    if (!widget.pulsing) _pulse.stop();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox.square(
          dimension: 7,
          child: CustomPaint(painter: _DotPainter(widget.color, widget.pulsing ? _pulse : null)),
        ),
      );
}

class _DotPainter extends CustomPainter {
  _DotPainter(this.color, this.pulse) : super(repaint: pulse);
  final Color color;
  final Animation<double>? pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    canvas.drawCircle(center, size.width / 2, Paint()..color = color);
    final pulse = this.pulse;
    if (pulse == null) return;
    final t = Curves.easeOut.transform(pulse.value);
    canvas.drawCircle(
      center,
      size.width / 2 * (1 + 1.6 * t),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = color.withValues(alpha: 0.5 * (1 - t)),
    );
  }

  @override
  bool shouldRepaint(_DotPainter old) => old.color != color || old.pulse != pulse;
}

/// A short label on a tinted capsule.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color = Palette.textSecondary});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: display(12, FontWeight.w600, color), maxLines: 1),
      );
}

/// An icon in a frosted circle, for the top of a screen or a card.
class GlowIcon extends StatelessWidget {
  const GlowIcon(this.icon, {super.key, this.size = 64, this.tint = Palette.textPrimary});
  final IconData icon;
  final double size;
  final Color tint;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Palette.white(0.12), Palette.white(0.04)],
            ),
            border: Border.all(color: Palette.white(0.14)),
          ),
          child: Icon(icon, size: size * 0.42, color: tint),
        ),
      );
}
