import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:porthole_protocol/porthole_protocol.dart' as pb;

import '../client/system.dart';
import '../input/geometry.dart';
import '../input/keys.dart';
import '../input/momentum.dart';
import '../input/soft_keyboard.dart';
import '../input/touch_interpreter.dart';
import 'key_bar.dart';
import 'touch_feedback.dart';

/// The streamed window, used like a tablet app: there is no pointer to push around (StreamSurfaceView.swift).
///
/// Touch: tap anywhere to click there, drag to scroll (with momentum), touch and hold to right-click,
/// touch and hold then move to drag, two-finger tap to right-click. Pinch to zoom in and drag with two
/// fingers to look around; zooming stays on this device.
/// Trackpad or mouse: move, click, right-click, drag and two-finger scroll, as on a Mac.
/// Keyboard: hardware keys go over as physical keys, so the Mac's own layout applies.
// no-prop-test: wiring between Flutter's pointer and key events and the tested pieces it uses
// (TouchInterpreter, ZoomViewport, MomentumScroller, keyboardEdit, usageForCharacter); checked on devices.
class StreamSurface extends StatefulWidget {
  const StreamSurface({
    super.key,
    required this.stream,
    required this.gen,
    required this.videoSize,
    required this.canControl,
    required this.showsKeyboard,
    required this.onKeyboardHidden,
    required this.zoomResetToken,
    required this.onZoomChange,
    required this.onInteraction,
    required this.send,
  });

  final MediaStream? stream;

  /// The stream the input is aimed at; null means no video yet, so input is dropped.
  final int? gen;

  /// The video's pixel size, to find where it sits in this view.
  final Size videoSize;
  final bool canControl;
  final bool showsKeyboard;
  final VoidCallback onKeyboardHidden;

  /// Bumped to ask for the zoom to go back to fit.
  final int zoomResetToken;
  final ValueChanged<double> onZoomChange;

  /// Any touch on the window, so the controls can step out of the way.
  final VoidCallback onInteraction;
  final void Function(pb.ClientMessage message) send;

  @override
  State<StreamSurface> createState() => _StreamSurfaceState();
}

typedef _HoldState = ({pb.NormalizedPoint start, Offset startLocation, bool dragging});

class _StreamSurfaceState extends State<StreamSurface> with TickerProviderStateMixin {
  final _renderer = RTCVideoRenderer();
  var _rendererReady = false;
  final _touch = TouchInterpreter();
  final _feedback = TouchFeedback();
  late final Ticker _ticker = createTicker((_) => _onTick());

  /// Pointer events carry the engine's timestamps; ticks between them are placed on the same timeline.
  final _clock = Stopwatch()..start();
  var _lastEventTime = Duration.zero;
  var _clockAtLastEvent = Duration.zero;

  var _viewport = const ZoomViewport();
  var _shown = const ZoomViewport();
  late final _settle = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  ZoomViewport _settleFrom = const ZoomViewport();
  var _bounds = Size.zero;
  var _reportedScale = 1.0;

  pb.NormalizedPoint? _scrollPoint;
  var _scrollBegan = false;
  var _scrollEndedWithoutFling = false;
  MomentumScroller? _momentum;
  var _momentumStart = Duration.zero;
  var _momentumFrames = 0;
  _HoldState? _hold;

  int? _mousePointer;
  pb.MouseButton? _mouseButton;
  Timer? _wheelEnd;
  Offset _panLast = Offset.zero;
  double _panScale = 1;
  var _panZoomed = false;
  final _panSamples = <(Duration, Offset)>[];

  final _surfaceFocus = FocusNode(debugLabel: 'stream');
  final _textFocus = FocusNode(debugLabel: 'stream keyboard');
  final _text = TextEditingController(text: keyboardSentinel);
  var _sticky = 0;

  @override
  void initState() {
    super.initState();
    _settle.addListener(() {
      final t = Curves.easeOutBack.transform(_settle.value).clamp(0.0, 1.05);
      setState(() => _shown = _lerp(_settleFrom, _viewport, t));
    });
    _renderer.initialize().then((_) {
      if (!mounted) return;
      _renderer.srcObject = widget.stream;
      setState(() => _rendererReady = true);
    }, onError: (Object error) => debugPrint('video renderer: $error'));
    _text.addListener(_onTextChanged);
    _textFocus.addListener(_onTextFocus);
    System.claimEdges(true);
  }

  @override
  void didUpdateWidget(StreamSurface old) {
    super.didUpdateWidget(old);
    if (_rendererReady && widget.stream != old.stream) _renderer.srcObject = widget.stream;
    if (widget.gen != old.gen) {
      _endGestures();
      widget.send(pb.ClientMessage(releaseAll: pb.Nothing()));
      // A different window starts unzoomed.
      _setViewport(const ZoomViewport(), animated: false);
    } else if (widget.videoSize != old.videoSize) {
      _setViewport(_viewport.settled(widget.videoSize, _bounds), animated: false);
    }
    if (widget.zoomResetToken != old.zoomResetToken) _setViewport(const ZoomViewport(), animated: true);
    if (widget.showsKeyboard != old.showsKeyboard) _showKeyboard(widget.showsKeyboard);
  }

  @override
  void dispose() {
    _endGestures();
    widget.send(pb.ClientMessage(releaseAll: pb.Nothing()));
    System.claimEdges(false);
    _wheelEnd?.cancel();
    _ticker.dispose();
    _settle.dispose();
    _feedback.dispose();
    if (_rendererReady) {
      _renderer.srcObject = null;
      _renderer.dispose();
    }
    _text.dispose();
    _textFocus.dispose();
    _surfaceFocus.dispose();
    super.dispose();
  }

  // MARK: Layout and zoom

  void _layout(Size bounds) {
    // Only a new size (rotation, the keyboard) moves the video; a pinch in progress keeps its place.
    if (bounds == _bounds) return;
    _bounds = bounds;
    _viewport = _viewport.settled(widget.videoSize, bounds);
    _shown = _viewport;
  }

  void _setViewport(ZoomViewport target, {required bool animated}) {
    _settleFrom = _shown;
    _viewport = target;
    if (animated) {
      _settle.forward(from: 0);
    } else {
      _settle.stop();
      setState(() => _shown = target);
    }
    _reportZoom();
  }

  static ZoomViewport _lerp(ZoomViewport a, ZoomViewport b, double t) =>
      ZoomViewport(scale: a.scale + (b.scale - a.scale) * t, offset: Offset.lerp(a.offset, b.offset, t)!);

  void _reportZoom() {
    final scale = (_viewport.scale * 10).roundToDouble() / 10;
    if (scale == _reportedScale) return;
    _reportedScale = scale;
    widget.onZoomChange(scale);
  }

  void _showResisted() => setState(() => _shown = _viewport.resisted(widget.videoSize, _bounds));

  void _settleZoom() {
    final settled = _viewport.settled(widget.videoSize, _bounds);
    _setViewport(settled.isZoomed ? settled : const ZoomViewport(), animated: true);
  }

  // MARK: Mapping

  pb.NormalizedPoint? _normalized(Offset location) => _point(_shown.normalized(location, widget.videoSize, _bounds));

  /// Like [_normalized], but clamps points off the video to its nearest edge, for drags that wander off.
  pb.NormalizedPoint? _clamped(Offset location) {
    final spot = _shown.spot(location, widget.videoSize, _bounds);
    return spot == null ? null : _point(clampToVideo(spot));
  }

  static pb.NormalizedPoint? _point(Offset? spot) => spot == null ? null : pb.NormalizedPoint(x: spot.dx, y: spot.dy);

  /// The video as drawn, zoom included; scrolling divides by it so content moves with the finger.
  Rect get _videoFrame => _shown.frame(widget.videoSize, _bounds);

  // MARK: Sending

  void _click(pb.MouseButton button, pb.NormalizedPoint point) {
    _button(button, point, isDown: true);
    _button(button, point, isDown: false);
  }

  void _button(pb.MouseButton button, pb.NormalizedPoint point, {required bool isDown}) {
    final gen = widget.gen;
    if (gen == null) return;
    widget.send(pb.ClientMessage(button: pb.ButtonEvent(gen: gen, point: point, button: button, isDown: isDown)));
  }

  void _pointer(pb.NormalizedPoint point) {
    final gen = widget.gen;
    if (gen == null) return;
    widget.send(pb.ClientMessage(pointer: pb.PointerEvent(gen: gen, point: point)));
  }

  void _scroll(pb.NormalizedPoint point, Offset delta, {pb.ScrollPhase? phase, pb.MomentumPhase? momentum}) {
    final gen = widget.gen;
    final frame = _videoFrame;
    if (gen == null || frame.width <= 0 || frame.height <= 0) return;
    widget.send(pb.ClientMessage(
      scroll: pb.ScrollEvent(
        gen: gen,
        point: point,
        dx: delta.dx / frame.width,
        dy: delta.dy / frame.height,
        phase: phase,
        momentum: momentum ?? pb.MomentumPhase.MOMENTUM_PHASE_NONE,
      ),
    ));
  }

  // MARK: Clock

  Duration get _now => _lastEventTime + (_clock.elapsed - _clockAtLastEvent);

  void _stamp(Duration time) {
    _lastEventTime = time;
    _clockAtLastEvent = _clock.elapsed;
  }

  void _ensureTicking() {
    if (!_ticker.isActive) _ticker.start();
  }

  void _onTick() {
    final now = _now;
    _apply(_touch.tick(now));
    _stepMomentum(now);
    _feedback.tick(now);
    if (_touch.isIdle && _momentum == null && !_feedback.isActive) _ticker.stop();
  }

  // MARK: Touch

  static bool _isTouch(PointerDeviceKind kind) =>
      kind == PointerDeviceKind.touch || kind == PointerDeviceKind.stylus || kind == PointerDeviceKind.invertedStylus;

  void _onDown(PointerDownEvent event) {
    _stamp(event.timeStamp);
    if (_isTouch(event.kind)) {
      widget.onInteraction();
      _apply(_touch.down(event.pointer, event.localPosition, event.timeStamp));
      _ensureTicking();
    } else if (event.kind == PointerDeviceKind.mouse && _mousePointer == null) {
      final point = _normalized(event.localPosition);
      if (point == null) return;
      widget.onInteraction();
      _stopMomentum();
      _mousePointer = event.pointer;
      _mouseButton = event.buttons & kSecondaryMouseButton != 0
          ? pb.MouseButton.MOUSE_BUTTON_RIGHT
          : pb.MouseButton.MOUSE_BUTTON_LEFT;
      _button(_mouseButton!, point, isDown: true);
    }
  }

  void _onMove(PointerMoveEvent event) {
    _stamp(event.timeStamp);
    if (_isTouch(event.kind)) {
      _apply(_touch.move(event.pointer, event.localPosition, event.timeStamp));
    } else if (event.pointer == _mousePointer) {
      final point = _clamped(event.localPosition);
      if (point != null) _pointer(point);
    }
  }

  void _onUp(PointerUpEvent event) {
    _stamp(event.timeStamp);
    if (_isTouch(event.kind)) {
      _apply(_touch.up(event.pointer, event.localPosition, event.timeStamp));
    } else if (event.pointer == _mousePointer) {
      _endMouse(event.localPosition);
    }
  }

  void _onCancel(PointerCancelEvent event) {
    if (_isTouch(event.kind)) {
      _apply(_touch.cancel(event.pointer));
    } else if (event.pointer == _mousePointer) {
      _endMouse(event.localPosition);
    }
  }

  void _endMouse(Offset location) {
    final button = _mouseButton;
    _mousePointer = null;
    _mouseButton = null;
    final point = _clamped(location);
    if (button != null && point != null) _button(button, point, isDown: false);
  }

  void _onHover(PointerHoverEvent event) {
    final point = _normalized(event.localPosition);
    if (point != null) _pointer(point);
  }

  void _apply(List<TouchAction> actions) {
    if (actions.isEmpty) return;
    var flung = false;
    _scrollEndedWithoutFling = false;
    for (final action in actions) {
      switch (action) {
        case Tap(:final at):
          final point = _normalized(at);
          if (point == null) continue;
          _stopMomentum();
          _click(pb.MouseButton.MOUSE_BUTTON_LEFT, point);
          if (widget.canControl) _feedback.tap(at);
        case SecondaryTap(:final at):
          final hold = _hold;
          _hold = null;
          _feedback.endHold();
          final point = hold?.start ?? _normalized(at);
          if (point == null) continue;
          _click(pb.MouseButton.MOUSE_BUTTON_RIGHT, point);
          if (widget.canControl) _feedback.secondaryTap(hold?.startLocation ?? at);
        case HoldBegan(:final at):
          final point = _normalized(at);
          if (point == null) continue;
          _stopMomentum();
          _hold = (start: point, startLocation: at, dragging: false);
          if (widget.canControl) {
            HapticFeedback.lightImpact();
            _feedback.beginHold(at);
          }
        case HoldCancel():
          _hold = null;
          _feedback.endHold();
        case DragStart():
          final hold = _hold;
          if (hold == null) continue;
          _hold = (start: hold.start, startLocation: hold.startLocation, dragging: true);
          _button(pb.MouseButton.MOUSE_BUTTON_LEFT, hold.start, isDown: true);
          if (widget.canControl) _feedback.beginDrag();
        case DragMove(:final at):
          if (_hold?.dragging != true) continue;
          final point = _clamped(at);
          if (point != null) _pointer(point);
          _feedback.moveHold(at);
        case DragEnd(:final at):
          final hold = _hold;
          _hold = null;
          _feedback.endHold();
          if (hold == null || !hold.dragging) continue;
          _button(pb.MouseButton.MOUSE_BUTTON_LEFT, _clamped(at) ?? hold.start, isDown: false);
        case ScrollStart(:final at):
          _stopMomentum();
          // Scroll what's under the finger where the gesture started.
          _scrollPoint = _clamped(at);
          _scrollBegan = false;
        case ScrollBy(:final delta):
          final point = _scrollPoint;
          if (point == null) continue;
          _scroll(point, delta,
              phase: _scrollBegan ? pb.ScrollPhase.SCROLL_PHASE_CHANGED : pb.ScrollPhase.SCROLL_PHASE_BEGAN);
          _scrollBegan = true;
        case ScrollEnd(:final cancelled):
          final point = _scrollPoint;
          if (point == null) continue;
          _scroll(point, Offset.zero,
              phase: cancelled ? pb.ScrollPhase.SCROLL_PHASE_CANCELLED : pb.ScrollPhase.SCROLL_PHASE_ENDED);
          if (cancelled) {
            _scrollPoint = null;
          } else {
            _scrollEndedWithoutFling = true;
          }
        case Fling(:final velocity):
          flung = true;
          _startMomentum(velocity);
        case Zoom(:final scale, :final focal, :final pan):
          _stopMomentum();
          _settle.stop();
          _viewport = _viewport
              .panned(pan)
              .zoomed(scale, around: focal, content: widget.videoSize, bounds: _bounds);
          _showResisted();
        case ZoomEnd():
          _settleZoom();
      }
    }
    if (_scrollEndedWithoutFling && !flung) _scrollPoint = null;
  }

  // MARK: Momentum

  void _startMomentum(Offset velocity) {
    final point = _scrollPoint;
    final scroller = MomentumScroller(velocity);
    final first = scroller.next();
    if (point == null || first == null) {
      _scrollPoint = null;
      return;
    }
    _scroll(point, first, momentum: pb.MomentumPhase.MOMENTUM_PHASE_BEGAN);
    _momentum = scroller;
    _momentumStart = _now;
    _momentumFrames = 1;
    _ensureTicking();
  }

  /// Steps at 60 a second whatever the screen's rate, so the glide is the same length everywhere.
  void _stepMomentum(Duration now) {
    final scroller = _momentum;
    final point = _scrollPoint;
    if (scroller == null) return;
    if (point == null) {
      _stopMomentum();
      return;
    }
    final due = ((now - _momentumStart).inMicroseconds * MomentumScroller.framesPerSecond / 1e6).floor() + 1;
    if (due <= _momentumFrames) return;
    final step = scroller.take(due - _momentumFrames);
    _momentumFrames = due;
    if (step == null) {
      _stopMomentum();
    } else {
      _scroll(point, step, momentum: pb.MomentumPhase.MOMENTUM_PHASE_CHANGED);
    }
  }

  /// Ends a glide in progress, telling the Mac it ended (a new touch stops scrolling, as on a trackpad).
  void _stopMomentum() {
    final point = _scrollPoint;
    if (_momentum != null && point != null) _scroll(point, Offset.zero, momentum: pb.MomentumPhase.MOMENTUM_PHASE_ENDED);
    _momentum = null;
    _scrollPoint = null;
  }

  /// Lets go of everything in progress, for a new window or when the view goes away.
  void _endGestures() {
    _stopMomentum();
    final hold = _hold;
    if (hold != null && hold.dragging) _button(pb.MouseButton.MOUSE_BUTTON_LEFT, hold.start, isDown: false);
    _hold = null;
    _mousePointer = null;
    _mouseButton = null;
    _feedback.endHold();
  }

  // MARK: Wheel and trackpad

  void _onSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (event) {
      final scroll = event as PointerScrollEvent;
      // Each wheel notch is a short gesture: began, changed while notches keep coming, then ended.
      final starting = _wheelEnd == null || _scrollPoint == null;
      if (starting) {
        widget.onInteraction();
        _stopMomentum();
        _scrollPoint = _clamped(scroll.localPosition);
      }
      final point = _scrollPoint;
      if (point == null) return;
      _scroll(point, -scroll.scrollDelta,
          phase: starting ? pb.ScrollPhase.SCROLL_PHASE_BEGAN : pb.ScrollPhase.SCROLL_PHASE_CHANGED);
      _wheelEnd?.cancel();
      _wheelEnd = Timer(const Duration(milliseconds: 150), () {
        _wheelEnd = null;
        final point = _scrollPoint;
        if (point != null) _scroll(point, Offset.zero, phase: pb.ScrollPhase.SCROLL_PHASE_ENDED);
        _scrollPoint = null;
      });
    });
  }

  void _onPanZoomStart(PointerPanZoomStartEvent event) {
    _stamp(event.timeStamp);
    widget.onInteraction();
    _stopMomentum();
    _scrollPoint = _clamped(event.localPosition);
    _scrollBegan = false;
    _panLast = Offset.zero;
    _panScale = 1;
    _panZoomed = false;
    _panSamples
      ..clear()
      ..add((event.timeStamp, Offset.zero));
  }

  void _onPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    _stamp(event.timeStamp);
    if (event.scale != _panScale && (event.scale - 1).abs() > 0.02) {
      // A pinch on the trackpad zooms here, as a pinch on the glass does.
      _settle.stop();
      _viewport = _viewport.zoomed(event.scale / _panScale, around: event.localPosition, content: widget.videoSize, bounds: _bounds);
      _panScale = event.scale;
      _panZoomed = true;
      _showResisted();
      return;
    }
    final point = _scrollPoint;
    final delta = event.pan - _panLast;
    _panLast = event.pan;
    _panSamples
      ..add((event.timeStamp, event.pan))
      ..removeWhere((s) => event.timeStamp - s.$1 > const Duration(milliseconds: 100));
    if (point == null || delta == Offset.zero) return;
    _scroll(point, delta, phase: _scrollBegan ? pb.ScrollPhase.SCROLL_PHASE_CHANGED : pb.ScrollPhase.SCROLL_PHASE_BEGAN);
    _scrollBegan = true;
  }

  void _onPanZoomEnd(PointerPanZoomEndEvent event) {
    _stamp(event.timeStamp);
    if (_panZoomed) _settleZoom();
    final point = _scrollPoint;
    if (point == null || !_scrollBegan) {
      _scrollPoint = null;
      return;
    }
    _scroll(point, Offset.zero, phase: pb.ScrollPhase.SCROLL_PHASE_ENDED);
    final velocity = _panVelocity(event.timeStamp);
    if (velocity.distance >= 250) {
      _startMomentum(velocity);
    } else {
      _scrollPoint = null;
    }
  }

  Offset _panVelocity(Duration now) {
    if (_panSamples.length < 2) return Offset.zero;
    final (firstTime, first) = _panSamples.first;
    final (lastTime, last) = _panSamples.last;
    if (now - lastTime > const Duration(milliseconds: 60)) return Offset.zero;
    final seconds = (lastTime - firstTime).inMicroseconds / 1e6;
    return seconds <= 0 ? Offset.zero : (last - first) / seconds;
  }

  // MARK: Hardware keyboard

  /// Sends key presses to the Mac. Ignores them when there is nothing to send them to, so the system can
  /// use them.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final gen = widget.gen;
    if (gen == null) return KeyEventResult.ignored;
    // The Mac repeats a held key itself.
    if (event is KeyRepeatEvent) return KeyEventResult.handled;
    final usage = _usage(event);
    if (usage == null) return KeyEventResult.ignored;
    // Caps Lock itself stays here; its effect travels as Shift on letters.
    if (usage == Usage.capsLock) return KeyEventResult.handled;
    final keyboard = HardwareKeyboard.instance;
    var modifiers = (keyboard.isShiftPressed ? Modifier.shift : 0) |
        (keyboard.isControlPressed ? Modifier.control : 0) |
        (keyboard.isAltPressed ? Modifier.option : 0) |
        (keyboard.isMetaPressed ? Modifier.command : 0);
    if (keyboard.lockModesEnabled.contains(KeyboardLockMode.capsLock) && isLetterUsage(usage)) modifiers |= Modifier.shift;
    widget.send(pb.ClientMessage(key: pb.KeyEvent(gen: gen, usage: usage, isDown: event is KeyDownEvent, modifiers: modifiers)));
    return KeyEventResult.handled;
  }

  /// The key's place on the keyboard page. On-screen keyboards on Android send Delete and Return as key
  /// events with no physical key, so those go by meaning.
  static int? _usage(KeyEvent event) {
    final hid = event.physicalKey.usbHidUsage;
    if (hid >> 16 == 0x07 && hid & 0xFFFF != 0) return hid & 0xFFFF;
    return _byMeaning[event.logicalKey];
  }

  static final _byMeaning = {
    LogicalKeyboardKey.backspace: Usage.deleteBackward,
    LogicalKeyboardKey.enter: Usage.returnKey,
    LogicalKeyboardKey.tab: Usage.tab,
    LogicalKeyboardKey.escape: Usage.escape,
    LogicalKeyboardKey.arrowLeft: Usage.leftArrow,
    LogicalKeyboardKey.arrowRight: Usage.rightArrow,
    LogicalKeyboardKey.arrowUp: Usage.upArrow,
    LogicalKeyboardKey.arrowDown: Usage.downArrow,
  };

  // MARK: On-screen keyboard

  void _showKeyboard(bool visible) {
    if (visible) {
      _resetText();
      _textFocus.requestFocus();
    } else if (_textFocus.hasFocus) {
      _textFocus.unfocus();
      _surfaceFocus.requestFocus();
    }
  }

  void _onTextFocus() {
    if (_textFocus.hasFocus) return;
    setState(() => _sticky = 0);
    // Take hardware keys again once the on-screen keyboard is gone.
    if (mounted) _surfaceFocus.requestFocus();
    if (widget.showsKeyboard) widget.onKeyboardHidden();
  }

  void _resetText() {
    _text.value = const TextEditingValue(
      text: keyboardSentinel,
      selection: TextSelection.collapsed(offset: keyboardSentinel.length),
    );
  }

  void _onTextChanged() {
    final value = _text.value;
    if (value.text == keyboardSentinel) return;
    // Wait for words still being composed (marked text) to be committed.
    if (value.composing.isValid && !value.composing.isCollapsed) return;
    final edit = keyboardEdit(keyboardSentinel, value.text);
    _resetText();
    for (var i = 0; i < edit.deletes; i++) {
      _pressKey(Usage.deleteBackward, _takeSticky());
    }
    final typed = typedText(edit.typed);
    if (typed.isNotEmpty) _type(typed);
  }

  int _takeSticky() {
    final sticky = _sticky;
    if (sticky != 0) setState(() => _sticky = 0);
    return sticky;
  }

  void _pressKey(int usage, int modifiers) {
    final gen = widget.gen;
    if (gen == null) return;
    widget.send(pb.ClientMessage(key: pb.KeyEvent(gen: gen, usage: usage, isDown: true, modifiers: modifiers)));
    widget.send(pb.ClientMessage(key: pb.KeyEvent(gen: gen, usage: usage, isDown: false, modifiers: modifiers)));
  }

  void _type(String text) {
    final gen = widget.gen;
    if (gen == null) return;
    final shortcut = shortcutFor(text, _takeSticky());
    if (shortcut == null) {
      widget.send(pb.ClientMessage(text: pb.TextEvent(gen: gen, text: text)));
    } else {
      _pressKey(shortcut.usage, shortcut.modifiers);
    }
  }

  // MARK: Build

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardUp = widget.showsKeyboard && _textFocus.hasFocus;
    final barHeight = keyboardUp ? KeyBar.height : 0.0;
    return Focus(
      focusNode: _surfaceFocus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Stack(children: [
        const Positioned.fill(child: ColoredBox(color: Color(0xFF000000))),
        // Fill the screen, but move up for the on-screen keyboard instead of hiding the window under it.
        Positioned.fill(
          bottom: inset + barHeight,
          child: LayoutBuilder(builder: (context, constraints) {
            _layout(constraints.biggest);
            final frame = widget.videoSize.isEmpty ? Offset.zero & _bounds : _videoFrame;
            return Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _onDown,
              onPointerMove: _onMove,
              onPointerUp: _onUp,
              onPointerCancel: _onCancel,
              onPointerHover: _onHover,
              onPointerSignal: _onSignal,
              onPointerPanZoomStart: _onPanZoomStart,
              onPointerPanZoomUpdate: _onPanZoomUpdate,
              onPointerPanZoomEnd: _onPanZoomEnd,
              child: ClipRect(
                child: Stack(children: [
                  if (_rendererReady)
                    Positioned.fromRect(
                      rect: frame,
                      child: RTCVideoView(
                        _renderer,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: TouchFeedbackPainter(_feedback)))),
                ]),
              ),
            );
          }),
        ),
        // The field behind the on-screen keyboard: out of sight, but focused while the keyboard is up.
        Positioned(
          left: 0,
          bottom: 0,
          width: 1,
          height: 1,
          child: Opacity(
            opacity: 0,
            child: Focus(
              onKeyEvent: _onKey,
              child: TextField(
                controller: _text,
                focusNode: _textFocus,
                autocorrect: false,
                enableSuggestions: false,
                enableIMEPersonalizedLearning: false,
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
                textCapitalization: TextCapitalization.none,
                keyboardType: Platform.isAndroid ? TextInputType.visiblePassword : TextInputType.multiline,
                keyboardAppearance: Brightness.dark,
                textInputAction: TextInputAction.newline,
                maxLines: null,
                showCursor: false,
                enableInteractiveSelection: false,
                style: const TextStyle(fontSize: 1, color: Color(0x00000000)),
                decoration: const InputDecoration.collapsed(hintText: null),
              ),
            ),
          ),
        ),
        if (keyboardUp)
          Positioned(
            left: 0,
            right: 0,
            bottom: inset,
            child: KeyBar(
              sticky: _sticky,
              onKey: (usage) => _pressKey(usage, _takeSticky()),
              onToggle: (modifier) => setState(() => _sticky ^= modifier),
              onHide: () => widget.onKeyboardHidden(),
            ),
          ),
      ]),
    );
  }
}
