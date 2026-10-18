import 'dart:typed_data';

/// The start of a PNG: its signature and header chunk, enough for anything that reads only the size.
Uint8List pngHeader(int width, int height) {
  final bytes = Uint8List(33);
  bytes.setAll(0, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  ByteData.sublistView(bytes)
    ..setUint32(8, 13)
    ..setUint32(16, width)
    ..setUint32(20, height);
  bytes.setAll(12, 'IHDR'.codeUnits);
  bytes.setAll(24, const [8, 6, 0, 0, 0]); // 8-bit RGBA; the CRC after it stays zero.
  return bytes;
}

/// The start of a JPEG: SOI, then [segments] as (marker, payload), then a frame header (SOF0, or
/// [frameMarker]) and a start of scan.
Uint8List jpegHeader(int width, int height, {List<(int, List<int>)> segments = const [], int frameMarker = 0xC0}) {
  final out = BytesBuilder()..add(const [0xFF, 0xD8]);
  void segment(int marker, List<int> payload) {
    final length = payload.length + 2;
    out
      ..add([0xFF, marker, length >> 8, length & 0xFF])
      ..add(payload);
  }

  for (final (marker, payload) in segments) {
    segment(marker, payload);
  }
  segment(frameMarker, [8, height >> 8, height & 0xFF, width >> 8, width & 0xFF, 3, 1, 0x22, 0, 2, 0x11, 1, 3, 0x11, 1]);
  segment(0xDA, [3, 1, 0, 2, 0x11, 3, 0x11, 0, 0x3F, 0]);
  return out.toBytes();
}
