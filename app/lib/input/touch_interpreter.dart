import 'dart:math' as math;
import 'dart:ui';

/// What a gesture on the stream means. Positions are in the view's coordinates (logical pixels).
sealed class TouchAction {
  const TouchAction();
}

/// A click where the finger lifted. `count` is 2 for the second tap of a double tap.
class Tap extends TouchAction {
  const Tap(this.at, {this.count = 1});
  final Offset at;
  final int count;
  @override
  String toString() => 'Tap($at, count: $count)';
}

/// A right-click: a two-finger tap, or touch and hold then lift without moving.
class SecondaryTap extends TouchAction {
  const SecondaryTap(this.at);
  final Offset at;
  @override
  String toString() => 'SecondaryTap($at)';
}

/// The finger has been held long enough for a right-click or a drag; for feedback only.
class HoldBegan extends TouchAction {
  const HoldBegan(this.at);
  final Offset at;
}

/// The finger started scrolling from `at`; the scroll's `ScrollBy`s and its `ScrollEnd` follow.
class ScrollStart extends TouchAction {
  const ScrollStart(this.at);
  final Offset at;
  @override
  String toString() => 'ScrollStart($at)';
}

/// Content follows the finger: positive dy means the finger moved down.
class ScrollBy extends TouchAction {
  const ScrollBy(this.delta);
  final Offset delta;
  @override
  String toString() => 'ScrollBy($delta)';
}

/// The scroll is over: the finger lifted, or (`cancelled`) a second finger or the system took over.
class ScrollEnd extends TouchAction {
  const ScrollEnd({this.cancelled = false});
  final bool cancelled;
  @override
  String toString() => 'ScrollEnd(cancelled: $cancelled)';
}

/// The finger lifted while scrolling; keep scrolling at this speed (logical pixels per second) and slow down.
/// Comes after the scroll's `ScrollEnd`.
class Fling extends TouchAction {
  const Fling(this.velocity);
  final Offset velocity;
}

/// A hold ended without a right-click or a drag, because a second finger or the system took over.
class HoldCancel extends TouchAction {
  const HoldCancel();
}

/// Touch and hold, then move: press at `at`, move, release.
class DragStart extends TouchAction {
  const DragStart(this.at);
  final Offset at;
}

class DragMove extends TouchAction {
  const DragMove(this.at);
  final Offset at;
}

class DragEnd extends TouchAction {
  const DragEnd(this.at);
  final Offset at;
}

/// Two fingers: zoom by `scale` around `focal` (where the fingers are now), after moving by `pan`.
class Zoom extends TouchAction {
  const Zoom({required this.scale, required this.focal, required this.pan});
  final double scale;
  final Offset focal;
  final Offset pan;
}

class ZoomEnd extends TouchAction {
  const ZoomEnd();
}

/// Turns raw touches into taps, scrolls, drags and pinches, the way an iPad app reads them.
/// Pure: feed it pointer downs, moves and ups with their times (and `tick` while a finger is down, so a hold
/// is noticed without a move), and it returns what each one means.
class TouchInterpreter {
  TouchInterpreter({
    this.slop = 10,
    this.holdDuration = const Duration(milliseconds: 450),
    this.doubleTapWindow = const Duration(milliseconds: 300),
    this.doubleTapDistance = 30,
    this.twoFingerTapDuration = const Duration(milliseconds: 280),
    this.flingMinimumSpeed = 250,
  });

  /// How far a finger can wander and still count as a tap.
  final double slop;
  final Duration holdDuration;
  final Duration doubleTapWindow;
  final double doubleTapDistance;
  final Duration twoFingerTapDuration;
  final double flingMinimumSpeed;

  final Map<int, Offset> _down = {};
  final Map<int, Offset> _now = {};
  _Phase _phase = _Phase.idle;
  Duration _downAt = Duration.zero;
  Offset? _lastScrollPosition;
  final List<(Duration, Offset)> _samples = [];
  Duration? _lastTapAt;
  Offset? _lastTapPosition;
  bool _twoFingerMoved = false;
  double? _pinchDistance;
  Offset? _pinchFocal;

  bool get isIdle => _phase == _Phase.idle;

  List<TouchAction> down(int pointer, Offset at, Duration time) {
    // Extra fingers during a drag or pinch, or while the last fingers of one lift, are ignored.
    if (_phase case _Phase.dragging || _Phase.twoFinger || _Phase.finishing) return const [];
    _down[pointer] = at;
    _now[pointer] = at;
    switch (_phase) {
      case _Phase.idle:
        _phase = _Phase.pending;
        _downAt = time;
        return const [];
      case _Phase.pending:
      case _Phase.held:
      case _Phase.scrolling:
        // A second finger turns whatever the first was doing into a two-finger gesture.
        final ended = switch (_phase) {
          _Phase.scrolling => const [ScrollEnd(cancelled: true)],
          _Phase.held => const [HoldCancel()],
          _ => const <TouchAction>[],
        };
        _phase = _Phase.twoFinger;
        _downAt = time;
        _twoFingerMoved = false;
        _startPinch();
        return ended;
      case _Phase.dragging:
      case _Phase.twoFinger:
      case _Phase.finishing:
        return const [];
    }
  }

  List<TouchAction> move(int pointer, Offset at, Duration time) {
    if (!_now.containsKey(pointer)) return const [];
    _now[pointer] = at;
    final start = _down[pointer]!;
    switch (_phase) {
      case _Phase.pending:
        if (time - _downAt >= holdDuration) {
          _phase = _Phase.held;
          return [HoldBegan(start), ...move(pointer, at, time)];
        }
        if ((at - start).distance <= slop) return const [];
        _phase = _Phase.scrolling;
        _lastScrollPosition = at;
        _samples
          ..clear()
          ..add((time, at));
        return [ScrollStart(start), ScrollBy(at - start)];
      case _Phase.held:
        if ((at - start).distance <= slop) return const [];
        _phase = _Phase.dragging;
        return [DragStart(start), DragMove(at)];
      case _Phase.dragging:
        return [DragMove(at)];
      case _Phase.scrolling:
        final delta = at - _lastScrollPosition!;
        _lastScrollPosition = at;
        _samples.add((time, at));
        _samples.removeWhere((sample) => time - sample.$1 > const Duration(milliseconds: 100));
        return delta == Offset.zero ? const [] : [ScrollBy(delta)];
      case _Phase.twoFinger:
        return _pinch();
      case _Phase.idle:
      case _Phase.finishing:
        return const [];
    }
  }

  List<TouchAction> up(int pointer, Offset at, Duration time) {
    if (!_now.containsKey(pointer)) return const [];
    final out = <TouchAction>[];
    out.addAll(move(pointer, at, time));
    final start = _down[pointer]!;
    final fingersBefore = _now.length;
    _down.remove(pointer);
    _now.remove(pointer);
    switch (_phase) {
      case _Phase.pending:
        out.add(_tap(start, time));
        _phase = _Phase.idle;
      case _Phase.held:
        out.add(SecondaryTap(start));
        _phase = _Phase.idle;
      case _Phase.dragging:
        out.add(DragEnd(at));
        _phase = _Phase.idle;
      case _Phase.scrolling:
        out.add(const ScrollEnd());
        final velocity = _velocity(time);
        if (velocity.distance >= flingMinimumSpeed) out.add(Fling(velocity));
        _phase = _Phase.idle;
      case _Phase.twoFinger:
        if (!_twoFingerMoved && time - _downAt <= twoFingerTapDuration && fingersBefore >= 2) {
          out.add(SecondaryTap(_midpoint(start, _now.values.firstOrNull ?? start)));
        } else if (_twoFingerMoved) {
          out.add(const ZoomEnd());
        }
        _phase = _now.isEmpty ? _Phase.idle : _Phase.finishing;
      case _Phase.finishing:
        if (_now.isEmpty) _phase = _Phase.idle;
      case _Phase.idle:
        break;
    }
    return out;
  }

  /// The system took the touches (a system gesture, the app going away): drop them without clicking.
  List<TouchAction> cancel(int pointer) {
    if (!_now.containsKey(pointer)) return const [];
    final at = _now[pointer]!;
    _down.remove(pointer);
    _now.remove(pointer);
    final out = <TouchAction>[
      if (_phase == _Phase.dragging) DragEnd(at),
      if (_phase == _Phase.scrolling) const ScrollEnd(cancelled: true),
      if (_phase == _Phase.held) const HoldCancel(),
      if (_phase == _Phase.twoFinger && _twoFingerMoved) const ZoomEnd(),
    ];
    _phase = _now.isEmpty ? _Phase.idle : _Phase.finishing;
    return out;
  }

  /// Call while a finger is down and still, so a hold is noticed without waiting for a move.
  List<TouchAction> tick(Duration time) {
    if (_phase != _Phase.pending || time - _downAt < holdDuration) return const [];
    _phase = _Phase.held;
    return [HoldBegan(_down.values.first)];
  }

  TouchAction _tap(Offset at, Duration time) {
    final isDouble = _lastTapAt != null &&
        time - _lastTapAt! <= doubleTapWindow &&
        (at - _lastTapPosition!).distance <= doubleTapDistance;
    _lastTapAt = isDouble ? null : time;
    _lastTapPosition = at;
    return Tap(at, count: isDouble ? 2 : 1);
  }

  void _startPinch() {
    final points = _now.values.take(2).toList();
    _pinchDistance = math.max(1, (points[0] - points[1]).distance);
    _pinchFocal = _midpoint(points[0], points[1]);
  }

  List<TouchAction> _pinch() {
    final points = _now.values.take(2).toList();
    if (points.length < 2) return const [];
    final distance = math.max(1.0, (points[0] - points[1]).distance);
    final focal = _midpoint(points[0], points[1]);
    if (!_twoFingerMoved) {
      final starts = _down.values.take(2).toList();
      final wandered = [for (var i = 0; i < 2; i++) (points[i] - starts[i]).distance].reduce(math.max);
      if (wandered <= slop) return const [];
      _twoFingerMoved = true;
    }
    final action = Zoom(scale: distance / _pinchDistance!, focal: focal, pan: focal - _pinchFocal!);
    _pinchDistance = distance;
    _pinchFocal = focal;
    return [action];
  }

  Offset _velocity(Duration now) {
    if (_samples.length < 2) return Offset.zero;
    final (firstTime, firstAt) = _samples.first;
    final (lastTime, lastAt) = _samples.last;
    // A finger that stopped before lifting doesn't fling.
    if (now - lastTime > const Duration(milliseconds: 60)) return Offset.zero;
    final seconds = (lastTime - firstTime).inMicroseconds / 1e6;
    return seconds <= 0 ? Offset.zero : (lastAt - firstAt) / seconds;
  }

  static Offset _midpoint(Offset a, Offset b) => Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
}

enum _Phase { idle, pending, held, scrolling, dragging, twoFinger, finishing }
