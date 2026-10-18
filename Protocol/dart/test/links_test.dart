import 'dart:typed_data';

import 'package:glados/glados.dart';
import 'package:porthole_protocol/porthole_protocol.dart';

import 'support/generators.dart';
import 'support/host_pairing.dart';

/// Feeds every message to the link in order and collects what it said.
Future<List<LinkOutput>> feed(DeviceLink link, List<Wire> messages) async =>
    [for (final message in messages) ...await link.receive(message)];

bool isEnding(LinkOutput output) => output is CloseLink || output is PeerClosed;

PairedHost savedPairing(Uint8List secret) =>
    PairedHost(hostId: 'host', hostName: 'Mac', pairId: 'pair-1', secret: secret);

/// Plays the Mac for a whole pairing and session, the way HostLink does, and returns what the device
/// link said along the way.
Future<List<LinkOutput>> pairAndConnect(DeviceLink link, HostPairing host, List<Signal> toHost) async {
  final outputs = <LinkOutput>[];
  Wire sent() => outputs.whereType<SendWire>().last.message;

  outputs.addAll(await link.start());
  outputs.addAll(await link.receive(Wire(pairChallenge: host.receiveRequest(sent().pairRequest))));
  await host.receiveReveal(sent().pairReveal);
  outputs.addAll(await link.codesMatch());
  await host.receiveConfirm(sent().pairConfirm);
  final (complete, secret) = await host.complete('pair-1');
  outputs.addAll(await link.receive(Wire(pairComplete: complete)));

  final hello = sent().sessionHello;
  expect(await SessionHandshake.isValidHello(hello, secret), isTrue);
  final accept = await SessionHandshake.accept(hello, secret);
  outputs.addAll(await link.receive(Wire(sessionAccept: accept)));
  final channel = await SessionHandshake.channel(role: SessionRole.host, secret: secret, hello: hello, accept: accept);
  for (final signal in toHost) {
    expect(Signal.fromBuffer(channel.open(link.seal(signal).sealed)), signal);
    outputs.addAll(await link.receive(Wire(sealed: channel.seal(Signal(answer: signal.offer).writeToBuffer()))));
  }
  return outputs;
}

void main() {
  final config = ExploreConfig(numRuns: 100);

  group('properties', () {
    Glados2(any.bytesOfLength(32), any.list(any.wire), config).test(
      'prop_no_sequence_of_forged_messages_gets_a_saved_pairing_established',
      (secret, messages) async {
        final link = DeviceLink(deviceId: 'd', deviceName: 'iPad', pairing: savedPairing(secret));
        final outputs = [...await link.start(), ...await feed(link, messages)];
        expect(outputs.whereType<Established>(), isEmpty);
        expect(outputs.whereType<Deliver>(), isEmpty);
        expect(link.phase, isNot(LinkPhase.established));
      },
    );

    Glados(any.list(any.wire), config).test('prop_no_sequence_of_messages_completes_pairing_without_the_person',
        (messages) async {
      final link = DeviceLink(deviceId: 'd', deviceName: 'iPad');
      final outputs = [...await link.start(), ...await feed(link, messages)];
      expect(outputs.whereType<Paired>(), isEmpty);
      expect(outputs.whereType<Established>(), isEmpty);
    });

    Glados2(any.bytesOfLength(32), any.list(any.wire), config).test(
      'prop_a_link_ends_at_most_once_and_then_stays_quiet',
      (secret, messages) async {
        final link = DeviceLink(deviceId: 'd', deviceName: 'iPad', pairing: savedPairing(secret));
        final outputs = [...await link.start(), ...await feed(link, messages), ...await link.close(CloseReason.timedOut)];
        final firstEnd = outputs.indexWhere(isEnding);
        expect(outputs.where(isEnding).length, 1);
        expect(outputs.sublist(firstEnd + 1), isEmpty);
        expect(link.phase, LinkPhase.closed);
      },
    );

    Glados3(any.text, any.text, any.list(any.text), ExploreConfig(numRuns: 40)).test(
      'prop_pairing_with_the_mac_establishes_and_carries_sealed_messages_both_ways',
      (deviceName, hostName, offers) async {
        final link = DeviceLink(deviceId: 'd', deviceName: deviceName, expectedHostId: 'host');
        final host = await HostPairing.create(hostId: 'host', hostName: hostName);
        final outputs = await pairAndConnect(link, host, [for (final offer in offers) Signal(offer: offer)]);

        final paired = outputs.whereType<Paired>().single.host;
        expect((paired.hostId, paired.hostName, paired.pairId), ('host', hostName, 'pair-1'));
        expect(outputs.whereType<Established>().single.host.secret, paired.secret);
        expect([for (final deliver in outputs.whereType<Deliver>()) deliver.message.answer], offers);
        expect(outputs.where(isEnding), isEmpty);
      },
    );
  });

  test('a Mac answering with another ID is refused before any code is shown', () async {
    final link = DeviceLink(deviceId: 'd', deviceName: 'iPad', expectedHostId: 'the-mac-you-chose');
    final request = ((await link.start()).single as SendWire).message.pairRequest;
    final impostor = await HostPairing.create(hostId: 'another-mac', hostName: 'Mac');
    final outputs = await link.receive(Wire(pairChallenge: impostor.receiveRequest(request)));
    expect(outputs, [const CloseLink(CloseReason.pairingFailed)]);
  });

  test('a bye is reported once', () async {
    final link = DeviceLink(deviceId: 'd', deviceName: 'iPad');
    await link.start();
    expect(await link.receive(Wire(bye: Bye(reason: 'pairing-closed'))), [const PeerClosed('pairing-closed')]);
    expect(await link.receive(Wire(bye: Bye(reason: 'again'))), isEmpty);
  });

  test('saying the codes differ closes with pairing-failed', () async {
    final link = DeviceLink(deviceId: 'd', deviceName: 'iPad');
    final request = ((await link.start()).single as SendWire).message.pairRequest;
    final host = await HostPairing.create(hostId: 'host', hostName: 'Mac');
    await link.receive(Wire(pairChallenge: host.receiveRequest(request)));
    expect(link.phase, LinkPhase.comparingCodes);
    expect(await link.codesDiffer(), [const CloseLink(CloseReason.pairingFailed)]);
  });

  test('sealing before the session is up is refused', () async {
    final link = DeviceLink(deviceId: 'd', deviceName: 'iPad', pairing: savedPairing(Uint8List(32)));
    await link.start();
    expect(() => link.seal(Signal(offer: 'v=0')), throwsA(isA<NotEstablished>()));
  });

  test('frames fed without awaiting are handled in order', () async {
    final link = DeviceLink(deviceId: 'd', deviceName: 'iPad');
    final start = link.start();
    final bye = link.receive(Wire(bye: Bye(reason: 'host-stopped')));
    expect((await start).single, isA<SendWire>());
    expect(await bye, [const PeerClosed('host-stopped')]);
  });

  test('every close reason round-trips through its wire name', () {
    for (final reason in CloseReason.values) {
      expect(CloseReason.fromWire(reason.wireName), reason);
    }
    expect(CloseReason.fromWire('from-a-newer-mac'), isNull);
  });
}
