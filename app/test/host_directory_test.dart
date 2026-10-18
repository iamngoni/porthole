import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test, setUp, tearDown;
import 'package:porthole/client/host_browser.dart';

// The Mac list the Bonjour browser keeps, checked against a plain map of what was last seen per name.

sealed class Op {
  const Op();
}

final class Resolve extends Op {
  const Resolve(this.host);
  final DiscoveredHost host;
  @override
  String toString() => 'Resolve($host)';
}

final class Lose extends Op {
  const Lose(this.name);
  final String name;
  @override
  String toString() => 'Lose($name)';
}

extension DirectoryAnys on Any {
  /// Few names, so the same Mac comes and goes, in mixed case so sorting is tested.
  Generator<String> get macName => choose(const ['Studio', 'studio', 'Air', 'b-Mac', 'Ngoni’s Mac', 'Zed']);

  Generator<DiscoveredHost> get host => combine4(
        macName,
        choose(const [null, 'id-1', 'id-2']),
        listWithLengthInRange(0, 3, choose(const ['192.168.1.5', 'fe80::1', '10.0.0.2', '2001:db8::1'])),
        choose(const [null, 'Studio.local.']),
        (String name, String? id, List<String> addresses, String? hostname) =>
            DiscoveredHost(name: name, hostId: id, addresses: addresses, hostname: hostname, port: 47801),
      );

  Generator<Op> get op => oneOf([host.map<Op>(Resolve.new), macName.map<Op>(Lose.new)]);
}

void main() {
  Glados(any.listWithLengthInRange(0, 40, any.op), ExploreConfig(numRuns: 400))
      .test('prop_the_list_holds_one_sorted_entry_per_name_seen_and_not_lost', (ops) {
    final directory = HostDirectory();
    final model = <String, DiscoveredHost>{};
    for (final op in ops) {
      switch (op) {
        case Resolve(:final host):
          final known = model[host.name]?.hostId;
          model[host.name] = host.hostId == null && known != null ? host.copyWith(hostId: known) : host;
          directory.resolved(host);
        case Lose(:final name):
          model.remove(name);
          directory.lost(name);
      }
      final hosts = directory.hosts;
      expect(hosts.map((h) => h.name).toSet(), model.keys.toSet());
      expect(hosts.length, model.length);
      for (final host in hosts) {
        expect(host, model[host.name]);
      }
      for (var i = 1; i < hosts.length; i++) {
        expect(hosts[i - 1].name.toLowerCase().compareTo(hosts[i].name.toLowerCase()) <= 0, isTrue);
      }
    }
  });

  Glados(any.host).test('prop_targets_put_ipv4_first_and_repeat_nothing', (host) {
    final targets = host.targets;
    expect(targets.toSet().length, targets.length);
    expect(targets.toSet(), {...host.addresses, ?host.hostname});
    final firstOther = targets.indexWhere((t) => !RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(t));
    if (firstOther >= 0) {
      expect(targets.skip(firstOther).any((t) => RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(t)), isFalse);
    }
  });

  test('a record without the ID keeps the one already known', () {
    final directory = HostDirectory();
    expect(directory.resolved(const DiscoveredHost(name: 'Studio', hostId: 'id-1', port: 1)), isTrue);
    expect(directory.resolved(const DiscoveredHost(name: 'Studio', port: 1)), isFalse);
    expect(directory.hosts.single.hostId, 'id-1');
    expect(directory.lost('Studio'), isTrue);
    expect(directory.lost('Studio'), isFalse);
  });

  test('IPv4, then the name, then IPv6', () {
    const host = DiscoveredHost(name: 'S', addresses: ['fe80::1', '192.168.1.5'], hostname: 'S.local.', port: 1);
    expect(host.targets, ['192.168.1.5', 'S.local.', 'fe80::1']);
  });
}
