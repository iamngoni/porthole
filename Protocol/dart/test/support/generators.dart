import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:glados/glados.dart';
import 'package:porthole_protocol/porthole_protocol.dart';

// glados runs every property with a fixed seed (Random(42)) and shrinks failures, so a failing case is
// the same small one on every run.

extension PortholeAny on Any {
  Generator<int> get byte => intInRange(0, 256);

  Generator<Uint8List> bytesOfLength(int length) => listWithLength(length, byte).map(Uint8List.fromList);

  Generator<Uint8List> get bytes => list(byte).map(Uint8List.fromList);

  /// Text with what trips encoders up: accents, curly quotes, emoji, quotes, braces, newlines and NUL.
  Generator<String> get text =>
      list(choose(const ['a', 'Z', '7', ' ', 'é', '’', '—', '😀', '🪟', '"', '{', '\n', '\u0000'])).map((parts) => parts.join());

  /// Any uint64 (as protobuf's Int64), shrinking towards 0 by halving.
  Generator<Int64> get uint64 => simple(
        generate: (random, size) => random.nextBool()
            ? Int64(random.nextInt(size + 1))
            : Int64(random.nextInt(1 << 32)) << 32 | Int64(random.nextInt(1 << 32)),
        shrink: (value) sync* {
          if (value != Int64.ZERO) {
            yield Int64.ZERO;
            yield value.shiftRightUnsigned(1);
          }
        },
      );

  /// One of every signaling message, with arbitrary contents.
  Generator<Wire> get wire => oneOf([
        combine3(text, text, bytes,
            (String id, String name, Uint8List c) => Wire(pairRequest: PairRequest(deviceId: id, deviceName: name, commitment: c))),
        combine4(
            text,
            text,
            bytes,
            bytes,
            (String id, String name, Uint8List key, Uint8List nonce) =>
                Wire(pairChallenge: PairChallenge(hostId: id, hostName: name, hostKey: key, hostNonce: nonce))),
        combine2(bytes, bytes,
            (Uint8List key, Uint8List nonce) => Wire(pairReveal: PairReveal(deviceKey: key, deviceNonce: nonce))),
        bytes.map((mac) => Wire(pairConfirm: PairConfirm(mac: mac))),
        combine2(text, bytes, (String id, Uint8List mac) => Wire(pairComplete: PairComplete(pairId: id, mac: mac))),
        combine3(text, bytes, bytes,
            (String id, Uint8List nonce, Uint8List mac) => Wire(sessionHello: SessionHello(pairId: id, nonce: nonce, mac: mac))),
        combine2(bytes, bytes, (Uint8List nonce, Uint8List mac) => Wire(sessionAccept: SessionAccept(nonce: nonce, mac: mac))),
        combine2(uint64, bytes, (Int64 counter, Uint8List box) => Wire(sealed: Sealed(counter: counter, box: box))),
        text.map((reason) => Wire(bye: Bye(reason: reason))),
      ]);
}

/// Splits [bytes] at the given cut points, the way TCP reads might.
List<List<int>> chunked(List<int> bytes, List<int> cuts) {
  final points = {0, for (final cut in cuts) cut % (bytes.length + 1), bytes.length}.toList()..sort();
  return [for (var i = 0; i + 1 < points.length; i++) bytes.sublist(points[i], points[i + 1])];
}
