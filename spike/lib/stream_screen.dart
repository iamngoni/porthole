import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'spike_link.dart';
import 'touch_interpreter.dart';

enum VideoRenderer { texture, platformView }

/// The stream, edge to edge, with touch, pinch zoom, keys and a stats panel.
class StreamScreen extends StatefulWidget {
  const StreamScreen({super.key, required this.link});
  final SpikeLink link;

  @override
  State<StreamScreen> createState() => _StreamScreenState();
}

class _StreamScreenState extends State<StreamScreen> with SingleTickerProviderStateMixin {
  final _texture = RTCVideoRenderer();
  RTCVideoPlatformViewController? _platformController;
  VideoRenderer _renderer = VideoRenderer.texture;
  final _interpreter = TouchInterpreter();
  final _clock = Stopwatch()..start();
  Duration _clockBase = Duration.zero;
  Timer? _holdTimer;
  double _scale = 1;
  Offset _offset = Offset.zero;
  Size _viewSize = Size.zero;
  Offset _flingVelocity = Offset.zero;
  late final Ticker _flingTicker = createTicker(_flingStep);
  Duration _lastFlingTick = Duration.zero;
  bool _showStats = true;
  bool _keyboard = false;
  final _keyFocus = FocusNode();
  final _textFocus = FocusNode();
  final _text = TextEditingController(text: _sentinel);
  final _marks = <(Offset, Color, DateTime)>[];
  int _patternFps = 60;
  int _framesThisSecond = 0;
  Timer? _flutterFpsTimer;

  /// The soft keyboard's field always holds this, so backspace has something to delete.
  static const _sentinel = '​';

  SpikeLink get link => widget.link;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _texture.initialize().then((_) => setState(() {}));
    link.addListener(_onLink);
    link.renderer = _renderer.name;
    link.connect();
    SchedulerBinding.instance.addTimingsCallback(_countFrames);
    _flutterFpsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      link.flutterFps = _framesThisSecond.toDouble();
      _framesThisSecond = 0;
    });
  }

  void _countFrames(List<FrameTiming> timings) => _framesThisSecond += timings.length;

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    link.removeListener(_onLink);
    link.close();
    SchedulerBinding.instance.removeTimingsCallback(_countFrames);
    _flutterFpsTimer?.cancel();
    _texture.dispose();
    _flingTicker.dispose();
    _holdTimer?.cancel();
    _keyFocus.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  void _onLink() {
    final stream = link.stream;
    if (stream != null && _texture.srcObject != stream) _texture.srcObject = stream;
    if (stream != null && _platformController != null && _platformController!.srcObject != stream) {
      _platformController!.srcObject = stream;
    }
    setState(() {});
  }

  // MARK: Geometry

  Size get _videoSize {
    final stats = link.stats;
    if (stats.width > 0 && stats.height > 0) return Size(stats.width.toDouble(), stats.height.toDouble());
    if (_texture.videoWidth > 0) return Size(_texture.videoWidth.toDouble(), _texture.videoHeight.toDouble());
    return const Size(16, 10);
  }

  /// Where the video sits in the view before zooming (fitted, centered).
  Rect get _contentRect {
    final video = _videoSize;
    final fit = math.min(_viewSize.width / video.width, _viewSize.height / video.height);
    final size = Size(video.width * fit, video.height * fit);
    return Offset((_viewSize.width - size.width) / 2, (_viewSize.height - size.height) / 2) & size;
  }

  /// A point on screen as a fraction of the video (0…1 on each axis), or null outside it.
  Offset? _normalized(Offset screen) {
    final unzoomed = (screen - _offset) / _scale;
    final rect = _contentRect;
    final x = (unzoomed.dx - rect.left) / rect.width;
    final y = (unzoomed.dy - rect.top) / rect.height;
    return (x < 0 || x > 1 || y < 0 || y > 1) ? null : Offset(x, y);
  }

  /// Screen points to video pixels at the current zoom.
  double get _videoPixelsPerPoint => _videoSize.height / _contentRect.height / _scale;

  // MARK: Input

  Duration _now() => _clockBase + _clock.elapsed;

  void _pointerDown(PointerDownEvent event) {
    _flingTicker.stop();
    _clockBase = event.timeStamp - _clock.elapsed;
    if (event.kind == PointerDeviceKind.mouse) {
      final at = _normalized(event.localPosition);
      if (at != null) {
        _sendTap(event.localPosition, secondary: event.buttons & kSecondaryMouseButton != 0);
      }
      return;
    }
    _apply(_interpreter.down(event.pointer, event.localPosition, event.timeStamp));
    _holdTimer ??= Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (_interpreter.isIdle) {
        _holdTimer?.cancel();
        _holdTimer = null;
      } else {
        _apply(_interpreter.tick(_now()));
      }
    });
  }

  void _pointerMove(PointerMoveEvent event) {
    if (event.kind == PointerDeviceKind.mouse) return;
    _apply(_interpreter.move(event.pointer, event.localPosition, event.timeStamp));
  }

  void _pointerUp(PointerUpEvent event) {
    if (event.kind == PointerDeviceKind.mouse) return;
    _apply(_interpreter.up(event.pointer, event.localPosition, event.timeStamp));
  }

  void _pointerCancel(PointerCancelEvent event) => _apply(_interpreter.cancel(event.pointer));

  void _pointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) _scrollBy(-event.scrollDelta);
  }

  void _apply(List<TouchAction> actions) {
    for (final action in actions) {
      switch (action) {
        case Tap(:final at):
          _sendTap(at, secondary: false);
        case SecondaryTap(:final at):
          _sendTap(at, secondary: true);
        case HoldBegan(:final at):
          _mark(at, Colors.orangeAccent);
          HapticFeedback.mediumImpact();
        case ScrollBy(:final delta):
          _scrollBy(delta);
        case Fling(:final velocity):
          _flingVelocity = velocity;
          _lastFlingTick = Duration.zero;
          _flingTicker.start();
        case DragStart(:final at) || DragMove(:final at) || DragEnd(:final at):
          final normalized = _normalized(at);
          if (normalized != null) link.control({'t': 'tap', 'x': normalized.dx, 'y': normalized.dy, 'kind': 'drag'});
        case Zoom(:final scale, :final focal, :final pan):
          _zoom(scale, focal, pan);
        case ZoomEnd():
          _settleZoom();
      }
    }
  }

  void _sendTap(Offset at, {required bool secondary}) {
    final normalized = _normalized(at);
    if (normalized == null) return;
    _mark(at, secondary ? Colors.orangeAccent : Colors.white);
    link.control({'t': 'tap', 'x': normalized.dx, 'y': normalized.dy, 'kind': secondary ? 'secondary' : 'tap'});
  }

  void _scrollBy(Offset delta) {
    // Finger up means the content moves up, which is further down the document.
    link.control({'t': 'scroll', 'dy': -delta.dy * _videoPixelsPerPoint});
  }

  void _flingStep(Duration elapsed) {
    final dt = (elapsed - _lastFlingTick).inMicroseconds / 1e6;
    _lastFlingTick = elapsed;
    if (dt <= 0) return;
    // iOS's normal deceleration: speed falls to 0.998 of itself every millisecond.
    _flingVelocity *= math.pow(0.998, dt * 1000).toDouble();
    if (_flingVelocity.distance < 20) return _flingTicker.stop();
    _scrollBy(_flingVelocity * dt);
  }

  void _zoom(double scale, Offset focal, Offset pan) {
    final previousFocal = focal - pan;
    final content = (previousFocal - _offset) / _scale;
    final newScale = (_scale * scale).clamp(0.6, 6.5);
    setState(() {
      _scale = newScale;
      _offset = focal - content * newScale;
    });
  }

  void _settleZoom() {
    setState(() {
      _scale = _scale.clamp(1.0, 5.0);
      double clampAxis(double value, double view) => value.clamp(view * (1 - _scale), 0.0);
      _offset = Offset(clampAxis(_offset.dx, _viewSize.width), clampAxis(_offset.dy, _viewSize.height));
    });
  }

  void _mark(Offset at, Color color) {
    setState(() => _marks.add((at, color, DateTime.now())));
    Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() => _marks.removeWhere((mark) => DateTime.now().difference(mark.$3) >= const Duration(milliseconds: 550)));
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    // The Mac repeats held keys itself.
    if (event is KeyRepeatEvent) return KeyEventResult.handled;
    final usage = event.physicalKey.usbHidUsage;
    if (usage >> 16 != 0x07) return KeyEventResult.ignored;
    link.control({'t': 'key', 'usage': usage & 0xFFFF, 'down': event is KeyDownEvent});
    return KeyEventResult.handled;
  }

  void _onSoftText(String value) {
    if (value.length < _sentinel.length) {
      link.control({'t': 'key', 'usage': 0x2A, 'down': true});
      link.control({'t': 'key', 'usage': 0x2A, 'down': false});
    } else if (value.length > _sentinel.length) {
      link.control({'t': 'text', 's': value.replaceAll(_sentinel, '')});
    }
    _text.value = const TextEditingValue(text: _sentinel, selection: TextSelection.collapsed(offset: 1));
  }

  // MARK: Building

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _keyFocus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: LayoutBuilder(builder: (context, constraints) {
          _viewSize = constraints.biggest;
          return Stack(children: [
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _pointerDown,
                onPointerMove: _pointerMove,
                onPointerUp: _pointerUp,
                onPointerCancel: _pointerCancel,
                onPointerSignal: _pointerSignal,
                child: ClipRect(
                  child: Transform(
                    transform: Matrix4.identity()
                      ..translateByDouble(_offset.dx, _offset.dy, 0, 1)
                      ..scaleByDouble(_scale, _scale, 1, 1),
                    child: IgnorePointer(child: _video()),
                  ),
                ),
              ),
            ),
            for (final (at, color, _) in _marks)
              Positioned(
                left: at.dx - 22,
                top: at.dy - 22,
                child: IgnorePointer(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 2.5)),
                  ),
                ),
              ),
            if (link.stream == null) Center(child: Text(link.status, style: const TextStyle(fontSize: 18))),
            Positioned(top: MediaQuery.paddingOf(context).top + 8, left: 8, right: 8, child: _toolbar()),
            if (_keyboard)
              Positioned(
                left: 0,
                bottom: 0,
                width: 1,
                height: 1,
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    focusNode: _textFocus,
                    controller: _text,
                    autocorrect: false,
                    enableSuggestions: false,
                    onChanged: _onSoftText,
                  ),
                ),
              ),
          ]);
        }),
      ),
    );
  }

  Widget _video() {
    if (_renderer == VideoRenderer.platformView && Platform.isIOS) {
      return RTCVideoPlatFormView(
        key: const ValueKey('platform'),
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
        onViewReady: (controller) {
          _platformController = controller;
          controller.srcObject = link.stream;
        },
      );
    }
    return RTCVideoView(
      _texture,
      key: const ValueKey('texture'),
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
      filterQuality: FilterQuality.medium,
    );
  }

  Widget _toolbar() {
    final stats = link.stats;
    final panel = DefaultTextStyle(
      style: const TextStyle(fontSize: 12, fontFamily: 'Menlo', color: Colors.white, height: 1.35),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${link.status} · ${_renderer.name}'),
        Text('${stats.width}×${stats.height}  ${stats.fps.toStringAsFixed(0)} fps  ${stats.bitrateMbps.toStringAsFixed(1)} Mb/s'),
        Text('screen ${link.refreshRate} Hz  Flutter drew ${link.flutterFps.toStringAsFixed(0)} frames/s'),
        Text('decode ${stats.decodeMs.toStringAsFixed(1)} ms  buffer ${stats.jitterBufferMs.toStringAsFixed(0)} ms'),
        Text('decoded ${stats.framesDecoded}  dropped ${stats.framesDropped}  freezes ${stats.freezes}'),
        Text('input round trip ${stats.inputRoundTripMs?.toStringAsFixed(0) ?? '–'} ms  zoom ${_scale.toStringAsFixed(2)}×'),
        Text(stats.decoder),
        Text(stats.codec, maxLines: 2, overflow: TextOverflow.ellipsis),
      ]),
    );
    Widget chip(String label, VoidCallback onTap, {bool on = false}) => Padding(
          padding: const EdgeInsets.only(right: 6, bottom: 6),
          child: ActionChip(
            label: Text(label, style: TextStyle(color: on ? Colors.black : Colors.white, fontSize: 12)),
            backgroundColor: on ? Colors.white : Colors.white.withValues(alpha: 0.12),
            side: BorderSide.none,
            onPressed: onTap,
          ),
        );
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.62), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Wrap(children: [
              chip('Close', () => Navigator.of(context).pop()),
              chip(_showStats ? 'Hide stats' : 'Stats', () => setState(() => _showStats = !_showStats)),
              if (Platform.isIOS)
                chip(_renderer == VideoRenderer.texture ? 'Texture' : 'Native view', () {
                  setState(() {
                    _renderer = _renderer == VideoRenderer.texture ? VideoRenderer.platformView : VideoRenderer.texture;
                    _platformController = null;
                    link.renderer = _renderer.name;
                  });
                }, on: _renderer == VideoRenderer.platformView),
              chip('Keyboard', () {
                setState(() => _keyboard = !_keyboard);
                if (_keyboard) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => _textFocus.requestFocus());
                } else {
                  _keyFocus.requestFocus();
                }
              }, on: _keyboard),
              chip('Fit', () => setState(() {
                    _scale = 1;
                    _offset = Offset.zero;
                  })),
              for (final (w, h) in const [(1280, 800), (1920, 1200), (2560, 1600), (3840, 2400)])
                chip('${w}p', () => link.control({'t': 'pattern', 'w': w, 'h': h}), on: link.stats.width == w),
              for (final fps in const [30, 60, 100, 120])
                chip('$fps fps', () {
                  setState(() => _patternFps = fps);
                  link.control({'t': 'pattern', 'fps': fps});
                }, on: _patternFps == fps),
            ]),
            if (_showStats) panel,
          ]),
        ),
      ),
    );
  }
}
