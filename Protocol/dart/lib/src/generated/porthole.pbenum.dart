// This is a generated file - do not edit.
//
// Generated from porthole.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class MouseButton extends $pb.ProtobufEnum {
  static const MouseButton MOUSE_BUTTON_LEFT =
      MouseButton._(0, _omitEnumNames ? '' : 'MOUSE_BUTTON_LEFT');
  static const MouseButton MOUSE_BUTTON_RIGHT =
      MouseButton._(1, _omitEnumNames ? '' : 'MOUSE_BUTTON_RIGHT');

  static const $core.List<MouseButton> values = <MouseButton>[
    MOUSE_BUTTON_LEFT,
    MOUSE_BUTTON_RIGHT,
  ];

  static final $core.List<MouseButton?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static MouseButton? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const MouseButton._(super.value, super.name);
}

/// Mirrors the Mac's trackpad scroll phases.
class ScrollPhase extends $pb.ProtobufEnum {
  static const ScrollPhase SCROLL_PHASE_BEGAN =
      ScrollPhase._(0, _omitEnumNames ? '' : 'SCROLL_PHASE_BEGAN');
  static const ScrollPhase SCROLL_PHASE_CHANGED =
      ScrollPhase._(1, _omitEnumNames ? '' : 'SCROLL_PHASE_CHANGED');
  static const ScrollPhase SCROLL_PHASE_ENDED =
      ScrollPhase._(2, _omitEnumNames ? '' : 'SCROLL_PHASE_ENDED');
  static const ScrollPhase SCROLL_PHASE_CANCELLED =
      ScrollPhase._(3, _omitEnumNames ? '' : 'SCROLL_PHASE_CANCELLED');

  static const $core.List<ScrollPhase> values = <ScrollPhase>[
    SCROLL_PHASE_BEGAN,
    SCROLL_PHASE_CHANGED,
    SCROLL_PHASE_ENDED,
    SCROLL_PHASE_CANCELLED,
  ];

  static final $core.List<ScrollPhase?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static ScrollPhase? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ScrollPhase._(super.value, super.name);
}

class MomentumPhase extends $pb.ProtobufEnum {
  static const MomentumPhase MOMENTUM_PHASE_NONE =
      MomentumPhase._(0, _omitEnumNames ? '' : 'MOMENTUM_PHASE_NONE');
  static const MomentumPhase MOMENTUM_PHASE_BEGAN =
      MomentumPhase._(1, _omitEnumNames ? '' : 'MOMENTUM_PHASE_BEGAN');
  static const MomentumPhase MOMENTUM_PHASE_CHANGED =
      MomentumPhase._(2, _omitEnumNames ? '' : 'MOMENTUM_PHASE_CHANGED');
  static const MomentumPhase MOMENTUM_PHASE_ENDED =
      MomentumPhase._(3, _omitEnumNames ? '' : 'MOMENTUM_PHASE_ENDED');

  static const $core.List<MomentumPhase> values = <MomentumPhase>[
    MOMENTUM_PHASE_NONE,
    MOMENTUM_PHASE_BEGAN,
    MOMENTUM_PHASE_CHANGED,
    MOMENTUM_PHASE_ENDED,
  ];

  static final $core.List<MomentumPhase?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static MomentumPhase? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const MomentumPhase._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
