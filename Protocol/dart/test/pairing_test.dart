import 'dart:typed_data';

import 'package:glados/glados.dart';
import 'package:porthole_protocol/porthole_protocol.dart';

import 'support/generators.dart';
import 'support/host_pairing.dart';

/// Everything that varies between two pairing attempts.
final class Setup {
  Setup(this.deviceKey, this.hostKey, this.deviceNonce, this.hostNonce, this.deviceName, this.hostName);
  final Uint8List deviceKey, hostKey, deviceNonce, hostNonce;
  final String deviceName, hostName;

  Future<(DevicePairing, HostPairing)> parties() async => (
        await DevicePairing.createWith(deviceId: 'device', deviceName: deviceName, privateKey: deviceKey, nonce: deviceNonce),
        await HostPairing.create(hostId: 'host', hostName: hostName, privateKey: hostKey, nonce: hostNonce),
      );

  @override
  String toString() => 'Setup(device ${toHex(deviceKey)}, host ${toHex(hostKey)}, "$deviceName", "$hostName")';
}

extension on Any {
  Generator<Setup> get setup => combine6(bytesOfLength(32), bytesOfLength(32), bytesOfLength(32), bytesOfLength(32), text,
      text, Setup.new);
}

Uint8List flipped(List<int> bytes, int index) => Uint8List.fromList(bytes)..[index % bytes.length] ^= 0x01;

void main() {
  final config = ExploreConfig(numRuns: 60);

  group('properties', () {
    Glados(any.setup, config).test('prop_both_sides_show_the_same_code_and_keep_the_same_secret', (setup) async {
      final (device, host) = await setup.parties();
      final challenge = host.receiveRequest(await device.start());
      final (reveal, deviceCode) = await device.receiveChallenge(challenge);
      final hostCode = await host.receiveReveal(reveal);
      await host.receiveConfirm(await device.confirm());
      final (complete, hostSecret) = await host.complete('pair-1');
      final paired = await device.receiveComplete(complete);

      expect(deviceCode, hostCode);
      expect(deviceCode, matches(RegExp(r'^\d{6}$')));
      expect(paired.secret, hostSecret);
      expect((paired.hostId, paired.hostName, paired.pairId), ('host', setup.hostName, 'pair-1'));
    });

    Glados2(any.setup, any.positiveIntOrZero, config).test(
      'prop_a_reveal_that_does_not_open_the_commitment_is_refused',
      (setup, index) async {
        final (device, host) = await setup.parties();
        final (reveal, _) = await device.receiveChallenge(host.receiveRequest(await device.start()));
        final forged = PairReveal(deviceKey: reveal.deviceKey, deviceNonce: flipped(reveal.deviceNonce, index));
        await expectLater(host.receiveReveal(forged), throwsA(PairingError.commitmentMismatch));
      },
    );

    Glados2(any.setup, any.positiveIntOrZero, config).test(
      'prop_a_completion_the_mac_did_not_sign_is_refused',
      (setup, index) async {
        final (device, host) = await setup.parties();
        final (reveal, _) = await device.receiveChallenge(host.receiveRequest(await device.start()));
        await host.receiveReveal(reveal);
        await host.receiveConfirm(await device.confirm());
        final (complete, _) = await host.complete('pair-1');
        final forged = PairComplete(pairId: complete.pairId, mac: flipped(complete.mac, index));
        await expectLater(device.receiveComplete(forged), throwsA(PairingError.confirmationFailed));
      },
    );

    Glados(any.setup, config).test('prop_a_completion_for_another_pairing_is_refused', (setup) async {
      final (device, host) = await setup.parties();
      final (reveal, _) = await device.receiveChallenge(host.receiveRequest(await device.start()));
      await host.receiveReveal(reveal);
      await host.receiveConfirm(await device.confirm());
      final (complete, _) = await host.complete('pair-1');
      final moved = PairComplete(pairId: 'pair-2', mac: complete.mac);
      await expectLater(device.receiveComplete(moved), throwsA(PairingError.confirmationFailed));
    });
  });

  Future<DevicePairing> device() => DevicePairing.create(deviceId: 'device', deviceName: 'iPad');

  test('steps out of order are refused', () async {
    final pairing = await device();
    await expectLater(pairing.confirm(), throwsA(PairingError.unexpectedMessage));
    await pairing.start();
    await expectLater(pairing.start(), throwsA(PairingError.unexpectedMessage));
  });

  test('a short host nonce is refused', () async {
    final pairing = await device();
    await pairing.start();
    final host = await HostPairing.create(hostId: 'host', hostName: 'Mac');
    final challenge = host.receiveRequest(PairRequest(commitment: Uint8List(32)));
    challenge.hostNonce = Uint8List(31);
    await expectLater(pairing.receiveChallenge(challenge), throwsA(PairingError.invalidNonce));
  });

  test('a host key of the wrong length is refused', () async {
    final pairing = await device();
    await pairing.start();
    final challenge = PairChallenge(hostKey: Uint8List(31), hostNonce: Uint8List(32));
    await expectLater(pairing.receiveChallenge(challenge), throwsA(PairingError.invalidKey));
  });

  test('a fresh device pairing uses a fresh key and nonce', () async {
    final first = await (await device()).start(), second = await (await device()).start();
    expect(first.commitment, isNot(second.commitment));
  });
}
