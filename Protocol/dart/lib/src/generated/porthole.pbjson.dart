// This is a generated file - do not edit.
//
// Generated from porthole.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use mouseButtonDescriptor instead')
const MouseButton$json = {
  '1': 'MouseButton',
  '2': [
    {'1': 'MOUSE_BUTTON_LEFT', '2': 0},
    {'1': 'MOUSE_BUTTON_RIGHT', '2': 1},
  ],
};

/// Descriptor for `MouseButton`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List mouseButtonDescriptor = $convert.base64Decode(
    'CgtNb3VzZUJ1dHRvbhIVChFNT1VTRV9CVVRUT05fTEVGVBAAEhYKEk1PVVNFX0JVVFRPTl9SSU'
    'dIVBAB');

@$core.Deprecated('Use scrollPhaseDescriptor instead')
const ScrollPhase$json = {
  '1': 'ScrollPhase',
  '2': [
    {'1': 'SCROLL_PHASE_BEGAN', '2': 0},
    {'1': 'SCROLL_PHASE_CHANGED', '2': 1},
    {'1': 'SCROLL_PHASE_ENDED', '2': 2},
    {'1': 'SCROLL_PHASE_CANCELLED', '2': 3},
  ],
};

/// Descriptor for `ScrollPhase`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List scrollPhaseDescriptor = $convert.base64Decode(
    'CgtTY3JvbGxQaGFzZRIWChJTQ1JPTExfUEhBU0VfQkVHQU4QABIYChRTQ1JPTExfUEhBU0VfQ0'
    'hBTkdFRBABEhYKElNDUk9MTF9QSEFTRV9FTkRFRBACEhoKFlNDUk9MTF9QSEFTRV9DQU5DRUxM'
    'RUQQAw==');

@$core.Deprecated('Use momentumPhaseDescriptor instead')
const MomentumPhase$json = {
  '1': 'MomentumPhase',
  '2': [
    {'1': 'MOMENTUM_PHASE_NONE', '2': 0},
    {'1': 'MOMENTUM_PHASE_BEGAN', '2': 1},
    {'1': 'MOMENTUM_PHASE_CHANGED', '2': 2},
    {'1': 'MOMENTUM_PHASE_ENDED', '2': 3},
  ],
};

/// Descriptor for `MomentumPhase`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List momentumPhaseDescriptor = $convert.base64Decode(
    'Cg1Nb21lbnR1bVBoYXNlEhcKE01PTUVOVFVNX1BIQVNFX05PTkUQABIYChRNT01FTlRVTV9QSE'
    'FTRV9CRUdBThABEhoKFk1PTUVOVFVNX1BIQVNFX0NIQU5HRUQQAhIYChRNT01FTlRVTV9QSEFT'
    'RV9FTkRFRBAD');

@$core.Deprecated('Use wireDescriptor instead')
const Wire$json = {
  '1': 'Wire',
  '2': [
    {'1': 'version', '3': 1, '4': 1, '5': 13, '10': 'version'},
    {
      '1': 'pair_request',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.PairRequest',
      '9': 0,
      '10': 'pairRequest'
    },
    {
      '1': 'pair_challenge',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.PairChallenge',
      '9': 0,
      '10': 'pairChallenge'
    },
    {
      '1': 'pair_reveal',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.PairReveal',
      '9': 0,
      '10': 'pairReveal'
    },
    {
      '1': 'pair_confirm',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.PairConfirm',
      '9': 0,
      '10': 'pairConfirm'
    },
    {
      '1': 'pair_complete',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.PairComplete',
      '9': 0,
      '10': 'pairComplete'
    },
    {
      '1': 'session_hello',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.SessionHello',
      '9': 0,
      '10': 'sessionHello'
    },
    {
      '1': 'session_accept',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.SessionAccept',
      '9': 0,
      '10': 'sessionAccept'
    },
    {
      '1': 'sealed',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.Sealed',
      '9': 0,
      '10': 'sealed'
    },
    {
      '1': 'bye',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.Bye',
      '9': 0,
      '10': 'bye'
    },
  ],
  '8': [
    {'1': 'msg'},
  ],
};

/// Descriptor for `Wire`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List wireDescriptor = $convert.base64Decode(
    'CgRXaXJlEhgKB3ZlcnNpb24YASABKA1SB3ZlcnNpb24SPQoMcGFpcl9yZXF1ZXN0GAIgASgLMh'
    'gucG9ydGhvbGUudjMuUGFpclJlcXVlc3RIAFILcGFpclJlcXVlc3QSQwoOcGFpcl9jaGFsbGVu'
    'Z2UYAyABKAsyGi5wb3J0aG9sZS52My5QYWlyQ2hhbGxlbmdlSABSDXBhaXJDaGFsbGVuZ2USOg'
    'oLcGFpcl9yZXZlYWwYBCABKAsyFy5wb3J0aG9sZS52My5QYWlyUmV2ZWFsSABSCnBhaXJSZXZl'
    'YWwSPQoMcGFpcl9jb25maXJtGAUgASgLMhgucG9ydGhvbGUudjMuUGFpckNvbmZpcm1IAFILcG'
    'FpckNvbmZpcm0SQAoNcGFpcl9jb21wbGV0ZRgGIAEoCzIZLnBvcnRob2xlLnYzLlBhaXJDb21w'
    'bGV0ZUgAUgxwYWlyQ29tcGxldGUSQAoNc2Vzc2lvbl9oZWxsbxgHIAEoCzIZLnBvcnRob2xlLn'
    'YzLlNlc3Npb25IZWxsb0gAUgxzZXNzaW9uSGVsbG8SQwoOc2Vzc2lvbl9hY2NlcHQYCCABKAsy'
    'Gi5wb3J0aG9sZS52My5TZXNzaW9uQWNjZXB0SABSDXNlc3Npb25BY2NlcHQSLQoGc2VhbGVkGA'
    'kgASgLMhMucG9ydGhvbGUudjMuU2VhbGVkSABSBnNlYWxlZBIkCgNieWUYCiABKAsyEC5wb3J0'
    'aG9sZS52My5CeWVIAFIDYnllQgUKA21zZw==');

@$core.Deprecated('Use pairRequestDescriptor instead')
const PairRequest$json = {
  '1': 'PairRequest',
  '2': [
    {'1': 'device_id', '3': 1, '4': 1, '5': 9, '10': 'deviceId'},
    {'1': 'device_name', '3': 2, '4': 1, '5': 9, '10': 'deviceName'},
    {'1': 'commitment', '3': 3, '4': 1, '5': 12, '10': 'commitment'},
  ],
};

/// Descriptor for `PairRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pairRequestDescriptor = $convert.base64Decode(
    'CgtQYWlyUmVxdWVzdBIbCglkZXZpY2VfaWQYASABKAlSCGRldmljZUlkEh8KC2RldmljZV9uYW'
    '1lGAIgASgJUgpkZXZpY2VOYW1lEh4KCmNvbW1pdG1lbnQYAyABKAxSCmNvbW1pdG1lbnQ=');

@$core.Deprecated('Use pairChallengeDescriptor instead')
const PairChallenge$json = {
  '1': 'PairChallenge',
  '2': [
    {'1': 'host_id', '3': 1, '4': 1, '5': 9, '10': 'hostId'},
    {'1': 'host_name', '3': 2, '4': 1, '5': 9, '10': 'hostName'},
    {'1': 'host_key', '3': 3, '4': 1, '5': 12, '10': 'hostKey'},
    {'1': 'host_nonce', '3': 4, '4': 1, '5': 12, '10': 'hostNonce'},
  ],
};

/// Descriptor for `PairChallenge`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pairChallengeDescriptor = $convert.base64Decode(
    'Cg1QYWlyQ2hhbGxlbmdlEhcKB2hvc3RfaWQYASABKAlSBmhvc3RJZBIbCglob3N0X25hbWUYAi'
    'ABKAlSCGhvc3ROYW1lEhkKCGhvc3Rfa2V5GAMgASgMUgdob3N0S2V5Eh0KCmhvc3Rfbm9uY2UY'
    'BCABKAxSCWhvc3ROb25jZQ==');

@$core.Deprecated('Use pairRevealDescriptor instead')
const PairReveal$json = {
  '1': 'PairReveal',
  '2': [
    {'1': 'device_key', '3': 1, '4': 1, '5': 12, '10': 'deviceKey'},
    {'1': 'device_nonce', '3': 2, '4': 1, '5': 12, '10': 'deviceNonce'},
  ],
};

/// Descriptor for `PairReveal`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pairRevealDescriptor = $convert.base64Decode(
    'CgpQYWlyUmV2ZWFsEh0KCmRldmljZV9rZXkYASABKAxSCWRldmljZUtleRIhCgxkZXZpY2Vfbm'
    '9uY2UYAiABKAxSC2RldmljZU5vbmNl');

@$core.Deprecated('Use pairConfirmDescriptor instead')
const PairConfirm$json = {
  '1': 'PairConfirm',
  '2': [
    {'1': 'mac', '3': 1, '4': 1, '5': 12, '10': 'mac'},
  ],
};

/// Descriptor for `PairConfirm`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pairConfirmDescriptor =
    $convert.base64Decode('CgtQYWlyQ29uZmlybRIQCgNtYWMYASABKAxSA21hYw==');

@$core.Deprecated('Use pairCompleteDescriptor instead')
const PairComplete$json = {
  '1': 'PairComplete',
  '2': [
    {'1': 'pair_id', '3': 1, '4': 1, '5': 9, '10': 'pairId'},
    {'1': 'mac', '3': 2, '4': 1, '5': 12, '10': 'mac'},
  ],
};

/// Descriptor for `PairComplete`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pairCompleteDescriptor = $convert.base64Decode(
    'CgxQYWlyQ29tcGxldGUSFwoHcGFpcl9pZBgBIAEoCVIGcGFpcklkEhAKA21hYxgCIAEoDFIDbW'
    'Fj');

@$core.Deprecated('Use sessionHelloDescriptor instead')
const SessionHello$json = {
  '1': 'SessionHello',
  '2': [
    {'1': 'pair_id', '3': 1, '4': 1, '5': 9, '10': 'pairId'},
    {'1': 'nonce', '3': 2, '4': 1, '5': 12, '10': 'nonce'},
    {'1': 'mac', '3': 3, '4': 1, '5': 12, '10': 'mac'},
  ],
};

/// Descriptor for `SessionHello`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sessionHelloDescriptor = $convert.base64Decode(
    'CgxTZXNzaW9uSGVsbG8SFwoHcGFpcl9pZBgBIAEoCVIGcGFpcklkEhQKBW5vbmNlGAIgASgMUg'
    'Vub25jZRIQCgNtYWMYAyABKAxSA21hYw==');

@$core.Deprecated('Use sessionAcceptDescriptor instead')
const SessionAccept$json = {
  '1': 'SessionAccept',
  '2': [
    {'1': 'nonce', '3': 1, '4': 1, '5': 12, '10': 'nonce'},
    {'1': 'mac', '3': 2, '4': 1, '5': 12, '10': 'mac'},
  ],
};

/// Descriptor for `SessionAccept`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sessionAcceptDescriptor = $convert.base64Decode(
    'Cg1TZXNzaW9uQWNjZXB0EhQKBW5vbmNlGAEgASgMUgVub25jZRIQCgNtYWMYAiABKAxSA21hYw'
    '==');

@$core.Deprecated('Use sealedDescriptor instead')
const Sealed$json = {
  '1': 'Sealed',
  '2': [
    {'1': 'counter', '3': 1, '4': 1, '5': 4, '10': 'counter'},
    {'1': 'box', '3': 2, '4': 1, '5': 12, '10': 'box'},
  ],
};

/// Descriptor for `Sealed`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sealedDescriptor = $convert.base64Decode(
    'CgZTZWFsZWQSGAoHY291bnRlchgBIAEoBFIHY291bnRlchIQCgNib3gYAiABKAxSA2JveA==');

@$core.Deprecated('Use byeDescriptor instead')
const Bye$json = {
  '1': 'Bye',
  '2': [
    {'1': 'reason', '3': 1, '4': 1, '5': 9, '10': 'reason'},
  ],
};

/// Descriptor for `Bye`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List byeDescriptor =
    $convert.base64Decode('CgNCeWUSFgoGcmVhc29uGAEgASgJUgZyZWFzb24=');

@$core.Deprecated('Use signalDescriptor instead')
const Signal$json = {
  '1': 'Signal',
  '2': [
    {
      '1': 'hello',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.ClientHello',
      '9': 0,
      '10': 'hello'
    },
    {
      '1': 'welcome',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.HostWelcome',
      '9': 0,
      '10': 'welcome'
    },
    {'1': 'offer', '3': 3, '4': 1, '5': 9, '9': 0, '10': 'offer'},
    {'1': 'answer', '3': 4, '4': 1, '5': 9, '9': 0, '10': 'answer'},
    {
      '1': 'candidate',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.IceCandidate',
      '9': 0,
      '10': 'candidate'
    },
  ],
  '8': [
    {'1': 'msg'},
  ],
};

/// Descriptor for `Signal`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List signalDescriptor = $convert.base64Decode(
    'CgZTaWduYWwSMAoFaGVsbG8YASABKAsyGC5wb3J0aG9sZS52My5DbGllbnRIZWxsb0gAUgVoZW'
    'xsbxI0Cgd3ZWxjb21lGAIgASgLMhgucG9ydGhvbGUudjMuSG9zdFdlbGNvbWVIAFIHd2VsY29t'
    'ZRIWCgVvZmZlchgDIAEoCUgAUgVvZmZlchIYCgZhbnN3ZXIYBCABKAlIAFIGYW5zd2VyEjkKCW'
    'NhbmRpZGF0ZRgFIAEoCzIZLnBvcnRob2xlLnYzLkljZUNhbmRpZGF0ZUgAUgljYW5kaWRhdGVC'
    'BQoDbXNn');

@$core.Deprecated('Use clientHelloDescriptor instead')
const ClientHello$json = {
  '1': 'ClientHello',
  '2': [
    {'1': 'protocol_version', '3': 1, '4': 1, '5': 13, '10': 'protocolVersion'},
    {'1': 'device_name', '3': 2, '4': 1, '5': 9, '10': 'deviceName'},
    {
      '1': 'viewport',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.PixelSize',
      '10': 'viewport'
    },
    {
      '1': 'max_frames_per_second',
      '3': 4,
      '4': 1,
      '5': 3,
      '9': 0,
      '10': 'maxFramesPerSecond',
      '17': true
    },
  ],
  '8': [
    {'1': '_max_frames_per_second'},
  ],
};

/// Descriptor for `ClientHello`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clientHelloDescriptor = $convert.base64Decode(
    'CgtDbGllbnRIZWxsbxIpChBwcm90b2NvbF92ZXJzaW9uGAEgASgNUg9wcm90b2NvbFZlcnNpb2'
    '4SHwoLZGV2aWNlX25hbWUYAiABKAlSCmRldmljZU5hbWUSMgoIdmlld3BvcnQYAyABKAsyFi5w'
    'b3J0aG9sZS52My5QaXhlbFNpemVSCHZpZXdwb3J0EjYKFW1heF9mcmFtZXNfcGVyX3NlY29uZB'
    'gEIAEoA0gAUhJtYXhGcmFtZXNQZXJTZWNvbmSIAQFCGAoWX21heF9mcmFtZXNfcGVyX3NlY29u'
    'ZA==');

@$core.Deprecated('Use hostWelcomeDescriptor instead')
const HostWelcome$json = {
  '1': 'HostWelcome',
  '2': [
    {'1': 'protocol_version', '3': 1, '4': 1, '5': 13, '10': 'protocolVersion'},
    {'1': 'host_name', '3': 2, '4': 1, '5': 9, '10': 'hostName'},
  ],
};

/// Descriptor for `HostWelcome`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List hostWelcomeDescriptor = $convert.base64Decode(
    'CgtIb3N0V2VsY29tZRIpChBwcm90b2NvbF92ZXJzaW9uGAEgASgNUg9wcm90b2NvbFZlcnNpb2'
    '4SGwoJaG9zdF9uYW1lGAIgASgJUghob3N0TmFtZQ==');

@$core.Deprecated('Use iceCandidateDescriptor instead')
const IceCandidate$json = {
  '1': 'IceCandidate',
  '2': [
    {'1': 'sdp', '3': 1, '4': 1, '5': 9, '10': 'sdp'},
    {'1': 'sdp_m_line_index', '3': 2, '4': 1, '5': 5, '10': 'sdpMLineIndex'},
    {
      '1': 'sdp_mid',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'sdpMid',
      '17': true
    },
  ],
  '8': [
    {'1': '_sdp_mid'},
  ],
};

/// Descriptor for `IceCandidate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List iceCandidateDescriptor = $convert.base64Decode(
    'CgxJY2VDYW5kaWRhdGUSEAoDc2RwGAEgASgJUgNzZHASJwoQc2RwX21fbGluZV9pbmRleBgCIA'
    'EoBVINc2RwTUxpbmVJbmRleBIcCgdzZHBfbWlkGAMgASgJSABSBnNkcE1pZIgBAUIKCghfc2Rw'
    'X21pZA==');

@$core.Deprecated('Use clientMessageDescriptor instead')
const ClientMessage$json = {
  '1': 'ClientMessage',
  '2': [
    {
      '1': 'list_windows',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.Nothing',
      '9': 0,
      '10': 'listWindows'
    },
    {'1': 'select', '3': 2, '4': 1, '5': 13, '9': 0, '10': 'select'},
    {
      '1': 'stop_stream',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.Nothing',
      '9': 0,
      '10': 'stopStream'
    },
    {
      '1': 'viewport',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.PixelSize',
      '9': 0,
      '10': 'viewport'
    },
    {'1': 'ping', '3': 5, '4': 1, '5': 4, '9': 0, '10': 'ping'},
    {
      '1': 'pointer',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.PointerEvent',
      '9': 0,
      '10': 'pointer'
    },
    {
      '1': 'button',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.ButtonEvent',
      '9': 0,
      '10': 'button'
    },
    {
      '1': 'scroll',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.ScrollEvent',
      '9': 0,
      '10': 'scroll'
    },
    {
      '1': 'key',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.KeyEvent',
      '9': 0,
      '10': 'key'
    },
    {
      '1': 'text',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.TextEvent',
      '9': 0,
      '10': 'text'
    },
    {
      '1': 'release_all',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.Nothing',
      '9': 0,
      '10': 'releaseAll'
    },
    {
      '1': 'thumbnails',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.ThumbnailRequest',
      '9': 0,
      '10': 'thumbnails'
    },
    {
      '1': 'app_icons',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.AppIconRequest',
      '9': 0,
      '10': 'appIcons'
    },
    {
      '1': 'list_apps',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.Nothing',
      '9': 0,
      '10': 'listApps'
    },
    {'1': 'launch', '3': 15, '4': 1, '5': 9, '9': 0, '10': 'launch'},
  ],
  '8': [
    {'1': 'msg'},
  ],
};

/// Descriptor for `ClientMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clientMessageDescriptor = $convert.base64Decode(
    'Cg1DbGllbnRNZXNzYWdlEjkKDGxpc3Rfd2luZG93cxgBIAEoCzIULnBvcnRob2xlLnYzLk5vdG'
    'hpbmdIAFILbGlzdFdpbmRvd3MSGAoGc2VsZWN0GAIgASgNSABSBnNlbGVjdBI3CgtzdG9wX3N0'
    'cmVhbRgDIAEoCzIULnBvcnRob2xlLnYzLk5vdGhpbmdIAFIKc3RvcFN0cmVhbRI0Cgh2aWV3cG'
    '9ydBgEIAEoCzIWLnBvcnRob2xlLnYzLlBpeGVsU2l6ZUgAUgh2aWV3cG9ydBIUCgRwaW5nGAUg'
    'ASgESABSBHBpbmcSNQoHcG9pbnRlchgGIAEoCzIZLnBvcnRob2xlLnYzLlBvaW50ZXJFdmVudE'
    'gAUgdwb2ludGVyEjIKBmJ1dHRvbhgHIAEoCzIYLnBvcnRob2xlLnYzLkJ1dHRvbkV2ZW50SABS'
    'BmJ1dHRvbhIyCgZzY3JvbGwYCCABKAsyGC5wb3J0aG9sZS52My5TY3JvbGxFdmVudEgAUgZzY3'
    'JvbGwSKQoDa2V5GAkgASgLMhUucG9ydGhvbGUudjMuS2V5RXZlbnRIAFIDa2V5EiwKBHRleHQY'
    'CiABKAsyFi5wb3J0aG9sZS52My5UZXh0RXZlbnRIAFIEdGV4dBI3CgtyZWxlYXNlX2FsbBgLIA'
    'EoCzIULnBvcnRob2xlLnYzLk5vdGhpbmdIAFIKcmVsZWFzZUFsbBI/Cgp0aHVtYm5haWxzGAwg'
    'ASgLMh0ucG9ydGhvbGUudjMuVGh1bWJuYWlsUmVxdWVzdEgAUgp0aHVtYm5haWxzEjoKCWFwcF'
    '9pY29ucxgNIAEoCzIbLnBvcnRob2xlLnYzLkFwcEljb25SZXF1ZXN0SABSCGFwcEljb25zEjMK'
    'CWxpc3RfYXBwcxgOIAEoCzIULnBvcnRob2xlLnYzLk5vdGhpbmdIAFIIbGlzdEFwcHMSGAoGbG'
    'F1bmNoGA8gASgJSABSBmxhdW5jaEIFCgNtc2c=');

@$core.Deprecated('Use hostMessageDescriptor instead')
const HostMessage$json = {
  '1': 'HostMessage',
  '2': [
    {
      '1': 'windows',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.WindowList',
      '9': 0,
      '10': 'windows'
    },
    {
      '1': 'stream_started',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.StreamInfo',
      '9': 0,
      '10': 'streamStarted'
    },
    {
      '1': 'geometry',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.StreamInfo',
      '9': 0,
      '10': 'geometry'
    },
    {
      '1': 'stream_state',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.StreamStateUpdate',
      '9': 0,
      '10': 'streamState'
    },
    {
      '1': 'error',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.Problem',
      '9': 0,
      '10': 'error'
    },
    {'1': 'pong', '3': 6, '4': 1, '5': 4, '9': 0, '10': 'pong'},
    {
      '1': 'control',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.ControlStatus',
      '9': 0,
      '10': 'control'
    },
    {
      '1': 'thumbnail',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.Thumbnail',
      '9': 0,
      '10': 'thumbnail'
    },
    {
      '1': 'app_icon',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.AppIcon',
      '9': 0,
      '10': 'appIcon'
    },
    {
      '1': 'apps',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.AppList',
      '9': 0,
      '10': 'apps'
    },
  ],
  '8': [
    {'1': 'msg'},
  ],
};

/// Descriptor for `HostMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List hostMessageDescriptor = $convert.base64Decode(
    'CgtIb3N0TWVzc2FnZRIzCgd3aW5kb3dzGAEgASgLMhcucG9ydGhvbGUudjMuV2luZG93TGlzdE'
    'gAUgd3aW5kb3dzEkAKDnN0cmVhbV9zdGFydGVkGAIgASgLMhcucG9ydGhvbGUudjMuU3RyZWFt'
    'SW5mb0gAUg1zdHJlYW1TdGFydGVkEjUKCGdlb21ldHJ5GAMgASgLMhcucG9ydGhvbGUudjMuU3'
    'RyZWFtSW5mb0gAUghnZW9tZXRyeRJDCgxzdHJlYW1fc3RhdGUYBCABKAsyHi5wb3J0aG9sZS52'
    'My5TdHJlYW1TdGF0ZVVwZGF0ZUgAUgtzdHJlYW1TdGF0ZRIsCgVlcnJvchgFIAEoCzIULnBvcn'
    'Rob2xlLnYzLlByb2JsZW1IAFIFZXJyb3ISFAoEcG9uZxgGIAEoBEgAUgRwb25nEjYKB2NvbnRy'
    'b2wYByABKAsyGi5wb3J0aG9sZS52My5Db250cm9sU3RhdHVzSABSB2NvbnRyb2wSNgoJdGh1bW'
    'JuYWlsGAggASgLMhYucG9ydGhvbGUudjMuVGh1bWJuYWlsSABSCXRodW1ibmFpbBIxCghhcHBf'
    'aWNvbhgJIAEoCzIULnBvcnRob2xlLnYzLkFwcEljb25IAFIHYXBwSWNvbhIqCgRhcHBzGAogAS'
    'gLMhQucG9ydGhvbGUudjMuQXBwTGlzdEgAUgRhcHBzQgUKA21zZw==');

@$core.Deprecated('Use nothingDescriptor instead')
const Nothing$json = {
  '1': 'Nothing',
};

/// Descriptor for `Nothing`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List nothingDescriptor =
    $convert.base64Decode('CgdOb3RoaW5n');

@$core.Deprecated('Use pixelSizeDescriptor instead')
const PixelSize$json = {
  '1': 'PixelSize',
  '2': [
    {'1': 'width', '3': 1, '4': 1, '5': 3, '10': 'width'},
    {'1': 'height', '3': 2, '4': 1, '5': 3, '10': 'height'},
  ],
};

/// Descriptor for `PixelSize`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pixelSizeDescriptor = $convert.base64Decode(
    'CglQaXhlbFNpemUSFAoFd2lkdGgYASABKANSBXdpZHRoEhYKBmhlaWdodBgCIAEoA1IGaGVpZ2'
    'h0');

@$core.Deprecated('Use pointSizeDescriptor instead')
const PointSize$json = {
  '1': 'PointSize',
  '2': [
    {'1': 'width', '3': 1, '4': 1, '5': 1, '10': 'width'},
    {'1': 'height', '3': 2, '4': 1, '5': 1, '10': 'height'},
  ],
};

/// Descriptor for `PointSize`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pointSizeDescriptor = $convert.base64Decode(
    'CglQb2ludFNpemUSFAoFd2lkdGgYASABKAFSBXdpZHRoEhYKBmhlaWdodBgCIAEoAVIGaGVpZ2'
    'h0');

@$core.Deprecated('Use normalizedPointDescriptor instead')
const NormalizedPoint$json = {
  '1': 'NormalizedPoint',
  '2': [
    {'1': 'x', '3': 1, '4': 1, '5': 1, '10': 'x'},
    {'1': 'y', '3': 2, '4': 1, '5': 1, '10': 'y'},
  ],
};

/// Descriptor for `NormalizedPoint`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List normalizedPointDescriptor = $convert.base64Decode(
    'Cg9Ob3JtYWxpemVkUG9pbnQSDAoBeBgBIAEoAVIBeBIMCgF5GAIgASgBUgF5');

@$core.Deprecated('Use windowInfoDescriptor instead')
const WindowInfo$json = {
  '1': 'WindowInfo',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 13, '10': 'id'},
    {'1': 'title', '3': 2, '4': 1, '5': 9, '10': 'title'},
    {'1': 'app_name', '3': 3, '4': 1, '5': 9, '10': 'appName'},
    {
      '1': 'bundle_id',
      '3': 4,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'bundleId',
      '17': true
    },
    {'1': 'pid', '3': 5, '4': 1, '5': 5, '10': 'pid'},
    {
      '1': 'size',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.PointSize',
      '10': 'size'
    },
    {'1': 'is_on_screen', '3': 7, '4': 1, '5': 8, '10': 'isOnScreen'},
  ],
  '8': [
    {'1': '_bundle_id'},
  ],
};

/// Descriptor for `WindowInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List windowInfoDescriptor = $convert.base64Decode(
    'CgpXaW5kb3dJbmZvEg4KAmlkGAEgASgNUgJpZBIUCgV0aXRsZRgCIAEoCVIFdGl0bGUSGQoIYX'
    'BwX25hbWUYAyABKAlSB2FwcE5hbWUSIAoJYnVuZGxlX2lkGAQgASgJSABSCGJ1bmRsZUlkiAEB'
    'EhAKA3BpZBgFIAEoBVIDcGlkEioKBHNpemUYBiABKAsyFi5wb3J0aG9sZS52My5Qb2ludFNpem'
    'VSBHNpemUSIAoMaXNfb25fc2NyZWVuGAcgASgIUgppc09uU2NyZWVuQgwKCl9idW5kbGVfaWQ=');

@$core.Deprecated('Use windowListDescriptor instead')
const WindowList$json = {
  '1': 'WindowList',
  '2': [
    {
      '1': 'windows',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.porthole.v3.WindowInfo',
      '10': 'windows'
    },
  ],
};

/// Descriptor for `WindowList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List windowListDescriptor = $convert.base64Decode(
    'CgpXaW5kb3dMaXN0EjEKB3dpbmRvd3MYASADKAsyFy5wb3J0aG9sZS52My5XaW5kb3dJbmZvUg'
    'd3aW5kb3dz');

@$core.Deprecated('Use streamInfoDescriptor instead')
const StreamInfo$json = {
  '1': 'StreamInfo',
  '2': [
    {'1': 'gen', '3': 1, '4': 1, '5': 13, '10': 'gen'},
    {'1': 'window_id', '3': 2, '4': 1, '5': 13, '10': 'windowId'},
    {'1': 'title', '3': 3, '4': 1, '5': 9, '10': 'title'},
    {'1': 'app_name', '3': 4, '4': 1, '5': 9, '10': 'appName'},
    {
      '1': 'point_size',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.PointSize',
      '10': 'pointSize'
    },
    {
      '1': 'pixel_size',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.PixelSize',
      '10': 'pixelSize'
    },
    {
      '1': 'frames_per_second',
      '3': 7,
      '4': 1,
      '5': 3,
      '9': 0,
      '10': 'framesPerSecond',
      '17': true
    },
  ],
  '8': [
    {'1': '_frames_per_second'},
  ],
};

/// Descriptor for `StreamInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List streamInfoDescriptor = $convert.base64Decode(
    'CgpTdHJlYW1JbmZvEhAKA2dlbhgBIAEoDVIDZ2VuEhsKCXdpbmRvd19pZBgCIAEoDVIId2luZG'
    '93SWQSFAoFdGl0bGUYAyABKAlSBXRpdGxlEhkKCGFwcF9uYW1lGAQgASgJUgdhcHBOYW1lEjUK'
    'CnBvaW50X3NpemUYBSABKAsyFi5wb3J0aG9sZS52My5Qb2ludFNpemVSCXBvaW50U2l6ZRI1Cg'
    'pwaXhlbF9zaXplGAYgASgLMhYucG9ydGhvbGUudjMuUGl4ZWxTaXplUglwaXhlbFNpemUSLwoR'
    'ZnJhbWVzX3Blcl9zZWNvbmQYByABKANIAFIPZnJhbWVzUGVyU2Vjb25kiAEBQhQKEl9mcmFtZX'
    'NfcGVyX3NlY29uZA==');

@$core.Deprecated('Use streamStateDescriptor instead')
const StreamState$json = {
  '1': 'StreamState',
  '2': [
    {
      '1': 'live',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.Nothing',
      '9': 0,
      '10': 'live'
    },
    {
      '1': 'paused',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.StreamState.Paused',
      '9': 0,
      '10': 'paused'
    },
    {
      '1': 'closed',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.Nothing',
      '9': 0,
      '10': 'closed'
    },
  ],
  '3': [StreamState_Paused$json],
  '8': [
    {'1': 'state'},
  ],
};

@$core.Deprecated('Use streamStateDescriptor instead')
const StreamState_Paused$json = {
  '1': 'Paused',
  '2': [
    {'1': 'reason', '3': 1, '4': 1, '5': 9, '10': 'reason'},
  ],
};

/// Descriptor for `StreamState`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List streamStateDescriptor = $convert.base64Decode(
    'CgtTdHJlYW1TdGF0ZRIqCgRsaXZlGAEgASgLMhQucG9ydGhvbGUudjMuTm90aGluZ0gAUgRsaX'
    'ZlEjkKBnBhdXNlZBgCIAEoCzIfLnBvcnRob2xlLnYzLlN0cmVhbVN0YXRlLlBhdXNlZEgAUgZw'
    'YXVzZWQSLgoGY2xvc2VkGAMgASgLMhQucG9ydGhvbGUudjMuTm90aGluZ0gAUgZjbG9zZWQaIA'
    'oGUGF1c2VkEhYKBnJlYXNvbhgBIAEoCVIGcmVhc29uQgcKBXN0YXRl');

@$core.Deprecated('Use streamStateUpdateDescriptor instead')
const StreamStateUpdate$json = {
  '1': 'StreamStateUpdate',
  '2': [
    {'1': 'gen', '3': 1, '4': 1, '5': 13, '10': 'gen'},
    {
      '1': 'state',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.StreamState',
      '10': 'state'
    },
  ],
};

/// Descriptor for `StreamStateUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List streamStateUpdateDescriptor = $convert.base64Decode(
    'ChFTdHJlYW1TdGF0ZVVwZGF0ZRIQCgNnZW4YASABKA1SA2dlbhIuCgVzdGF0ZRgCIAEoCzIYLn'
    'BvcnRob2xlLnYzLlN0cmVhbVN0YXRlUgVzdGF0ZQ==');

@$core.Deprecated('Use problemDescriptor instead')
const Problem$json = {
  '1': 'Problem',
  '2': [
    {'1': 'code', '3': 1, '4': 1, '5': 9, '10': 'code'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `Problem`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List problemDescriptor = $convert.base64Decode(
    'CgdQcm9ibGVtEhIKBGNvZGUYASABKAlSBGNvZGUSGAoHbWVzc2FnZRgCIAEoCVIHbWVzc2FnZQ'
    '==');

@$core.Deprecated('Use controlStatusDescriptor instead')
const ControlStatus$json = {
  '1': 'ControlStatus',
  '2': [
    {'1': 'allowed', '3': 1, '4': 1, '5': 8, '10': 'allowed'},
    {'1': 'reason', '3': 2, '4': 1, '5': 9, '9': 0, '10': 'reason', '17': true},
  ],
  '8': [
    {'1': '_reason'},
  ],
};

/// Descriptor for `ControlStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List controlStatusDescriptor = $convert.base64Decode(
    'Cg1Db250cm9sU3RhdHVzEhgKB2FsbG93ZWQYASABKAhSB2FsbG93ZWQSGwoGcmVhc29uGAIgAS'
    'gJSABSBnJlYXNvbogBAUIJCgdfcmVhc29u');

@$core.Deprecated('Use thumbnailDescriptor instead')
const Thumbnail$json = {
  '1': 'Thumbnail',
  '2': [
    {'1': 'window_id', '3': 1, '4': 1, '5': 13, '10': 'windowId'},
    {'1': 'jpeg', '3': 2, '4': 1, '5': 12, '10': 'jpeg'},
  ],
};

/// Descriptor for `Thumbnail`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List thumbnailDescriptor = $convert.base64Decode(
    'CglUaHVtYm5haWwSGwoJd2luZG93X2lkGAEgASgNUgh3aW5kb3dJZBISCgRqcGVnGAIgASgMUg'
    'RqcGVn');

@$core.Deprecated('Use appIconDescriptor instead')
const AppIcon$json = {
  '1': 'AppIcon',
  '2': [
    {'1': 'bundle_id', '3': 1, '4': 1, '5': 9, '10': 'bundleId'},
    {'1': 'png', '3': 2, '4': 1, '5': 12, '10': 'png'},
  ],
};

/// Descriptor for `AppIcon`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List appIconDescriptor = $convert.base64Decode(
    'CgdBcHBJY29uEhsKCWJ1bmRsZV9pZBgBIAEoCVIIYnVuZGxlSWQSEAoDcG5nGAIgASgMUgNwbm'
    'c=');

@$core.Deprecated('Use appInfoDescriptor instead')
const AppInfo$json = {
  '1': 'AppInfo',
  '2': [
    {'1': 'bundle_id', '3': 1, '4': 1, '5': 9, '10': 'bundleId'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'is_running', '3': 3, '4': 1, '5': 8, '10': 'isRunning'},
  ],
};

/// Descriptor for `AppInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List appInfoDescriptor = $convert.base64Decode(
    'CgdBcHBJbmZvEhsKCWJ1bmRsZV9pZBgBIAEoCVIIYnVuZGxlSWQSEgoEbmFtZRgCIAEoCVIEbm'
    'FtZRIdCgppc19ydW5uaW5nGAMgASgIUglpc1J1bm5pbmc=');

@$core.Deprecated('Use appListDescriptor instead')
const AppList$json = {
  '1': 'AppList',
  '2': [
    {
      '1': 'apps',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.porthole.v3.AppInfo',
      '10': 'apps'
    },
  ],
};

/// Descriptor for `AppList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List appListDescriptor = $convert.base64Decode(
    'CgdBcHBMaXN0EigKBGFwcHMYASADKAsyFC5wb3J0aG9sZS52My5BcHBJbmZvUgRhcHBz');

@$core.Deprecated('Use thumbnailRequestDescriptor instead')
const ThumbnailRequest$json = {
  '1': 'ThumbnailRequest',
  '2': [
    {'1': 'window_ids', '3': 1, '4': 3, '5': 13, '10': 'windowIds'},
    {'1': 'max_long_side', '3': 2, '4': 1, '5': 3, '10': 'maxLongSide'},
  ],
};

/// Descriptor for `ThumbnailRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List thumbnailRequestDescriptor = $convert.base64Decode(
    'ChBUaHVtYm5haWxSZXF1ZXN0Eh0KCndpbmRvd19pZHMYASADKA1SCXdpbmRvd0lkcxIiCg1tYX'
    'hfbG9uZ19zaWRlGAIgASgDUgttYXhMb25nU2lkZQ==');

@$core.Deprecated('Use appIconRequestDescriptor instead')
const AppIconRequest$json = {
  '1': 'AppIconRequest',
  '2': [
    {'1': 'bundle_ids', '3': 1, '4': 3, '5': 9, '10': 'bundleIds'},
  ],
};

/// Descriptor for `AppIconRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List appIconRequestDescriptor = $convert.base64Decode(
    'Cg5BcHBJY29uUmVxdWVzdBIdCgpidW5kbGVfaWRzGAEgAygJUglidW5kbGVJZHM=');

@$core.Deprecated('Use pointerEventDescriptor instead')
const PointerEvent$json = {
  '1': 'PointerEvent',
  '2': [
    {'1': 'gen', '3': 1, '4': 1, '5': 13, '10': 'gen'},
    {
      '1': 'point',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.NormalizedPoint',
      '10': 'point'
    },
  ],
};

/// Descriptor for `PointerEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pointerEventDescriptor = $convert.base64Decode(
    'CgxQb2ludGVyRXZlbnQSEAoDZ2VuGAEgASgNUgNnZW4SMgoFcG9pbnQYAiABKAsyHC5wb3J0aG'
    '9sZS52My5Ob3JtYWxpemVkUG9pbnRSBXBvaW50');

@$core.Deprecated('Use buttonEventDescriptor instead')
const ButtonEvent$json = {
  '1': 'ButtonEvent',
  '2': [
    {'1': 'gen', '3': 1, '4': 1, '5': 13, '10': 'gen'},
    {
      '1': 'point',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.NormalizedPoint',
      '10': 'point'
    },
    {
      '1': 'button',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.porthole.v3.MouseButton',
      '10': 'button'
    },
    {'1': 'is_down', '3': 4, '4': 1, '5': 8, '10': 'isDown'},
  ],
};

/// Descriptor for `ButtonEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List buttonEventDescriptor = $convert.base64Decode(
    'CgtCdXR0b25FdmVudBIQCgNnZW4YASABKA1SA2dlbhIyCgVwb2ludBgCIAEoCzIcLnBvcnRob2'
    'xlLnYzLk5vcm1hbGl6ZWRQb2ludFIFcG9pbnQSMAoGYnV0dG9uGAMgASgOMhgucG9ydGhvbGUu'
    'djMuTW91c2VCdXR0b25SBmJ1dHRvbhIXCgdpc19kb3duGAQgASgIUgZpc0Rvd24=');

@$core.Deprecated('Use scrollEventDescriptor instead')
const ScrollEvent$json = {
  '1': 'ScrollEvent',
  '2': [
    {'1': 'gen', '3': 1, '4': 1, '5': 13, '10': 'gen'},
    {
      '1': 'point',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.porthole.v3.NormalizedPoint',
      '10': 'point'
    },
    {'1': 'dx', '3': 3, '4': 1, '5': 1, '10': 'dx'},
    {'1': 'dy', '3': 4, '4': 1, '5': 1, '10': 'dy'},
    {
      '1': 'phase',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.porthole.v3.ScrollPhase',
      '9': 0,
      '10': 'phase',
      '17': true
    },
    {
      '1': 'momentum',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.porthole.v3.MomentumPhase',
      '10': 'momentum'
    },
  ],
  '8': [
    {'1': '_phase'},
  ],
};

/// Descriptor for `ScrollEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List scrollEventDescriptor = $convert.base64Decode(
    'CgtTY3JvbGxFdmVudBIQCgNnZW4YASABKA1SA2dlbhIyCgVwb2ludBgCIAEoCzIcLnBvcnRob2'
    'xlLnYzLk5vcm1hbGl6ZWRQb2ludFIFcG9pbnQSDgoCZHgYAyABKAFSAmR4Eg4KAmR5GAQgASgB'
    'UgJkeRIzCgVwaGFzZRgFIAEoDjIYLnBvcnRob2xlLnYzLlNjcm9sbFBoYXNlSABSBXBoYXNliA'
    'EBEjYKCG1vbWVudHVtGAYgASgOMhoucG9ydGhvbGUudjMuTW9tZW50dW1QaGFzZVIIbW9tZW50'
    'dW1CCAoGX3BoYXNl');

@$core.Deprecated('Use keyEventDescriptor instead')
const KeyEvent$json = {
  '1': 'KeyEvent',
  '2': [
    {'1': 'gen', '3': 1, '4': 1, '5': 13, '10': 'gen'},
    {'1': 'usage', '3': 2, '4': 1, '5': 13, '10': 'usage'},
    {'1': 'is_down', '3': 3, '4': 1, '5': 8, '10': 'isDown'},
    {'1': 'modifiers', '3': 4, '4': 1, '5': 13, '10': 'modifiers'},
  ],
};

/// Descriptor for `KeyEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List keyEventDescriptor = $convert.base64Decode(
    'CghLZXlFdmVudBIQCgNnZW4YASABKA1SA2dlbhIUCgV1c2FnZRgCIAEoDVIFdXNhZ2USFwoHaX'
    'NfZG93bhgDIAEoCFIGaXNEb3duEhwKCW1vZGlmaWVycxgEIAEoDVIJbW9kaWZpZXJz');

@$core.Deprecated('Use textEventDescriptor instead')
const TextEvent$json = {
  '1': 'TextEvent',
  '2': [
    {'1': 'gen', '3': 1, '4': 1, '5': 13, '10': 'gen'},
    {'1': 'text', '3': 2, '4': 1, '5': 9, '10': 'text'},
  ],
};

/// Descriptor for `TextEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List textEventDescriptor = $convert.base64Decode(
    'CglUZXh0RXZlbnQSEAoDZ2VuGAEgASgNUgNnZW4SEgoEdGV4dBgCIAEoCVIEdGV4dA==');
