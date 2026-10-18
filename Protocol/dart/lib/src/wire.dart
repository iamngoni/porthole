import 'dart:convert';
import 'dart:typed_data';

import 'package:protobuf/protobuf.dart' show InvalidProtocolBufferException;

import 'generated/porthole.pb.dart';
import 'messages.dart';

/// The protocol version this package speaks.
const portholeProtocolVersion = 3;

/// What a frame on the signaling connection turned out to be.
sealed class WireDecoded {
  const WireDecoded();
}

/// A frame of this version. Its `msg` is always set.
final class WireFrame extends WireDecoded {
  const WireFrame(this.wire);
  final Wire wire;

  @override
  bool operator ==(Object other) => other is WireFrame && other.wire == wire;

  @override
  int get hashCode => wire.hashCode;

  @override
  String toString() => 'WireFrame(${wire.whichMsg().name})';
}

/// The other side runs another protocol version. [reason] is set if it sent a bye.
final class UnsupportedVersion extends WireDecoded {
  const UnsupportedVersion(this.version, {this.reason});
  final int version;
  final String? reason;

  @override
  bool operator ==(Object other) => other is UnsupportedVersion && other.version == version && other.reason == reason;

  @override
  int get hashCode => Object.hash(version, reason);

  @override
  String toString() => 'UnsupportedVersion($version, reason: $reason)';
}

/// The bytes aren't a Porthole frame of any version.
final class NotAFrame implements Exception {
  const NotAFrame();

  @override
  bool operator ==(Object other) => other is NotAFrame;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'NotAFrame';
}

/// Every frame is a protobuf `Wire` carrying the protocol version.
///
/// Version 2 framed JSON instead, `{"v": 2, "msg": {...}}`. A v2 frame starts with `{`, which no v3 frame
/// can, so an old Mac is recognized and the app can say which side needs updating.
abstract final class WireCoding {
  /// The last version that framed JSON.
  static const lastJsonVersion = 2;

  /// Encodes [message], stamped with this version.
  static Uint8List encode(Wire message) => (message.deepCopy()..version = portholeProtocolVersion).writeToBuffer();

  static WireDecoded decode(List<int> bytes) {
    if (bytes.isNotEmpty && bytes.first == 0x7B) return _decodeJson(bytes);
    final Wire wire;
    try {
      wire = Wire.fromBuffer(bytes);
    } on InvalidProtocolBufferException {
      throw const NotAFrame();
    }
    if (wire.version != portholeProtocolVersion) {
      return UnsupportedVersion(wire.version, reason: wire.hasBye() ? wire.bye.reason : null);
    }
    if (wire.whichMsg() == Wire_Msg.notSet) throw const ProtoError.missing('Wire.msg');
    return WireFrame(wire);
  }

  /// A bye in the v2 JSON shape, for telling a Mac that predates v3 why the app is leaving.
  static Uint8List legacyBye(String reason) => utf8.encode(jsonEncode({
        'msg': {
          'bye': {'reason': reason},
        },
        'v': lastJsonVersion,
      }));

  /// Frames from before v3 are only ever read for their version and a bye.
  static UnsupportedVersion _decodeJson(List<int> bytes) {
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const NotAFrame();
    }
    if (json case {'v': final int version}) {
      final reason = switch (json) {
        {'msg': {'bye': {'reason': final String reason}}} => reason,
        _ => null,
      };
      return UnsupportedVersion(version, reason: reason);
    }
    throw const NotAFrame();
  }
}
