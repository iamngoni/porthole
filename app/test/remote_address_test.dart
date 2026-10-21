import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test, setUp, tearDown;
import 'package:porthole/client/host_browser.dart';
import 'package:porthole/client/remote_address.dart';
import 'package:porthole_protocol/porthole_protocol.dart';

// glados runs every property from a fixed seed (Random(42)) and shrinks failures.

extension AddressAnys on Any {
  /// A DNS label as Tailscale makes them: starting with a letter, hyphens only inside.
  Generator<String> get label => listWithLengthInRange(0, 12, choose('abcxyz019-'.split('')))
      .map((chars) => 'm${chars.join()}')
      .map((label) => label.endsWith('-') ? '${label}0' : label);

  /// Tailscale-style names, IPv4 and IPv6 addresses, each with the usual port or another.
  Generator<RemoteAddress> get remoteAddress => combine2(
        oneOf([
          listWithLengthInRange(1, 4, label).map((labels) => labels.join('.')),
          listWithLength(4, intInRange(0, 256)).map((parts) => parts.join('.')),
          listWithLength(3, intInRange(0, 0x10000)).map((parts) => 'fd7a:${parts.map((p) => p.toRadixString(16)).join(':')}::1'),
        ]),
        oneOf([choose(const [portholeSignalingPort]), intInRange(1, 65536)]),
        (String host, int port) => RemoteAddress(host, port),
      );

  /// What someone might type: pieces of names, addresses, ports, schemes, spaces and stray symbols.
  Generator<String> get typed => listWithLengthInRange(0, 10, choose(const [
        'studio-mac', '.', ':', '[', ']', '100', '47801', 'fd7a', '::', ' ', 'http://', '/', '-', '%en0', 'Ünï', '99999', '0',
      ])).map((parts) => parts.join());
}

void main() {
  Glados(any.remoteAddress, ExploreConfig(numRuns: 400)).test('prop_an_address_reads_back_the_same', (address) {
    expect(RemoteAddress.parse(address.text), address);
  });

  Glados(any.typed, ExploreConfig(numRuns: 500)).test('prop_reading_typed_text_never_throws_and_settles', (typed) {
    final address = RemoteAddress.parse(typed);
    if (address == null) return;
    expect(address.port, inInclusiveRange(1, 65535));
    expect(address.host, isNot(contains(' ')));
    // Reading what it shows gives the same address back.
    expect(RemoteAddress.parse(address.text), address);
  });

  Glados(any.remoteAddress, ExploreConfig(numRuns: 300)).test('prop_a_remote_mac_is_reached_only_at_its_address', (address) {
    final pairing = PairedHost(hostId: 'host-1', hostName: 'Studio Mac', pairId: 'pair-1', secret: Uint8List(32));
    final host = DiscoveredHost.remote(pairing, address);
    expect(host.targets, [address.host]);
    expect(host.port, address.port);
    // It goes by the pairing, so the handshake checks the Mac it paired with.
    expect((host.hostId, host.name, host.remote), (pairing.hostId, pairing.hostName, address));
  });

  test('Tailscale names and addresses', () {
    expect(RemoteAddress.parse('studio-mac'), const RemoteAddress('studio-mac'));
    expect(RemoteAddress.parse('  Studio-Mac.tail1234.ts.net  '), const RemoteAddress('studio-mac.tail1234.ts.net'));
    expect(RemoteAddress.parse('100.101.102.103'), const RemoteAddress('100.101.102.103'));
    expect(RemoteAddress.parse('fd7a:115c:a1e0::1'), const RemoteAddress('fd7a:115c:a1e0::1'));
    expect(RemoteAddress.parse('studio-mac')!.port, portholeSignalingPort);
  });

  test('a port of its own', () {
    expect(RemoteAddress.parse('studio-mac:47900'), const RemoteAddress('studio-mac', 47900));
    expect(RemoteAddress.parse('[fd7a:115c:a1e0::1]:47900'), const RemoteAddress('fd7a:115c:a1e0::1', 47900));
    expect(const RemoteAddress('studio-mac', 47900).text, 'studio-mac:47900');
    expect(const RemoteAddress('fd7a::1', 47900).text, '[fd7a::1]:47900');
    expect(const RemoteAddress('studio-mac').text, 'studio-mac');
  });

  test('typos and things that aren’t an address', () {
    for (final text in [
      '', '   ', 'studio mac', 'http://studio-mac', 'studio-mac/', 'studio-mac:', 'studio-mac:0', 'studio-mac:65536',
      'studio-mac:+1', 'studio-mac:047801', '100.101.102.300', '100.101.102', '-studio', 'studio_mac', '[studio-mac]:1',
      'fe80::1%en0', '[fd7a::1', '[fd7a::1]x', 'ünïcode',
    ]) {
      expect(RemoteAddress.parse(text), isNull, reason: text);
    }
  });

  test('a name of digits alone is read as an address, so it must be one', () {
    // Found by prop_an_address_reads_back_the_same: "0" is neither a name nor an IPv4 address.
    expect(RemoteAddress.parse('0'), isNull);
    expect(RemoteAddress.parse('0.0.0.0'), const RemoteAddress('0.0.0.0'));
    expect(RemoteAddress.parse('mac0'), const RemoteAddress('mac0'));
  });

  test('names and addresses are told apart', () {
    expect(const RemoteAddress('100.101.102.103').isIp, isTrue);
    expect(const RemoteAddress('fd7a::1').isIp, isTrue);
    expect(const RemoteAddress('studio-mac').isIp, isFalse);
  });
}
