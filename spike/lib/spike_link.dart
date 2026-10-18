import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// The Mac's test feed (Porthole Host launched with `-spike`): plain JSON over TCP, each message prefixed
/// with its 4-byte big-endian length, then a WebRTC connection with the video and a "ctl" data channel.
const spikePort = 47800;

class SpikeStats {
  const SpikeStats({
    this.fps = 0,
    this.width = 0,
    this.height = 0,
    this.framesDecoded = 0,
    this.framesDropped = 0,
    this.decodeMs = 0,
    this.jitterBufferMs = 0,
    this.freezes = 0,
    this.codec = '',
    this.decoder = '',
    this.inputRoundTripMs,
    this.bitrateMbps = 0,
  });

  final double fps;
  final int width;
  final int height;
  final int framesDecoded;
  final int framesDropped;
  final double decodeMs;
  final double jitterBufferMs;
  final int freezes;
  final String codec;
  final String decoder;
  final double? inputRoundTripMs;
  final double bitrateMbps;

  Map<String, Object?> toJson() => {
        'fps': fps,
        'size': '${width}x$height',
        'decoded': framesDecoded,
        'dropped': framesDropped,
        'decodeMs': double.parse(decodeMs.toStringAsFixed(2)),
        'jitterBufferMs': double.parse(jitterBufferMs.toStringAsFixed(1)),
        'freezes': freezes,
        'codec': codec,
        'decoder': decoder,
        'rttMs': inputRoundTripMs?.toStringAsFixed(1),
        'mbps': double.parse(bitrateMbps.toStringAsFixed(1)),
      };
}

class SpikeLink extends ChangeNotifier {
  SpikeLink({required this.host, required this.deviceName, required this.screen, required this.refreshRate});

  final String host;
  final String deviceName;

  /// The device's screen in physical pixels, so the Mac picks the right H.264 level.
  final Size screen;

  /// How many times a second the screen refreshes (120 on ProMotion).
  final int refreshRate;

  /// Frames Flutter drew in the last second, set by the stream screen.
  double flutterFps = 0;

  String status = 'Connecting…';
  MediaStream? stream;
  SpikeStats stats = const SpikeStats();
  String renderer = '';

  Socket? _socket;
  final _buffer = BytesBuilder(copy: false);
  RTCPeerConnection? _peer;
  RTCDataChannel? _channel;
  Timer? _statsTimer;
  Timer? _pingTimer;
  final _pings = <double>[];
  int _lastBytes = 0;
  DateTime? _lastBytesAt;

  /// Totals at the previous reading, so decode time and buffering are for the last second, not the whole session.
  ({double decoded, double decodeTime, double emitted, double bufferDelay}) _last =
      (decoded: 0, decodeTime: 0, emitted: 0, bufferDelay: 0);
  bool _closed = false;

  Future<void> connect() async {
    try {
      final socket = await Socket.connect(host, spikePort, timeout: const Duration(seconds: 6));
      socket.setOption(SocketOption.tcpNoDelay, true);
      _socket = socket;
      socket.listen(_onBytes, onDone: () => _fail('The Mac closed the connection.'), onError: (Object e) => _fail('$e'));
      _send({
        'hello': {
          'name': deviceName,
          'width': screen.width.round(),
          'height': screen.height.round(),
          'refreshRate': refreshRate,
        },
      });
      _setStatus('Waiting for the Mac…');
    } catch (e) {
      _fail('Could not reach $host:$spikePort. $e');
    }
  }

  /// Sends one control message on the data channel.
  void control(Map<String, Object?> message) {
    final channel = _channel;
    if (channel == null || channel.state != RTCDataChannelState.RTCDataChannelOpen) return;
    channel.send(RTCDataChannelMessage(jsonEncode(message)));
  }

  Future<void> close() async {
    _closed = true;
    _statsTimer?.cancel();
    _pingTimer?.cancel();
    await _channel?.close();
    await _peer?.close();
    await stream?.dispose();
    _socket?.destroy();
  }

  // MARK: Signaling

  void _onBytes(Uint8List bytes) {
    _buffer.add(bytes);
    var data = _buffer.takeBytes();
    while (data.length >= 4) {
      final length = ByteData.sublistView(data, 0, 4).getUint32(0);
      if (length > 1 << 20) return _fail('The Mac sent a frame that is too large.');
      if (data.length < 4 + length) break;
      final message = jsonDecode(utf8.decode(data.sublist(4, 4 + length))) as Map<String, dynamic>;
      data = data.sublist(4 + length);
      _handle(message);
    }
    _buffer.add(data);
  }

  void _send(Map<String, Object?> message) {
    final payload = utf8.encode(jsonEncode(message));
    final header = ByteData(4)..setUint32(0, payload.length);
    _socket?.add([...header.buffer.asUint8List(), ...payload]);
  }

  Future<void> _handle(Map<String, dynamic> message) async {
    if (message['offer'] case final String sdp) {
      await _answer(sdp);
    } else if (message['candidate'] case final Map<String, dynamic> candidate) {
      await _peer?.addCandidate(RTCIceCandidate(
        candidate['candidate'] as String,
        candidate['sdpMid'] as String?,
        candidate['sdpMLineIndex'] as int?,
      ));
    }
  }

  Future<void> _answer(String offer) async {
    final peer = await createPeerConnection({'iceServers': <Object>[], 'sdpSemantics': 'unified-plan'});
    _peer = peer;
    peer.onIceCandidate = (candidate) {
      _send({
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      });
    };
    peer.onTrack = (event) {
      if (event.track.kind == 'video' && event.streams.isNotEmpty) {
        stream = event.streams.first;
        notifyListeners();
      }
    };
    peer.onDataChannel = (channel) {
      _channel = channel;
      channel.onMessage = _onControl;
      channel.onDataChannelState = (state) {
        if (state == RTCDataChannelState.RTCDataChannelOpen) _startMeasuring();
      };
      if (channel.state == RTCDataChannelState.RTCDataChannelOpen) _startMeasuring();
    };
    peer.onConnectionState = (state) {
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          _setStatus('Connected');
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          _fail('The video connection failed.');
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          _setStatus('Reconnecting…');
        default:
          break;
      }
    };
    await peer.setRemoteDescription(RTCSessionDescription(offer, 'offer'));
    final answer = await peer.createAnswer({});
    await peer.setLocalDescription(answer);
    _send({'answer': answer.sdp});
    _setStatus('Starting video…');
  }

  // MARK: Measuring

  void _onControl(RTCDataChannelMessage message) {
    final decoded = jsonDecode(message.text) as Map<String, dynamic>;
    if (decoded['t'] == 'pong') {
      final sent = (decoded['at'] as num).toDouble();
      _pings.add(DateTime.now().microsecondsSinceEpoch / 1000 - sent);
      if (_pings.length > 20) _pings.removeAt(0);
    }
  }

  void _startMeasuring() {
    _pingTimer ??= Timer.periodic(const Duration(milliseconds: 500), (_) {
      control({'t': 'ping', 'at': DateTime.now().microsecondsSinceEpoch / 1000});
    });
    _statsTimer ??= Timer.periodic(const Duration(seconds: 1), (_) => _readStats());
  }

  Future<void> _readStats() async {
    final peer = _peer;
    if (peer == null || _closed) return;
    final reports = await peer.getStats();
    final byId = {for (final report in reports) report.id: report};
    for (final report in reports) {
      final v = report.values;
      if (report.type != 'inbound-rtp' || v['kind'] != 'video') continue;
      double number(String key) => (v[key] as num?)?.toDouble() ?? 0;
      final decoded = number('framesDecoded');
      final emitted = number('jitterBufferEmittedCount');
      final decodeTime = number('totalDecodeTime');
      final bufferDelay = number('jitterBufferDelay');
      final newFrames = decoded - _last.decoded;
      final newEmitted = emitted - _last.emitted;
      final decodeMs = newFrames > 0 ? (decodeTime - _last.decodeTime) / newFrames * 1000 : stats.decodeMs;
      final bufferMs = newEmitted > 0 ? (bufferDelay - _last.bufferDelay) / newEmitted * 1000 : stats.jitterBufferMs;
      _last = (decoded: decoded, decodeTime: decodeTime, emitted: emitted, bufferDelay: bufferDelay);
      final codec = byId[v['codecId']]?.values;
      final bytes = number('bytesReceived').toInt();
      final now = DateTime.now();
      var mbps = stats.bitrateMbps;
      if (_lastBytesAt != null) {
        final seconds = now.difference(_lastBytesAt!).inMicroseconds / 1e6;
        if (seconds > 0) mbps = (bytes - _lastBytes) * 8 / seconds / 1e6;
      }
      _lastBytes = bytes;
      _lastBytesAt = now;
      final sortedPings = [..._pings]..sort();
      stats = SpikeStats(
        fps: number('framesPerSecond'),
        width: number('frameWidth').toInt(),
        height: number('frameHeight').toInt(),
        framesDecoded: decoded.toInt(),
        framesDropped: number('framesDropped').toInt(),
        decodeMs: decodeMs,
        jitterBufferMs: bufferMs,
        freezes: number('freezeCount').toInt(),
        codec: '${codec?['mimeType'] ?? '?'} ${codec?['sdpFmtpLine'] ?? ''}',
        decoder: '${v['decoderImplementation'] ?? '?'}',
        inputRoundTripMs: sortedPings.isEmpty ? null : sortedPings[sortedPings.length ~/ 2],
        bitrateMbps: mbps,
      );
      control({
        't': 'stats',
        'renderer': renderer,
        'device': deviceName,
        'screenHz': refreshRate,
        'flutterFps': flutterFps,
        ...stats.toJson(),
      });
      notifyListeners();
    }
  }

  void _setStatus(String text) {
    if (_closed) return;
    status = text;
    notifyListeners();
  }

  void _fail(String text) {
    if (_closed) return;
    status = text;
    notifyListeners();
  }
}
