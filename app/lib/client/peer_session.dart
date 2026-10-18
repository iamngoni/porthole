import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:porthole_protocol/porthole_protocol.dart' as pb;

enum PeerState { fresh, connecting, connected, disconnected, failed, closed }

/// The device's end of the video connection, as the controller sees it. Tests drive a fake.
abstract class PeerLink {
  void Function(pb.IceCandidate candidate)? onLocalCandidate;
  void Function(PeerState state)? onStateChange;
  void Function()? onControlOpen;
  void Function(Uint8List data)? onControlMessage;
  void Function(MediaStream stream)? onRemoteStream;

  /// Applies the Mac's offer and returns the answer.
  Future<String> acceptOffer(String sdp);
  void addRemoteCandidate(pb.IceCandidate candidate);

  /// Control messages are binary protobuf on the "ctl" data channel.
  void sendControl(Uint8List data);

  /// Callbacks stop first, so nothing queued reaches a later session.
  Future<void> close();
}

/// The client role of PeerSession.swift on flutter_webrtc: receives the Mac's video and opens the
/// control channel the Mac creates.
// no-prop-test: glue over the WebRTC plugin; the negotiation is covered by the interop tests on the Swift side
// and checked end to end on devices.
final class PeerSession extends PeerLink {
  PeerSession() {
    _connection = createPeerConnection({
      'iceServers': <Object>[],
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
      'continualGatheringPolicy': 'gather_continually',
    }).then(_wire);
  }

  static const controlChannelLabel = 'ctl';

  late final Future<RTCPeerConnection> _connection;
  RTCDataChannel? _channel;
  var _hasRemoteDescription = false;
  final _pendingCandidates = <RTCIceCandidate>[];
  var _isClosed = false;

  RTCPeerConnection _wire(RTCPeerConnection connection) {
    connection.onIceCandidate = (candidate) {
      final sdp = candidate.candidate;
      if (sdp == null || sdp.isEmpty) return;
      onLocalCandidate?.call(pb.IceCandidate(sdp: sdp, sdpMLineIndex: candidate.sdpMLineIndex ?? 0, sdpMid: candidate.sdpMid));
    };
    connection.onConnectionState = (state) => onStateChange?.call(switch (state) {
          RTCPeerConnectionState.RTCPeerConnectionStateNew => PeerState.fresh,
          RTCPeerConnectionState.RTCPeerConnectionStateConnecting => PeerState.connecting,
          RTCPeerConnectionState.RTCPeerConnectionStateConnected => PeerState.connected,
          RTCPeerConnectionState.RTCPeerConnectionStateDisconnected => PeerState.disconnected,
          RTCPeerConnectionState.RTCPeerConnectionStateFailed => PeerState.failed,
          RTCPeerConnectionState.RTCPeerConnectionStateClosed => PeerState.closed,
        });
    connection.onDataChannel = (channel) {
      if (channel.label != controlChannelLabel) return;
      // Attach straight away: messages that arrive with no listener are dropped.
      _channel = channel;
      channel.onMessage = (message) {
        if (message.isBinary) onControlMessage?.call(message.binary);
      };
      channel.onDataChannelState = (state) {
        if (state == RTCDataChannelState.RTCDataChannelOpen) onControlOpen?.call();
      };
      if (channel.state == RTCDataChannelState.RTCDataChannelOpen) onControlOpen?.call();
    };
    connection.onTrack = (event) {
      if (event.track.kind == 'video' && event.streams.isNotEmpty) onRemoteStream?.call(event.streams.first);
    };
    return connection;
  }

  @override
  Future<String> acceptOffer(String sdp) async {
    final connection = await _connection;
    await connection.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
    _hasRemoteDescription = true;
    final queued = [..._pendingCandidates];
    _pendingCandidates.clear();
    for (final candidate in queued) {
      _add(connection, candidate);
    }
    final answer = await connection.createAnswer();
    await connection.setLocalDescription(answer);
    return answer.sdp ?? '';
  }

  @override
  void addRemoteCandidate(pb.IceCandidate candidate) {
    final rtc = RTCIceCandidate(candidate.sdp, candidate.hasSdpMid() ? candidate.sdpMid : null, candidate.sdpMLineIndex);
    if (!_hasRemoteDescription) {
      _pendingCandidates.add(rtc);
      return;
    }
    _connection.then((connection) => _add(connection, rtc));
  }

  void _add(RTCPeerConnection connection, RTCIceCandidate candidate) {
    if (_isClosed) return;
    connection.addCandidate(candidate).catchError((Object error) => debugPrint('remote candidate rejected: $error'));
  }

  @override
  void sendControl(Uint8List data) {
    final channel = _channel;
    if (_isClosed || channel == null || channel.state != RTCDataChannelState.RTCDataChannelOpen) return;
    channel.send(RTCDataChannelMessage.fromBinary(data));
  }

  @override
  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;
    onLocalCandidate = null;
    onStateChange = null;
    onControlOpen = null;
    onControlMessage = null;
    onRemoteStream = null;
    try {
      await _channel?.close();
      final connection = await _connection;
      await connection.close();
      await connection.dispose();
    } catch (error) {
      debugPrint('closing the peer connection: $error');
    }
  }
}
