import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test, setUp, tearDown;
import 'package:porthole/input/geometry.dart';

// The same properties as AspectFitTests and ZoomViewportTests in InputLogicTests.swift.
// glados runs every property from a fixed seed (Random(42)) and shrinks failures.

extension GeometryAnys on Any {
  Generator<Size> sizeUpTo(double max) =>
      combine2(doubleInRange(1, max), doubleInRange(1, max), (double w, double h) => Size(w, h));
  Generator<Size> get size => sizeUpTo(4000);
  Generator<Offset> get point => combine2(doubleInRange(-3000, 3000), doubleInRange(-3000, 3000), (double x, double y) => Offset(x, y));
  Generator<double> get fraction => doubleInRange(0.001, 0.999);

  /// Any state a gesture could leave behind, including the odd non-finite value.
  Generator<ZoomViewport> get viewport => combine2(
        either(doubleInRange(0.01, 12), choose([0.0, 1.0, -1.0, double.infinity, double.nan])),
        point,
        (double scale, Offset offset) => ZoomViewport(scale: scale, offset: offset),
      );
  Generator<ZoomViewport> viewportIn(double min, double max) =>
      combine2(doubleInRange(min, max), point, (double scale, Offset offset) => ZoomViewport(scale: scale, offset: offset));
}

bool close(double a, double b, double scale) => (a - b).abs() <= 1e-6 * math.max(1, scale);

void main() {
  group('AspectFit', () {
    Glados2(any.sizeUpTo(5000), any.sizeUpTo(5000), ExploreConfig(numRuns: 300))
        .test('prop_fitted_video_keeps_its_shape_fills_one_side_and_is_centered', (content, bounds) {
      final r = AspectFit.rect(content, bounds);
      final tolerance = 1e-6 * math.max(bounds.width, bounds.height);
      expect(r.left >= -tolerance && r.top >= -tolerance, isTrue);
      expect(r.right <= bounds.width + tolerance && r.bottom <= bounds.height + tolerance, isTrue);
      final ratio = content.width / content.height;
      expect((r.width / r.height - ratio).abs() <= 1e-9 * ratio, isTrue);
      expect((r.width - bounds.width).abs() <= tolerance || (r.height - bounds.height).abs() <= tolerance, isTrue);
      expect(close(r.center.dx, bounds.width / 2, tolerance * 1e6) && close(r.center.dy, bounds.height / 2, tolerance * 1e6), isTrue);
    });

    Glados3(any.combine2(any.sizeUpTo(5000), any.sizeUpTo(5000), (Size c, Size b) => (c, b)), any.fraction, any.fraction,
            ExploreConfig(numRuns: 300))
        .test('prop_a_spot_on_the_video_maps_back_to_itself', (sizes, x, y) {
      final (content, bounds) = sizes;
      final r = AspectFit.rect(content, bounds);
      final mapped = AspectFit.normalized(Offset(r.left + x * r.width, r.top + y * r.height), content, bounds)!;
      expect((mapped.dx - x).abs() < 1e-6 && (mapped.dy - y).abs() < 1e-6, isTrue);
    });

    Glados3(any.combine2(any.size, any.size, (Size c, Size b) => (c, b)), any.doubleInRange(0, 1), any.doubleInRange(0, 1))
        .test('prop_the_bars_around_the_video_map_to_nothing', (sizes, x, y) {
      final (content, bounds) = sizes;
      final point = Offset(x * bounds.width, y * bounds.height);
      final r = AspectFit.rect(content, bounds);
      final inside = point.dx >= r.left && point.dx <= r.right && point.dy >= r.top && point.dy <= r.bottom;
      expect(AspectFit.normalized(point, content, bounds) != null, inside);
    });

    test('a wide video on a square view has bars top and bottom', () {
      expect(AspectFit.rect(const Size(1600, 900), const Size(800, 800)), const Rect.fromLTWH(0, 175, 800, 450));
      expect(AspectFit.normalized(const Offset(400, 100), const Size(1600, 900), const Size(800, 800)), isNull);
      expect(AspectFit.rect(Size.zero, const Size(10, 10)), Rect.zero);
    });
  });

  group('ZoomViewport', () {
    final sizes = any.combine2(any.size, any.size, (Size c, Size b) => (c, b));

    Glados2(any.viewport, sizes, ExploreConfig(numRuns: 400))
        .test('prop_settled_zoom_is_in_range_and_keeps_the_video_over_the_view', (viewport, sizes) {
      final (content, bounds) = sizes;
      final settled = viewport.settled(content, bounds);
      expect(settled.scale >= 1 && settled.scale <= ZoomViewport.maxScale, isTrue);
      final frame = settled.frame(content, bounds);
      final tolerance = 1e-6 * math.max(math.max(frame.width, frame.height), 1);
      if (frame.width > bounds.width + tolerance) {
        expect(frame.left <= tolerance && frame.right >= bounds.width - tolerance, isTrue);
      } else {
        expect(close(frame.center.dx, bounds.width / 2, frame.width), isTrue);
      }
      if (frame.height > bounds.height + tolerance) {
        expect(frame.top <= tolerance && frame.bottom >= bounds.height - tolerance, isTrue);
      } else {
        expect(close(frame.center.dy, bounds.height / 2, frame.height), isTrue);
      }
    });

    Glados2(any.viewport, sizes, ExploreConfig(numRuns: 300)).test('prop_settling_twice_changes_nothing', (viewport, sizes) {
      final (content, bounds) = sizes;
      final once = viewport.settled(content, bounds);
      final twice = once.settled(content, bounds);
      expect(once.scale, twice.scale);
      expect(close(once.offset.dx, twice.offset.dx, bounds.width) && close(once.offset.dy, twice.offset.dy, bounds.height), isTrue);
    });

    Glados3(any.combine2(any.viewportIn(0.2, 6), any.doubleInRange(0.2, 4), (ZoomViewport v, double f) => (v, f)), any.point,
            sizes, ExploreConfig(numRuns: 400))
        .test('prop_pinching_keeps_the_spot_under_the_fingers', (start, anchor, sizes) {
      final (viewport, factor) = start;
      final (content, bounds) = sizes;
      final before = viewport.spot(anchor, content, bounds)!;
      final after = viewport.zoomed(factor, around: anchor, content: content, bounds: bounds).spot(anchor, content, bounds)!;
      expect((before.dx - after.dx).abs() <= 1e-6 * math.max(1, before.dx.abs()), isTrue);
      expect((before.dy - after.dy).abs() <= 1e-6 * math.max(1, before.dy.abs()), isTrue);
    });

    Glados3(any.viewportIn(0.01, 12), any.combine2(any.point, any.point, (Offset p, Offset m) => (p, m)), sizes,
            ExploreConfig(numRuns: 300))
        .test('prop_two_finger_drag_moves_the_video_with_the_fingers', (viewport, points, sizes) {
      final (point, move) = points;
      final (content, bounds) = sizes;
      final before = viewport.spot(point, content, bounds)!;
      final after = viewport.panned(move).spot(point + move, content, bounds)!;
      expect((before.dx - after.dx).abs() < 1e-6 * math.max(1, before.dx.abs()), isTrue);
      expect((before.dy - after.dy).abs() < 1e-6 * math.max(1, before.dy.abs()), isTrue);
    });

    Glados2(any.point, sizes, ExploreConfig(numRuns: 300))
        .test('prop_unzoomed_touches_land_exactly_where_the_fitted_video_says', (point, sizes) {
      final (content, bounds) = sizes;
      final zoom = const ZoomViewport().normalized(point, content, bounds);
      final fit = AspectFit.normalized(point, content, bounds);
      expect(zoom == null, fit == null);
      if (zoom != null && fit != null) {
        expect((zoom.dx - fit.dx).abs() < 1e-9 && (zoom.dy - fit.dy).abs() < 1e-9, isTrue);
      }
    });

    Glados2(any.viewportIn(0.2, 8), sizes, ExploreConfig(numRuns: 300))
        .test('prop_overshoot_is_drawn_between_the_limit_and_the_finger', (raw, sizes) {
      final (content, bounds) = sizes;
      final rest = raw.settled(content, bounds);
      final shown = raw.resisted(content, bounds);
      bool between(double value, double a, double b) {
        final slack = 1e-9 * [1.0, a.abs(), b.abs()].reduce(math.max);
        return value >= math.min(a, b) - slack && value <= math.max(a, b) + slack;
      }

      expect(between(shown.scale, rest.scale, raw.scale), isTrue);
      expect(between(shown.offset.dx, rest.offset.dx, raw.offset.dx), isTrue);
      expect(between(shown.offset.dy, rest.offset.dy, raw.offset.dy), isTrue);
    });

    Glados2(any.viewport, sizes, ExploreConfig(numRuns: 300)).test('prop_a_view_at_rest_does_not_resist', (viewport, sizes) {
      final (content, bounds) = sizes;
      final rest = viewport.settled(content, bounds);
      final shown = rest.resisted(content, bounds);
      expect(shown.scale, rest.scale);
      expect(close(shown.offset.dx, rest.offset.dx, bounds.width) && close(shown.offset.dy, rest.offset.dy, bounds.height), isTrue);
    });

    test('pinching to double at the center, then dragging past the edge', () {
      const size = Size(1000, 500);
      final zoomed = const ZoomViewport().zoomed(2, around: const Offset(500, 250), content: size, bounds: size);
      expect(zoomed.frame(size, size), const Rect.fromLTWH(-500, -250, 2000, 1000));
      // A spot a quarter of the way in now sits at the left edge of the view.
      expect(zoomed.normalized(const Offset(0, 250), size, size), const Offset(0.25, 0.5));
      expect(zoomed.panned(const Offset(900, 0)).settled(size, size).offset, const Offset(500, 0));
    });

    test('pinching in past one springs back to fit', () {
      const size = Size(800, 600);
      final squeezed = const ZoomViewport().zoomed(0.5, around: const Offset(100, 100), content: size, bounds: size);
      expect(squeezed.scale, 0.7);
      expect(squeezed.settled(size, size), const ZoomViewport());
    });
  });
}
