import 'dart:typed_data';

import 'package:glados/glados.dart';
import 'package:porthole_protocol/porthole_protocol.dart';

import 'support/generators.dart';

void main() {
  group('properties', () {
    Glados2(any.list(any.bytes), any.list(any.positiveIntOrZero), ExploreConfig(numRuns: 300)).test(
      'prop_frames_survive_any_chunking',
      (List<Uint8List> payloads, List<int> cuts) {
        final stream = [for (final payload in payloads) ...Framing.frame(payload)];
        final decoder = FrameDecoder();
        final frames = [for (final chunk in chunked(stream, cuts)) ...decoder.append(chunk)];
        expect(frames, payloads);
        expect(decoder.pendingByteCount, 0);
      },
    );

    Glados2(any.bytes, any.positiveIntOrZero, ExploreConfig(numRuns: 300)).test(
      'prop_an_incomplete_frame_is_held_not_returned',
      (Uint8List payload, int cut) {
        final framed = Framing.frame(payload);
        final kept = cut % framed.length;
        final decoder = FrameDecoder();
        expect(decoder.append(framed.sublist(0, kept)), isEmpty);
        expect(decoder.pendingByteCount, kept);
        expect(decoder.append(framed.sublist(kept)), [payload]);
      },
    );
  });

  test('a frame announcing more than 1 MiB is refused before it arrives', () {
    final decoder = FrameDecoder();
    expect(() => decoder.append([0x00, 0x10, 0x00, 0x01]), throwsA(const PayloadTooLarge(0x100001)));
  });

  test('a 1 MiB frame sent one byte at a time costs about as much as one sent at once', () {
    // Copying the buffer on every read made this take minutes; it should take well under a second.
    final framed = Framing.frame(Uint8List(Framing.maxPayloadLength));
    final decoder = FrameDecoder();
    final clock = Stopwatch()..start();
    final frames = <Uint8List>[];
    for (var i = 0; i < framed.length; i++) {
      frames.addAll(decoder.append(Uint8List.sublistView(framed, i, i + 1)));
    }
    expect(frames.single.length, Framing.maxPayloadLength);
    expect(clock.elapsed, lessThan(const Duration(seconds: 3)));
  }, timeout: const Timeout(Duration(seconds: 20)));

  test('exactly 1 MiB is allowed', () {
    final payload = Uint8List(Framing.maxPayloadLength);
    expect(FrameDecoder().append(Framing.frame(payload)).single.length, Framing.maxPayloadLength);
  });

  test('two frames in one read come out in order', () {
    final bytes = [...Framing.frame([1]), ...Framing.frame([2, 3])];
    expect(FrameDecoder().append(bytes), [
      [1],
      [2, 3],
    ]);
  });
}
