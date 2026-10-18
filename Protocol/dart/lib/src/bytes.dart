import 'dart:typed_data';

/// Lowercase hex, as in Protocol/vectors.
String toHex(List<int> bytes) => bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

Uint8List fromHex(String hex) {
  if (hex.length.isOdd) throw FormatException('odd-length hex', hex);
  return Uint8List.fromList([
    for (var i = 0; i < hex.length; i += 2) int.parse(hex.substring(i, i + 2), radix: 16),
  ]);
}

/// Constant-time comparison of equal-length MACs.
bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var difference = 0;
  for (var i = 0; i < a.length; i++) {
    difference |= a[i] ^ b[i];
  }
  return difference == 0;
}

Uint8List concat(List<List<int>> parts) {
  final out = BytesBuilder(copy: false);
  parts.forEach(out.add);
  return out.toBytes();
}
