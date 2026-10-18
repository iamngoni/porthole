import 'dart:typed_data';

/// An image's size in pixels, read from its header without decoding it.
typedef PixelDimensions = ({int width, int height});

/// Whether an image is there and no side is longer than [maxSide], so decoding it can't use more than
/// about maxSide² × 4 bytes.
bool fitsWithin(PixelDimensions? size, int maxSide) =>
    size != null && size.width > 0 && size.height > 0 && size.width <= maxSide && size.height <= maxSide;

/// The size in a PNG's header chunk, or null if [bytes] isn't a PNG.
PixelDimensions? pngSize(Uint8List bytes) {
  const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  // Signature, then the IHDR chunk: length, type, width, height.
  if (bytes.length < 24) return null;
  for (var i = 0; i < signature.length; i++) {
    if (bytes[i] != signature[i]) return null;
  }
  final data = ByteData.sublistView(bytes);
  if (data.getUint32(8) != 13 || String.fromCharCodes(bytes, 12, 16) != 'IHDR') return null;
  return (width: data.getUint32(16), height: data.getUint32(20));
}

/// The size in a JPEG's first frame header, or null if [bytes] isn't a JPEG or ends before one.
PixelDimensions? jpegSize(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) return null;
  final data = ByteData.sublistView(bytes);
  var at = 2;
  while (at + 4 <= bytes.length) {
    if (bytes[at] != 0xFF) return null;
    final marker = bytes[at + 1];
    if (marker == 0xFF) {
      at += 1; // Fill byte before a marker.
      continue;
    }
    // Markers with no length: restart intervals and TEM.
    if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
      at += 2;
      continue;
    }
    // Start of scan or end of image with no frame header before it.
    if (marker == 0xDA || marker == 0xD9) return null;
    final length = data.getUint16(at + 2);
    if (length < 2) return null;
    // SOF0 to SOF15, except DHT (C4), JPG (C8) and DAC (CC), which share the range.
    final isFrame = marker >= 0xC0 && marker <= 0xCF && marker != 0xC4 && marker != 0xC8 && marker != 0xCC;
    if (isFrame) {
      // Length, precision, height, width.
      if (length < 7 || at + 9 > bytes.length) return null;
      return (width: data.getUint16(at + 7), height: data.getUint16(at + 5));
    }
    at += 2 + length;
  }
  return null;
}
