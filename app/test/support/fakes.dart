import 'dart:async';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:porthole/client/client_controller.dart';
import 'package:porthole/client/host_browser.dart';
import 'package:porthole/client/pairing_store.dart';
import 'package:porthole/client/peer_session.dart';
import 'package:porthole/client/signaling.dart';
import 'package:porthole_protocol/porthole_protocol.dart';

/// A Mac that already knows this device: it accepts the session handshake with the saved secret, then
/// trades sealed signals with the controller.
final class FakeMac implements Signaling {
  FakeMac(this.pairing);

  final PairedHost pairing;
  final _events = StreamController<ConnectionEvent>();
  SecureChannel? _channel;
  final signals = <Signal>[];
  CloseReason? closedWith;
  var isClosed = false;

  @override
  Stream<ConnectionEvent> get events => _events.stream;

  bool get isEstablished => _channel != null;

  @override
  void send(Wire message) {
    if (message.hasSessionHello()) {
      final hello = message.sessionHello;
      SessionHandshake.accept(hello, pairing.secret).then((accept) async {
        _channel = await SessionHandshake.channel(role: SessionRole.host, secret: pairing.secret, hello: hello, accept: accept);
        _push(Wire(sessionAccept: accept));
      });
    } else if (message.hasSealed()) {
      signals.add(MessageCoding.decodeSignal(_channel!.open(message.sealed)));
    }
  }

  /// The Mac sends [signal] over the sealed session.
  void sendSignal(Signal signal) => _push(Wire(sealed: _channel!.seal(signal.writeToBuffer())));

  /// The Mac says goodbye and hangs up.
  void bye(CloseReason reason) {
    _push(Wire(bye: Bye(reason: reason.wireName)));
    hangUp();
  }

  void hangUp() {
    if (isClosed) return;
    isClosed = true;
    _events
      ..add(const ConnectionClosed())
      ..close();
  }

  void _push(Wire wire) {
    if (!isClosed) _events.add(ConnectionMessage(wire));
  }

  @override
  Future<void> closeWith(CloseReason reason) async {
    closedWith ??= reason;
    hangUp();
  }

  @override
  Future<void> close() async => hangUp();
}

/// A video connection that records what the controller sends on the control channel.
final class FakePeer extends PeerLink {
  final sent = <ClientMessage>[];
  final remoteCandidates = <IceCandidate>[];
  String? offer;
  var isClosed = false;

  @override
  Future<String> acceptOffer(String sdp) async {
    offer = sdp;
    return 'answer to $sdp';
  }

  @override
  void addRemoteCandidate(IceCandidate candidate) => remoteCandidates.add(candidate);

  @override
  void sendControl(Uint8List data) {
    if (!isClosed) sent.add(ClientMessage.fromBuffer(data));
  }

  /// The Mac sends [message] on the control channel.
  void receive(HostMessage message) => onControlMessage?.call(message.writeToBuffer());

  @override
  Future<void> close() async {
    isClosed = true;
    onLocalCandidate = null;
    onStateChange = null;
    onControlOpen = null;
    onControlMessage = null;
    onRemoteStream = null;
  }
}

const testHost = DiscoveredHost(name: 'Studio Mac', hostId: 'host-1', addresses: ['192.168.1.20'], port: 47801);

final testPairing = PairedHost(hostId: 'host-1', hostName: 'Studio Mac', pairId: 'pair-1', secret: Uint8List(32)..[0] = 7);

/// A controller wired to a [FakeMac] and [FakePeer]s, one per offer.
final class Harness {
  Harness() {
    controller = ClientController(
      deviceId: 'device-1',
      deviceName: 'Test iPad',
      store: store,
      connect: (host) async {
        connects += 1;
        return mac = FakeMac(testPairing);
      },
      makePeer: () {
        final peer = FakePeer();
        peers.add(peer);
        return peer;
      },
      screen: () => (width: 2752, height: 2064, refreshRate: 120),
      keepAwake: (on) async => awake = on,
    );
  }

  final store = MemoryPairingStore([testPairing]);
  late final ClientController controller;
  late FakeMac mac;
  final peers = <FakePeer>[];
  var awake = false;

  /// How many times the controller opened a connection to a Mac.
  var connects = 0;

  FakePeer get peer => peers.last;

  /// Connects with the saved pairing, takes the Mac's offer, and opens the control channel.
  Future<void> connect({DiscoveredHost host = testHost}) async {
    await settle();
    controller.connect(host);
    await until(() => mac.signals.any((s) => s.hasHello()));
    mac.sendSignal(Signal(offer: 'offer-sdp'));
    await until(() => mac.signals.any((s) => s.hasAnswer()));
    peer.onStateChange?.call(PeerState.connected);
    peer.onControlOpen?.call();
  }

  /// Lets queued futures and timers run.
  static Future<void> settle() => Future<void>.delayed(Duration.zero);

  static Future<void> until(bool Function() condition, {int rounds = 200}) async {
    for (var i = 0; i < rounds && !condition(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    if (!condition()) throw StateError('timed out waiting');
  }
}

WindowInfo window(int id, {String app = 'Safari', String? bundleId = 'com.apple.Safari'}) => WindowInfo(
      id: id,
      title: 'Window $id',
      appName: app,
      bundleId: bundleId,
      pid: 100 + id,
      size: PointSize(width: 1280, height: 800),
      isOnScreen: true,
    );

StreamInfo streamInfo(int gen, int windowId) => StreamInfo(
      gen: gen,
      windowId: windowId,
      title: 'Window $windowId',
      appName: 'Safari',
      pointSize: PointSize(width: 1280, height: 800),
      pixelSize: PixelSize(width: Int64(2560), height: Int64(1600)),
    );
