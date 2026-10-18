import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:porthole_protocol/porthole_protocol.dart';
import 'package:test/test.dart';

// A Dart device against the real Swift HostLink and SignalingConnection over loopback TCP
// (Packages/PortholeKit/Sources/PortholeInteropHost). ./test.sh builds the host and passes its path in
// PORTHOLE_INTEROP_HOST; without it these tests are skipped.

final _hostPath = Platform.environment['PORTHOLE_INTEROP_HOST'];

/// The Swift host process and the lines it prints.
final class InteropHost {
  InteropHost._(this._process) {
    _process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      _lines.add(line);
      _changed.add(null);
    });
  }

  static Future<InteropHost> start() async {
    final host = InteropHost._(await Process.start(_hostPath!, []));
    host.port = int.parse((await host.line('listening ')).split(' ').last);
    return host;
  }

  final Process _process;
  final _lines = <String>[];
  final _changed = StreamController<void>.broadcast();
  var _read = 0;
  late final int port;

  /// The next line, after those already returned, that starts with [prefix].
  Future<String> line(String prefix) async {
    while (true) {
      for (; _read < _lines.length; _read++) {
        if (_lines[_read].startsWith(prefix)) return _lines[_read++];
      }
      await _changed.stream.first.timeout(const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException('host never printed "$prefix"; it printed $_lines'));
    }
  }

  Future<void> stop() async {
    await _process.stdin.close();
    await _process.exitCode.timeout(const Duration(seconds: 5), onTimeout: () {
      _process.kill();
      return -1;
    });
  }
}

/// A device driving a DeviceLink over a SignalingConnection, the way the app does.
final class Device {
  Device._(this.connection, this.link) {
    connection.events.listen((event) async {
      switch (event) {
        case ConnectionMessage(:final message):
          _apply(await link.receive(message));
        case ConnectionIncompatible():
          break;
        case ConnectionClosed():
          if (!closed.isCompleted) closed.complete();
      }
    });
  }

  static Future<Device> connect(InteropHost host, {PairedHost? pairing}) async {
    final link = DeviceLink(deviceId: 'dart-device', deviceName: 'Dart', pairing: pairing, expectedHostId: 'interop-host');
    final device = Device._(await SignalingConnection.connect(InternetAddress.loopbackIPv4, host.port), link);
    device._apply(await link.start());
    return device;
  }

  final SignalingConnection connection;
  final DeviceLink link;
  final code = Completer<String>();
  final paired = Completer<PairedHost>();
  final established = Completer<void>();
  final peerClosed = Completer<String>();
  final closed = Completer<void>();
  final _delivered = StreamController<Signal>();
  late final delivered = StreamIterator(_delivered.stream);

  void send(Signal message) => connection.send(link.seal(message));

  Future<Signal> next() async {
    if (!await delivered.moveNext().timeout(const Duration(seconds: 10))) throw StateError('closed');
    return delivered.current;
  }

  Future<void> establishedWithin() => established.future.timeout(const Duration(seconds: 10));

  void _apply(List<LinkOutput> outputs) {
    for (final output in outputs) {
      switch (output) {
        case SendWire(:final message):
          connection.send(message);
        case ShowCode(:final code):
          this.code.complete(code);
        case Paired(:final host):
          paired.complete(host);
        case Established():
          established.complete();
        case Deliver(:final message):
          _delivered.add(message);
        case CloseLink(:final reason):
          connection.closeWith(reason);
        case PeerClosed(:final reason):
          peerClosed.complete(reason);
      }
    }
  }
}

Signal hello() => Signal(
    hello: ClientHello(
        protocolVersion: portholeProtocolVersion, deviceName: 'Dart', viewport: PixelSize(width: Int64(2560), height: Int64(1600))));

void main() {
  late InteropHost host;
  late PairedHost pairing;

  setUpAll(() async {
    if (_hostPath != null) host = await InteropHost.start();
  });
  tearDownAll(() async {
    if (_hostPath != null) await host.stop();
  });

  group('against the Swift host', skip: _hostPath == null ? 'set PORTHOLE_INTEROP_HOST (./test.sh does)' : null, () {
    test('pairs with the same code on both sides, then exchanges sealed messages both ways', () async {
      final device = await Device.connect(host);
      final deviceCode = await device.code.future.timeout(const Duration(seconds: 10));
      expect(await host.line('code '), 'code $deviceCode');
      device._apply(await device.link.codesMatch());

      pairing = await device.paired.future.timeout(const Duration(seconds: 10));
      expect((pairing.hostId, pairing.hostName), ('interop-host', 'Interop Mac'));
      await host.line('paired Dart');
      await device.establishedWithin();

      device.send(hello());
      expect((await device.next()).welcome.hostName, 'Interop Mac');
      await host.line('established');
      await host.line('deliver hello Dart 2560x1600');

      device.send(Signal(offer: 'v=0'));
      expect((await device.next()).answer, 'answer to v=0');

      final candidate = IceCandidate(sdp: 'candidate:1 1 udp 1 192.168.1.2 5000 typ host', sdpMLineIndex: 0, sdpMid: '0');
      device.send(Signal(candidate: candidate));
      // Compared field by field: Swift leaves out sdpMLineIndex 0, which Dart counts as a difference.
      final echoed = (await device.next()).candidate;
      expect((echoed.sdp, echoed.sdpMLineIndex, echoed.sdpMid), (candidate.sdp, 0, '0'));
      await device.connection.closeWith(CloseReason.disconnected);
      await host.line('peer-closed disconnected');
    });

    test('reconnects with the saved pairing without pairing again', () async {
      final device = await Device.connect(host, pairing: pairing);
      await device.establishedWithin();
      device.send(hello());
      expect((await device.next()).hasWelcome(), isTrue);
      expect(device.code.isCompleted, isFalse);
      await device.connection.close();
    });

    test('a replayed sealed frame closes the connection', () async {
      final device = await Device.connect(host, pairing: pairing);
      await device.establishedWithin();
      final frame = device.link.seal(hello());
      device.connection
        ..send(frame)
        ..send(frame);
      expect((await device.next()).hasWelcome(), isTrue);
      expect(await host.line('close '), 'close bad-frame');
      expect(await device.peerClosed.future.timeout(const Duration(seconds: 10)), 'bad-frame');
    });

    test('a tampered sealed frame closes the connection', () async {
      final device = await Device.connect(host, pairing: pairing);
      await device.establishedWithin();
      final frame = device.link.seal(hello());
      frame.sealed.box = Uint8List.fromList(frame.sealed.box)..[0] ^= 0x01;
      device.connection.send(frame);
      expect(await host.line('close '), 'close bad-frame');
      expect(await device.peerClosed.future.timeout(const Duration(seconds: 10)), 'bad-frame');
    });

    test('a device without the pairing secret is refused', () async {
      final forged = PairedHost(
          hostId: pairing.hostId,
          hostName: pairing.hostName,
          pairId: pairing.pairId,
          secret: Uint8List.fromList(pairing.secret)..[0] ^= 0x01);
      final device = await Device.connect(host, pairing: forged);
      expect(await host.line('close '), 'close handshake-failed');
      expect(await device.peerClosed.future.timeout(const Duration(seconds: 10)), 'handshake-failed');
      expect(device.established.isCompleted, isFalse);
    });

    test('a pairing the Mac does not know is refused', () async {
      final unknown = PairedHost(hostId: 'interop-host', hostName: 'x', pairId: 'nope', secret: Uint8List(32));
      final device = await Device.connect(host, pairing: unknown);
      expect(await host.line('close '), 'close unknown-pairing');
      expect(await device.peerClosed.future.timeout(const Duration(seconds: 10)), 'unknown-pairing');
    });

    test('saying the codes differ ends pairing on both sides', () async {
      final device = await Device.connect(host);
      await device.code.future.timeout(const Duration(seconds: 10));
      await host.line('code ');
      device._apply(await device.link.codesDiffer());
      expect(await host.line('peer-closed '), 'peer-closed pairing-failed');
      await device.closed.future.timeout(const Duration(seconds: 10));
    });

    test('an app from before v3 is told, in JSON, to update', () async {
      final socket = await Socket.connect(InternetAddress.loopbackIPv4, host.port);
      socket.add(Framing.frame(utf8.encode('{"v":2,"msg":{"pairRequest":{}}}')));
      final decoder = FrameDecoder();
      final frames = <Uint8List>[];
      await for (final bytes in socket.timeout(const Duration(seconds: 10))) {
        frames.addAll(decoder.append(bytes));
        if (frames.isNotEmpty) break;
      }
      socket.destroy();
      expect(WireCoding.decode(frames.single), const UnsupportedVersion(2, reason: 'version-mismatch'));
      expect(await host.line('incompatible '), 'incompatible 2 -');
    });
  });
}
