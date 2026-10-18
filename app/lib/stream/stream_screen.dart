import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../client/client_scope.dart';
import '../client/picker_logic.dart';
import '../design/backdrop.dart';
import '../design/buttons.dart';
import '../design/glass.dart';
import '../design/mark.dart';
import '../design/theme.dart';
import '../screens/window_picker.dart';
import 'stream_surface.dart';

/// The streamed window, edge to edge, with a small floating bar that tucks itself away.
class StreamScreen extends StatefulWidget {
  const StreamScreen({super.key});

  @override
  State<StreamScreen> createState() => _StreamScreenState();
}

class _StreamScreenState extends State<StreamScreen> {
  var _showsKeyboard = false;
  var _barOpen = true;
  var _showsSwitcher = false;
  var _zoom = 1.0;
  var _zoomResetToken = 0;
  Timer? _tuck;
  int? _lastGen;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _scheduleTuck();
  }

  @override
  void dispose() {
    _tuck?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  /// Using the window tucks the bar away so it doesn't cover anything.
  void _tuckBar() {
    _tuck?.cancel();
    if (_barOpen && !_showsKeyboard) setState(() => _barOpen = false);
  }

  void _scheduleTuck() {
    _tuck?.cancel();
    _tuck = Timer(const Duration(seconds: 4), () {
      if (mounted && !_showsSwitcher) setState(() => _barOpen = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final client = ClientScope.of(context);
    final stream = client.stream;
    if (stream?.gen != _lastGen) {
      _lastGen = stream?.gen;
      _scheduleTuck();
    }
    final window = client.streamedWindow;
    final title = stream != null
        ? (stream.title.isEmpty ? stream.appName : stream.title)
        : client.pendingLaunch?.name ?? (window == null ? '' : windowTitle(window));
    final icon = client.icon(window != null && window.hasBundleId() ? window.bundleId : client.pendingLaunch?.bundleId);
    final control = client.control;

    return Stack(children: [
      const Positioned.fill(child: ColoredBox(color: Color(0xFF000000))),
      Positioned.fill(
        child: AnimatedOpacity(
          opacity: stream == null ? 0 : 1,
          duration: const Duration(milliseconds: 400),
          child: StreamSurface(
            stream: client.videoStream,
            gen: stream?.gen,
            videoSize: stream == null
                ? Size.zero
                : Size(stream.pixelSize.width.toDouble(), stream.pixelSize.height.toDouble()),
            canControl: client.canControl,
            showsKeyboard: _showsKeyboard,
            onKeyboardHidden: () {
              if (_showsKeyboard) setState(() => _showsKeyboard = false);
            },
            zoomResetToken: _zoomResetToken,
            onZoomChange: (scale) => setState(() => _zoom = scale),
            onInteraction: _tuckBar,
            send: client.sendInput,
          ),
        ),
      ),
      if (stream == null)
        Positioned.fill(
          child: _OpeningView(title: title, thumbnail: window == null ? null : client.thumbnails[window.id], icon: icon),
        ),
      SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 10, left: 12, right: 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 380),
                switchInCurve: Curves.easeOutBack,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, -0.4), end: Offset.zero).animate(animation),
                    child: child,
                  ),
                ),
                child: _barOpen
                    ? _ControlBar(
                        key: const ValueKey('bar'),
                        title: title,
                        appName: window?.appName,
                        icon: icon,
                        showsKeyboard: _showsKeyboard,
                        canType: client.canControl && stream != null,
                        zoom: _zoom,
                        onWindows: client.stopStream,
                        onKeyboard: () {
                          setState(() => _showsKeyboard = !_showsKeyboard);
                          _scheduleTuck();
                        },
                        onSwitcher: () {
                          setState(() => _showsSwitcher = true);
                          _scheduleTuck();
                        },
                        onFit: () {
                          setState(() => _zoomResetToken++);
                          _scheduleTuck();
                        },
                        onDisconnect: client.disconnect,
                        onHide: () => setState(() => _barOpen = false),
                      )
                    : _Handle(
                        key: const ValueKey('handle'),
                        icon: icon,
                        onTap: () {
                          setState(() => _barOpen = true);
                          _scheduleTuck();
                        },
                      ),
              ),
              if (control != null && !control.allowed && control.hasReason()) ...[
                const SizedBox(height: 10),
                _Notice(icon: Icons.visibility_outlined, text: control.reason, color: Palette.warning),
              ],
              if (stream != null && client.pendingWindowId != null) ...[
                const SizedBox(height: 10),
                const _Notice(text: 'Switching…', busy: true),
              ],
            ]),
          ),
        ),
      ),
      if (_showsSwitcher)
        Positioned.fill(
          child: _WindowSwitcher(onClose: () => setState(() => _showsSwitcher = false)),
        ),
    ]);
  }
}

/// The floating bar: back to all windows, what's showing, keyboard, switch, zoom, disconnect and hide.
class _ControlBar extends StatelessWidget {
  const _ControlBar({
    super.key,
    required this.title,
    required this.appName,
    required this.icon,
    required this.showsKeyboard,
    required this.canType,
    required this.zoom,
    required this.onWindows,
    required this.onKeyboard,
    required this.onSwitcher,
    required this.onFit,
    required this.onDisconnect,
    required this.onHide,
  });

  final String title;
  final String? appName;
  final ImageProvider? icon;
  final bool showsKeyboard;
  final bool canType;
  final double zoom;
  final VoidCallback onWindows;
  final VoidCallback onKeyboard;
  final VoidCallback onSwitcher;
  final VoidCallback onFit;
  final VoidCallback onDisconnect;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final divider = Container(width: 1, height: 26, color: Palette.white(0.12), margin: const EdgeInsets.symmetric(horizontal: 4));
    final width = MediaQuery.sizeOf(context).width;
    // On a phone the title gives way to the buttons; the app's icon still says what's showing.
    final showsTitle = width >= 520;
    return _GlassCapsule(
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        CircleButton(Icons.grid_view_rounded, size: 42, label: 'All Windows', onPressed: onWindows),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Semantics(label: title, child: AppIconView(image: icon, size: 28)),
            if (showsTitle) ...[
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: width < 760 ? 150 : 260),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(title, style: display(15, FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (appName != null && appName != title)
                    Text(appName!, style: body(12, FontWeight.w500, Palette.textTertiary), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
            ],
          ]),
        ),
        divider,
        const SizedBox(width: 4),
        CircleButton(
          showsKeyboard ? Icons.keyboard_hide_rounded : Icons.keyboard_rounded,
          size: 42,
          isOn: showsKeyboard,
          label: showsKeyboard ? 'Hide Keyboard' : 'Show Keyboard',
          onPressed: canType ? onKeyboard : null,
        ),
        const SizedBox(width: 8),
        CircleButton(Icons.filter_none_rounded, size: 42, label: 'Switch Window', onPressed: onSwitcher),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          child: zoom > 1.01
              ? Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Pressable(
                    onTap: onFit,
                    label: 'Zoom to Fit',
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: Palette.white(0.1), borderRadius: BorderRadius.circular(21)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.zoom_in_map_rounded, size: 16, color: Palette.textPrimary),
                        const SizedBox(width: 5),
                        Text('${zoom.toStringAsFixed(1)}×',
                            style: display(14, FontWeight.w700).copyWith(fontFeatures: const [ui.FontFeature.tabularFigures()])),
                      ]),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(width: 4),
        divider,
        const SizedBox(width: 4),
        CircleButton(Icons.power_settings_new_rounded, size: 42, label: 'Disconnect', onPressed: onDisconnect),
        const SizedBox(width: 8),
        CircleButton(Icons.keyboard_arrow_up_rounded, size: 36, label: 'Hide Controls', onPressed: onHide),
      ]),
    );
  }
}

class _GlassCapsule extends StatelessWidget {
  const _GlassCapsule({required this.child, this.padding = const EdgeInsets.all(6), this.shadow = 22});
  final Widget child;
  final EdgeInsets padding;
  final double shadow;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          boxShadow: [BoxShadow(color: Palette.black(0.5), blurRadius: shadow, offset: Offset(0, shadow * 0.45))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                color: Palette.canvas.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: Palette.white(0.16)),
              ),
              child: child,
            ),
          ),
        ),
      );
}

/// The bar tucked away: a small pill with the app's icon, to bring it back.
class _Handle extends StatelessWidget {
  const _Handle({super.key, required this.icon, required this.onTap});
  final ImageProvider? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        label: 'Show Controls',
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: _GlassCapsule(
            shadow: 10,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              AppIconView(image: icon, size: 18),
              const SizedBox(width: 7),
              Container(
                width: 26,
                height: 4,
                decoration: BoxDecoration(color: Palette.white(0.75), borderRadius: BorderRadius.circular(2)),
              ),
            ]),
          ),
        ),
      );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.icon, this.color = Palette.textPrimary, this.busy = false});
  final String text;
  final IconData? icon;
  final Color color;
  final bool busy;

  @override
  Widget build(BuildContext context) => Glass(
        radius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (busy)
            const SizedBox.square(dimension: 16, child: CircularProgressIndicator(color: Color(0xFFFFFFFF), strokeWidth: 2))
          else if (icon != null)
            Icon(icon, size: 17, color: color),
          const SizedBox(width: 10),
          Flexible(child: Text(text, style: display(14, FontWeight.w600, color))),
        ]),
      );
}

/// While the first frame is on its way: the window's last still, softly blurred, with the mark turning.
class _OpeningView extends StatelessWidget {
  const _OpeningView({required this.title, required this.thumbnail, required this.icon});
  final String title;
  final ImageProvider? thumbnail;
  final ImageProvider? icon;

  @override
  Widget build(BuildContext context) => Stack(children: [
        const Positioned.fill(child: Backdrop(intensity: 0.6)),
        if (thumbnail != null)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(60),
              child: Opacity(
                opacity: 0.35,
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Image(image: thumbnail!, fit: BoxFit.contain, gaplessPlayback: true),
                ),
              ),
            ),
          ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(Metrics.gutter),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(
                height: 200,
                child: Stack(alignment: Alignment.center, children: [
                  OverflowBox(maxWidth: 240, maxHeight: 240, child: RadarRings(size: 240)),
                  PortholeMark(size: 84, isActive: true),
                ]),
              ),
              const SizedBox(height: 22),
              Glass(
                radius: 22,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  AppIconView(image: icon, size: 34),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text('Opening ${title.isEmpty ? 'window' : title}',
                        style: display(22), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ]);
}

/// Every window on the Mac, over the stream, to jump to another one.
class _WindowSwitcher extends StatefulWidget {
  const _WindowSwitcher({required this.onClose});
  final VoidCallback onClose;

  @override
  State<_WindowSwitcher> createState() => _WindowSwitcherState();
}

class _WindowSwitcherState extends State<_WindowSwitcher> {
  String? _app;
  var _mode = PickerMode.windows;

  @override
  Widget build(BuildContext context) {
    final client = ClientScope.of(context);
    final windows = _mode == PickerMode.windows;
    final narrow = MediaQuery.sizeOf(context).width < 700;
    final heading = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(windows ? 'Switch window' : 'Open an app', style: display(24, FontWeight.w800)),
      const SizedBox(height: 3),
      Text(windows ? 'Pick any window on your Mac' : 'It opens on your Mac and shows up here',
          style: body(14, FontWeight.w500, Palette.textSecondary)),
    ]);
    final tools = Row(mainAxisSize: MainAxisSize.min, children: [
      ModeToggle(mode: _mode, onChanged: (mode) => setState(() => _mode = mode)),
      const SizedBox(width: 10),
      if (!narrow) ...[
        SecondaryButton('All Windows', icon: Icons.grid_view_rounded, onPressed: () {
          widget.onClose();
          client.stopStream();
        }),
        const SizedBox(width: 10),
      ],
      CircleButton(Icons.close_rounded, label: 'Close', onPressed: widget.onClose),
    ]);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(opacity: t, child: Transform.scale(scale: 0.97 + 0.03 * t, child: child)),
      child: Stack(children: [
        Positioned.fill(child: GestureDetector(onTap: widget.onClose, child: ColoredBox(color: Palette.black(0.55)))),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980, maxHeight: 720),
                child: Glass(
                  radius: 34,
                  highlight: true,
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
                      child: narrow
                          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [heading, const SizedBox(height: 12), tools])
                          : Row(children: [Expanded(child: heading), tools]),
                    ),
                    Expanded(
                      child: windows
                          ? WindowGrid(
                              query: '',
                              app: _app,
                              compact: true,
                              onApp: (app) => setState(() => _app = app),
                              onSelect: (window) {
                                widget.onClose();
                                if (window.id != client.stream?.windowId) client.select(window);
                              },
                            )
                          : AppGrid(
                              query: '',
                              compact: true,
                              onLaunch: (app) {
                                widget.onClose();
                                client.launch(app);
                              },
                            ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
