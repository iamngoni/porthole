import 'package:flutter/widgets.dart';

import '../design/theme.dart';

final class _Ripple {
  _Ripple(this.at, this.color, this.radius, this.start);
  final Offset at;
  final Color color;
  final double radius;
  final Duration start;
}

final class _Hold {
  _Hold(this.at, this.start);
  Offset at;
  final Duration start;
  Duration? dragAt;
  Duration? endAt;
}

/// Shows where a touch landed, since there's no pointer on the video: a ripple for a tap, a double ring
/// for a right-click, and a lit dot under the finger while dragging. Driven by the surface's clock.
// no-prop-test: drawing only; checked by eye in the simulator.
final class TouchFeedback extends ChangeNotifier {
  static const _primary = Color(0xFFFFFFFF);
  static const _secondary = Palette.accent;
  static const _rippleLength = Duration(milliseconds: 480);
  static const _holdFade = Duration(milliseconds: 200);

  final _ripples = <_Ripple>[];
  final _holds = <_Hold>[];
  Duration _now = Duration.zero;

  bool get isActive => _ripples.isNotEmpty || _holds.isNotEmpty;

  void tap(Offset at) => _ripples.add(_Ripple(at, _primary, 26, _now));

  void secondaryTap(Offset at) {
    _ripples
      ..add(_Ripple(at, _secondary, 24, _now))
      ..add(_Ripple(at, _secondary, 24, _now + const Duration(milliseconds: 90)));
  }

  void beginHold(Offset at) {
    endHold();
    _holds.add(_Hold(at, _now));
  }

  /// The press turned into a drag: the ring tightens into a dot that follows the finger.
  void beginDrag() => _current?.dragAt = _now;

  void moveHold(Offset to) => _current?.at = to;

  void endHold() => _current?.endAt = _now;

  _Hold? get _current => _holds.where((h) => h.endAt == null).lastOrNull;

  void tick(Duration now) {
    _now = now;
    _ripples.removeWhere((r) => now - r.start > _rippleLength);
    _holds.removeWhere((h) => h.endAt != null && now - h.endAt! > _holdFade);
    notifyListeners();
  }

  void paint(Canvas canvas) {
    for (final ripple in _ripples) {
      final t = (_now - ripple.start).inMicroseconds / _rippleLength.inMicroseconds;
      if (t < 0) continue;
      final eased = Curves.easeOut.transform(t.clamp(0.0, 1.0));
      final opacity = t < 0.4 ? 0.95 - 0.25 * (t / 0.4) : 0.7 * (1 - (t - 0.4) / 0.6);
      _ring(canvas, ripple.at, ripple.radius * (0.35 + 0.9 * eased), ripple.color, opacity.clamp(0.0, 1.0), fill: 0.22);
    }
    for (final hold in _holds) {
      final grow = Curves.easeOut.transform(((_now - hold.start).inMicroseconds / 220000).clamp(0.0, 1.0));
      final tighten = hold.dragAt == null ? 0.0 : ((_now - hold.dragAt!).inMicroseconds / 180000).clamp(0.0, 1.0);
      final fade = hold.endAt == null ? 1.0 : 1 - ((_now - hold.endAt!).inMicroseconds / _holdFade.inMicroseconds).clamp(0.0, 1.0);
      final scale = (0.4 + 0.6 * grow) * (1 - 0.45 * tighten);
      final color = Color.lerp(_secondary, _primary, tighten)!;
      _ring(canvas, hold.at, 30 * scale, color, fade, fill: 0.18 + 0.27 * tighten);
    }
  }

  static void _ring(Canvas canvas, Offset at, double radius, Color color, double opacity, {required double fill}) {
    if (opacity <= 0) return;
    canvas.drawCircle(
      at,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.5 * opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8),
    );
    canvas.drawCircle(at, radius, Paint()..color = color.withValues(alpha: fill * opacity));
    canvas.drawCircle(
      at,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: 0.95 * opacity),
    );
  }
}

class TouchFeedbackPainter extends CustomPainter {
  TouchFeedbackPainter(this.feedback) : super(repaint: feedback);
  final TouchFeedback feedback;

  @override
  void paint(Canvas canvas, Size size) => feedback.paint(canvas);

  @override
  bool shouldRepaint(TouchFeedbackPainter old) => old.feedback != feedback;
}
