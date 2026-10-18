import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:porthole_protocol/porthole_protocol.dart';

/// The Mac's side of pairing, as in Pairing.swift, so the tests can pair a Dart device with something.
/// Apps never need it: the host is always the Mac.
final class HostPairing {
  HostPairing._(this.hostId, this.hostName, this._keyPair, this._publicKey, this._nonce);

  static Future<HostPairing> create({
    required String hostId,
    required String hostName,
    List<int>? privateKey,
    List<int>? nonce,
  }) async {
    final keyPair = privateKey == null ? await PairingCrypto.newKeyPair() : await PairingCrypto.keyPair(privateKey);
    return HostPairing._(hostId, hostName, keyPair, await PairingCrypto.publicKey(keyPair),
        Uint8List.fromList(nonce ?? PairingCrypto.randomNonce()));
  }

  final String hostId;
  final String hostName;
  final SimpleKeyPair _keyPair;
  final Uint8List _publicKey;
  final Uint8List _nonce;
  PairRequest? _request;
  PairChallenge? _challenge;
  Uint8List _transcript = Uint8List(0);
  Uint8List _secret = Uint8List(0);
  var _confirmed = false;

  PairChallenge receiveRequest(PairRequest request) {
    if (_request != null) throw PairingError.unexpectedMessage;
    if (request.commitment.length != 32) throw PairingError.commitmentMismatch;
    _request = request;
    return _challenge = PairChallenge(hostId: hostId, hostName: hostName, hostKey: _publicKey, hostNonce: _nonce);
  }

  /// Checks the commitment and returns the code to show.
  Future<String> receiveReveal(PairReveal reveal) async {
    final request = _request, challenge = _challenge;
    if (request == null || challenge == null || _transcript.isNotEmpty) throw PairingError.unexpectedMessage;
    if (reveal.deviceNonce.length != PairingCrypto.nonceLength) throw PairingError.invalidNonce;
    final expected = await PairingCrypto.commitment(reveal.deviceKey, reveal.deviceNonce);
    if (!PairingCrypto.verify(expected, request.commitment)) throw PairingError.commitmentMismatch;
    final shared = await PairingCrypto.agree(_keyPair, reveal.deviceKey);
    _transcript = await PairingCrypto.transcript(request, challenge, reveal);
    _secret = await PairingCrypto.secret(shared, _transcript);
    return PairingCrypto.code(shared, _transcript);
  }

  Future<void> receiveConfirm(PairConfirm confirm) async {
    if (_transcript.isEmpty || _confirmed) throw PairingError.unexpectedMessage;
    final expected = await PairingCrypto.deviceConfirmation(_secret, _transcript);
    if (!PairingCrypto.verify(expected, confirm.mac)) throw PairingError.confirmationFailed;
    _confirmed = true;
  }

  /// Returns the message to send and the secret the Mac keeps.
  Future<(PairComplete, Uint8List)> complete(String pairId) async {
    if (!_confirmed) throw PairingError.unexpectedMessage;
    final mac = await PairingCrypto.hostConfirmation(_secret, _transcript, pairId);
    return (PairComplete(pairId: pairId, mac: mac), _secret);
  }
}
