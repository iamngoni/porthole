import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' show MediaStream;
import 'package:porthole_protocol/porthole_protocol.dart';

import '../input/display_name.dart';
import 'host_browser.dart';
import 'image_size.dart';
import 'pairing_store.dart';
import 'peer_session.dart';
import 'signaling.dart';
import 'system.dart';

sealed class Phase {
  const Phase();
}

final class Browsing extends Phase {
  const Browsing();
  @override
  bool operator ==(Object other) => other is Browsing;
  @override
  int get hashCode => 0;
}

final class Connecting extends Phase {
  const Connecting(this.hostName);
  final String hostName;
  @override
  bool operator ==(Object other) => other is Connecting && other.hostName == hostName;
  @override
  int get hashCode => hostName.hashCode;
}

/// Both screens show a code; the person checks they match.
final class ComparingCode extends Phase {
  const ComparingCode(this.hostName, this.code);
  final String hostName;
  final String code;
  @override
  bool operator ==(Object other) => other is ComparingCode && other.hostName == hostName && other.code == code;
  @override
  int get hashCode => Object.hash(hostName, code);
}

/// The codes matched here; waiting for Allow on the Mac.
final class WaitingForMac extends Phase {
  const WaitingForMac(this.hostName);
  final String hostName;
  @override
  bool operator ==(Object other) => other is WaitingForMac && other.hostName == hostName;
  @override
  int get hashCode => hostName.hashCode;
}

final class Connected extends Phase {
  const Connected(this.hostName);
  final String hostName;
  @override
  bool operator ==(Object other) => other is Connected && other.hostName == hostName;
  @override
  int get hashCode => hostName.hashCode;
}

enum ProblemAction { tryAgain, pairAgain }

/// Something to tell the user, maybe with a way forward.
final class Problem {
  Problem(this.text, {this.action, this.host}) : id = _next++;
  static var _next = 0;

  final int id;
  final String text;
  final ProblemAction? action;
  final DiscoveredHost? host;

  @override
  String toString() => 'Problem($text, $action)';
}

/// The screen the hello describes: its size in physical pixels and how often it refreshes.
typedef ScreenInfo = ({int width, int height, int refreshRate});

/// One attempt at a Mac, from connecting to the end. Work that finishes after the next attempt began
/// checks it is still current and drops itself.
final class _Session {
  _Session(this.host, this.link, this.pairing, this.name);
  final DiscoveredHost host;
  final DeviceLink link;

  /// The pairing in use: the saved one, or the one just made.
  PairedHost? pairing;

  /// What to call the Mac. Once paired, the name it gave while pairing or in its welcome, both
  /// authenticated, rather than the Bonjour name, which anyone can advertise.
  String name;
  Signaling? signaling;
  PeerLink? peer;

  /// Connection events run one after another, so a bye is read before the close that follows it.
  Future<void> events = Future.value();
}

/// Runs the iPad, iPhone or Android side: finds Macs, pairs with them, connects to one, and shows and
/// controls the window the user picks (ClientController.swift).
final class ClientController extends ChangeNotifier {
  ClientController({
    required this.deviceId,
    required this.deviceName,
    required this._store,
    this._browser,
    this._connect = connectToHost,
    PeerLink Function()? makePeer,
    ScreenInfo Function()? screen,
    this._keepAwake = System.keepAwake,
  })  : _makePeer = makePeer ?? PeerSession.new,
        _screen = screen ?? (() => (width: 2752, height: 2064, refreshRate: 60)) {
    _browser?.addListener(notifyListeners);
    _browser?.start();
    reloadPairedHosts();
  }

  /// Thumbnails are this many pixels on the long side: sharp on a card two-fifths of an iPad wide.
  static const thumbnailLongSide = 720;

  /// The Mac answers icon requests in batches of at most this many.
  static const iconBatch = 40;

  /// The most of each list kept from the Mac, and the largest images decoded: far beyond anything a Mac
  /// sends (thumbnails are at most 800 pixels, icons 128), but small enough that a misbehaving one can't
  /// run the device out of memory.
  static const maxWindows = 500;
  static const maxApps = 2000;
  static const maxThumbnailSide = 1024;
  static const maxIconSide = 512;

  final String deviceId;
  final String deviceName;
  final PairingStore _store;
  final HostBrowser? _browser;
  final Connector _connect;
  final PeerLink Function() _makePeer;
  final ScreenInfo Function() _screen;

  /// Keeps the screen on while connected.
  final Future<void> Function(bool on) _keepAwake;

  _Session? _session;
  Timer? _pingTimer;
  var _pingCounter = Int64.ZERO;
  Timer? _previewTimer;
  var _previewViewers = 0;
  final _requestedIcons = <String>{};
  final _wantedIcons = <String>{};
  var _isDisposed = false;

  Phase _phase = const Browsing();
  List<PairedHost> _pairedHosts = const [];
  List<WindowInfo> _windows = const [];
  StreamInfo? _stream;
  int? _pendingWindowId;
  MediaStream? _videoStream;
  ControlStatus? _control;
  final _thumbnails = <int, ImageProvider>{};
  final _appIcons = <String, ImageProvider>{};
  List<AppInfo> _apps = const [];
  AppInfo? _pendingLaunch;
  Problem? _problem;
  List<DiscoveredHost>? _sampleHosts;
  String? _previewScreen;

  /// The design preview being shown, if any.
  String? get previewScreen => _previewScreen;

  Phase get phase => _phase;
  List<DiscoveredHost> get hosts => _sampleHosts ?? _browser?.hosts ?? const [];
  List<PairedHost> get pairedHosts => _pairedHosts;
  BrowseStatus get browseStatus => _browser?.status ?? BrowseStatus.searching;
  List<WindowInfo> get windows => _windows;
  StreamInfo? get stream => _stream;
  int? get pendingWindowId => _pendingWindowId;
  MediaStream? get videoStream => _videoStream;

  /// Whether the Mac accepts clicks and typing. Null until it says.
  ControlStatus? get control => _control;

  /// Stills of the Mac's windows and the icons of their apps, for the window grid.
  Map<int, ImageProvider> get thumbnails => Map.unmodifiable(_thumbnails);
  Map<String, ImageProvider> get appIcons => Map.unmodifiable(_appIcons);

  /// The Mac's installed apps, once asked for.
  List<AppInfo> get apps => _apps;

  /// An app the Mac is opening; its window streams as soon as it appears.
  AppInfo? get pendingLaunch => _pendingLaunch;
  Problem? get problem => _problem;

  bool get isShowingStream => _stream != null || _pendingWindowId != null || _pendingLaunch != null;
  bool get canControl => _control?.allowed ?? true;

  WindowInfo? get streamedWindow {
    final id = _stream?.windowId ?? _pendingWindowId;
    return id == null ? null : _windows.where((w) => w.id == id).firstOrNull;
  }

  ImageProvider? icon(String? bundleId) => bundleId == null ? null : _appIcons[bundleId];

  @override
  void dispose() {
    _isDisposed = true;
    _browser?.removeListener(notifyListeners);
    _teardown();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) super.notifyListeners();
  }

  // MARK: User actions

  /// The pairing for [host], by the ID in its Bonjour record and never by name. Another Mac can copy
  /// the ID too, but then it can't finish the handshake without the secret.
  PairedHost? savedPairing(DiscoveredHost host) {
    final hostId = host.hostId;
    return hostId == null ? null : _pairedHosts.where((p) => p.hostId == hostId).firstOrNull;
  }

  /// What to call [host]: the name a paired Mac gave over an authenticated connection, else its
  /// Bonjour name.
  String hostName(DiscoveredHost host, {String fallback = 'the Mac'}) =>
      savedPairing(host)?.hostName ?? DisplayName.clean(host.name, fallback: fallback);

  /// Connects, reusing the saved pairing unless [pairAgain] asks for a fresh one.
  void connect(DiscoveredHost host, {bool pairAgain = false}) {
    _teardown();
    final name = hostName(host);
    if (host.hostId == null) {
      // Every Porthole Host advertises its ID. Pairing holds the Mac to it, so without one a Mac could
      // claim another's ID and take over that Mac's saved pairing.
      _fail(Problem('Couldn’t read $name’s details. Check that Porthole Host is up to date, then try again.',
          action: ProblemAction.tryAgain, host: host));
      return;
    }
    final pairing = pairAgain ? null : savedPairing(host);
    final link = DeviceLink(deviceId: deviceId, deviceName: deviceName, pairing: pairing, expectedHostId: host.hostId);
    final session = _Session(host, link, pairing, name);
    _session = session;
    _phase = Connecting(name);
    notifyListeners();
    _connect(host).then((signaling) {
      if (!identical(session, _session)) {
        signaling.close();
        return;
      }
      session.signaling = signaling;
      signaling.events.listen((event) => session.events = session.events
          .then((_) => _handleEvent(session, event))
          // One failure would otherwise skip every event after it, the close included.
          .catchError((Object error) => _interrupted(session, error)));
      link.start().then((outputs) => _apply(session, outputs));
    }, onError: (Object error) {
      if (!identical(session, _session)) return;
      _fail(Problem("Couldn’t reach $name. Check that it’s awake and on the same Wi‑Fi, then try again.",
          action: ProblemAction.tryAgain, host: host));
    });
  }

  void retry(Problem problem) {
    final host = problem.host;
    if (host == null) return;
    // Use the latest Bonjour result in case the Mac's address changed.
    final latest = hosts.where((h) => h.name == host.name).firstOrNull ?? host;
    connect(latest, pairAgain: problem.action == ProblemAction.pairAgain);
  }

  void dismissProblem() {
    if (_problem == null) return;
    _problem = null;
    notifyListeners();
  }

  void codesMatch() {
    final session = _session;
    final phase = _phase;
    if (session == null || phase is! ComparingCode) return;
    _phase = WaitingForMac(phase.hostName);
    notifyListeners();
    session.link.codesMatch().then((outputs) => _apply(session, outputs));
  }

  void codesDiffer() {
    final session = _session;
    if (session == null) return;
    session.link.codesDiffer().then((outputs) => _apply(session, outputs));
  }

  void disconnect() {
    _session?.signaling?.closeWith(CloseReason.disconnected);
    _teardown();
    notifyListeners();
  }

  Future<void> forget(PairedHost host) async {
    await _store.remove(host.hostId);
    await reloadPairedHosts();
  }

  void select(WindowInfo window) {
    _pendingLaunch = null;
    _pendingWindowId = window.id;
    _sendControl(ClientMessage(releaseAll: Nothing()));
    _sendControl(ClientMessage(select: window.id));
    notifyListeners();
  }

  void stopStream() {
    if (!isShowingStream) return;
    _stream = null;
    _pendingWindowId = null;
    _pendingLaunch = null;
    _sendControl(ClientMessage(releaseAll: Nothing()));
    _sendControl(ClientMessage(stopStream: Nothing()));
    notifyListeners();
  }

  void refreshApps() => _sendControl(ClientMessage(listApps: Nothing()));

  /// Opens an app on the Mac and shows its window when it appears.
  void launch(AppInfo app) {
    _pendingWindowId = null;
    _pendingLaunch = app;
    _sendControl(ClientMessage(releaseAll: Nothing()));
    _sendControl(ClientMessage(launch: app.bundleId));
    notifyListeners();
  }

  /// App tiles call this as they come on screen, so a long list only fetches the icons someone sees.
  void wantIcon(String bundleId) {
    if (_requestedIcons.contains(bundleId) || _appIcons.containsKey(bundleId)) return;
    final isFirst = _wantedIcons.isEmpty;
    _wantedIcons.add(bundleId);
    if (!isFirst) return;
    // Gather the tiles that appear together into one request.
    Timer.run(() {
      final batch = _wantedIcons.difference(_requestedIcons).toList()..sort();
      _wantedIcons.clear();
      _requestedIcons.addAll(batch);
      _requestIcons(batch);
    });
  }

  void refreshWindows() {
    _sendControl(ClientMessage(listWindows: Nothing()));
    _requestPreviews();
  }

  /// Window grids call this while on screen, so thumbnails stay fresh only while someone is looking.
  void setPreviewsVisible(bool visible) {
    _previewViewers = (_previewViewers + (visible ? 1 : -1)).clamp(0, 1 << 20);
    if (_previewViewers > 0 && _previewTimer == null) {
      _requestPreviews();
      _previewTimer = Timer.periodic(const Duration(seconds: 4), (_) => _requestPreviews());
    } else if (_previewViewers == 0) {
      _previewTimer?.cancel();
      _previewTimer = null;
    }
  }

  /// Input from the stream view. The view stamps each event with the stream it was aimed at.
  void sendInput(ClientMessage message) {
    if (canControl) _sendControl(message);
  }

  Future<void> reloadPairedHosts() async {
    final hosts = await _store.all();
    _pairedHosts = hosts;
    notifyListeners();
  }

  // MARK: Signaling

  String get _hostName => _session?.name ?? 'the Mac';

  void _interrupted(_Session session, Object error) {
    if (!identical(session, _session)) return;
    debugPrint('signaling event failed: $error');
    session.signaling?.closeWith(CloseReason.unexpectedMessage);
    _fail(problemFor(null, saidByMac: false, hostName: session.name, host: session.host));
  }

  Future<void> _handleEvent(_Session session, ConnectionEvent event) async {
    if (!identical(session, _session)) return;
    switch (event) {
      case ConnectionMessage(:final message):
        _apply(session, await session.link.receive(message));
      case ConnectionIncompatible(:final version):
        _fail(Problem(incompatibleText(_hostName, version)));
      case ConnectionClosed(:final error):
        if (error != null) debugPrint('signaling closed: $error');
        if (_phase is! Browsing) {
          _fail(Problem('Lost the connection to $_hostName.', action: ProblemAction.tryAgain, host: session.host));
        }
    }
  }

  void _apply(_Session session, List<LinkOutput> outputs) {
    for (final output in outputs) {
      if (!identical(session, _session)) return;
      switch (output) {
        case SendWire(:final message):
          session.signaling?.send(message);
        case ShowCode(:final code):
          _phase = ComparingCode(_hostName, code);
          notifyListeners();
        case Paired(:final host):
          final cleaned = _cleaned(host);
          session
            ..pairing = cleaned
            ..name = cleaned.hostName;
          _save(cleaned);
        case Established():
          _phase = Connecting(_hostName);
          notifyListeners();
          final screen = _screen();
          _send(session, Signal(
            hello: ClientHello(
              protocolVersion: portholeProtocolVersion,
              deviceName: deviceName,
              viewport: PixelSize(width: Int64(screen.width), height: Int64(screen.height)),
              maxFramesPerSecond: Int64(screen.refreshRate),
            ),
          ));
        case Deliver(:final message):
          _handleSignal(session, message);
        case CloseLink(:final reason):
          session.signaling?.closeWith(reason);
          _fail(problemFor(reason, saidByMac: false, hostName: _hostName, host: session.host));
        case PeerClosed(:final reason):
          _fail(problemFor(CloseReason.fromWire(reason), saidByMac: true, hostName: _hostName, host: session.host));
      }
    }
  }

  /// What to say when the link ends for [reason]. Reasons that arrive before the session is up aren't
  /// authenticated, so these say what to check on the Mac rather than taking anyone's word for it.
  static Problem problemFor(CloseReason? reason,
      {required bool saidByMac, required String hostName, DiscoveredHost? host}) {
    final name = hostName;
    const again = ProblemAction.tryAgain;
    return switch (reason) {
      CloseReason.pairingClosed => Problem(
          '$name isn’t accepting new devices right now. On the Mac, click the Porthole icon in the menu bar, '
          'choose Pair New Device, then try again.',
          action: again,
          host: host),
      CloseReason.pairingDenied => Problem('Pairing was declined on $name.'),
      CloseReason.pairingFailed when !saidByMac => Problem(
          'Pairing stopped. If the codes didn’t match, another device on this network may be pretending to be '
          '$name. Try again, and if it keeps happening, pair on a network you trust.',
          action: again,
          host: host),
      CloseReason.pairingFailed => Problem('Pairing with $name didn’t finish.', action: again, host: host),
      CloseReason.pairingContested => Problem(
          'Another device tried to pair with $name at the same time, so the Mac stopped pairing. Check the Mac, '
          'then try again.',
          action: again,
          host: host),
      CloseReason.unknownPairing => Problem(
          '$name didn’t recognize this device. If you removed it in the Porthole menu on the Mac, pair again.',
          action: ProblemAction.pairAgain,
          host: host),
      CloseReason.handshakeFailed => Problem(
          'Couldn’t confirm this is your $name. If you paired this device again on the Mac, pair again here too. '
          'Otherwise, another device may be pretending to be your Mac.',
          action: ProblemAction.pairAgain,
          host: host),
      CloseReason.replaced => Problem('Another device connected to $name.', action: again, host: host),
      CloseReason.disconnected => Problem('$name ended the session.'),
      CloseReason.hostStopped => Problem('Porthole Host quit on $name.'),
      CloseReason.versionMismatch =>
        Problem('$name runs a different version of Porthole. Update Porthole Host on the Mac and this app.'),
      CloseReason.timedOut => Problem('$name didn’t respond in time.', action: again, host: host),
      CloseReason.badFrame || CloseReason.unexpectedMessage || null =>
        Problem('The connection to $name was interrupted.', action: again, host: host),
    };
  }

  /// What to say when the Mac speaks another version of the protocol: which side needs the update.
  static String incompatibleText(String hostName, int theirVersion) => theirVersion < portholeProtocolVersion
      ? '$hostName runs an older Porthole Host. Update it on the Mac, then try again.'
      : '$hostName runs a newer Porthole Host. Update this app, then try again.';

  static PairedHost _cleaned(PairedHost host, [String? name]) => PairedHost(
        hostId: host.hostId,
        hostName: DisplayName.clean(name ?? host.hostName, fallback: 'Mac'),
        pairId: host.pairId,
        secret: host.secret,
      );

  Future<void> _save(PairedHost host) async {
    try {
      await _store.save(host);
    } catch (error) {
      debugPrint('could not save pairing: $error');
    }
    await reloadPairedHosts();
  }

  void _send(_Session session, Signal message) {
    try {
      session.signaling?.send(session.link.seal(message));
    } on Object catch (error) {
      debugPrint('could not seal a signal: $error');
    }
  }

  void _handleSignal(_Session session, Signal message) {
    switch (message.whichMsg()) {
      case Signal_Msg.offer:
        final peer = session.peer ??= _preparePeer(session);
        peer.acceptOffer(message.offer).then((answer) {
          if (identical(session, _session) && identical(peer, session.peer)) _send(session, Signal(answer: answer));
        }, onError: (Object error) {
          // A bye or a cancel may have closed this peer meanwhile; keep that reason.
          if (!identical(session, _session) || !identical(peer, session.peer)) return;
          _fail(Problem('Could not set up the video connection: $error', action: ProblemAction.tryAgain, host: session.host));
        });
      case Signal_Msg.candidate:
        session.peer?.addRemoteCandidate(message.candidate);
      case Signal_Msg.welcome:
        // Sealed with the pairing secret, so this is the paired Mac: keep its name current if it was
        // renamed.
        final pairing = session.pairing;
        if (pairing == null) return;
        final renamed = _cleaned(pairing, message.welcome.hostName);
        if (renamed.hostName == pairing.hostName) return;
        session
          ..pairing = renamed
          ..name = renamed.hostName;
        _save(renamed);
      case Signal_Msg.hello || Signal_Msg.answer || Signal_Msg.notSet:
        break;
    }
  }

  PeerLink _preparePeer(_Session session) {
    final peer = _makePeer();
    final hostName = _hostName;
    bool current() => identical(session, _session) && identical(peer, session.peer);
    peer
      ..onLocalCandidate = (candidate) {
        if (current()) _send(session, Signal(candidate: candidate));
      }
      ..onStateChange = (state) {
        if (!current()) return;
        switch (state) {
          case PeerState.connected:
            _phase = Connected(hostName);
            _keepAwake(true);
            notifyListeners();
          case PeerState.failed:
            _fail(Problem('The connection to $hostName failed.', action: ProblemAction.tryAgain, host: session.host));
          case PeerState.fresh || PeerState.connecting || PeerState.disconnected || PeerState.closed:
            break;
        }
      }
      ..onControlOpen = () {
        if (!current()) return;
        _sendControl(ClientMessage(listWindows: Nothing()));
        _startPinging();
      }
      ..onControlMessage = (data) {
        if (current()) handleControl(data);
      }
      ..onRemoteStream = (stream) {
        if (!current()) return;
        _videoStream = stream;
        notifyListeners();
      };
    return peer;
  }

  // MARK: Control channel

  /// One message from the Mac on the control channel.
  @visibleForTesting
  void handleControl(Uint8List data) {
    final HostMessage message;
    try {
      message = MessageCoding.decodeHost(data);
    } on Object {
      debugPrint('ignoring unreadable control message');
      return;
    }
    switch (message.whichMsg()) {
      case HostMessage_Msg.windows:
        final isFirst = _windows.isEmpty;
        _windows = List.unmodifiable(message.windows.windows.take(maxWindows));
        final alive = {for (final w in _windows) w.id};
        _thumbnails.removeWhere((id, image) {
          final dead = !alive.contains(id);
          if (dead) image.evict();
          return dead;
        });
        if (_previewViewers > 0 || isFirst) _requestPreviews();
      case HostMessage_Msg.streamStarted:
        final info = message.streamStarted;
        if (_pendingWindowId != info.windowId && _pendingLaunch == null && _stream == null) {
          // The user backed out while it was starting; make sure the Mac stops too. While another window
          // is on its way this is an older start, and stopping now would stop that one instead.
          if (_pendingWindowId == null) _sendControl(ClientMessage(stopStream: Nothing()));
          return;
        }
        _stream = info;
        _pendingWindowId = null;
        _pendingLaunch = null;
      case HostMessage_Msg.geometry:
        if (message.geometry.gen == _stream?.gen) _stream = message.geometry;
      case HostMessage_Msg.streamState:
        final update = message.streamState;
        if (update.gen == _stream?.gen && update.state.whichState() == StreamState_State.closed) {
          _stream = null;
          _problem = Problem('The window was closed on the Mac.');
        }
      case HostMessage_Msg.error:
        _pendingWindowId = null;
        _pendingLaunch = null;
        _problem = Problem(message.error.message);
      case HostMessage_Msg.control:
        _control = message.control;
      case HostMessage_Msg.thumbnail:
        final thumbnail = message.thumbnail;
        final bytes = Uint8List.fromList(thumbnail.jpeg);
        if (!_windows.any((w) => w.id == thumbnail.windowId) || !fitsWithin(jpegSize(bytes), maxThumbnailSide)) return;
        _replace(_thumbnails, thumbnail.windowId, MemoryImage(bytes));
      case HostMessage_Msg.appIcon:
        final icon = message.appIcon;
        final bytes = Uint8List.fromList(icon.png);
        if (!_requestedIcons.contains(icon.bundleId) || !fitsWithin(pngSize(bytes), maxIconSide)) return;
        _replace(_appIcons, icon.bundleId, MemoryImage(bytes));
      case HostMessage_Msg.apps:
        _apps = List.unmodifiable(message.apps.apps.take(maxApps));
      case HostMessage_Msg.pong || HostMessage_Msg.notSet:
        return;
    }
    notifyListeners();
  }

  /// Swaps in a new image and drops the old one from the image cache, which would otherwise fill with
  /// stale thumbnails every few seconds.
  static void _replace<K>(Map<K, ImageProvider> images, K key, ImageProvider image) {
    images[key]?.evict();
    images[key] = image;
  }

  void _requestPreviews() {
    if (_windows.isEmpty) return;
    _sendControl(ClientMessage(
      thumbnails: ThumbnailRequest(windowIds: [for (final w in _windows) w.id], maxLongSide: Int64(thumbnailLongSide)),
    ));
    final missing = {
      for (final w in _windows)
        if (w.hasBundleId() && !_requestedIcons.contains(w.bundleId)) w.bundleId,
    }.toList()
      ..sort();
    _requestedIcons.addAll(missing);
    _requestIcons(missing);
  }

  void _requestIcons(List<String> bundleIds) {
    for (var start = 0; start < bundleIds.length; start += iconBatch) {
      final end = (start + iconBatch).clamp(0, bundleIds.length);
      _sendControl(ClientMessage(appIcons: AppIconRequest(bundleIds: bundleIds.sublist(start, end))));
    }
  }

  void _sendControl(ClientMessage message) => _session?.peer?.sendControl(message.writeToBuffer());

  /// A heartbeat: if it stops, the Mac lets go of any keys or buttons this device was holding.
  void _startPinging() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _pingCounter += 1;
      _sendControl(ClientMessage(ping: _pingCounter));
    });
  }

  // MARK: Helpers

  void _fail(Problem problem) {
    _teardown();
    _problem = problem;
    notifyListeners();
  }

  void _teardown() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _previewTimer?.cancel();
    _previewTimer = null;
    _previewViewers = 0;
    for (final image in [..._thumbnails.values, ..._appIcons.values]) {
      image.evict();
    }
    _thumbnails.clear();
    _appIcons.clear();
    _requestedIcons.clear();
    _wantedIcons.clear();
    _apps = const [];
    _pendingLaunch = null;
    final session = _session;
    _session = null;
    session?.peer?.close();
    session?.signaling?.close();
    _phase = const Browsing();
    _windows = const [];
    _stream = null;
    _pendingWindowId = null;
    _videoStream = null;
    _control = null;
    _keepAwake(false);
  }

  // MARK: Design previews

  /// Sample state for checking layouts without a Mac: `--dart-define=PREVIEW=<screen>` (see preview.dart).
  void loadPreview(String screen, {required List<WindowInfo> windows, required List<AppInfo> apps,
      Map<int, ImageProvider> thumbnails = const {}, Map<String, ImageProvider> icons = const {},
      List<DiscoveredHost> hosts = const [], List<PairedHost> paired = const []}) {
    const host = 'Ngonidzashe’s MacBook Pro';
    _previewScreen = screen;
    _sampleHosts = hosts;
    _pairedHosts = paired;
    _windows = windows;
    _apps = apps;
    _thumbnails.addAll(thumbnails);
    _appIcons.addAll(icons);
    _control = ControlStatus(allowed: true);
    switch (screen) {
      case 'connecting':
        _phase = const Connecting(host);
      case 'pairing':
        _phase = const ComparingCode(host, '482916');
      case 'waiting':
        _phase = const WaitingForMac(host);
      case 'problem':
        _problem = Problem('Lost the connection to $host.', action: ProblemAction.tryAgain);
      case 'opening':
        _phase = const Connected(host);
        _pendingWindowId = windows.firstOrNull?.id;
      case 'launching':
        _phase = const Connected(host);
        _pendingLaunch = apps.where((a) => a.bundleId == 'com.apple.Maps').firstOrNull;
      case 'stream':
        _phase = const Connected(host);
        final first = windows.first;
        _stream = StreamInfo(
          gen: 1,
          windowId: first.id,
          title: first.title,
          appName: first.appName,
          pointSize: PointSize(width: 1280, height: 800),
          pixelSize: PixelSize(width: Int64(2560), height: Int64(1600)),
        );
      case 'browsing' || 'searching':
        break;
      default:
        _phase = const Connected(host);
    }
    notifyListeners();
  }
}
