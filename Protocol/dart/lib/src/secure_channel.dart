import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:fixnum/fixnum.dart';
import 'package:meta/meta.dart';

import 'bytes.dart';
import 'generated/porthole.pb.dart';
import 'pairing.dart';

// Every connection from a paired device starts with a mutual proof of the pairing secret, then derives
// fresh keys for that connection only (SecureChannel.swift has the full picture):
//
//  device: sessionHello{pairID, nD, MAC(secret, pairID ‖ nD)}
//  host:   sessionAccept{nM, MAC(secret, pairID ‖ nD ‖ nM)}
//  keys:   HKDF(secret, salt nD ‖ nM, "d2m" / "m2d")
//
// After that, each Signal is sealed with ChaCha20-Poly1305. The nonce is a per-direction counter that
// must arrive in order with no gaps, which rejects replayed, reordered and dropped frames.

sealed class SecureChannelError implements Exception {
  const SecureChannelError();
}

final class OutOfOrder extends SecureChannelError {
  const OutOfOrder({required this.expected, required this.received});
  final Int64 expected;
  final Int64 received;

  @override
  bool operator ==(Object other) => other is OutOfOrder && other.expected == expected && other.received == received;

  @override
  int get hashCode => Object.hash(expected, received);

  @override
  String toString() => 'OutOfOrder(expected: $expected, received: $received)';
}

final class AuthenticationFailed extends SecureChannelError {
  const AuthenticationFailed();

  @override
  bool operator ==(Object other) => other is AuthenticationFailed;

  @override
  int get hashCode => 1;

  @override
  String toString() => 'AuthenticationFailed';
}

final class Exhausted extends SecureChannelError {
  const Exhausted();

  @override
  bool operator ==(Object other) => other is Exhausted;

  @override
  int get hashCode => 2;

  @override
  String toString() => 'Exhausted';
}

enum SessionRole { device, host }

abstract final class SessionHandshake {
  static Future<SessionHello> hello({required String pairId, required List<int> secret}) =>
      helloWith(pairId: pairId, secret: secret, nonce: PairingCrypto.randomNonce());

  /// With a fixed nonce, for the vectors. Reusing one would let an old accept and its frames be replayed.
  @visibleForTesting
  static Future<SessionHello> helloWith({required String pairId, required List<int> secret, required List<int> nonce}) async {
    final helloNonce = Uint8List.fromList(nonce);
    return SessionHello(pairId: pairId, nonce: helloNonce, mac: await _helloMac(pairId, helloNonce, secret));
  }

  static Future<bool> isValidHello(SessionHello hello, List<int> secret) async =>
      hello.nonce.length == PairingCrypto.nonceLength &&
      PairingCrypto.verify(await _helloMac(hello.pairId, hello.nonce, secret), hello.mac);

  /// The Mac's answer; apps never send one. Here for the tests that play the Mac.
  @visibleForTesting
  static Future<SessionAccept> accept(SessionHello hello, List<int> secret, {List<int>? nonce}) async {
    final acceptNonce = Uint8List.fromList(nonce ?? PairingCrypto.randomNonce());
    return SessionAccept(nonce: acceptNonce, mac: await _acceptMac(hello, acceptNonce, secret));
  }

  static Future<bool> isValidAccept(SessionAccept accept, SessionHello hello, List<int> secret) async =>
      accept.nonce.length == PairingCrypto.nonceLength &&
      PairingCrypto.verify(await _acceptMac(hello, accept.nonce, secret), accept.mac);

  /// The channel for one side of a connection whose handshake both sides have verified.
  static Future<SecureChannel> channel({
    required SessionRole role,
    required List<int> secret,
    required SessionHello hello,
    required SessionAccept accept,
  }) async {
    final master = SecretKey(secret);
    final salt = concat([hello.nonce, accept.nonce]);
    Future<SecretKeyData> key(String info) async =>
        SecretKeyData(await PairingCrypto.hkdf(master, salt: salt, info: info, length: 32));
    final deviceToHost = await key('porthole-d2m-v1');
    final hostToDevice = await key('porthole-m2d-v1');
    // "v2" is part of the key derivation, not the wire version; it stays so pairings keep working.
    final d2mData = utf8.encode('porthole-v2|${hello.pairId}|d2m');
    final m2dData = utf8.encode('porthole-v2|${hello.pairId}|m2d');
    return switch (role) {
      SessionRole.device => SecureChannel._(deviceToHost, d2mData, hostToDevice, m2dData),
      SessionRole.host => SecureChannel._(hostToDevice, m2dData, deviceToHost, d2mData),
    };
  }

  static Future<Uint8List> _helloMac(String pairId, List<int> nonce, List<int> secret) =>
      PairingCrypto.mac(secret, 'session-hello', [utf8.encode(pairId), nonce]);

  static Future<Uint8List> _acceptMac(SessionHello hello, List<int> nonce, List<int> secret) =>
      PairingCrypto.mac(secret, 'session-accept', [utf8.encode(hello.pairId), hello.nonce, nonce]);
}

/// Both directions of a secured connection. Synchronous, so frames are sealed and opened strictly in the
/// order they're handed over.
final class SecureChannel {
  SecureChannel._(this._sendKey, this._sendAad, this._receiveKey, this._receiveAad);

  static const _cipher = DartChacha20.poly1305Aead();
  static const _tagLength = 16;

  final SecretKeyData _sendKey;
  final List<int> _sendAad;
  final SecretKeyData _receiveKey;
  final List<int> _receiveAad;
  var _sendCounter = Int64.ZERO;
  var _receiveCounter = Int64.ZERO;

  Sealed seal(List<int> plaintext) {
    if (_sendCounter == Int64.MAX_VALUE) throw const Exhausted();
    final counter = _sendCounter;
    final box = _cipher.encryptSync(plaintext, secretKey: _sendKey, nonce: _nonce(counter), aad: _sendAad);
    _sendCounter += 1;
    return Sealed(counter: counter, box: concat([box.cipherText, box.mac.bytes]));
  }

  Uint8List open(Sealed frame) {
    if (frame.counter != _receiveCounter) throw OutOfOrder(expected: _receiveCounter, received: frame.counter);
    if (frame.box.length < _tagLength) throw const AuthenticationFailed();
    final split = frame.box.length - _tagLength;
    final List<int> plaintext;
    try {
      plaintext = _cipher.decryptSync(
        SecretBox(frame.box.sublist(0, split), nonce: _nonce(frame.counter), mac: Mac(frame.box.sublist(split))),
        secretKey: _receiveKey,
        aad: _receiveAad,
      );
    } on SecretBoxAuthenticationError {
      throw const AuthenticationFailed();
    }
    _receiveCounter += 1;
    return Uint8List.fromList(plaintext);
  }

  /// Four zero bytes, then the counter as 8 bytes big-endian.
  static List<int> _nonce(Int64 counter) => [0, 0, 0, 0, ...counter.toBytes().reversed];
}
