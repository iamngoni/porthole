import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porthole/client/client_controller.dart';
import 'package:porthole/client/host_browser.dart';
import 'package:porthole/client/pairing_store.dart';

import 'support/fakes.dart';

// The app's controller against the real Swift HostLink over loopback TCP: pairing with the code, saving
// the pairing, the hello, and reconnecting with the saved pairing. ./test.sh builds the host and passes
// its path in PORTHOLE_INTEROP_HOST; without it these tests are skipped.

final _hostPath = Platform.environment['PORTHOLE_INTEROP_HOST'];

final class _Host {
  _Host(this._process) {
    _process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      _lines.add(line);
      _changed.add(null);
    });
  }

  final Process _process;
  final _lines = <String>[];
  final _changed = StreamController<void>.broadcast();
  var _read = 0;

  Future<String> line(String prefix) async {
    while (true) {
      for (; _read < _lines.length; _read++) {
        if (_lines[_read].startsWith(prefix)) return _lines[_read++];
      }
      await _changed.stream.first.timeout(const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException('host never printed "$prefix"; it printed $_lines'));
    }
  }

  Future<void> stop() async {
    await _process.stdin.close();
    await _process.exitCode.timeout(const Duration(seconds: 5), onTimeout: () {
      _process.kill();
      return -1;
    });
  }
}

void main() {
  test('pairs with the code, says hello, and reconnects with the saved pairing',
      skip: _hostPath == null ? 'set PORTHOLE_INTEROP_HOST (./test.sh does)' : null, () async {
    final host = _Host(await Process.start(_hostPath!, []));
    addTearDown(host.stop);
    final port = int.parse((await host.line('listening ')).split(' ').last);
    final store = MemoryPairingStore();
    final controller = ClientController(
      deviceId: 'device-1',
      deviceName: 'Test iPad',
      store: store,
      makePeer: FakePeer.new,
      screen: () => (width: 2752, height: 2064, refreshRate: 120),
      keepAwake: (_) async {},
    );
    addTearDown(controller.dispose);
    final mac = DiscoveredHost(name: 'Interop Mac', hostId: 'interop-host', addresses: const ['127.0.0.1'], port: port);

    controller.connect(mac);
    final code = (await host.line('code ')).split(' ').last;
    await Harness.until(() => controller.phase is ComparingCode, rounds: 5000);
    expect(controller.phase, ComparingCode('Interop Mac', code));

    controller.codesMatch();
    expect(await host.line('paired '), 'paired Test iPad');
    expect(await host.line('deliver hello'), 'deliver hello Test iPad 2752x2064');
    await Harness.until(() => controller.pairedHosts.isNotEmpty, rounds: 5000);
    expect(controller.pairedHosts.single.hostId, 'interop-host');
    expect(controller.phase, const Connecting('Interop Mac'));

    controller.disconnect();
    expect(await host.line('peer-closed '), 'peer-closed disconnected');

    // Back again: no code this time.
    controller.connect(mac);
    expect(await host.line('established'), 'established');
    expect(await host.line('deliver hello'), 'deliver hello Test iPad 2752x2064');
    expect(controller.problem, isNull);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
