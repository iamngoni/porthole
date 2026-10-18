import 'dart:async';

import 'generated/porthole.pb.dart';
import 'messages.dart';
import 'pairing.dart';
import 'secure_channel.dart';

// The device's side of a signaling connection as a pure state machine, as DeviceLink in Links.swift:
// feed it what arrived, act on what it returns. Every decision about trusting the Mac lives here.

/// Why a side closed the connection, sent as `Bye.reason`.
enum CloseReason {
  /// The Mac isn't accepting new devices; choose Pair New Device on the Mac first.
  pairingClosed('pairing-closed'),
  pairingDenied('pairing-denied'),

  /// The pairing exchange didn't check out, most likely because the codes differed.
  pairingFailed('pairing-failed'),

  /// Two devices tried to pair at once, so the Mac stopped pairing rather than guess which is yours.
  pairingContested('pairing-contested'),

  /// The Mac doesn't know this pairing (it was removed there).
  unknownPairing('unknown-pairing'),
  handshakeFailed('handshake-failed'),
  badFrame('bad-frame'),
  unexpectedMessage('unexpected-message'),
  replaced('replaced'),
  disconnected('disconnected'),
  hostStopped('host-stopped'),
  versionMismatch('version-mismatch'),
  timedOut('timed-out');

  const CloseReason(this.wireName);

  /// What goes in `Bye.reason`.
  final String wireName;

  static CloseReason? fromWire(String name) => values.where((reason) => reason.wireName == name).firstOrNull;
}

/// What the app must do after feeding the link.
sealed class LinkOutput {
  const LinkOutput();
}

final class SendWire extends LinkOutput {
  const SendWire(this.message);
  final Wire message;

  @override
  String toString() => 'SendWire(${message.whichMsg().name})';
}

/// Show the code and ask whether it matches the one on the Mac.
final class ShowCode extends LinkOutput {
  const ShowCode(this.code);
  final String code;

  @override
  bool operator ==(Object other) => other is ShowCode && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

/// Save it, replacing any earlier pairing with the same Mac.
final class Paired extends LinkOutput {
  const Paired(this.host);
  final PairedHost host;
}

/// The Mac proved it holds the pairing keys; sealed messages can flow.
final class Established extends LinkOutput {
  const Established(this.host);
  final PairedHost host;
}

final class Deliver extends LinkOutput {
  const Deliver(this.message);
  final Signal message;
}

/// Send `bye` with this reason and close.
final class CloseLink extends LinkOutput {
  const CloseLink(this.reason);
  final CloseReason reason;

  @override
  bool operator ==(Object other) => other is CloseLink && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'CloseLink(${reason.wireName})';
}

/// The Mac said goodbye.
final class PeerClosed extends LinkOutput {
  const PeerClosed(this.reason);
  final String reason;

  @override
  bool operator ==(Object other) => other is PeerClosed && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'PeerClosed($reason)';
}

enum LinkPhase { idle, pairing, comparingCodes, handshaking, established, closed }

/// Thrown by [DeviceLink.seal] before the session is established.
final class NotEstablished implements Exception {
  const NotEstablished();
}

sealed class _Stage {
  const _Stage();
}

final class _Idle extends _Stage {
  const _Idle();
}

final class _AwaitingChallenge extends _Stage {
  const _AwaitingChallenge(this.pairing);
  final DevicePairing pairing;
}

final class _Comparing extends _Stage {
  const _Comparing(this.pairing);
  final DevicePairing pairing;
}

final class _AwaitingComplete extends _Stage {
  const _AwaitingComplete(this.pairing);
  final DevicePairing pairing;
}

final class _AwaitingAccept extends _Stage {
  const _AwaitingAccept(this.hello, this.host);
  final SessionHello hello;
  final PairedHost host;
}

final class _Established extends _Stage {
  const _Established(this.channel);
  final SecureChannel channel;
}

final class _Closed extends _Stage {
  const _Closed();
}

/// The iPad, iPhone or Android side of one signaling connection.
///
/// Calls run one at a time in the order they're made, even without awaiting each, so frames can be fed
/// as they arrive.
final class DeviceLink {
  /// With a saved [pairing] the link reconnects straight away; without one it pairs first.
  /// [expectedHostId] is the ID the chosen Mac advertised; a Mac answering with another ID is refused,
  /// so pairing can't quietly replace the saved pairing of a different Mac.
  DeviceLink({required this.deviceId, required this.deviceName, this.pairing, this.expectedHostId});

  final String deviceId;
  final String deviceName;
  final PairedHost? pairing;
  final String? expectedHostId;
  _Stage _stage = const _Idle();
  Future<void> _queue = Future.value();

  LinkPhase get phase => switch (_stage) {
        _Idle() => LinkPhase.idle,
        _AwaitingChallenge() || _AwaitingComplete() => LinkPhase.pairing,
        _Comparing() => LinkPhase.comparingCodes,
        _AwaitingAccept() => LinkPhase.handshaking,
        _Established() => LinkPhase.established,
        _Closed() => LinkPhase.closed,
      };

  /// Call once the connection is up.
  Future<List<LinkOutput>> start() => _serially(() async {
        if (_stage is! _Idle) return const [];
        final saved = pairing;
        if (saved != null) return _startSession(saved);
        final devicePairing = await DevicePairing.create(deviceId: deviceId, deviceName: deviceName);
        final request = await devicePairing.start();
        _stage = _AwaitingChallenge(devicePairing);
        return [SendWire(Wire(pairRequest: request))];
      });

  Future<List<LinkOutput>> receive(Wire message) => _serially(() async {
        if (message.hasBye()) {
          if (phase == LinkPhase.closed) return const [];
          _stage = const _Closed();
          return [PeerClosed(message.bye.reason)];
        }
        switch ((_stage, message.whichMsg())) {
          case (_Closed(), _):
            return const [];

          case (_AwaitingChallenge(:final pairing), Wire_Msg.pairChallenge):
            final challenge = message.pairChallenge;
            if (expectedHostId != null && challenge.hostId != expectedHostId) return _close(CloseReason.pairingFailed);
            final PairReveal reveal;
            final String code;
            try {
              (reveal, code) = await pairing.receiveChallenge(challenge);
            } on PairingError {
              return _close(CloseReason.pairingFailed);
            }
            _stage = _Comparing(pairing);
            return [SendWire(Wire(pairReveal: reveal)), ShowCode(code)];

          case (_AwaitingComplete(:final pairing), Wire_Msg.pairComplete):
            final PairedHost host;
            try {
              host = await pairing.receiveComplete(message.pairComplete);
            } on PairingError {
              return _close(CloseReason.pairingFailed);
            }
            return [Paired(host), ...await _startSession(host)];

          case (_AwaitingAccept(:final hello, :final host), Wire_Msg.sessionAccept):
            final accept = message.sessionAccept;
            if (!await SessionHandshake.isValidAccept(accept, hello, host.secret)) {
              return _close(CloseReason.handshakeFailed);
            }
            _stage = _Established(await SessionHandshake.channel(
                role: SessionRole.device, secret: host.secret, hello: hello, accept: accept));
            return [Established(host)];

          case (_Established(:final channel), Wire_Msg.sealed):
            final Signal signal;
            try {
              signal = MessageCoding.decodeSignal(channel.open(message.sealed));
            } catch (_) {
              return _close(CloseReason.badFrame);
            }
            return [Deliver(signal)];

          case (_AwaitingChallenge() || _Comparing() || _AwaitingComplete(), _):
            return _close(CloseReason.pairingFailed);

          default:
            return _close(CloseReason.unexpectedMessage);
        }
      });

  /// The person says the codes match.
  Future<List<LinkOutput>> codesMatch() => _serially(() async {
        final stage = _stage;
        if (stage is! _Comparing) return const [];
        final confirm = await stage.pairing.confirm();
        _stage = _AwaitingComplete(stage.pairing);
        return [SendWire(Wire(pairConfirm: confirm))];
      });

  /// The person says the codes differ, or cancels.
  Future<List<LinkOutput>> codesDiffer() => _serially(() async {
        if (_stage is! _Comparing) return const [];
        return _close(CloseReason.pairingFailed);
      });

  /// Closes from this side, for reasons the link can't see (timeouts, the app going away).
  Future<List<LinkOutput>> close(CloseReason reason) => _serially(() async => _close(reason));

  /// Seals a message for the Mac. Throws [NotEstablished] before the session is up.
  Wire seal(Signal message) {
    final stage = _stage;
    if (stage is! _Established) throw const NotEstablished();
    return Wire(sealed: stage.channel.seal(message.writeToBuffer()));
  }

  List<LinkOutput> _close(CloseReason reason) {
    if (phase == LinkPhase.closed) return const [];
    _stage = const _Closed();
    return [CloseLink(reason)];
  }

  Future<List<LinkOutput>> _startSession(PairedHost host) async {
    final hello = await SessionHandshake.hello(pairId: host.pairId, secret: host.secret);
    _stage = _AwaitingAccept(hello, host);
    return [SendWire(Wire(sessionHello: hello))];
  }

  Future<T> _serially<T>(Future<T> Function() work) {
    final result = _queue.then((_) => work());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }
}
