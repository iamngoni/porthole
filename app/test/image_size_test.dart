import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test, setUp, tearDown;
import 'package:porthole/client/image_size.dart';

import 'support/images.dart';

// glados runs every property from a fixed seed (Random(42)) and shrinks failures.

extension ImageAnys on Any {
  /// Segments a JPEG may carry before its frame header: APP0–APP15, quantization and Huffman tables,
  /// restart interval and comments, with payloads that may contain 0xFF and fake frame markers.
  Generator<(int, List<int>)> get jpegSegment => combine2(
        choose(const [0xE0, 0xE1, 0xE2, 0xED, 0xEE, 0xDB, 0xC4, 0xCC, 0xDD, 0xFE]),
        listWithLengthInRange(0, 40, choose(const [0x00, 0x01, 0x7F, 0xC0, 0xC2, 0xD8, 0xD9, 0xDA, 0xFF])),
        (int marker, List<int> payload) => (marker, payload),
      );

  Generator<List<int>> get bytes => listWithLengthInRange(0, 64, intInRange(0, 256));
}

void main() {
  group('pngSize', () {
    Glados2(any.intInRange(0, 1 << 31), any.intInRange(0, 1 << 31)).test('prop_png_size_round_trips', (width, height) {
      expect(pngSize(pngHeader(width, height)), (width: width, height: height));
    });

    test('a PNG from ImageIO, as the Mac makes icons', () {
      final bytes = File('test/fixtures/imageio-5x3.png').readAsBytesSync();
      expect(pngSize(bytes), (width: 5, height: 3));
    });

    test('an app icon drawn the way the Mac host draws them, and small enough to keep', () {
      // NSBitmapImageRep's PNG, from the same code as Host/Capture/PreviewService.swift at 12 pixels.
      final bytes = File('test/fixtures/appkit-icon-12.png').readAsBytesSync();
      expect(pngSize(bytes), (width: 12, height: 12));
      expect(fitsWithin(pngSize(bytes), 512), isTrue);
    });

    test('anything else is not a PNG', () {
      expect(pngSize(Uint8List(0)), isNull);
      expect(pngSize(File('test/fixtures/imageio-5x3.jpg').readAsBytesSync()), isNull);
      expect(pngSize(Uint8List.fromList('GIF89a'.codeUnits + List.filled(30, 0))), isNull);
      expect(pngSize(Uint8List.sublistView(pngHeader(5, 3), 0, 23)), isNull);
    });
  });

  group('jpegSize', () {
    Glados3(any.intInRange(1, 1 << 16), any.intInRange(1, 1 << 16), any.listWithLengthInRange(0, 6, any.jpegSegment))
        .test('prop_jpeg_size_round_trips_past_other_segments', (width, height, segments) {
      expect(jpegSize(jpegHeader(width, height, segments: segments)), (width: width, height: height));
    });

    Glados2(any.listWithLengthInRange(0, 4, any.jpegSegment), any.intInRange(0, 200))
        .test('prop_a_jpeg_cut_off_before_its_size_has_no_size', (segments, cut) {
      final whole = jpegHeader(640, 480, segments: segments);
      // The start of scan is the last 14 bytes and the frame header the 19 before; its size ends 9 in.
      final sizeEnd = whole.length - 14 - 19 + 9;
      final bytes = Uint8List.sublistView(whole, 0, cut.clamp(0, sizeEnd - 1));
      expect(jpegSize(bytes), isNull);
    });

    Glados(any.bytes, ExploreConfig(numRuns: 500)).test('prop_reading_any_bytes_never_throws', (bytes) {
      final data = Uint8List.fromList(bytes);
      for (final start in [data, Uint8List.fromList([0xFF, 0xD8, ...bytes])]) {
        jpegSize(start);
        pngSize(start);
        pngSize(Uint8List.fromList([...pngHeader(1, 1).sublist(0, 16), ...bytes]));
      }
    });

    test('a JPEG from ImageIO, as the Mac makes thumbnails, with JFIF and Exif first', () {
      final bytes = File('test/fixtures/imageio-5x3.jpg').readAsBytesSync();
      expect(jpegSize(bytes), (width: 5, height: 3));
    });

    test('progressive JPEGs have their size in SOF2', () {
      expect(jpegSize(jpegHeader(800, 450, frameMarker: 0xC2)), (width: 800, height: 450));
    });

    test('Huffman tables share the frame markers’ range but are not frames', () {
      final bytes = jpegHeader(320, 200, segments: [(0xC4, List.filled(20, 0x10))]);
      expect(jpegSize(bytes), (width: 320, height: 200));
    });

    test('anything else is not a JPEG', () {
      expect(jpegSize(Uint8List(0)), isNull);
      expect(jpegSize(pngHeader(5, 3)), isNull);
      expect(jpegSize(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xDA, 0, 2])), isNull);
    });
  });

  group('fitsWithin', () {
    Glados3(any.intInRange(0, 5000), any.intInRange(0, 5000), any.intInRange(1, 5000))
        .test('prop_an_image_that_fits_also_fits_anything_larger', (width, height, side) {
      final size = (width: width, height: height);
      if (fitsWithin(size, side)) expect(fitsWithin(size, side + 1), isTrue);
      if (!fitsWithin(size, side + 1)) expect(fitsWithin(size, side), isFalse);
    });

    test('limits', () {
      expect(fitsWithin((width: 800, height: 450), 1024), isTrue);
      expect(fitsWithin((width: 1024, height: 1024), 1024), isTrue);
      expect(fitsWithin((width: 1025, height: 10), 1024), isFalse);
      expect(fitsWithin((width: 10, height: 8000), 1024), isFalse);
      expect(fitsWithin((width: 0, height: 10), 1024), isFalse);
      expect(fitsWithin(null, 1024), isFalse);
    });
  });
}
