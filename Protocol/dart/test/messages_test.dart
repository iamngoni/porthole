import 'package:fixnum/fixnum.dart';
import 'package:porthole_protocol/porthole_protocol.dart';
import 'package:test/test.dart';

// The Mac's messages are checked for the fields the app relies on, the same ones Swift checks.
// no-prop-test: each check is one presence test on a fixed field, so a property would restate it.

void main() {
  test('a message with no case is refused', () {
    expect(() => MessageCoding.decodeHost([]), throwsA(const ProtoError.missing('HostMessage.msg')));
    expect(() => MessageCoding.decodeSignal([]), throwsA(const ProtoError.missing('Signal.msg')));
  });

  test('a stream without its size is refused', () {
    final info = StreamInfo(gen: 1, windowId: 2, pointSize: PointSize(width: 10, height: 10));
    expect(() => MessageCoding.decodeHost(HostMessage(streamStarted: info).writeToBuffer()),
        throwsA(const ProtoError.missing('StreamInfo.pixelSize')));
    expect(() => MessageCoding.decodeHost(HostMessage(geometry: StreamInfo(pixelSize: PixelSize())).writeToBuffer()),
        throwsA(const ProtoError.missing('StreamInfo.pointSize')));
  });

  test('a stream state without a state is refused', () {
    expect(() => MessageCoding.decodeHost(HostMessage(streamState: StreamStateUpdate(gen: 1)).writeToBuffer()),
        throwsA(const ProtoError.missing('StreamStateUpdate.state')));
    expect(
        () => MessageCoding.decodeHost(
            HostMessage(streamState: StreamStateUpdate(gen: 1, state: StreamState())).writeToBuffer()),
        throwsA(const ProtoError.missing('StreamState.state')));
  });

  test('a window without a size is refused', () {
    final list = WindowList(windows: [WindowInfo(id: 1, size: PointSize(width: 1, height: 1)), WindowInfo(id: 2)]);
    expect(() => MessageCoding.decodeHost(HostMessage(windows: list).writeToBuffer()),
        throwsA(const ProtoError.missing('WindowInfo.size')));
  });

  test('a hello without a viewport is refused', () {
    expect(() => MessageCoding.decodeSignal(Signal(hello: ClientHello(deviceName: 'x')).writeToBuffer()),
        throwsA(const ProtoError.missing('ClientHello.viewport')));
  });

  test('a message from a newer Mac with a field this app does not know still decodes', () {
    // Field 2000 (varint 1) is unknown here; protobuf keeps it aside.
    final bytes = [...HostMessage(pong: Int64.ONE).writeToBuffer(), 0x80, 0x7D, 0x01];
    expect(MessageCoding.decodeHost(bytes).pong.toInt(), 1);
  });
}

