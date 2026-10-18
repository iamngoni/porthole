import 'dart:math' as math;
import 'dart:ui';

/// Keeps a scroll gliding after the finger lifts, slowing like a Mac trackpad (MomentumScroller in
/// InputLogic.swift). It steps 60 times a second whatever the screen's rate, so the glide is the same
/// length on every device.
final class MomentumScroller {
  /// [velocity] is in logical pixels per second.
  MomentumScroller(Offset velocity)
      : _vx = velocity.dx.isFinite ? velocity.dx / framesPerSecond : 0,
        _vy = velocity.dy.isFinite ? velocity.dy / framesPerSecond : 0;

  static const framesPerSecond = 60.0;
  static const decayPerFrame = 0.95;

  /// Below this speed (pixels per frame) the glide stops.
  static const stopSpeed = 0.3;

  double _vx;
  double _vy;

  bool get isFinished => math.sqrt(_vx * _vx + _vy * _vy) < stopSpeed;

  /// The next frame's movement, or null when the glide is over.
  Offset? next() {
    if (isFinished) return null;
    final step = Offset(_vx, _vy);
    _vx *= decayPerFrame;
    _vy *= decayPerFrame;
    return step;
  }

  /// The movement for [frames] frames at once, for a screen that draws faster or slower than 60 a second.
  Offset? take(int frames) {
    Offset? total;
    for (var i = 0; i < frames; i++) {
      final step = next();
      if (step == null) break;
      total = (total ?? Offset.zero) + step;
    }
    return total;
  }
}
