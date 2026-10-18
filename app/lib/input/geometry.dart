import 'dart:math' as math;
import 'dart:ui';

// Where the video sits on screen and where a touch lands on the Mac's window, as AspectFit and
// ZoomViewport in InputLogic.swift. Points on the video are fractions of its size, 0…1 from the top left.

/// How the video sits in its view: scaled to fit, centered, with bars on two sides.
abstract final class AspectFit {
  /// The rectangle [content] occupies when fitted inside [bounds].
  static Rect rect(Size content, Size bounds) {
    if (content.width <= 0 || content.height <= 0 || bounds.width <= 0 || bounds.height <= 0) return Rect.zero;
    final scale = math.min(bounds.width / content.width, bounds.height / content.height);
    final size = Size(content.width * scale, content.height * scale);
    return Rect.fromLTWH((bounds.width - size.width) / 2, (bounds.height - size.height) / 2, size.width, size.height);
  }

  /// Where [point] (in the view) lands on the video, as fractions of its width and height.
  /// Null on the bars around it, or before there is any video.
  static Offset? normalized(Offset point, Size content, Size bounds) {
    final frame = rect(content, bounds);
    if (frame.width <= 0 || frame.height <= 0 || !_contains(frame, point)) return null;
    return Offset((point.dx - frame.left) / frame.width, (point.dy - frame.top) / frame.height);
  }

  /// Like `Rect.contains`, but including the right and bottom edges, as CGRect does for a point on them.
  static bool _contains(Rect rect, Offset point) =>
      point.dx >= rect.left && point.dx <= rect.right && point.dy >= rect.top && point.dy <= rect.bottom;
}

/// Pinch-zoom on the device: the fitted video drawn [scale] times bigger and moved by [offset].
/// It never reaches the Mac; it only changes where on the window a touch lands.
final class ZoomViewport {
  const ZoomViewport({this.scale = 1, this.offset = Offset.zero});

  static const maxScale = 5.0;

  /// How far a pinch may go past the limits before it settles back, for a rubber-band feel.
  static const stretchMin = 0.7;
  static const stretchMax = maxScale * 1.3;

  final double scale;

  /// From the fitted video's center to the zoomed video's center, in view points.
  final Offset offset;

  bool get isZoomed => scale > 1.01;

  /// Where the video is drawn in a view of size [bounds].
  Rect frame(Size content, Size bounds) {
    final fitted = AspectFit.rect(content, bounds);
    final size = Size(fitted.width * scale, fitted.height * scale);
    return Rect.fromLTWH(fitted.center.dx + offset.dx - size.width / 2, fitted.center.dy + offset.dy - size.height / 2,
        size.width, size.height);
  }

  /// The spot on the video under [point], as fractions of its size; outside 0…1 off the video.
  /// Null before there is any video.
  Offset? spot(Offset point, Size content, Size bounds) {
    final frame = this.frame(content, bounds);
    if (!(frame.width > 0) || !(frame.height > 0)) return null;
    return Offset((point.dx - frame.left) / frame.width, (point.dy - frame.top) / frame.height);
  }

  /// The spot under [point], or null when the point is off the video.
  Offset? normalized(Offset point, Size content, Size bounds) {
    final spot = this.spot(point, content, bounds);
    if (spot == null || spot.dx < 0 || spot.dx > 1 || spot.dy < 0 || spot.dy > 1) return null;
    return spot;
  }

  /// Scales by [factor] while the spot under [anchor] stays under it, as a pinch does.
  ZoomViewport zoomed(double factor, {required Offset around, required Size content, required Size bounds}) {
    final anchor = around;
    if (!factor.isFinite || factor <= 0 || !anchor.dx.isFinite || !anchor.dy.isFinite) return this;
    final newScale = (scale * factor).clamp(stretchMin, stretchMax);
    final fitted = AspectFit.rect(content, bounds);
    final ratio = newScale / scale;
    final center = fitted.center + offset;
    final newCenter = anchor - (anchor - center) * ratio;
    return ZoomViewport(scale: newScale, offset: newCenter - fitted.center);
  }

  /// Moved by [translation], as a two-finger drag does.
  ZoomViewport panned(Offset translation) {
    if (!translation.dx.isFinite || !translation.dy.isFinite) return this;
    return ZoomViewport(scale: scale, offset: offset + translation);
  }

  /// What to draw while a gesture is past the limits: the settled view plus part of the overshoot,
  /// so the video gives a little and springs back instead of stopping dead.
  ZoomViewport resisted(Size content, Size bounds, {double give = 0.35}) {
    final rest = settled(content, bounds);
    if (!scale.isFinite || !offset.dx.isFinite || !offset.dy.isFinite) return rest;
    double blend(double rest, double raw) => rest + (raw - rest) * give;
    return ZoomViewport(
      scale: blend(rest.scale, scale),
      offset: Offset(blend(rest.offset.dx, offset.dx), blend(rest.offset.dy, offset.dy)),
    );
  }

  /// Back within limits: between 1× and the maximum, with no gap between the video and the view's edge
  /// on a side where the video is bigger than the view, and centered on a side where it is smaller.
  ZoomViewport settled(Size content, Size bounds) {
    final scale = this.scale.isFinite ? this.scale.clamp(1.0, maxScale) : 1.0;
    final fitted = AspectFit.rect(content, bounds);
    double limit(double value, double size, double view) {
      final slack = math.max(0.0, (size - view) / 2);
      return value.isFinite ? value.clamp(-slack, slack) : 0;
    }

    return ZoomViewport(
      scale: scale,
      offset: Offset(limit(offset.dx, fitted.width * scale, bounds.width), limit(offset.dy, fitted.height * scale, bounds.height)),
    );
  }

  @override
  bool operator ==(Object other) => other is ZoomViewport && other.scale == scale && other.offset == offset;

  @override
  int get hashCode => Object.hash(scale, offset);

  @override
  String toString() => 'ZoomViewport(${scale.toStringAsFixed(3)}×, $offset)';
}

/// A point clamped to the video's edges, for drags that wander off it.
Offset clampToVideo(Offset spot) => Offset(spot.dx.clamp(0.0, 1.0), spot.dy.clamp(0.0, 1.0));
