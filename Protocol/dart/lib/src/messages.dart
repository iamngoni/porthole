import 'generated/porthole.pb.dart';

/// Why a well-formed protobuf still isn't a valid message.
final class ProtoError implements Exception {
  /// A field the message can't do without, or the message's case, is absent.
  const ProtoError.missing(this.field) : kind = ProtoErrorKind.missing;

  final ProtoErrorKind kind;
  final String field;

  @override
  bool operator ==(Object other) => other is ProtoError && other.kind == kind && other.field == field;

  @override
  int get hashCode => Object.hash(kind, field);

  @override
  String toString() => 'ProtoError.${kind.name}($field)';
}

enum ProtoErrorKind { missing }

/// Decodes what the Mac sends, refusing messages that leave out a field the app relies on, the same
/// fields the Swift side refuses (ProtoMapping.swift). Protobuf reads an absent field as zero, which would
/// otherwise show up later as a window of size 0×0.
///
/// What the app sends needs no checks: build `ClientMessage`s directly and call `writeToBuffer`.
///
/// Dart writes a field that was set to its default (`gen: 0`) and counts it as present; Swift leaves it
/// out. Both read the same values, but compare decoded messages by their fields, not with `==`.
abstract final class MessageCoding {
  /// The content of a sealed frame. Throws `InvalidProtocolBufferException` if it isn't protobuf.
  static Signal decodeSignal(List<int> bytes) => validateSignal(Signal.fromBuffer(bytes));

  /// A message on the "ctl" data channel. Throws `InvalidProtocolBufferException` if it isn't protobuf.
  static HostMessage decodeHost(List<int> bytes) => validateHost(HostMessage.fromBuffer(bytes));

  static Signal validateSignal(Signal signal) {
    switch (signal.whichMsg()) {
      case Signal_Msg.notSet:
        throw const ProtoError.missing('Signal.msg');
      case Signal_Msg.hello:
        _require(signal.hello.hasViewport(), 'ClientHello.viewport');
      case Signal_Msg.welcome || Signal_Msg.offer || Signal_Msg.answer || Signal_Msg.candidate:
        break;
    }
    return signal;
  }

  static HostMessage validateHost(HostMessage message) {
    switch (message.whichMsg()) {
      case HostMessage_Msg.notSet:
        throw const ProtoError.missing('HostMessage.msg');
      case HostMessage_Msg.windows:
        for (final window in message.windows.windows) {
          _require(window.hasSize(), 'WindowInfo.size');
        }
      case HostMessage_Msg.streamStarted:
        _validateStreamInfo(message.streamStarted);
      case HostMessage_Msg.geometry:
        _validateStreamInfo(message.geometry);
      case HostMessage_Msg.streamState:
        _require(message.streamState.hasState(), 'StreamStateUpdate.state');
        _require(message.streamState.state.whichState() != StreamState_State.notSet, 'StreamState.state');
      case HostMessage_Msg.error ||
            HostMessage_Msg.pong ||
            HostMessage_Msg.control ||
            HostMessage_Msg.thumbnail ||
            HostMessage_Msg.appIcon ||
            HostMessage_Msg.apps:
        break;
    }
    return message;
  }

  static void _validateStreamInfo(StreamInfo info) {
    _require(info.hasPointSize(), 'StreamInfo.pointSize');
    _require(info.hasPixelSize(), 'StreamInfo.pixelSize');
  }

  static void _require(bool present, String field) {
    if (!present) throw ProtoError.missing(field);
  }
}
