import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test, setUp, tearDown;
import 'package:porthole/client/pairing_store.dart';
import 'package:porthole_protocol/porthole_protocol.dart';

extension PairingAnys on Any {
  Generator<String> get text => listWithLengthInRange(0, 12, choose(const ['a', 'Z', '’', '"', r'\', '\n', '👨‍👩‍👧', ' ', '{', '9']))
      .map((parts) => parts.join());
  Generator<String> get nonEmptyText => text.map((s) => s.isEmpty ? 'x' : s);
  Generator<Uint8List> get secret =>
      listWithLength(PairedHostCodec.secretLength, intInRange(0, 256)).map(Uint8List.fromList);

  /// Records as the Swift app left them: whole pairings for a few Macs, and damaged text.
  Generator<String> get swiftAppRecord => oneOf([
        combine2(choose(const ['mac-1', 'mac-2', 'mac-3']), pairedHost,
            (String id, PairedHost host) => PairedHostCodec.encode(
                PairedHost(hostId: id, hostName: host.hostName, pairId: host.pairId, secret: host.secret))),
        text,
      ]);

  Generator<PairedHost> get pairedHost => combine4(nonEmptyText, text, nonEmptyText, secret,
      (String hostId, String hostName, String pairId, Uint8List secret) =>
          PairedHost(hostId: hostId, hostName: hostName, pairId: pairId, secret: secret));
}

void expectSameHost(PairedHost? actual, PairedHost expected) {
  expect(actual, isNotNull);
  expect((actual!.hostId, actual.hostName, actual.pairId), (expected.hostId, expected.hostName, expected.pairId));
  expect(actual.secret, expected.secret);
}

void main() {
  Glados(any.pairedHost, ExploreConfig(numRuns: 300)).test('prop_a_saved_pairing_reads_back_the_same', (host) {
    expectSameHost(PairedHostCodec.decode(PairedHostCodec.encode(host)), host);
  });

  Glados(any.text, ExploreConfig(numRuns: 300)).test('prop_damaged_text_never_throws_and_never_half_reads', (text) {
    final decoded = PairedHostCodec.decode(text);
    if (decoded != null) {
      expect(decoded.hostId.isNotEmpty && decoded.pairId.isNotEmpty, isTrue);
      expect(decoded.secret.length, PairedHostCodec.secretLength);
    }
  });

  Glados(any.intInRange(0, 1 << 30)).test('prop_device_ids_are_version_4_uuids', (seed) {
    final id = randomUuid(Random(seed));
    expect(RegExp(r'^[0-9A-F]{8}-[0-9A-F]{4}-4[0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}$').hasMatch(id), isTrue);
  });

  Glados(any.listWithLengthInRange(0, 8, any.swiftAppRecord), ExploreConfig(numRuns: 300))
      .test('prop_an_update_carries_over_the_last_whole_pairing_for_each_mac', (records) {
    final carried = carriedOver(records);
    final ids = [for (final host in carried) host.hostId];
    expect(ids.toSet().length, ids.length);
    final whole = [for (final record in records) ?PairedHostCodec.decode(record)];
    expect(ids.toSet(), {for (final host in whole) host.hostId});
    for (final host in carried) {
      expectSameHost(host, whole.lastWhere((h) => h.hostId == host.hostId));
    }
  });

  test('a record exactly as the Swift app’s JSONEncoder wrote it carries over', () {
    // From PortholeSession's KeychainPairingStore: keys in any order, slashes escaped, secret in base64.
    const record = '{"hostName":"Ngoni’s MacBook Pro\\/Studio","secret":"BwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP8=",'
        '"hostID":"3F2A9C1E-0B7D-4E58-9A61-2C4D8E0F1B3A","pairID":"8D1E5B7A-6C3F-4A92-B0E4-7F2C9D1A5E68"}';
    final host = carriedOver([record]).single;
    expect((host.hostId, host.hostName, host.pairId),
        ('3F2A9C1E-0B7D-4E58-9A61-2C4D8E0F1B3A', 'Ngoni’s MacBook Pro/Studio', '8D1E5B7A-6C3F-4A92-B0E4-7F2C9D1A5E68'));
    expect(host.secret, Uint8List(32)
      ..[0] = 7
      ..[31] = 0xFF);
  });

  test('installed over the Swift app, its pairings and device ID carry over', () async {
    final store = MemoryPairingStore();
    final record = PairedHostCodec.encode(PairedHost(hostId: 'mac-1', hostName: 'Studio Mac', pairId: 'pair-1', secret: Uint8List(32)));
    await settleInstall(store, UpdatedFromSwiftApp('SWIFT-DEVICE-ID', [record, 'not a pairing']));
    expect((await store.all()).map((h) => h.hostId), ['mac-1']);
    expect(await store.deviceId(), 'SWIFT-DEVICE-ID');
  });

  test('a fresh install drops whatever the Keychain kept from before', () async {
    final store = MemoryPairingStore([PairedHost(hostId: 'mac-1', hostName: 'Studio Mac', pairId: 'pair-1', secret: Uint8List(32))]);
    final before = await store.deviceId();
    await settleInstall(store, const FreshInstall());
    expect(await store.all(), isEmpty);
    expect(await store.deviceId(), isNot(before));
    await store.save(PairedHost(hostId: 'mac-2', hostName: 'MacBook', pairId: 'pair-2', secret: Uint8List(32)));
    await settleInstall(store, const KnownInstall());
    expect((await store.all()).single.hostId, 'mac-2');
  });

  test('what AppDelegate reports', () {
    expect(InstallState.fromPlatform({'state': 'known'}), isA<KnownInstall>());
    expect(InstallState.fromPlatform({'state': 'fresh'}), isA<FreshInstall>());
    final update = InstallState.fromPlatform({'state': 'upgrade', 'deviceId': 'D', 'pairings': ['a', 7, null, 'b']});
    expect(update, isA<UpdatedFromSwiftApp>().having((u) => u.deviceId, 'device ID', 'D').having((u) => u.records, 'records', ['a', 'b']));
    expect(InstallState.fromPlatform({'state': 'upgrade', 'deviceId': '', 'pairings': <Object?>[]}), isNull);
    expect(InstallState.fromPlatform({'state': 'upgrade'}), isNull);
    expect(InstallState.fromPlatform('known'), isNull);
    expect(InstallState.fromPlatform(null), isNull);
  });

  test('a pairing with a short secret or a missing field is skipped', () {
    final good = PairedHost(hostId: 'h', hostName: 'Mac', pairId: 'p', secret: Uint8List(32));
    final json = jsonDecode(PairedHostCodec.encode(good)) as Map<String, dynamic>;
    expect(PairedHostCodec.decode(jsonEncode({...json, 'secret': base64Encode(Uint8List(16))})), isNull);
    expect(PairedHostCodec.decode(jsonEncode({...json}..remove('pairID'))), isNull);
    expect(PairedHostCodec.decode(jsonEncode({...json, 'secret': '%%%'})), isNull);
    expect(PairedHostCodec.decode('[1,2]'), isNull);
  });

  test('the memory store saves, lists in host order, and forgets', () async {
    final store = MemoryPairingStore();
    final b = PairedHost(hostId: 'b', hostName: 'B', pairId: 'p2', secret: Uint8List(32));
    final a = PairedHost(hostId: 'a', hostName: 'A', pairId: 'p1', secret: Uint8List(32));
    await store.save(b);
    await store.save(a);
    expect((await store.all()).map((h) => h.hostId), ['a', 'b']);
    await store.remove('a');
    expect((await store.all()).map((h) => h.hostId), ['b']);
    expect(await store.deviceId(), await store.deviceId());
  });
}
