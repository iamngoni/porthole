import 'dart:convert';

import 'package:glados/glados.dart';
import 'package:porthole_protocol/porthole_protocol.dart';

import 'support/generators.dart';

void main() {
  group('properties', () {
    Glados(any.wire, ExploreConfig(numRuns: 300)).test('prop_wire_messages_roundtrip', (Wire message) {
      final decoded = WireCoding.decode(WireCoding.encode(message));
      expect(decoded, WireFrame(message.deepCopy()..version = portholeProtocolVersion));
    });

    Glados2(any.intInRange(-5, 50), any.text, ExploreConfig(numRuns: 200)).test(
      'prop_any_json_frame_is_an_old_version_never_a_message',
      (int version, String reason) {
        final json = utf8.encode(jsonEncode({
          'v': version,
          'msg': {
            'bye': {'reason': reason},
          },
        }));
        expect(WireCoding.decode(json), UnsupportedVersion(version, reason: reason));
      },
    );

    Glados2(any.intInRange(0, 1000), any.text, ExploreConfig(numRuns: 200)).test(
      'prop_any_other_protobuf_version_is_reported_not_misread',
      (int version, String reason) {
        if (version == portholeProtocolVersion) return;
        final wire = Wire(version: version, bye: Bye(reason: reason));
        expect(WireCoding.decode(wire.writeToBuffer()), UnsupportedVersion(version, reason: reason));
      },
    );

    Glados(any.text).test('prop_the_legacy_bye_reads_as_a_v2_bye', (String reason) {
      expect(WireCoding.decode(WireCoding.legacyBye(reason)), UnsupportedVersion(2, reason: reason));
    });
  });

  // Examples: pin the bytes the Swift side produces (WireTests.swift has the same ones).

  test('frame wire format', () {
    final bytes = [0x08, 0x03, 0x52, 0x06, 0x0A, 0x04, ...utf8.encode('done')];
    expect(WireCoding.encode(Wire(bye: Bye(reason: 'done'))), bytes);
    expect(WireCoding.decode(bytes), WireFrame(Wire(version: 3, bye: Bye(reason: 'done'))));
  });

  test('a Mac from before v3 is recognized from its JSON', () {
    final old = utf8.encode('{"v":2,"msg":{"offer":{"sdp":"v=0"}}}');
    expect(WireCoding.decode(old), const UnsupportedVersion(2));
    // What a v2 Mac sends an app it can't serve.
    final bye = utf8.encode('{"msg":{"bye":{"reason":"version-mismatch"}},"v":2}');
    expect(WireCoding.decode(bye), const UnsupportedVersion(2, reason: 'version-mismatch'));
  });

  test('a future version without a bye is still reported', () {
    expect(WireCoding.decode([0x08, 0x04, 0x2A, 0x00]), const UnsupportedVersion(4));
  });

  test('a frame without a message is rejected', () {
    expect(() => WireCoding.decode([0x08, 0x03]), throwsA(const ProtoError.missing('Wire.msg')));
  });

  test('garbage and phase-one JSON are not frames', () {
    expect(() => WireCoding.decode([0xFF, 0xFF, 0xFF]), throwsA(const NotAFrame()));
    expect(() => WireCoding.decode(utf8.encode('{"offer":{"sdp":"v=0"}}')), throwsA(const NotAFrame()));
    expect(() => WireCoding.decode(utf8.encode('{not json')), throwsA(const NotAFrame()));
  });

  test('encoding stamps the version without changing the message passed in', () {
    final message = Wire(bye: Bye(reason: 'x'));
    WireCoding.encode(message);
    expect(message.hasVersion(), isFalse);
  });
}
