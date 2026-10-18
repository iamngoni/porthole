import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:meta/meta.dart';

import 'bytes.dart';
import 'generated/porthole.pb.dart';

// Pairing by numeric comparison with a commitment, as in Bluetooth Secure Simple Pairing. The same steps
// as Pairing.swift, which has the full picture:
//
//  device                                   host (Mac, pairing window open)
//  pairRequest{deviceID, name, C} ────────▶  C = H(deviceKey ‖ deviceNonce)
//                                 ◀────────  pairChallenge{hostID, name, hostKey, hostNonce}
//  pairReveal{deviceKey, nonce}   ────────▶  checks C
//  both: shared = X25519, T = H(every field above), code = HKDF(shared, T) mod 10^6
//  person compares the 6-digit codes on both screens
//  pairConfirm{MAC(secret, T)}    ────────▶  checks MAC, waits for Allow
//                                 ◀────────  pairComplete{pairID, MAC(secret, T ‖ pairID)}

enum PairingError implements Exception {
  invalidKey,
  invalidNonce,
  commitmentMismatch,
  confirmationFailed,
  unexpectedMessage,
}

/// What the device keeps after pairing.
final class PairedHost {
  const PairedHost({required this.hostId, required this.hostName, required this.pairId, required this.secret});

  final String hostId;
  final String hostName;
  final String pairId;
  final Uint8List secret;
}

// The pure-Dart implementations, named outright: `X25519()` and friends would follow whatever
// `Cryptography.instance` is, and a platform plugin could change it under the checks below.
abstract final class PairingCrypto {
  static const nonceLength = 32;
  static final _random = Random.secure();
  static final _x25519 = DartX25519();
  static final _hmac = DartHmac.sha256();
  static const _sha256 = DartSha256();

  static Uint8List randomNonce() => Uint8List.fromList(List.generate(nonceLength, (_) => _random.nextInt(256)));

  static Future<SimpleKeyPair> newKeyPair() => _x25519.newKeyPair();

  /// [privateKey] is the 32 raw bytes, as CryptoKit's `rawRepresentation` gives them.
  @visibleForTesting
  static Future<SimpleKeyPair> keyPair(List<int> privateKey) => _x25519.newKeyPairFromSeed(privateKey);

  static Future<Uint8List> publicKey(SimpleKeyPair keyPair) async =>
      Uint8List.fromList((await keyPair.extractPublicKey()).bytes);

  static Future<Uint8List> commitment(List<int> deviceKey, List<int> deviceNonce) =>
      lengthPrefixedHash('porthole-commit-v1', [deviceKey, deviceNonce]);

  static Future<Uint8List> transcript(PairRequest request, PairChallenge challenge, PairReveal reveal) =>
      lengthPrefixedHash('porthole-pair-v1', [
        utf8.encode(request.deviceId),
        utf8.encode(request.deviceName),
        request.commitment,
        utf8.encode(challenge.hostId),
        utf8.encode(challenge.hostName),
        challenge.hostKey,
        challenge.hostNonce,
        reveal.deviceKey,
        reveal.deviceNonce,
      ]);

  /// The 6 digits both people compare, zero-padded.
  static Future<String> code(SecretKey shared, List<int> transcript) async {
    final bytes = await hkdf(shared, salt: transcript, info: 'porthole-sas-v1', length: 8);
    final value = bytes.fold(BigInt.zero, (value, byte) => value << 8 | BigInt.from(byte));
    return (value % BigInt.from(1000000)).toString().padLeft(6, '0');
  }

  static Future<Uint8List> secret(SecretKey shared, List<int> transcript) =>
      hkdf(shared, salt: transcript, info: 'porthole-pair-secret-v1', length: 32);

  static Future<Uint8List> deviceConfirmation(List<int> secret, List<int> transcript) =>
      mac(secret, 'device-confirm', [transcript]);

  static Future<Uint8List> hostConfirmation(List<int> secret, List<int> transcript, String pairId) =>
      mac(secret, 'host-confirm', [transcript, utf8.encode(pairId)]);

  /// HMAC-SHA256 over the length-prefixed label and parts.
  static Future<Uint8List> mac(List<int> secret, String label, List<List<int>> parts) async {
    final result = await _hmac.calculateMac(lengthPrefixed(label, parts), secretKey: SecretKey(secret));
    return Uint8List.fromList(result.bytes);
  }

  static bool verify(List<int> expected, List<int> actual) => constantTimeEquals(expected, actual);

  /// X25519 with the peer's raw public key. Refuses low-order keys, which would force a shared secret
  /// of zero that a man in the middle knows; CryptoKit refuses the same ones.
  static Future<SecretKey> agree(SimpleKeyPair keyPair, List<int> peerKey) async {
    if (peerKey.length != 32) throw PairingError.invalidKey;
    final List<int> shared;
    try {
      shared = await (await _x25519.sharedSecretKey(
        keyPair: keyPair,
        remotePublicKey: SimplePublicKey(peerKey, type: KeyPairType.x25519),
      ))
          .extractBytes();
    } catch (_) {
      throw PairingError.invalidKey;
    }
    if (shared.every((byte) => byte == 0)) throw PairingError.invalidKey;
    return SecretKeyData(shared);
  }

  static Future<Uint8List> hkdf(SecretKey key, {required List<int> salt, required String info, required int length}) async {
    final derived = await DartHkdf(hmac: _hmac, outputLength: length)
        .deriveKey(secretKey: key, nonce: salt, info: utf8.encode(info));
    return Uint8List.fromList(await derived.extractBytes());
  }
}

/// The length-prefixed bytes of a label and parts: each is a 4-byte big-endian length, then the bytes,
/// so no two different lists of fields produce the same bytes.
Uint8List lengthPrefixed(String label, List<List<int>> parts) {
  final out = BytesBuilder(copy: false);
  for (final part in [utf8.encode(label), ...parts]) {
    out
      ..add((ByteData(4)..setUint32(0, part.length)).buffer.asUint8List())
      ..add(part);
  }
  return out.toBytes();
}

Future<Uint8List> lengthPrefixedHash(String label, List<List<int>> parts) async =>
    Uint8List.fromList((await PairingCrypto._sha256.hash(lengthPrefixed(label, parts))).bytes);

enum _DeviceStage { created, requested, revealed, confirmed, done, busy }

/// The device's side of pairing. Await each call before making the next; a call that throws ends the
/// attempt, and pairing starts again on a new connection.
final class DevicePairing {
  DevicePairing._(this.deviceId, this.deviceName, this._keyPair, this._publicKey, this._nonce);

  /// A pairing attempt with a fresh key and nonce, as every attempt must have.
  static Future<DevicePairing> create({required String deviceId, required String deviceName}) async {
    final keyPair = await PairingCrypto.newKeyPair();
    return DevicePairing._(deviceId, deviceName, keyPair, await PairingCrypto.publicKey(keyPair), PairingCrypto.randomNonce());
  }

  /// With a fixed key and nonce, for the vectors. Reusing them would let a man in the middle try again
  /// and again for matching codes.
  @visibleForTesting
  static Future<DevicePairing> createWith({
    required String deviceId,
    required String deviceName,
    required List<int> privateKey,
    required List<int> nonce,
  }) async {
    final keyPair = await PairingCrypto.keyPair(privateKey);
    return DevicePairing._(deviceId, deviceName, keyPair, await PairingCrypto.publicKey(keyPair), Uint8List.fromList(nonce));
  }

  final String deviceId;
  final String deviceName;
  final SimpleKeyPair _keyPair;
  final Uint8List _publicKey;
  final Uint8List _nonce;
  var _stage = _DeviceStage.created;
  PairRequest? _request;
  PairChallenge? _challenge;
  Uint8List _transcript = Uint8List(0);
  Uint8List _secret = Uint8List(0);

  /// The code to show once the challenge arrives.
  String? code;

  Future<PairRequest> start() async {
    _advance(from: _DeviceStage.created);
    final request = PairRequest(
      deviceId: deviceId,
      deviceName: deviceName,
      commitment: await PairingCrypto.commitment(_publicKey, _nonce),
    );
    _request = request;
    _stage = _DeviceStage.requested;
    return request;
  }

  /// Returns the reveal to send and the code to show.
  Future<(PairReveal, String)> receiveChallenge(PairChallenge received) async {
    _advance(from: _DeviceStage.requested);
    // A copy that can't change while the checks below await.
    final challenge = received.deepCopy()..freeze();
    if (challenge.hostNonce.length != PairingCrypto.nonceLength) throw PairingError.invalidNonce;
    final shared = await PairingCrypto.agree(_keyPair, challenge.hostKey);
    final reveal = PairReveal(deviceKey: _publicKey, deviceNonce: _nonce);
    _transcript = await PairingCrypto.transcript(_request!, challenge, reveal);
    _secret = await PairingCrypto.secret(shared, _transcript);
    final code = await PairingCrypto.code(shared, _transcript);
    _challenge = challenge;
    this.code = code;
    _stage = _DeviceStage.revealed;
    return (reveal, code);
  }

  /// Call only after the person confirms the Mac shows the same code.
  Future<PairConfirm> confirm() async {
    _advance(from: _DeviceStage.revealed);
    final confirm = PairConfirm(mac: await PairingCrypto.deviceConfirmation(_secret, _transcript));
    _stage = _DeviceStage.confirmed;
    return confirm;
  }

  Future<PairedHost> receiveComplete(PairComplete complete) async {
    _advance(from: _DeviceStage.confirmed);
    final expected = await PairingCrypto.hostConfirmation(_secret, _transcript, complete.pairId);
    if (!PairingCrypto.verify(expected, complete.mac)) throw PairingError.confirmationFailed;
    _stage = _DeviceStage.done;
    final challenge = _challenge!;
    return PairedHost(hostId: challenge.hostId, hostName: challenge.hostName, pairId: complete.pairId, secret: _secret);
  }

  void _advance({required _DeviceStage from}) {
    if (_stage != from) throw PairingError.unexpectedMessage;
    _stage = _DeviceStage.busy;
  }
}
