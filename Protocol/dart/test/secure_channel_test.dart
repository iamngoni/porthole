import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:glados/glados.dart';
import 'package:porthole_protocol/porthole_protocol.dart';

import 'support/generators.dart';

/// One connection: what the handshake is built from.
final class Connection {
  Connection(this.secret, this.pairId, this.helloNonce, this.acceptNonce);
  final Uint8List secret, helloNonce, acceptNonce;
  final String pairId;

  Future<(SessionHello, SessionAccept)> handshake() async {
    final hello = await SessionHandshake.helloWith(pairId: pairId, secret: secret, nonce: helloNonce);
    return (hello, await SessionHandshake.accept(hello, secret, nonce: acceptNonce));
  }

  Future<(SecureChannel device, SecureChannel host)> channels() async {
    final (hello, accept) = await handshake();
    Future<SecureChannel> side(SessionRole role) =>
        SessionHandshake.channel(role: role, secret: secret, hello: hello, accept: accept);
    return (await side(SessionRole.device), await side(SessionRole.host));
  }

  @override
  String toString() => 'Connection(${toHex(secret)}, "$pairId")';
}

extension on Any {
  Generator<Connection> get connection =>
      combine4(bytesOfLength(32), text, bytesOfLength(32), bytesOfLength(32), Connection.new);
}

void main() {
  final config = ExploreConfig(numRuns: 100);

  group('properties', () {
    Glados3(any.connection, any.list(any.bytes), any.list(any.bytes), config).test(
      'prop_frames_open_in_order_both_ways',
      (connection, toHost, toDevice) async {
        final (device, host) = await connection.channels();
        for (final (i, plaintext) in toHost.indexed) {
          final frame = device.seal(plaintext);
          expect(frame.counter, Int64(i));
          expect(host.open(frame), plaintext);
        }
        for (final plaintext in toDevice) {
          expect(device.open(host.seal(plaintext)), plaintext);
        }
      },
    );

    Glados3(any.connection, any.intInRange(1, 8), any.positiveIntOrZero, config).test(
      'prop_a_skipped_or_replayed_frame_is_refused',
      (connection, count, pick) async {
        final (device, host) = await connection.channels();
        final frames = [for (var i = 0; i < count; i++) device.seal([i])];
        final opened = pick % count;
        for (final frame in frames.take(opened)) {
          host.open(frame);
        }
        for (final (i, frame) in frames.indexed) {
          if (i == opened) continue;
          expect(() => host.open(frame), throwsA(OutOfOrder(expected: Int64(opened), received: Int64(i))));
        }
      },
    );

    Glados3(any.connection, any.bytes, any.positiveIntOrZero, config).test(
      'prop_any_changed_bit_is_refused_and_the_real_frame_still_opens',
      (connection, plaintext, bit) async {
        final (device, host) = await connection.channels();
        final frame = device.seal(plaintext);
        final box = Uint8List.fromList(frame.box);
        box[bit ~/ 8 % box.length] ^= 1 << bit % 8;
        expect(() => host.open(Sealed(counter: frame.counter, box: box)), throwsA(const AuthenticationFailed()));
        expect(host.open(frame), plaintext);
      },
    );

    Glados2(any.connection, any.bytesOfLength(32), config).test(
      'prop_frames_from_another_connection_do_not_open',
      (connection, otherAcceptNonce) async {
        if (toHex(otherAcceptNonce) == toHex(connection.acceptNonce)) return;
        final (device, _) = await connection.channels();
        final other = Connection(connection.secret, connection.pairId, connection.helloNonce, otherAcceptNonce);
        final (_, otherHost) = await other.channels();
        expect(() => otherHost.open(device.seal([1, 2, 3])), throwsA(const AuthenticationFailed()));
      },
    );

    Glados2(any.connection, any.positiveIntOrZero, config).test(
      'prop_the_handshake_checks_out_only_with_the_pairing_secret',
      (connection, index) async {
        final (hello, accept) = await connection.handshake();
        final wrong = Uint8List.fromList(connection.secret)..[index % 32] ^= 0x80;
        expect(await SessionHandshake.isValidHello(hello, connection.secret), isTrue);
        expect(await SessionHandshake.isValidAccept(accept, hello, connection.secret), isTrue);
        expect(await SessionHandshake.isValidHello(hello, wrong), isFalse);
        expect(await SessionHandshake.isValidAccept(accept, hello, wrong), isFalse);
      },
    );
  });

  final example = Connection(Uint8List(32), 'pair', Uint8List(32)..[0] = 1, Uint8List(32)..[0] = 2);

  test('a box shorter than its tag is refused', () async {
    final (_, host) = await example.channels();
    expect(() => host.open(Sealed(counter: Int64.ZERO, box: Uint8List(15))), throwsA(const AuthenticationFailed()));
  });

  test('a frame sealed by the device does not open as one from the Mac', () async {
    final (device, _) = await example.channels();
    final (otherDevice, _) = await example.channels();
    expect(() => otherDevice.open(device.seal([1])), throwsA(const AuthenticationFailed()));
  });

  test('a hello with a short nonce is invalid', () async {
    final hello = await SessionHandshake.helloWith(pairId: 'pair', secret: example.secret, nonce: Uint8List(31));
    expect(await SessionHandshake.isValidHello(hello, example.secret), isFalse);
  });

  test('an empty message seals to just its tag', () async {
    final (device, _) = await example.channels();
    expect(device.seal([]).box.length, 16);
  });
}
