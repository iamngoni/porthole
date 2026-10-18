import 'dart:async';

import 'package:porthole_protocol/porthole_protocol.dart';

import 'host_browser.dart';

/// The TCP connection to a Mac, as the controller sees it. Tests drive a fake.
abstract interface class Signaling {
  /// Messages and the end of the connection, in order. Listen once.
  Stream<ConnectionEvent> get events;
  void send(Wire message);

  /// Says why, then closes.
  Future<void> closeWith(CloseReason reason);

  /// Closes without a word.
  Future<void> close();
}

typedef Connector = Future<Signaling> Function(DiscoveredHost host);

/// Tries each of the Mac's addresses in turn, best first.
// no-prop-test: glue over sockets; SignalingConnection itself is covered by the protocol package's interop tests.
Future<Signaling> connectToHost(DiscoveredHost host) async {
  Object? lastError;
  for (final target in host.targets) {
    try {
      return _Connection(await SignalingConnection.connect(target, host.port));
    } catch (error) {
      lastError = error;
    }
  }
  throw lastError ?? StateError('${host.name} has no address yet');
}

final class _Connection implements Signaling {
  _Connection(this._connection);
  final SignalingConnection _connection;

  @override
  Stream<ConnectionEvent> get events => _connection.events;
  @override
  void send(Wire message) => _connection.send(message);
  @override
  Future<void> closeWith(CloseReason reason) => _connection.closeWith(reason);
  @override
  Future<void> close() => _connection.close();
}
