import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'framing.dart';
import 'generated/porthole.pb.dart';
import 'links.dart';
import 'wire.dart';

/// The Bonjour service type the Mac advertises.
const portholeBonjourType = '_porthole._tcp';

/// The Bonjour TXT key that carries the Mac's stable ID, so a device knows which pairing to use.
const portholeHostIdKey = 'id';

/// The port the Mac listens on when it's free, so a device can reach it by name or address where Bonjour
/// doesn't (over Tailscale or another VPN). PortholeProtocol's `portholeSignalingPort` on the Swift side.
const portholeSignalingPort = 47801;

sealed class ConnectionEvent {
  const ConnectionEvent();
}

final class ConnectionMessage extends ConnectionEvent {
  const ConnectionMessage(this.message);
  final Wire message;
}

/// The Mac speaks another protocol version; the connection is closing.
final class ConnectionIncompatible extends ConnectionEvent {
  const ConnectionIncompatible(this.version, this.reason);
  final int version;
  final String? reason;
}

final class ConnectionClosed extends ConnectionEvent {
  const ConnectionClosed([this.error]);
  final Object? error;
}

/// A framed TCP connection carrying versioned `Wire` messages, as SignalingConnection in LANSignaling.swift.
final class SignalingConnection {
  SignalingConnection._(this._socket) {
    _subscription = _socket.listen(_receive, onError: _finish, onDone: () => _finish(null), cancelOnError: true);
  }

  /// How long to wait for an unreachable Mac (say, a stale Bonjour record) before giving up.
  static const connectTimeout = Duration(seconds: 10);

  static Future<SignalingConnection> connect(Object host, int port) async {
    final socket = await Socket.connect(host, port, timeout: connectTimeout);
    socket.setOption(SocketOption.tcpNoDelay, true);
    return SignalingConnection._(socket);
  }

  final Socket _socket;
  late final StreamSubscription<Uint8List> _subscription;
  final _decoder = FrameDecoder();
  final _events = StreamController<ConnectionEvent>();
  var _isClosed = false;
  var _isClosing = false;

  /// Messages and the end of the connection, in order. Listen once.
  Stream<ConnectionEvent> get events => _events.stream;

  void send(Wire message) {
    if (_isClosed || _isClosing) return;
    _socket.add(Framing.frame(WireCoding.encode(message)));
  }

  /// Says why, then closes once that has gone out.
  Future<void> closeWith(CloseReason reason) => _closeSending(WireCoding.encode(Wire(bye: Bye(reason: reason.wireName))));

  /// Closes without a word, for when the other side is already gone.
  Future<void> close() async {
    if (_isClosing) return;
    _isClosing = true;
    _socket.destroy();
    _finish(null);
  }

  /// Sends one last frame, then closes. Closing straight after a write can drop it, and the Mac would
  /// only see a lost connection.
  Future<void> _closeSending(Uint8List payload) async {
    if (_isClosed || _isClosing) return;
    _isClosing = true;
    _socket.add(Framing.frame(payload));
    try {
      await _socket.flush().timeout(const Duration(seconds: 1));
      await _socket.close().timeout(const Duration(seconds: 1));
    } catch (_) {
      // The Mac stopped reading; fall through and drop the socket.
    }
    _socket.destroy();
    _finish(null);
  }

  void _receive(Uint8List bytes) {
    if (_isClosed) return;
    try {
      for (final frame in _decoder.append(bytes)) {
        switch (WireCoding.decode(frame)) {
          case WireFrame(:final wire):
            _events.add(ConnectionMessage(wire));
          case UnsupportedVersion(:final version, :final reason):
            _events.add(ConnectionIncompatible(version, reason));
            if (version <= WireCoding.lastJsonVersion) {
              // A Mac from before v3 only reads JSON; tell it in its own format.
              _closeSending(WireCoding.legacyBye(CloseReason.versionMismatch.wireName));
            } else {
              closeWith(CloseReason.versionMismatch);
            }
            return;
        }
        if (_isClosed || _isClosing) return;
      }
    } catch (error) {
      _socket.destroy();
      _finish(error);
    }
  }

  void _finish(Object? error) {
    if (_isClosed) return;
    _isClosed = true;
    _subscription.cancel();
    _events
      ..add(ConnectionClosed(error))
      ..close();
  }
}
