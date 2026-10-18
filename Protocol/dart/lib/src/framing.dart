import 'dart:typed_data';

/// Length-prefixed framing for byte streams: a 4-byte big-endian length, then the payload.
abstract final class Framing {
  /// Signaling messages are small (SDP is a few KB); anything bigger is a bug or an attack.
  static const maxPayloadLength = 1 << 20;

  static Uint8List frame(List<int> payload) {
    if (payload.length > maxPayloadLength) throw ArgumentError('payload too large to frame');
    final out = Uint8List(4 + payload.length);
    ByteData.sublistView(out).setUint32(0, payload.length);
    out.setRange(4, out.length, payload);
    return out;
  }
}

/// The other side announced a frame larger than [Framing.maxPayloadLength].
final class PayloadTooLarge implements Exception {
  const PayloadTooLarge(this.length);
  final int length;

  @override
  bool operator ==(Object other) => other is PayloadTooLarge && other.length == length;

  @override
  int get hashCode => length.hashCode;

  @override
  String toString() => 'PayloadTooLarge($length)';
}

/// Reassembles frames from arbitrarily chunked stream reads.
///
/// Bytes go into one growing buffer and are copied out only when a frame completes, so a frame sent one
/// byte at a time costs no more than one sent at once.
class FrameDecoder {
  Uint8List _buffer = Uint8List(256);
  int _start = 0;
  int _end = 0;

  /// Number of bytes received but not yet returned as a complete frame.
  int get pendingByteCount => _end - _start;

  /// Appends newly received bytes and returns every frame they complete, in order.
  List<Uint8List> append(List<int> bytes) {
    _reserve(bytes.length);
    _buffer.setRange(_end, _end + bytes.length, bytes);
    _end += bytes.length;

    final frames = <Uint8List>[];
    while (_end - _start >= 4) {
      final length = ByteData.sublistView(_buffer, _start, _start + 4).getUint32(0);
      if (length > Framing.maxPayloadLength) throw PayloadTooLarge(length);
      if (_end - _start < 4 + length) break;
      frames.add(Uint8List.fromList(Uint8List.sublistView(_buffer, _start + 4, _start + 4 + length)));
      _start += 4 + length;
    }
    if (_start == _end) _start = _end = 0;
    return frames;
  }

  /// Makes room for [count] more bytes. Growing leaves at least as much room as is pending, so every
  /// move of pending bytes is paid for by as many new ones and the total work stays linear.
  void _reserve(int count) {
    if (_end + count <= _buffer.length) return;
    final pending = _end - _start;
    final needed = pending + count;
    if (needed * 2 <= _buffer.length) {
      _buffer.setRange(0, pending, _buffer, _start);
    } else {
      var capacity = _buffer.length;
      while (capacity < needed * 2) {
        capacity *= 2;
      }
      final old = _buffer;
      _buffer = Uint8List(capacity)..setRange(0, pending, old, _start);
    }
    _start = 0;
    _end = pending;
  }
}
