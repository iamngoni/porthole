import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test, setUp, tearDown;
import 'package:porthole/input/touch_interpreter.dart';

extension TouchAnys on Any {
  Generator<Offset> offsetIn(double min, double max) =>
      combine2(doubleInRange(min, max), doubleInRange(min, max), (double x, double y) => Offset(x, y));
  Generator<Offset> get spot => offsetIn(0, 1200);
  Generator<Offset> get jitter => offsetIn(-7, 7);
  Generator<Offset> get stroke => offsetIn(-300, 300);

  /// A first move far enough to start a scroll, in any direction.
  Generator<Offset> get push => combine3(doubleInRange(15, 200), doubleInRange(-200, 200), this.bool,
      (double along, double across, bool vertical) => vertical ? Offset(across, along) : Offset(along, across));

  /// One raw event for a random touch stream: kind (down, move, up, cancel, tick), pointer, place, gap.
  Generator<(int, int, Offset, int)> get rawEvent => combine4(intInRange(0, 5), intInRange(1, 4), spot, intInRange(0, 300),
      (int kind, int pointer, Offset at, int gap) => (kind, pointer, at, gap));
}

Duration ms(int value) => Duration(milliseconds: value);

bool isClickOrScroll(TouchAction action) =>
    action is Tap ||
    action is ScrollStart ||
    action is ScrollBy ||
    action is Fling ||
    action is DragStart ||
    action is DragMove ||
    action is DragEnd;

void main() {
  // glados runs every property from the same fixed seed (Random(42)), so a failure replays exactly.

  group('properties', () {
    Glados3(any.spot, any.listWithLengthInRange(0, 8, any.jitter), any.intInRange(0, 440))
        .test('a still, short touch is one tap where it landed', (start, jitters, upAt) {
      final touch = TouchInterpreter();
      final actions = [...touch.down(1, start, Duration.zero)];
      for (final (i, jitter) in jitters.indexed) {
        actions.addAll(touch.move(1, start + jitter, ms(upAt * i ~/ (jitters.length + 1))));
      }
      actions.addAll(touch.up(1, start, ms(upAt)));
      expect(actions, hasLength(1));
      final tap = actions.single as Tap;
      expect((tap.at, tap.count), (start, 1));
      expect(touch.isIdle, isTrue);
    });

    Glados3(any.spot, any.push, any.listWithLengthInRange(0, 12, any.stroke))
        .test('scrolling moves the content exactly as far as the finger', (start, push, strokes) {
      final touch = TouchInterpreter();
      final actions = [...touch.down(1, start, Duration.zero)];
      var at = start + push;
      var time = 10;
      actions.addAll(touch.move(1, at, ms(time)));
      for (final stroke in strokes) {
        at += stroke;
        time += 16;
        actions.addAll(touch.move(1, at, ms(time)));
      }
      actions.addAll(touch.up(1, at, ms(time + 16)));

      final moved = actions.whereType<ScrollBy>().fold(Offset.zero, (sum, scroll) => sum + scroll.delta);
      expect(moved.dx, closeTo((at - start).dx, 1e-6));
      expect(moved.dy, closeTo((at - start).dy, 1e-6));
      expect(actions.where((a) => a is Tap || a is SecondaryTap || a is DragStart || a is Zoom), isEmpty);
      // One scroll from where the finger landed: it starts first and ends once, before any fling.
      expect((actions.first as ScrollStart).at, start);
      final end = actions.indexWhere((a) => a is ScrollEnd);
      expect(actions.whereType<ScrollEnd>().single.cancelled, isFalse);
      expect(actions.skip(end + 1).every((a) => a is Fling), isTrue);
    });

    Glados3(
      any.combine2(any.spot, any.offsetIn(40, 400), (Offset a, Offset apart) => (a, a + apart)),
      any.intInRange(0, 100),
      any.listWithLengthInRange(0, 10, any.combine2(any.stroke, any.stroke, (Offset a, Offset b) => (a, b))),
    ).test('two fingers never click or scroll, and a pinch zooms exactly as far as the fingers spread', (starts, secondAt, moves) {
      final touch = TouchInterpreter();
      var (a, b) = starts;
      final actions = [...touch.down(1, a, Duration.zero), ...touch.down(2, b, ms(secondAt))];
      var time = secondAt;
      for (final (da, db) in moves) {
        time += 16;
        a += da;
        b += db;
        actions
          ..addAll(touch.move(1, a, ms(time)))
          ..addAll(touch.move(2, b, ms(time)));
      }
      actions
        ..addAll(touch.up(1, a, ms(time + 16)))
        ..addAll(touch.up(2, b, ms(time + 32)));

      expect(actions.where(isClickOrScroll), isEmpty);
      final zooms = actions.whereType<Zoom>().toList();
      expect(actions.whereType<ZoomEnd>().length, zooms.isEmpty ? 0 : 1);
      if (zooms.isNotEmpty) {
        final (a0, b0) = starts;
        final scale = zooms.fold(1.0, (product, zoom) => product * zoom.scale);
        expect(scale, closeTo(math.max(1.0, (a - b).distance) / math.max(1.0, (a0 - b0).distance), 1e-9));
        final pan = zooms.fold(Offset.zero, (sum, zoom) => sum + zoom.pan);
        final focalMoved = (a + b) / 2 - (a0 + b0) / 2;
        expect(pan.dx, closeTo(focalMoved.dx, 1e-6));
        expect(pan.dy, closeTo(focalMoved.dy, 1e-6));
      }
      expect(touch.isIdle, isTrue);
    });

    Glados(any.listWithLengthInRange(0, 60, any.rawEvent))
        .test('any stream of touches keeps drags and zooms balanced and ends idle', (events) {
      final touch = TouchInterpreter();
      final down = <int, Offset>{};
      final actions = <TouchAction>[];
      var time = 0;
      for (final (kind, pointer, at, gap) in events) {
        time += gap;
        final t = ms(time);
        switch (kind) {
          case 0 when !down.containsKey(pointer):
            down[pointer] = at;
            actions.addAll(touch.down(pointer, at, t));
          case 1 when down.containsKey(pointer):
            actions.addAll(touch.move(pointer, at, t));
          case 2 when down.containsKey(pointer):
            down.remove(pointer);
            actions.addAll(touch.up(pointer, at, t));
          case 3 when down.containsKey(pointer):
            down.remove(pointer);
            actions.addAll(touch.cancel(pointer));
          case 4:
            actions.addAll(touch.tick(t));
          default:
            break;
        }
      }
      for (final pointer in [...down.keys]) {
        time += 10;
        actions.addAll(touch.up(pointer, Offset.zero, ms(time)));
      }

      var dragging = false;
      var zooming = false;
      var scrolling = false;
      var holding = false;
      for (final action in actions) {
        switch (action) {
          case ScrollStart():
            expect(scrolling, isFalse, reason: 'a scroll started inside another');
            scrolling = true;
          case ScrollBy():
            expect(scrolling, isTrue, reason: 'a scroll moved before it started');
          case ScrollEnd():
            expect(scrolling, isTrue, reason: 'a scroll ended before it started');
            scrolling = false;
          case HoldBegan():
            expect(holding, isFalse, reason: 'a hold began inside another');
            holding = true;
          case HoldCancel():
            expect(holding, isTrue, reason: 'a hold was cancelled before it began');
            holding = false;
          case SecondaryTap() when holding:
            holding = false;
          case DragStart():
            expect(dragging, isFalse, reason: 'a drag started inside another');
            dragging = true;
            holding = false;
          case DragMove():
            expect(dragging, isTrue, reason: 'a drag moved before it started');
          case DragEnd():
            expect(dragging, isTrue, reason: 'a drag ended before it started');
            dragging = false;
          case Zoom():
            zooming = true;
          case ZoomEnd():
            expect(zooming, isTrue, reason: 'a zoom ended before it started');
            zooming = false;
          default:
            break;
        }
      }
      expect((dragging, zooming, scrolling, holding), (false, false, false, false));
      expect(touch.isIdle, isTrue);
    });
  });

  group('examples', () {
    test('two quick taps in the same place are a double tap', () {
      final touch = TouchInterpreter();
      const spot = Offset(300, 200);
      touch.down(1, spot, ms(0));
      final first = touch.up(1, spot, ms(60));
      touch.down(2, spot + const Offset(4, 3), ms(200));
      final second = touch.up(2, spot + const Offset(4, 3), ms(250));
      expect((first.single as Tap).count, 1);
      expect((second.single as Tap).count, 2);
    });

    test('touch and hold, then lift, is a right-click where the finger was', () {
      final touch = TouchInterpreter();
      const spot = Offset(500, 400);
      touch.down(1, spot, ms(0));
      expect(touch.tick(ms(300)), isEmpty);
      expect(touch.tick(ms(460)).single, isA<HoldBegan>());
      expect((touch.up(1, spot, ms(700)).single as SecondaryTap).at, spot);
    });

    test('touch and hold, then move, drags from where the finger landed', () {
      final touch = TouchInterpreter();
      const spot = Offset(100, 100);
      touch.down(1, spot, ms(0));
      touch.tick(ms(500));
      final moved = touch.move(1, const Offset(160, 130), ms(600));
      expect((moved[0] as DragStart).at, spot);
      expect((moved[1] as DragMove).at, const Offset(160, 130));
      expect((touch.up(1, const Offset(200, 150), ms(700)).last as DragEnd).at, const Offset(200, 150));
    });

    test('a quick swipe up flings the content up', () {
      final touch = TouchInterpreter();
      touch.down(1, const Offset(400, 900), ms(0));
      for (var i = 1; i <= 6; i++) {
        touch.move(1, Offset(400, 900 - i * 60.0), ms(i * 12));
      }
      final fling = touch.up(1, const Offset(400, 540), ms(80)).last as Fling;
      expect(fling.velocity.dy, lessThan(-1000));
    });

    test('a finger that stops before lifting does not fling', () {
      final touch = TouchInterpreter();
      touch.down(1, const Offset(400, 900), ms(0));
      touch.move(1, const Offset(400, 700), ms(40));
      expect(touch.up(1, const Offset(400, 700), ms(400)).whereType<Fling>(), isEmpty);
    });

    test('a second finger during a scroll cancels it, and during a hold cancels the hold', () {
      final scroll = TouchInterpreter()..down(1, const Offset(100, 100), ms(0));
      expect(scroll.move(1, const Offset(100, 160), ms(20)).first, isA<ScrollStart>());
      expect((scroll.down(2, const Offset(300, 300), ms(40)).single as ScrollEnd).cancelled, isTrue);

      final hold = TouchInterpreter()..down(1, const Offset(100, 100), ms(0));
      expect(hold.tick(ms(500)).single, isA<HoldBegan>());
      expect(hold.down(2, const Offset(300, 300), ms(520)).single, isA<HoldCancel>());
    });

    test('a two-finger tap is a right-click between the fingers', () {
      final touch = TouchInterpreter()
        ..down(1, const Offset(100, 100), ms(0))
        ..down(2, const Offset(200, 140), ms(30));
      expect((touch.up(1, const Offset(100, 100), ms(120)).single as SecondaryTap).at, const Offset(150, 120));
      expect(touch.up(2, const Offset(200, 140), ms(130)), isEmpty);
      expect(touch.isIdle, isTrue);
    });
  });
}
