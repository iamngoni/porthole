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

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'porthole.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'porthole.pbenum.dart';

enum Wire_Msg {
  pairRequest,
  pairChallenge,
  pairReveal,
  pairConfirm,
  pairComplete,
  sessionHello,
  sessionAccept,
  sealed,
  bye,
  notSet
}

class Wire extends $pb.GeneratedMessage {
  factory Wire({
    $core.int? version,
    PairRequest? pairRequest,
    PairChallenge? pairChallenge,
    PairReveal? pairReveal,
    PairConfirm? pairConfirm,
    PairComplete? pairComplete,
    SessionHello? sessionHello,
    SessionAccept? sessionAccept,
    Sealed? sealed,
    Bye? bye,
  }) {
    final result = create();
    if (version != null) result.version = version;
    if (pairRequest != null) result.pairRequest = pairRequest;
    if (pairChallenge != null) result.pairChallenge = pairChallenge;
    if (pairReveal != null) result.pairReveal = pairReveal;
    if (pairConfirm != null) result.pairConfirm = pairConfirm;
    if (pairComplete != null) result.pairComplete = pairComplete;
    if (sessionHello != null) result.sessionHello = sessionHello;
    if (sessionAccept != null) result.sessionAccept = sessionAccept;
    if (sealed != null) result.sealed = sealed;
    if (bye != null) result.bye = bye;
    return result;
  }

  Wire._();

  factory Wire.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Wire.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, Wire_Msg> _Wire_MsgByTag = {
    2: Wire_Msg.pairRequest,
    3: Wire_Msg.pairChallenge,
    4: Wire_Msg.pairReveal,
    5: Wire_Msg.pairConfirm,
    6: Wire_Msg.pairComplete,
    7: Wire_Msg.sessionHello,
    8: Wire_Msg.sessionAccept,
    9: Wire_Msg.sealed,
    10: Wire_Msg.bye,
    0: Wire_Msg.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Wire',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'porthole.v3'),
      createEmptyInstance: create)
    ..oo(0, [2, 3, 4, 5, 6, 7, 8, 9, 10])
    ..aI(1, _omitFieldNames ? '' : 'version', fieldType: $pb.PbFieldType.OU3)
    ..aOM<PairRequest>(2, _omitFieldNames ? '' : 'pairRequest',
        subBuilder: PairRequest.create)
    ..aOM<PairChallenge>(3, _omitFieldNames ? '' : 'pairChallenge',
        subBuilder: PairChallenge.create)
    ..aOM<PairReveal>(4, _omitFieldNames ? '' : 'pairReveal',
        subBuilder: PairReveal.create)
    ..aOM<PairConfirm>(5, _omitFieldNames ? '' : 'pairConfirm',
        subBuilder: PairConfirm.create)
    ..aOM<PairComplete>(6, _omitFieldNames ? '' : 'pairComplete',
        subBuilder: PairComplete.create)
    ..aOM<SessionHello>(7, _omitFieldNames ? '' : 'sessionHello',
        subBuilder: SessionHello.create)
    ..aOM<SessionAccept>(8, _omitFieldNames ? '' : 'sessionAccept',
        subBuilder: SessionAccept.create)
    ..aOM<Sealed>(9, _omitFieldNames ? '' : 'sealed', subBuilder: Sealed.create)
    ..aOM<Bye>(10, _omitFieldNames ? '' : 'bye', subBuilder: Bye.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Wire clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Wire copyWith(void Function(Wire) updates) =>
      super.copyWith((message) => updates(message as Wire)) as Wire;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Wire create() => Wire._();
  @$core.override
  Wire createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Wire getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Wire>(create);
  static Wire? _defaultInstance;

  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  Wire_Msg whichMsg() => _Wire_MsgByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  void clearMsg() => $_clearField($_whichOneof(0));

  /// 3 for this schema. A side that gets another number says bye with reason "versionMismatch".
  @$pb.TagNumber(1)
  $core.int get version => $_getIZ(0);
  @$pb.TagNumber(1)
  set version($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearVersion() => $_clearField(1);

  @$pb.TagNumber(2)
  PairRequest get pairRequest => $_getN(1);
  @$pb.TagNumber(2)
  set pairRequest(PairRequest value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasPairRequest() => $_has(1);
  @$pb.TagNumber(2)
  void clearPairRequest() => $_clearField(2);
  @$pb.TagNumber(2)
  PairRequest ensurePairRequest() => $_ensure(1);

  @$pb.TagNumber(3)
  PairChallenge get pairChallenge => $_getN(2);
  @$pb.TagNumber(3)
  set pairChallenge(PairChallenge value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasPairChallenge() => $_has(2);
  @$pb.TagNumber(3)
  void clearPairChallenge() => $_clearField(3);
  @$pb.TagNumber(3)
  PairChallenge ensurePairChallenge() => $_ensure(2);

  @$pb.TagNumber(4)
  PairReveal get pairReveal => $_getN(3);
  @$pb.TagNumber(4)
  set pairReveal(PairReveal value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasPairReveal() => $_has(3);
  @$pb.TagNumber(4)
  void clearPairReveal() => $_clearField(4);
  @$pb.TagNumber(4)
  PairReveal ensurePairReveal() => $_ensure(3);

  @$pb.TagNumber(5)
  PairConfirm get pairConfirm => $_getN(4);
  @$pb.TagNumber(5)
  set pairConfirm(PairConfirm value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasPairConfirm() => $_has(4);
  @$pb.TagNumber(5)
  void clearPairConfirm() => $_clearField(5);
  @$pb.TagNumber(5)
  PairConfirm ensurePairConfirm() => $_ensure(4);

  @$pb.TagNumber(6)
  PairComplete get pairComplete => $_getN(5);
  @$pb.TagNumber(6)
  set pairComplete(PairComplete value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasPairComplete() => $_has(5);
  @$pb.TagNumber(6)
  void clearPairComplete() => $_clearField(6);
  @$pb.TagNumber(6)
  PairComplete ensurePairComplete() => $_ensure(5);

  @$pb.TagNumber(7)
  SessionHello get sessionHello => $_getN(6);
  @$pb.TagNumber(7)
  set sessionHello(SessionHello value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasSessionHello() => $_has(6);
  @$pb.TagNumber(7)
  void clearSessionHello() => $_clearField(7);
  @$pb.TagNumber(7)
  SessionHello ensureSessionHello() => $_ensure(6);

  @$pb.TagNumber(8)
  SessionAccept get sessionAccept => $_getN(7);
  @$pb.TagNumber(8)
  set sessionAccept(SessionAccept value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasSessionAccept() => $_has(7);
  @$pb.TagNumber(8)
  void clearSessionAccept() => $_clearField(8);
  @$pb.TagNumber(8)
  SessionAccept ensureSessionAccept() => $_ensure(7);

  @$pb.TagNumber(9)
  Sealed get sealed => $_getN(8);
  @$pb.TagNumber(9)
  set sealed(Sealed value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasSealed() => $_has(8);
  @$pb.TagNumber(9)
  void clearSealed() => $_clearField(9);
  @$pb.TagNumber(9)
  Sealed ensureSealed() => $_ensure(8);

  /// Unauthenticated; it only ever closes a connection.
  @$pb.TagNumber(10)
  Bye get bye => $_getN(9);
  @$pb.TagNumber(10)
  set bye(Bye value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasBye() => $_has(9);
  @$pb.TagNumber(10)
  void clearBye() => $_clearField(10);
  @$pb.TagNumber(10)
  Bye ensureBye() => $_ensure(9);
}

/// Device → host. Commits to the device's key before the host reveals anything.
class PairRequest extends $pb.GeneratedMessage {
  factory PairRequest({
    $core.String? deviceId,
    $core.String? deviceName,
    $core.List<$core.int>? commitment,
  }) {
    final result = create();
    if (deviceId != null) result.deviceId = deviceId;
    if (deviceName != null) result.deviceName = deviceName;
    if (commitment != null) result.commitment = commitment;
    return result;
  }

  PairRequest._();

  factory PairRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PairRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PairRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'porthole.v3'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'deviceId')
    ..aOS(2, _omitFieldNames ? '' : 'deviceName')
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'commitment', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PairRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PairRequest copyWith(void Function(PairRequest) updates) =>
      super.copyWith((message) => updates(message as PairRequest))
          as PairRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PairRequest create() => PairRequest._();
  @$core.override
  PairRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PairRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PairRequest>(create);
  static PairRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get deviceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set deviceId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeviceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeviceId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get deviceName => $_getSZ(1);
  @$pb.TagNumber(2)
  set deviceName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDeviceName() => $_has(1);
  @$pb.TagNumber(2)
  void clearDeviceName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get commitment => $_getN(2);
  @$pb.TagNumber(3)
  set commitment($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCommitment() => $_has(2);
  @$pb.TagNumber(3)
  void clearCommitment() => $_clearField(3);
}

/// Host → device.
class PairChallenge extends $pb.GeneratedMessage {
  factory PairChallenge({
    $core.String? hostId,
    $core.String? hostName,
    $core.List<$core.int>? hostKey,
    $core.List<$core.int>? hostNonce,
  }) {
    final result = create();
    if (hostId != null) result.hostId = hostId;
    if (hostName != null) result.hostName = hostName;
    if (hostKey != null) result.hostKey = hostKey;
    if (hostNonce != null) result.hostNonce = hostNonce;
    return result;
  }

  PairChallenge._();

  factory PairChallenge.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PairChallenge.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PairChallenge',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'porthole.v3'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'hostId')
    ..aOS(2, _omitFieldNames ? '' : 'hostName')
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'hostKey', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'hostNonce', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PairChallenge clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PairChallenge copyWith(void Function(PairChallenge) updates) =>
      super.copyWith((message) => updates(message as PairChallenge))
          as PairChallenge;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PairChallenge create() => PairChallenge._();
  @$core.override
  PairChallenge createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PairChallenge getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PairChallenge>(create);
  static PairChallenge? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get hostId => $_getSZ(0);
  @$pb.TagNumber(1)
  set hostId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasHostId() => $_has(0);
  @$pb.TagNumber(1)
  void clearHostId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get hostName => $_getSZ(1);
  @$pb.TagNumber(2)
  set hostName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHostName() => $_has(1);
  @$pb.TagNumber(2)
  void clearHostName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get hostKey => $_getN(2);
  @$pb.TagNumber(3)
  set hostKey($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasHostKey() => $_has(2);
  @$pb.TagNumber(3)
  void clearHostKey() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get hostNonce => $_getN(3);
  @$pb.TagNumber(4)
  set hostNonce($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasHostNonce() => $_has(3);
  @$pb.TagNumber(4)
  void clearHostNonce() => $_clearField(4);
}

/// Device → host. Opens the commitment.
class PairReveal extends $pb.GeneratedMessage {
  factory PairReveal({
    $core.List<$core.int>? deviceKey,
    $core.List<$core.int>? deviceNonce,
  }) {
    final result = create();
    if (deviceKey != null) result.deviceKey = deviceKey;
    if (deviceNonce != null) result.deviceNonce = deviceNonce;
    return result;
  }

  PairReveal._();

  factory PairReveal.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PairReveal.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PairReveal',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'porthole.v3'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'deviceKey', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'deviceNonce', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PairReveal clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PairReveal copyWith(void Function(PairReveal) updates) =>
      super.copyWith((message) => updates(message as PairReveal)) as PairReveal;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PairReveal create() => PairReveal._();
  @$core.override
  PairReveal createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PairReveal getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PairReveal>(create);
  static PairReveal? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get deviceKey => $_getN(0);
  @$pb.TagNumber(1)
  set deviceKey($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeviceKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeviceKey() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get deviceNonce => $_getN(1);
  @$pb.TagNumber(2)
  set deviceNonce($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDeviceNonce() => $_has(1);
  @$pb.TagNumber(2)
  void clearDeviceNonce() => $_clearField(2);
}

/// Device → host, once the person confirms the codes match.
class PairConfirm extends $pb.GeneratedMessage {
  factory PairConfirm({
    $core.List<$core.int>? mac,
  }) {
    final result = create();
    if (mac != null) result.mac = mac;
    return result;
  }

  PairConfirm._();

  factory PairConfirm.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PairConfirm.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PairConfirm',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'porthole.v3'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'mac', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PairConfirm clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PairConfirm copyWith(void Function(PairConfirm) updates) =>
      super.copyWith((message) => updates(message as PairConfirm))
          as PairConfirm;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PairConfirm create() => PairConfirm._();
  @$core.override
  PairConfirm createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PairConfirm getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PairConfirm>(create);
  static PairConfirm? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get mac => $_getN(0);
  @$pb.TagNumber(1)
  set mac($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMac() => $_has(0);
  @$pb.TagNumber(1)
  void clearMac() => $_clearField(1);
}

/// Host → device, once the person at the Mac clicks Allow.
class PairComplete extends $pb.GeneratedMessage {
  factory PairComplete({
    $core.String? pairId,
    $core.List<$core.int>? mac,
  }) {
    final result = create();
    if (pairId != null) result.pairId = pairId;
    if (mac != null) result.mac = mac;
    return result;
  }

  PairComplete._();

  factory PairComplete.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PairComplete.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PairComplete',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'porthole.v3'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'pairId')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'mac', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PairComplete clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PairComplete copyWith(void Function(PairComplete) updates) =>
      super.copyWith((message) => updates(message as PairComplete))
          as PairComplete;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PairComplete create() => PairComplete._();
  @$core.override
  PairComplete createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PairComplete getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PairComplete>(create);
  static PairComplete? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get pairId => $_getSZ(0);
  @$pb.TagNumber(1)
  set pairId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPairId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPairId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get mac => $_getN(1);
  @$pb.TagNumber(2)
  set mac($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMac() => $_has(1);
  @$pb.TagNumber(2)
  void clearMac() => $_clearField(2);
}

/// Device → host at the start of every connection from a paired device.
class SessionHello extends $pb.GeneratedMessage {
  factory SessionHello({
    $core.String? pairId,
    $core.List<$core.int>? nonce,
    $core.List<$core.int>? mac,
  }) {
    final result = create();
    if (pairId != null) result.pairId = pairId;
    if (nonce != null) result.nonce = nonce;
    if (mac != null) result.mac = mac;
    return result;
  }

  SessionHello._();

  factory SessionHello.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SessionHello.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SessionHello',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'porthole.v3'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'pairId')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'nonce', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'mac', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionHello clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionHello copyWith(void Function(SessionHello) updates) =>
      super.copyWith((message) => updates(message as SessionHello))
          as SessionHello;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SessionHello create() => SessionHello._();
  @$core.override
  SessionHello createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SessionHello getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SessionHello>(create);
  static SessionHello? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get pairId => $_getSZ(0);
  @$pb.TagNumber(1)
  set pairId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPairId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPairId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get nonce => $_getN(1);
  @$pb.TagNumber(2)
  set nonce($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNonce() => $_has(1);
  @$pb.TagNumber(2)
  void clearNonce() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get mac => $_getN(2);
  @$pb.TagNumber(3)
  set mac($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMac() => $_has(2);
  @$pb.TagNumber(3)
  void clearMac() => $_clearField(3);
}

/// Host → device. Proves the Mac knows the pairing secret too.
class SessionAccept extends $pb.GeneratedMessage {
  factory SessionAccept({
    $core.List<$core.int>? nonce,
    $core.List<$core.int>? mac,
  }) {
    final result = create();
    if (nonce != null) result.nonce = nonce;
    if (mac != null) result.mac = mac;
    return result;
  }

  SessionAccept._();

  factory SessionAccept.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SessionAccept.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SessionAccept',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'porthole.v3'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'nonce', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'mac', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionAccept clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionAccept copyWith(void Function(SessionAccept) updates) =>
      super.copyWith((message) => updates(message as SessionAccept))
          as SessionAccept;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SessionAccept create() => SessionAccept._();
  @$core.override
  SessionAccept createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SessionAccept getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SessionAccept>(create);
  static SessionAccept? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get nonce => $_getN(0);
  @$pb.TagNumber(1)
  set nonce($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNonce() => $_has(0);
  @$pb.TagNumber(1)
  void clearNonce() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get mac => $_getN(1);
  @$pb.TagNumber(2)
  set mac($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMac() => $_has(1);
  @$pb.TagNumber(2)
  void clearMac() => $_clearField(2);
}

/// An encrypted `Signal`. `counter` is the nonce; each direction counts from 0 with no gaps.
class Sealed extends $pb.GeneratedMessage {
  factory Sealed({
    $fixnum.Int64? counter,
    $core.List<$core.int>? box,
  }) {
    final result = create();
    if (counter != null) result.counter = counter;
    if (box != null) result.box = box;
    return result;
  }

  Sealed._();

  factory Sealed.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Sealed.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Sealed',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'porthole.v3'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'counter', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'box', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Sealed clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Sealed copyWith(void Function(Sealed) updates) =>
      super.copyWith((message) => updates(message as Sealed)) as Sealed;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Sealed create() => Sealed._();
  @$core.override
  Sealed createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Sealed getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Sealed>(create);
  static Sealed? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get counter => $_getI64(0);
  @$pb.TagNumber(1)
  set counter($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCounter() => $_has(0);
  @$pb.TagNumber(1)
  void clearCounter() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get box => $_getN(1);
  @$pb.TagNumber(2)
  set box($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBox() => $_has(1);
  @$pb.TagNumber(2)
  void clearBox() => $_clearField(2);
}

class Bye extends $pb.GeneratedMessage {
  factory Bye({
    $core.String? reason,
  }) {
    final result = create();
    if (reason != null) result.reason = reason;
    return result;
  }

  Bye._();

  factory Bye.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Bye.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Bye',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'porthole.v3'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Bye clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Bye copyWith(void Function(Bye) updates) =>
      super.copyWith((message) => updates(message as Bye)) as Bye;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Bye create() => Bye._();
  @$core.override
  Bye createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Bye getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Bye>(create);
  static Bye? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get reason => $_getSZ(0);
  @$pb.TagNumber(1)
  set reason($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasReason() => $_has(0);
  @$pb.TagNumber(1)
  void clearReason() => $_clearField(1);
}

enum Signal_Msg { hello, welcome, offer, answer, candidate, notSet }

class Signal extends $pb.GeneratedMessage {
  factory Signal({
    ClientHello? hello,
    HostWelcome? welcome,
    $core.String? offer,
    $core.String? answer,
    IceCandidate? candidate,
  }) {
    final result = create();
    if (hello != null) result.hello = hello;
    if (welcome != null) result.welcome = welcome;
    if (offer != null) result.offer = offer;
    if (answer != null) result.answer = answer;
    if (candidate != null) result.candidate = candidate;
    return result;
  }

  Signal._();

  factory Signal.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Signal.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, Signal_Msg> _Signal_MsgByTag = {
    1: Signal_Msg.hello,
    2: Signal_Msg.welcome,
    3: Signal_Msg.offer,
    4: Signal_Msg.answer,
    5: Signal_Msg.candidate,
    0: Signal_Msg.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Signal',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'porthole.v3'),
      createEmptyInstance: create)
    ..oo(0, [1, 2, 3, 4, 5])
    ..aOM<ClientHello>(1, _omitFieldNames ? '' : 'hello',
        subBuilder: ClientHello.create)
    ..aOM<HostWelcome>(2, _omitFieldNames ? '' : 'welcome',
        subBuilder: HostWelcome.create)
    ..aOS(3, _omitFieldNames ? '' : 'offer')
    ..aOS(4, _omitFieldNames ? '' : 'answer')
    ..aOM<IceCandidate>(5, _omitFieldNames ? '' : 'candidate',
        subBuilder: IceCandidate.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Signal clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Signal copyWith(void Function(Signal) updates) =>
      super.copyWith((message) => updates(message as Signal)) as Signal;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Signal create() => Signal._();
  @$core.override
  Signal createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Signal getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Signal>(create);
  static Signal? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  Signal_Msg whichMsg() => _Signal_MsgByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  void clearMsg() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  ClientHello get hello => $_getN(0);
  @$pb.TagNumber(1)
  set hello(ClientHello value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasHello() => $_has(0);
  @$pb.TagNumber(1)
  void clearHello() => $_clearField(1);
  @$pb.TagNumber(1)
  ClientHello ensureHello() => $_ensure(0);

  @$pb.TagNumber(2)
  HostWelcome get welcome => $_getN(1);
  @$pb.TagNumber(2)
  set welcome(HostWelcome value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasWelcome() => $_has(1);
  @$pb.TagNumber(2)
  void clearWelcome() => $_clearField(2);
  @$pb.TagNumber(2)
  HostWelcome ensureWelcome() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.String get offer => $_getSZ(2);
  @$pb.TagNumber(3)
  set offer($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOffer() => $_has(2);
  @$pb.TagNumber(3)
  void clearOffer() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get answer => $_getSZ(3);
  @$pb.TagNumber(4)
  set answer($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAnswer() => $_has(3);
  @$pb.TagNumber(4)
  void clearAnswer() => $_clearField(4);

  @$pb.TagNumber(5)
  IceCandidate get candidate => $_getN(4);
  @$pb.TagNumber(5)
  set candidate(IceCandidate value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasCandidate() => $_has(4);
  @$pb.TagNumber(5)
  void clearCandidate() => $_clearField(5);
  @$pb.TagNumber(5)
  IceCandidate ensureCandidate() => $_ensure(4);
}

class ClientHello extends $pb.GeneratedMessage {
  factory ClientHello({
    $core.int? protocolVersion,
    $core.String? deviceName,
    PixelSize? viewport,
    $fixnum.Int64? maxFramesPerSecond,
  }) {
    final result = create();
    if (protocolVersion != null) result.protocolVersion = protocolVersion;
    if (deviceName != null) result.deviceName = deviceName;
    if (viewport != null) result.viewport = viewport;
    if (maxFramesPerSecond != null)
      result.maxFramesPerSecond = maxFramesPerSecond;
    return result;
  }

  ClientHello._();

  factory ClientHello.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClientHello.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClientHello',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'porthole.v3'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'protocolVersion',
        fieldType: $pb.PbFieldType.OU3)
    ..aOS(2, _omitFieldNames ? '' : 'deviceName')
    ..aOM<PixelSize>(3, _omitFieldNames ? '' : 'viewport',
        subBuilder: PixelSize.create)
    ..aInt64(4, _omitFieldNames ? '' : 'maxFramesPerSecond')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientHello clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientHello copyWith(void Function(ClientHello) updates) =>
      super.copyWith((message) => updates(message as ClientHello))
          as ClientHello;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClientHello create() => ClientHello._();
  @$core.override
  ClientHello createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClientHello getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClientHello>(create);
  static ClientHello? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get protocolVersion => $_getIZ(0);
  @$pb.TagNumber(1)
  set protocolVersion($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasProtocolVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearProtocolVersion() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get deviceName => $_getSZ(1);
  @$pb.TagNumber(2)
  set deviceName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDeviceName() => $_has(1);
  @$pb.TagNumber(2)
  void clearDeviceName() => $_clearField(2);

  /// The client's screen in pixels; the host never sends video larger than this.
  @$pb.TagNumber(3)
  PixelSize get viewport => $_getN(2);
  @$pb.TagNumber(3)
  set viewport(PixelSize value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasViewport() => $_has(2);
  @$pb.TagNumber(3)
  void clearViewport() => $_clearField(3);
  @$pb.TagNumber(3)
  PixelSize ensureViewport() => $_ensure(2);

  /// How many times a second the client's screen refreshes. Absent: 60.
  @$pb.TagNumber(4)
  $fixnum.Int64 get maxFramesPerSecond => $_getI64(3);
  @$pb.TagNumber(4)
  set maxFramesPerSecond($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMaxFramesPerSecond() => $_has(3);
  @$pb.TagNumber(4)
  void clearMaxFramesPerSecond() => $_clearField(4);
}

class HostWelcome extends $pb.GeneratedMessage {
  factory HostWelcome({
    $core.int? protocolVersion,
    $core.String? hostName,
  }) {
    final result = create();
    if (protocolVersion != null) result.protocolVersion = protocolVersion;
    if (hostName != null) result.hostName = hostName;
    return result;
  }

  HostWelcome._();

  factory HostWelcome.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory HostWelcome.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HostWelcome',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'porthole.v3'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'protocolVersion',
        fieldType: $pb.PbFieldType.OU3)
    ..aOS(2, _omitFieldNames ? '' : 'hostName')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HostWelcome clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HostWelcome copyWith(void Function(HostWelcome) updates) =>
      super.copyWith((message) => updates(message as HostWelcome))
          as HostWelcome;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HostWelcome create() => HostWelcome._();
  @$core.override
  HostWelcome createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static HostWelcome getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HostWelcome>(create);
  static HostWelcome? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get protocolVersion => $_getIZ(0);
  @$pb.TagNumber(1)
  set protocolVersion($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasProtocolVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearProtocolVersion() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get hostName => $_getSZ(1);
  @$pb.TagNumber(2)
  set hostName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHostName() => $_has(1);
  @$pb.TagNumber(2)
  void clearHostName() => $_clearField(2);
}

class IceCandidate extends $pb.GeneratedMessage {
  factory IceCandidate({
    $core.String? sdp,
    $core.int? sdpMLineIndex,
    $core.String? sdpMid,
  }) {
    final result = create();
    if (sdp != null) result.sdp = sdp;
    if (sdpMLineIndex != null) result.sdpMLineIndex = sdpMLineIndex;
    if (sdpMid != null) result.sdpMid = sdpMid;
    return result;
  }

  IceCandidate._();

  factory IceCandidate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory IceCandidate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'IceCandidate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'porthole.v3'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sdp')
    ..aI(2, _omitFieldNames ? '' : 'sdpMLineIndex')
    ..aOS(3, _omitFieldNames ? '' : 'sdpMid')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IceCandidate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IceCandidate copyWith(void Function(IceCandidate) updates) =>
      super.copyWith((message) => updates(message as IceCandidate))
          as IceCandidate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static IceCandidate create() => IceCandidate._();
  @$core.override
  IceCandidate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static IceCandidate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<IceCandidate>(create);
  static IceCandidate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sdp => $_getSZ(0);
  @$pb.TagNumber(1)
  set sdp($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSdp() => $_has(0);
  @$pb.TagNumber(1)
  void clearSdp() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get sdpMLineIndex => $_getIZ(1);
  @$pb.TagNumber(2)
  set sdpMLineIndex($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSdpMLineIndex() => $_has(1);
  @$pb.TagNumber(2)
  void clearSdpMLineIndex() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get sdpMid => $_getSZ(2);
  @$pb.TagNumber(3)
  set sdpMid($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSdpMid() => $_has(2);
  @$pb.TagNumber(3)
  void clearSdpMid() => $_clearField(3);
}

enum ClientMessage_Msg {
  listWindows,
  select,
  stopStream,
  viewport,
  ping,
  pointer,
  button,
  scroll,
  key,
  text,
  releaseAll,
  thumbnails,
  appIcons,
  listApps,
  launch,
  notSet
}

class ClientMessage extends $pb.GeneratedMessage {
  factory ClientMessage({
    Nothing? listWindows,
    $core.int? select,
    Nothing? stopStream,
    PixelSize? viewport,
    $fixnum.Int64? ping,
    PointerEvent? pointer,
    ButtonEvent? button,
    ScrollEvent? scroll,
    KeyEvent? key,
    TextEvent? text,
    Nothing? releaseAll,
    ThumbnailRequest? thumbnails,
    AppIconRequest? appIcons,
    Nothing? listApps,
    $core.String? launch,
  }) {
    final result = create();
    if (listWindows != null) result.listWindows = listWindows;
    if (select != null) result.select = select;
    if (stopStream != null) result.stopStream = stopStream;
    if (viewport != null) result.viewport = viewport;
    if (ping != null) result.ping = ping;
    if (pointer != null) result.pointer = pointer;
    if (button != null) result.button = button;
    if (scroll != null) result.scroll = scroll;
    if (key != null) result.key = key;
    if (text != null) result.text = text;
    if (releaseAll != null) result.releaseAll = releaseAll;
    if (thumbnails != null) result.thumbnails = thumbnails;
    if (appIcons != null) result.appIcons = appIcons;
    if (listApps != null) result.listApps = listApps;
    if (launch != null) result.launch = launch;
    return result;
  }

  ClientMessage._();

  factory ClientMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClientMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, ClientMessage_Msg> _ClientMessage_MsgByTag =
      {
    1: ClientMessage_Msg.listWindows,
    2: ClientMessage_Msg.select,
    3: ClientMessage_Msg.stopStream,
    4: ClientMessage_Msg.viewport,
    5: ClientMessage_Msg.ping,
    6: ClientMessage_Msg.pointer,
    7: ClientMessage_Msg.button,
    8: ClientMessage_Msg.scroll,
    9: ClientMessage_Msg.key,
    10: ClientMessage_Msg.text,
    11: ClientMessage_Msg.releaseAll,
    12: ClientMessage_Msg.thumbnails,
    13: ClientMessage_Msg.appIcons,
    14: ClientMessage_Msg.listApps,
    15: ClientMessage_Msg.launch,
    0: ClientMessage_Msg.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClientMessage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'porthole.v3'),
      createEmptyInstance: create)
    ..oo(0, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15])
    ..aOM<Nothing>(1, _omitFieldNames ? '' : 'listWindows',
        subBuilder: Nothing.create)
    ..aI(2, _omitFieldNames ? '' : 'select', fieldType: $pb.PbFieldType.OU3)
    ..aOM<Nothing>(3, _omitFieldNames ? '' : 'stopStream',
        subBuilder: Nothing.create)
    ..aOM<PixelSize>(4, _omitFieldNames ? '' : 'viewport',
        subBuilder: PixelSize.create)
    ..a<$fixnum.Int64>(5, _omitFieldNames ? '' : 'ping', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOM<PointerEvent>(6, _omitFieldNames ? '' : 'pointer',
        subBuilder: PointerEvent.create)
    ..aOM<ButtonEvent>(7, _omitFieldNames ? '' : 'button',
        subBuilder: ButtonEvent.create)
    ..aOM<ScrollEvent>(8, _omitFieldNames ? '' : 'scroll',
        subBuilder: ScrollEvent.create)
    ..aOM<KeyEvent>(9, _omitFieldNames ? '' : 'key',
        subBuilder: KeyEvent.create)
    ..aOM<TextEvent>(10, _omitFieldNames ? '' : 'text',
        subBuilder: TextEvent.create)
    ..aOM<Nothing>(11, _omitFieldNames ? '' : 'releaseAll',
        subBuilder: Nothing.create)
    ..aOM<ThumbnailRequest>(12, _omitFieldNames ? '' : 'thumbnails',
        subBuilder: ThumbnailRequest.create)
    ..aOM<AppIconRequest>(13, _omitFieldNames ? '' : 'appIcons',
        subBuilder: AppIconRequest.create)
    ..aOM<Nothing>(14, _omitFieldNames ? '' : 'listApps',
        subBuilder: Nothing.create)
    ..aOS(15, _omitFieldNames ? '' : 'launch')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientMessage copyWith(void Function(ClientMessage) updates) =>
      super.copyWith((message) => updates(message as ClientMessage))
          as ClientMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClientMessage create() => ClientMessage._();
  @$core.override
  ClientMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClientMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClientMessage>(create);
  static ClientMessage? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  ClientMessage_Msg whichMsg() => _ClientMessage_MsgByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  void clearMsg() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  Nothing get listWindows => $_getN(0);
  @$pb.TagNumber(1)
  set listWindows(Nothing value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasListWindows() => $_has(0);
  @$pb.TagNumber(1)
  void clearListWindows() => $_clearField(1);
  @$pb.TagNumber(1)
  Nothing ensureListWindows() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.int get select => $_getIZ(1);
  @$pb.TagNumber(2)
  set select($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSelect() => $_has(1);
  @$pb.TagNumber(2)
  void clearSelect() => $_clearField(2);

  @$pb.TagNumber(3)
  Nothing get stopStream => $_getN(2);
  @$pb.TagNumber(3)
  set stopStream(Nothing value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasStopStream() => $_has(2);
  @$pb.TagNumber(3)
  void clearStopStream() => $_clearField(3);
  @$pb.TagNumber(3)
  Nothing ensureStopStream() => $_ensure(2);

  @$pb.TagNumber(4)
  PixelSize get viewport => $_getN(3);
  @$pb.TagNumber(4)
  set viewport(PixelSize value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasViewport() => $_has(3);
  @$pb.TagNumber(4)
  void clearViewport() => $_clearField(4);
  @$pb.TagNumber(4)
  PixelSize ensureViewport() => $_ensure(3);

  /// Sent every second while connected. The host releases held keys and buttons if these stop.
  @$pb.TagNumber(5)
  $fixnum.Int64 get ping => $_getI64(4);
  @$pb.TagNumber(5)
  set ping($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPing() => $_has(4);
  @$pb.TagNumber(5)
  void clearPing() => $_clearField(5);

  @$pb.TagNumber(6)
  PointerEvent get pointer => $_getN(5);
  @$pb.TagNumber(6)
  set pointer(PointerEvent value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasPointer() => $_has(5);
  @$pb.TagNumber(6)
  void clearPointer() => $_clearField(6);
  @$pb.TagNumber(6)
  PointerEvent ensurePointer() => $_ensure(5);

  @$pb.TagNumber(7)
  ButtonEvent get button => $_getN(6);
  @$pb.TagNumber(7)
  set button(ButtonEvent value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasButton() => $_has(6);
  @$pb.TagNumber(7)
  void clearButton() => $_clearField(7);
  @$pb.TagNumber(7)
  ButtonEvent ensureButton() => $_ensure(6);

  @$pb.TagNumber(8)
  ScrollEvent get scroll => $_getN(7);
  @$pb.TagNumber(8)
  set scroll(ScrollEvent value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasScroll() => $_has(7);
  @$pb.TagNumber(8)
  void clearScroll() => $_clearField(8);
  @$pb.TagNumber(8)
  ScrollEvent ensureScroll() => $_ensure(7);

  @$pb.TagNumber(9)
  KeyEvent get key => $_getN(8);
  @$pb.TagNumber(9)
  set key(KeyEvent value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasKey() => $_has(8);
  @$pb.TagNumber(9)
  void clearKey() => $_clearField(9);
  @$pb.TagNumber(9)
  KeyEvent ensureKey() => $_ensure(8);

  @$pb.TagNumber(10)
  TextEvent get text => $_getN(9);
  @$pb.TagNumber(10)
  set text(TextEvent value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasText() => $_has(9);
  @$pb.TagNumber(10)
  void clearText() => $_clearField(10);
  @$pb.TagNumber(10)
  TextEvent ensureText() => $_ensure(9);

  @$pb.TagNumber(11)
  Nothing get releaseAll => $_getN(10);
  @$pb.TagNumber(11)
  set releaseAll(Nothing value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasReleaseAll() => $_has(10);
  @$pb.TagNumber(11)
  void clearReleaseAll() => $_clearField(11);
  @$pb.TagNumber(11)
  Nothing ensureReleaseAll() => $_ensure(10);

  @$pb.TagNumber(12)
  ThumbnailRequest get thumbnails => $_getN(11);
  @$pb.TagNumber(12)
  set thumbnails(ThumbnailRequest value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasThumbnails() => $_has(11);
  @$pb.TagNumber(12)
  void clearThumbnails() => $_clearField(12);
  @$pb.TagNumber(12)
  ThumbnailRequest ensureThumbnails() => $_ensure(11);

  @$pb.TagNumber(13)
  AppIconRequest get appIcons => $_getN(12);
  @$pb.TagNumber(13)
  set appIcons(AppIconRequest value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasAppIcons() => $_has(12);
  @$pb.TagNumber(13)
  void clearAppIcons() => $_clearField(13);
  @$pb.TagNumber(13)
  AppIconRequest ensureAppIcons() => $_ensure(12);

  @$pb.TagNumber(14)
  Nothing get listApps => $_getN(13);
  @$pb.TagNumber(14)
  set listApps(Nothing value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasListApps() => $_has(13);
  @$pb.TagNumber(14)
  void clearListApps() => $_clearField(14);
  @$pb.TagNumber(14)
  Nothing ensureListApps() => $_ensure(13);

  /// Open one of the listed apps (or ask it for a window) and stream its window.
  @$pb.TagNumber(15)
  $core.String get launch => $_getSZ(14);
  @$pb.TagNumber(15)
  set launch($core.String value) => $_setString(14, value);
  @$pb.TagNumber(15)
  $core.bool hasLaunch() => $_has(14);
  @$pb.TagNumber(15)
  void clearLaunch() => $_clearField(15);
}

enum HostMessage_Msg {
  windows,
  streamStarted,
  geometry,
  streamState,
  error,
  pong,
  control,
  thumbnail,
  appIcon,
  apps,
  notSet
}

class HostMessage extends $pb.GeneratedMessage {
  factory HostMessage({
    WindowList? windows,
    StreamInfo? streamStarted,
    StreamInfo? geometry,
    StreamStateUpdate? streamState,
    Problem? error,
    $fixnum.Int64? pong,
    ControlStatus? control,
    Thumbnail? thumbnail,
    AppIcon? appIcon,
    AppList? apps,
  }) {
    final result = create();
    if (windows != null) result.windows = windows;
    if (streamStarted != null) result.streamStarted = streamStarted;
    if (geometry != null) result.geometry = geometry;
    if (streamState != null) result.streamState = streamState;
    if (error != null) result.error = error;
    if (pong != null) result.pong = pong;
    if (control != null) result.control = control;
    if (thumbnail != null) result.thumbnail = thumbnail;
    if (appIcon != null) result.appIcon = appIcon;
    if (apps != null) result.apps = apps;
    return result;
  }

  HostMessage._();

  factory HostMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory HostMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, HostMessage_Msg> _HostMessage_MsgByTag = {
    1: HostMessage_Msg.windows,
    2: HostMessage_Msg.streamStarted,
    3: HostMessage_Msg.geometry,
    4: HostMessage_Msg.streamState,
    5: HostMessage_Msg.error,
    6: HostMessage_Msg.pong,
    7: HostMessage_Msg.control,
    8: HostMessage_Msg.thumbnail,
    9: HostMessage_Msg.appIcon,
    10: HostMessage_Msg.apps,
    0: HostMessage_Msg.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HostMessage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'porthole.v3'),
      createEmptyInstance: create)
    ..oo(0, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
    ..aOM<WindowList>(1, _omitFieldNames ? '' : 'windows',
        subBuilder: WindowList.create)
    ..aOM<StreamInfo>(2, _omitFieldNames ? '' : 'streamStarted',
        subBuilder: StreamInfo.create)
    ..aOM<StreamInfo>(3, _omitFieldNames ? '' : 'geometry',
        subBuilder: StreamInfo.create)
    ..aOM<StreamStateUpdate>(4, _omitFieldNames ? '' : 'streamState',
        subBuilder: StreamStateUpdate.create)
    ..aOM<Problem>(5, _omitFieldNames ? '' : 'error',
        subBuilder: Problem.create)
    ..a<$fixnum.Int64>(6, _omitFieldNames ? '' : 'pong', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOM<ControlStatus>(7, _omitFieldNames ? '' : 'control',
        subBuilder: ControlStatus.create)
    ..aOM<Thumbnail>(8, _omitFieldNames ? '' : 'thumbnail',
        subBuilder: Thumbnail.create)
    ..aOM<AppIcon>(9, _omitFieldNames ? '' : 'appIcon',
        subBuilder: AppIcon.create)
    ..aOM<AppList>(10, _omitFieldNames ? '' : 'apps',
        subBuilder: AppList.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HostMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HostMessage copyWith(void Function(HostMessage) updates) =>
      super.copyWith((message) => updates(message as HostMessage))
          as HostMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HostMessage create() => HostMessage._();
  @$core.override
  HostMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static HostMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HostMessage>(create);
  static HostMessage? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  HostMessage_Msg whichMsg() => _HostMessage_MsgByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  void clearMsg() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  WindowList get windows => $_getN(0);
  @$pb.TagNumber(1)
  set windows(WindowList value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasWindows() => $_has(0);
  @$pb.TagNumber(1)
  void clearWindows() => $_clearField(1);
  @$pb.TagNumber(1)
  WindowList ensureWindows() => $_ensure(0);

  @$pb.TagNumber(2)
  StreamInfo get streamStarted => $_getN(1);
  @$pb.TagNumber(2)
  set streamStarted(StreamInfo value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasStreamStarted() => $_has(1);
  @$pb.TagNumber(2)
  void clearStreamStarted() => $_clearField(2);
  @$pb.TagNumber(2)
  StreamInfo ensureStreamStarted() => $_ensure(1);

  @$pb.TagNumber(3)
  StreamInfo get geometry => $_getN(2);
  @$pb.TagNumber(3)
  set geometry(StreamInfo value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasGeometry() => $_has(2);
  @$pb.TagNumber(3)
  void clearGeometry() => $_clearField(3);
  @$pb.TagNumber(3)
  StreamInfo ensureGeometry() => $_ensure(2);

  @$pb.TagNumber(4)
  StreamStateUpdate get streamState => $_getN(3);
  @$pb.TagNumber(4)
  set streamState(StreamStateUpdate value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasStreamState() => $_has(3);
  @$pb.TagNumber(4)
  void clearStreamState() => $_clearField(4);
  @$pb.TagNumber(4)
  StreamStateUpdate ensureStreamState() => $_ensure(3);

  @$pb.TagNumber(5)
  Problem get error => $_getN(4);
  @$pb.TagNumber(5)
  set error(Problem value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasError() => $_has(4);
  @$pb.TagNumber(5)
  void clearError() => $_clearField(5);
  @$pb.TagNumber(5)
  Problem ensureError() => $_ensure(4);

  @$pb.TagNumber(6)
  $fixnum.Int64 get pong => $_getI64(5);
  @$pb.TagNumber(6)
  set pong($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPong() => $_has(5);
  @$pb.TagNumber(6)
  void clearPong() => $_clearField(6);

  @$pb.TagNumber(7)
  ControlStatus get control => $_getN(6);
  @$pb.TagNumber(7)
  set control(ControlStatus value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasControl() => $_has(6);
  @$pb.TagNumber(7)
  void clearControl() => $_clearField(7);
  @$pb.TagNumber(7)
  ControlStatus ensureControl() => $_ensure(6);

  @$pb.TagNumber(8)
  Thumbnail get thumbnail => $_getN(7);
  @$pb.TagNumber(8)
  set thumbnail(Thumbnail value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasThumbnail() => $_has(7);
  @$pb.TagNumber(8)
  void clearThumbnail() => $_clearField(8);
  @$pb.TagNumber(8)
  Thumbnail ensureThumbnail() => $_ensure(7);

  @$pb.TagNumber(9)
  AppIcon get appIcon => $_getN(8);
  @$pb.TagNumber(9)
  set appIcon(AppIcon value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasAppIcon() => $_has(8);
  @$pb.TagNumber(9)
  void clearAppIcon() => $_clearField(9);
  @$pb.TagNumber(9)
  AppIcon ensureAppIcon() => $_ensure(8);

  @$pb.TagNumber(10)
  AppList get apps => $_getN(9);
  @$pb.TagNumber(10)
  set apps(AppList value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasApps() => $_has(9);
  @$pb.TagNumber(10)
  void clearApps() => $_clearField(10);
  @$pb.TagNumber(10)
  AppList ensureApps() => $_ensure(9);
}

/// A case with nothing to say.
class Nothing extends $pb.GeneratedMessage {
  factory Nothing() => create();

  Nothing._();

  factory Nothing.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Nothing.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Nothing',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'porthole.v3'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Nothing clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Nothing copyWith(void Function(Nothing) updates) =>
      super.copyWith((message) => updates(message as Nothing)) as Nothing;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Nothing create() => Nothing._();
  @$core.override
  Nothing createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Nothing getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Nothing>(create);
  static Nothing? _defaultInstance;
}

class PixelSize extends $pb.GeneratedMessage {
  factory PixelSize({
    $fixnum.Int64? width,
    $fixnum.Int64? height,
  }) {
    final result = create();
    if (width != null) result.width = width;
    if (height != null) result.height = height;
    return result;
  }

  PixelSize._();

  factory PixelSize.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PixelSize.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PixelSize',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'porthole.v3'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'width')
    ..aInt64(2, _omitFieldNames ? '' : 'height')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PixelSize clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PixelSize copyWith(void Function(PixelSize) updates) =>
      super.copyWith((message) => updates(message as PixelSize)) as PixelSize;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PixelSize create() => PixelSize._();
  @$core.override
  PixelSize createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PixelSize getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PixelSize>(create);
  static PixelSize? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get width => $_getI64(0);
  @$pb.TagNumber(1)
  set width($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWidth() => $_has(0);
  @$pb.TagNumber(1)
  void clearWidth() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get height => $_getI64(1);
  @$pb.TagNumber(2)
  set height($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHeight() => $_has(1);
  @$pb.TagNumber(2)
  void clearHeight() => $_clearField(2);
}

class PointSize extends $pb.GeneratedMessage {
  factory PointSize({
    $core.double? width,
    $core.double? height,
  }) {
    final result = create();
    if (width != null) result.width = width;
    if (height != null) result.height = height;
    return result;
  }

  PointSize._();

  factory PointSize.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PointSize.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PointSize',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'porthole.v3'),
      createEmptyInstance: create)
    ..aD(1, _omitFieldNames ? '' : 'width')
    ..aD(2, _omitFieldNames ? '' : 'height')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PointSize clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PointSize copyWith(void Function(PointSize) updates) =>
      super.copyWith((message) => updates(message as PointSize)) as PointSize;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PointSize create() => PointSize._();
  @$core.override
  PointSize createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PointSize getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PointSize>(create);
  static PointSize? _defaultInstance;

  @$pb.TagNumber(1)
  $core.double get width => $_getN(0);
  @$pb.TagNumber(1)
  set width($core.double value) => $_setDouble(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWidth() => $_has(0);
  @$pb.TagNumber(1)
  void clearWidth() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get height => $_getN(1);
  @$pb.TagNumber(2)
  set height($core.double value) => $_setDouble(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHeight() => $_has(1);
  @$pb.TagNumber(2)
  void clearHeight() => $_clearField(2);
}

/// A position as a fraction of the video frame, 0…1 from the top left.
class NormalizedPoint extends $pb.GeneratedMessage {
  factory NormalizedPoint({
    $core.double? x,
    $core.double? y,
  }) {
    final result = create();
    if (x != null) result.x = x;
    if (y != null) result.y = y;
    return result;
  }

  NormalizedPoint._();

  factory NormalizedPoint.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory NormalizedPoint.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NormalizedPoint',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'porthole.v3'),
      createEmptyInstance: create)
    ..aD(1, _omitFieldNames ? '' : 'x')
    ..aD(2, _omitFieldNames ? '' : 'y')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NormalizedPoint clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NormalizedPoint copyWith(void Function(NormalizedPoint) updates) =>
      super.copyWith((message) => updates(message as NormalizedPoint))
          as NormalizedPoint;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NormalizedPoint create() => NormalizedPoint._();
  @$core.override
  NormalizedPoint createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static NormalizedPoint getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NormalizedPoint>(create);
  static NormalizedPoint? _defaultInstance;

  @$pb.TagNumber(1)
  $core.double get x => $_getN(0);
  @$pb.TagNumber(1)
  set x($core.double value) => $_setDouble(0, value);
  @$pb.TagNumber(1)
  $core.bool hasX() => $_has(0);
  @$pb.TagNumber(1)
  void clearX() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get y => $_getN(1);
  @$pb.TagNumber(2)
  set y($core.double value) => $_setDouble(1, value);
  @$pb.TagNumber(2)
  $core.bool hasY() => $_has(1);
  @$pb.TagNumber(2)
  void clearY() => $_clearField(2);
}

class WindowInfo extends $pb.GeneratedMessage {
  factory WindowInfo({
    $core.int? id,
    $core.String? title,
    $core.String? appName,
    $core.String? bundleId,
    $core.int? pid,
    PointSize? size,
    $core.bool? isOnScreen,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (title != null) result.title = title;
    if (appName != null) result.appName = appName;
    if (bundleId != null) result.bundleId = bundleId;
    if (pid != null) result.pid = pid;
    if (size != null) result.size = size;
    if (isOnScreen != null) result.isOnScreen = isOnScreen;
    return result;
  }

  WindowInfo._();

  factory WindowInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory WindowInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WindowInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'porthole.v3'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'id', fieldType: $pb.PbFieldType.OU3)
    ..aOS(2, _omitFieldNames ? '' : 'title')
    ..aOS(3, _omitFieldNames ? '' : 'appName')
    ..aOS(4, _omitFieldNames ? '' : 'bundleId')
    ..aI(5, _omitFieldNames ? '' : 'pid')
    ..aOM<PointSize>(6, _omitFieldNames ? '' : 'size',
        subBuilder: PointSize.create)
    ..aOB(7, _omitFieldNames ? '' : 'isOnScreen')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WindowInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WindowInfo copyWith(void Function(WindowInfo) updates) =>
      super.copyWith((message) => updates(message as WindowInfo)) as WindowInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WindowInfo create() => WindowInfo._();
  @$core.override
  WindowInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static WindowInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WindowInfo>(create);
  static WindowInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get id => $_getIZ(0);
  @$pb.TagNumber(1)
  set id($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(2)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearTitle() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get appName => $_getSZ(2);
  @$pb.TagNumber(3)
  set appName($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAppName() => $_has(2);
  @$pb.TagNumber(3)
  void clearAppName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get bundleId => $_getSZ(3);
  @$pb.TagNumber(4)
  set bundleId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBundleId() => $_has(3);
  @$pb.TagNumber(4)
  void clearBundleId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get pid => $_getIZ(4);
  @$pb.TagNumber(5)
  set pid($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPid() => $_has(4);
  @$pb.TagNumber(5)
  void clearPid() => $_clearField(5);

  @$pb.TagNumber(6)
  PointSize get size => $_getN(5);
  @$pb.TagNumber(6)
  set size(PointSize value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasSize() => $_has(5);
  @$pb.TagNumber(6)
  void clearSize() => $_clearField(6);
  @$pb.TagNumber(6)
  PointSize ensureSize() => $_ensure(5);

  @$pb.TagNumber(7)
  $core.bool get isOnScreen => $_getBF(6);
  @$pb.TagNumber(7)
  set isOnScreen($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasIsOnScreen() => $_has(6);
  @$pb.TagNumber(7)
  void clearIsOnScreen() => $_clearField(7);
}

class WindowList extends $pb.GeneratedMessage {
  factory WindowList({
    $core.Iterable<WindowInfo>? windows,
  }) {
    final result = create();
    if (windows != null) result.windows.addAll(windows);
    return result;
  }

  WindowList._();

  factory WindowList.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory WindowList.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WindowList',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'porthole.v3'),
      createEmptyInstance: create)
    ..pPM<WindowInfo>(1, _omitFieldNames ? '' : 'windows',
        subBuilder: WindowInfo.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WindowList clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WindowList copyWith(void Function(WindowList) updates) =>
      super.copyWith((message) => updates(message as WindowList)) as WindowList;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WindowList create() => WindowList._();
  @$core.override
  WindowList createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static WindowList getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WindowList>(create);
  static WindowList? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<WindowInfo> get windows => $_getList(0);
}

/// The window on the video track. `gen` increases every time it changes, so stale input can be dropped.
class StreamInfo extends $pb.GeneratedMessage {
  factory StreamInfo({
    $core.int? gen,
    $core.int? windowId,
    $core.String? title,
    $core.String? appName,
    PointSize? pointSize,
    PixelSize? pixelSize,
    $fixnum.Int64? framesPerSecond,
  }) {
    final result = create();
    if (gen != null) result.gen = gen;
    if (windowId != null) result.windowId = windowId;
    if (title != null) result.title = title;
    if (appName != null) result.appName = appName;
    if (pointSize != null) result.pointSize = pointSize;
    if (pixelSize != null) result.pixelSize = pixelSize;
    if (framesPerSecond != null) result.framesPerSecond = framesPerSecond;
    return result;
  }

  StreamInfo._();

  factory StreamInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StreamInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StreamInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'porthole.v3'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'gen', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'windowId', fieldType: $pb.PbFieldType.OU3)
    ..aOS(3, _omitFieldNames ? '' : 'title')
    ..aOS(4, _omitFieldNames ? '' : 'appName')
    ..aOM<PointSize>(5, _omitFieldNames ? '' : 'pointSize',
        subBuilder: PointSize.create)
    ..aOM<PixelSize>(6, _omitFieldNames ? '' : 'pixelSize',
        subBuilder: PixelSize.create)
    ..aInt64(7, _omitFieldNames ? '' : 'framesPerSecond')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamInfo copyWith(void Function(StreamInfo) updates) =>
      super.copyWith((message) => updates(message as StreamInfo)) as StreamInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StreamInfo create() => StreamInfo._();
  @$core.override
  StreamInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StreamInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StreamInfo>(create);
  static StreamInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get gen => $_getIZ(0);
  @$pb.TagNumber(1)
  set gen($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGen() => $_has(0);
  @$pb.TagNumber(1)
  void clearGen() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get windowId => $_getIZ(1);
  @$pb.TagNumber(2)
  set windowId($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWindowId() => $_has(1);
  @$pb.TagNumber(2)
  void clearWindowId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get title => $_getSZ(2);
  @$pb.TagNumber(3)
  set title($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTitle() => $_has(2);
  @$pb.TagNumber(3)
  void clearTitle() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get appName => $_getSZ(3);
  @$pb.TagNumber(4)
  set appName($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAppName() => $_has(3);
  @$pb.TagNumber(4)
  void clearAppName() => $_clearField(4);

  @$pb.TagNumber(5)
  PointSize get pointSize => $_getN(4);
  @$pb.TagNumber(5)
  set pointSize(PointSize value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasPointSize() => $_has(4);
  @$pb.TagNumber(5)
  void clearPointSize() => $_clearField(5);
  @$pb.TagNumber(5)
  PointSize ensurePointSize() => $_ensure(4);

  @$pb.TagNumber(6)
  PixelSize get pixelSize => $_getN(5);
  @$pb.TagNumber(6)
  set pixelSize(PixelSize value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasPixelSize() => $_has(5);
  @$pb.TagNumber(6)
  void clearPixelSize() => $_clearField(6);
  @$pb.TagNumber(6)
  PixelSize ensurePixelSize() => $_ensure(5);

  /// The most frames per second the Mac sends. Absent: 60.
  @$pb.TagNumber(7)
  $fixnum.Int64 get framesPerSecond => $_getI64(6);
  @$pb.TagNumber(7)
  set framesPerSecond($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasFramesPerSecond() => $_has(6);
  @$pb.TagNumber(7)
  void clearFramesPerSecond() => $_clearField(7);
}

class StreamState_Paused extends $pb.GeneratedMessage {
  factory StreamState_Paused({
    $core.String? reason,
  }) {
    final result = create();
    if (reason != null) result.reason = reason;
    return result;
  }

  StreamState_Paused._();

  factory StreamState_Paused.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StreamState_Paused.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StreamState.Paused',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'porthole.v3'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamState_Paused clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamState_Paused copyWith(void Function(StreamState_Paused) updates) =>
      super.copyWith((message) => updates(message as StreamState_Paused))
          as StreamState_Paused;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StreamState_Paused create() => StreamState_Paused._();
  @$core.override
  StreamState_Paused createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StreamState_Paused getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StreamState_Paused>(create);
  static StreamState_Paused? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get reason => $_getSZ(0);
  @$pb.TagNumber(1)
  set reason($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasReason() => $_has(0);
  @$pb.TagNumber(1)
  void clearReason() => $_clearField(1);
}

enum StreamState_State { live, paused, closed, notSet }

class StreamState extends $pb.GeneratedMessage {
  factory StreamState({
    Nothing? live,
    StreamState_Paused? paused,
    Nothing? closed,
  }) {
    final result = create();
    if (live != null) result.live = live;
    if (paused != null) result.paused = paused;
    if (closed != null) result.closed = closed;
    return result;
  }

  StreamState._();

  factory StreamState.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StreamState.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, StreamState_State> _StreamState_StateByTag =
      {
    1: StreamState_State.live,
    2: StreamState_State.paused,
    3: StreamState_State.closed,
    0: StreamState_State.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StreamState',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'porthole.v3'),
      createEmptyInstance: create)
    ..oo(0, [1, 2, 3])
    ..aOM<Nothing>(1, _omitFieldNames ? '' : 'live', subBuilder: Nothing.create)
    ..aOM<StreamState_Paused>(2, _omitFieldNames ? '' : 'paused',
        subBuilder: StreamState_Paused.create)
    ..aOM<Nothing>(3, _omitFieldNames ? '' : 'closed',
        subBuilder: Nothing.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamState clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamState copyWith(void Function(StreamState) updates) =>
      super.copyWith((message) => updates(message as StreamState))
          as StreamState;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StreamState create() => StreamState._();
  @$core.override
  StreamState createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StreamState getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StreamState>(create);
  static StreamState? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  StreamState_State whichState() => _StreamState_StateByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  void clearState() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  Nothing get live => $_getN(0);
  @$pb.TagNumber(1)
  set live(Nothing value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasLive() => $_has(0);
  @$pb.TagNumber(1)
  void clearLive() => $_clearField(1);
  @$pb.TagNumber(1)
  Nothing ensureLive() => $_ensure(0);

  @$pb.TagNumber(2)
  StreamState_Paused get paused => $_getN(1);
  @$pb.TagNumber(2)
  set paused(StreamState_Paused value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasPaused() => $_has(1);
  @$pb.TagNumber(2)
  void clearPaused() => $_clearField(2);
  @$pb.TagNumber(2)
  StreamState_Paused ensurePaused() => $_ensure(1);

  @$pb.TagNumber(3)
  Nothing get closed => $_getN(2);
  @$pb.TagNumber(3)
  set closed(Nothing value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasClosed() => $_has(2);
  @$pb.TagNumber(3)
  void clearClosed() => $_clearField(3);
  @$pb.TagNumber(3)
  Nothing ensureClosed() => $_ensure(2);
}

class StreamStateUpdate extends $pb.GeneratedMessage {
  factory StreamStateUpdate({
    $core.int? gen,
    StreamState? state,
  }) {
    final result = create();
    if (gen != null) result.gen = gen;
    if (state != null) result.state = state;
    return result;
  }

  StreamStateUpdate._();

  factory StreamStateUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StreamStateUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StreamStateUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'porthole.v3'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'gen', fieldType: $pb.PbFieldType.OU3)
    ..aOM<StreamState>(2, _omitFieldNames ? '' : 'state',
        subBuilder: StreamState.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamStateUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StreamStateUpdate copyWith(void Function(StreamStateUpdate) updates) =>
      super.copyWith((message) => updates(message as StreamStateUpdate))
          as StreamStateUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StreamStateUpdate create() => StreamStateUpdate._();
  @$core.override
  StreamStateUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StreamStateUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StreamStateUpdate>(create);
  static StreamStateUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get gen => $_getIZ(0);
  @$pb.TagNumber(1)
  set gen($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGen() => $_has(0);
  @$pb.TagNumber(1)
  void clearGen() => $_clearField(1);

  @$pb.TagNumber(2)
  StreamState get state => $_getN(1);
  @$pb.TagNumber(2)
  set state(StreamState value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasState() => $_has(1);
  @$pb.TagNumber(2)
  void clearState() => $_clearField(2);
  @$pb.TagNumber(2)
  StreamState ensureState() => $_ensure(1);
}

class Problem extends $pb.GeneratedMessage {
  factory Problem({
    $core.String? code,
    $core.String? message,
  }) {
    final result = create();
    if (code != null) result.code = code;
    if (message != null) result.message = message;
    return result;
  }

  Problem._();

  factory Problem.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Problem.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Problem',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'porthole.v3'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'code')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Problem clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Problem copyWith(void Function(Problem) updates) =>
      super.copyWith((message) => updates(message as Problem)) as Problem;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Problem create() => Problem._();
  @$core.override
  Problem createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Problem getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Problem>(create);
  static Problem? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get code => $_getSZ(0);
  @$pb.TagNumber(1)
  set code($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearCode() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);
}

class ControlStatus extends $pb.GeneratedMessage {
  factory ControlStatus({
    $core.bool? allowed,
    $core.String? reason,
  }) {
    final result = create();
    if (allowed != null) result.allowed = allowed;
    if (reason != null) result.reason = reason;
    return result;
  }

  ControlStatus._();

  factory ControlStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ControlStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ControlStatus',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'porthole.v3'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'allowed')
    ..aOS(2, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ControlStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ControlStatus copyWith(void Function(ControlStatus) updates) =>
      super.copyWith((message) => updates(message as ControlStatus))
          as ControlStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ControlStatus create() => ControlStatus._();
  @$core.override
  ControlStatus createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ControlStatus getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ControlStatus>(create);
  static ControlStatus? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get allowed => $_getBF(0);
  @$pb.TagNumber(1)
  set allowed($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAllowed() => $_has(0);
  @$pb.TagNumber(1)
  void clearAllowed() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get reason => $_getSZ(1);
  @$pb.TagNumber(2)
  set reason($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReason() => $_has(1);
  @$pb.TagNumber(2)
  void clearReason() => $_clearField(2);
}

class Thumbnail extends $pb.GeneratedMessage {
  factory Thumbnail({
    $core.int? windowId,
    $core.List<$core.int>? jpeg,
  }) {
    final result = create();
    if (windowId != null) result.windowId = windowId;
    if (jpeg != null) result.jpeg = jpeg;
    return result;
  }

  Thumbnail._();

  factory Thumbnail.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Thumbnail.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Thumbnail',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'porthole.v3'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'windowId', fieldType: $pb.PbFieldType.OU3)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'jpeg', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Thumbnail clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Thumbnail copyWith(void Function(Thumbnail) updates) =>
      super.copyWith((message) => updates(message as Thumbnail)) as Thumbnail;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Thumbnail create() => Thumbnail._();
  @$core.override
  Thumbnail createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Thumbnail getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Thumbnail>(create);
  static Thumbnail? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get windowId => $_getIZ(0);
  @$pb.TagNumber(1)
  set windowId($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWindowId() => $_has(0);
  @$pb.TagNumber(1)
  void clearWindowId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get jpeg => $_getN(1);
  @$pb.TagNumber(2)
  set jpeg($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasJpeg() => $_has(1);
  @$pb.TagNumber(2)
  void clearJpeg() => $_clearField(2);
}

class AppIcon extends $pb.GeneratedMessage {
  factory AppIcon({
    $core.String? bundleId,
    $core.List<$core.int>? png,
  }) {
    final result = create();
    if (bundleId != null) result.bundleId = bundleId;
    if (png != null) result.png = png;
    return result;
  }

  AppIcon._();

  factory AppIcon.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AppIcon.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AppIcon',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'porthole.v3'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'bundleId')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'png', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AppIcon clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AppIcon copyWith(void Function(AppIcon) updates) =>
      super.copyWith((message) => updates(message as AppIcon)) as AppIcon;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AppIcon create() => AppIcon._();
  @$core.override
  AppIcon createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AppIcon getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AppIcon>(create);
  static AppIcon? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get bundleId => $_getSZ(0);
  @$pb.TagNumber(1)
  set bundleId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBundleId() => $_has(0);
  @$pb.TagNumber(1)
  void clearBundleId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get png => $_getN(1);
  @$pb.TagNumber(2)
  set png($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPng() => $_has(1);
  @$pb.TagNumber(2)
  void clearPng() => $_clearField(2);
}

class AppInfo extends $pb.GeneratedMessage {
  factory AppInfo({
    $core.String? bundleId,
    $core.String? name,
    $core.bool? isRunning,
  }) {
    final result = create();
    if (bundleId != null) result.bundleId = bundleId;
    if (name != null) result.name = name;
    if (isRunning != null) result.isRunning = isRunning;
    return result;
  }

  AppInfo._();

  factory AppInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AppInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AppInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'porthole.v3'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'bundleId')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOB(3, _omitFieldNames ? '' : 'isRunning')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AppInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AppInfo copyWith(void Function(AppInfo) updates) =>
      super.copyWith((message) => updates(message as AppInfo)) as AppInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AppInfo create() => AppInfo._();
  @$core.override
  AppInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AppInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AppInfo>(create);
  static AppInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get bundleId => $_getSZ(0);
  @$pb.TagNumber(1)
  set bundleId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBundleId() => $_has(0);
  @$pb.TagNumber(1)
  void clearBundleId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get isRunning => $_getBF(2);
  @$pb.TagNumber(3)
  set isRunning($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIsRunning() => $_has(2);
  @$pb.TagNumber(3)
  void clearIsRunning() => $_clearField(3);
}

class AppList extends $pb.GeneratedMessage {
  factory AppList({
    $core.Iterable<AppInfo>? apps,
  }) {
    final result = create();
    if (apps != null) result.apps.addAll(apps);
    return result;
  }

  AppList._();

  factory AppList.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AppList.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AppList',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'porthole.v3'),
      createEmptyInstance: create)
    ..pPM<AppInfo>(1, _omitFieldNames ? '' : 'apps', subBuilder: AppInfo.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AppList clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AppList copyWith(void Function(AppList) updates) =>
      super.copyWith((message) => updates(message as AppList)) as AppList;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AppList create() => AppList._();
  @$core.override
  AppList createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AppList getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AppList>(create);
  static AppList? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<AppInfo> get apps => $_getList(0);
}

class ThumbnailRequest extends $pb.GeneratedMessage {
  factory ThumbnailRequest({
    $core.Iterable<$core.int>? windowIds,
    $fixnum.Int64? maxLongSide,
  }) {
    final result = create();
    if (windowIds != null) result.windowIds.addAll(windowIds);
    if (maxLongSide != null) result.maxLongSide = maxLongSide;
    return result;
  }

  ThumbnailRequest._();

  factory ThumbnailRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ThumbnailRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ThumbnailRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'porthole.v3'),
      createEmptyInstance: create)
    ..p<$core.int>(1, _omitFieldNames ? '' : 'windowIds', $pb.PbFieldType.KU3)
    ..aInt64(2, _omitFieldNames ? '' : 'maxLongSide')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ThumbnailRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ThumbnailRequest copyWith(void Function(ThumbnailRequest) updates) =>
      super.copyWith((message) => updates(message as ThumbnailRequest))
          as ThumbnailRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ThumbnailRequest create() => ThumbnailRequest._();
  @$core.override
  ThumbnailRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ThumbnailRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ThumbnailRequest>(create);
  static ThumbnailRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.int> get windowIds => $_getList(0);

  @$pb.TagNumber(2)
  $fixnum.Int64 get maxLongSide => $_getI64(1);
  @$pb.TagNumber(2)
  set maxLongSide($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMaxLongSide() => $_has(1);
  @$pb.TagNumber(2)
  void clearMaxLongSide() => $_clearField(2);
}

class AppIconRequest extends $pb.GeneratedMessage {
  factory AppIconRequest({
    $core.Iterable<$core.String>? bundleIds,
  }) {
    final result = create();
    if (bundleIds != null) result.bundleIds.addAll(bundleIds);
    return result;
  }

  AppIconRequest._();

  factory AppIconRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AppIconRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AppIconRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'porthole.v3'),
      createEmptyInstance: create)
    ..pPS(1, _omitFieldNames ? '' : 'bundleIds')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AppIconRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AppIconRequest copyWith(void Function(AppIconRequest) updates) =>
      super.copyWith((message) => updates(message as AppIconRequest))
          as AppIconRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AppIconRequest create() => AppIconRequest._();
  @$core.override
  AppIconRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AppIconRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AppIconRequest>(create);
  static AppIconRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get bundleIds => $_getList(0);
}

class PointerEvent extends $pb.GeneratedMessage {
  factory PointerEvent({
    $core.int? gen,
    NormalizedPoint? point,
  }) {
    final result = create();
    if (gen != null) result.gen = gen;
    if (point != null) result.point = point;
    return result;
  }

  PointerEvent._();

  factory PointerEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PointerEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PointerEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'porthole.v3'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'gen', fieldType: $pb.PbFieldType.OU3)
    ..aOM<NormalizedPoint>(2, _omitFieldNames ? '' : 'point',
        subBuilder: NormalizedPoint.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PointerEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PointerEvent copyWith(void Function(PointerEvent) updates) =>
      super.copyWith((message) => updates(message as PointerEvent))
          as PointerEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PointerEvent create() => PointerEvent._();
  @$core.override
  PointerEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PointerEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PointerEvent>(create);
  static PointerEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get gen => $_getIZ(0);
  @$pb.TagNumber(1)
  set gen($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGen() => $_has(0);
  @$pb.TagNumber(1)
  void clearGen() => $_clearField(1);

  @$pb.TagNumber(2)
  NormalizedPoint get point => $_getN(1);
  @$pb.TagNumber(2)
  set point(NormalizedPoint value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasPoint() => $_has(1);
  @$pb.TagNumber(2)
  void clearPoint() => $_clearField(2);
  @$pb.TagNumber(2)
  NormalizedPoint ensurePoint() => $_ensure(1);
}

class ButtonEvent extends $pb.GeneratedMessage {
  factory ButtonEvent({
    $core.int? gen,
    NormalizedPoint? point,
    MouseButton? button,
    $core.bool? isDown,
  }) {
    final result = create();
    if (gen != null) result.gen = gen;
    if (point != null) result.point = point;
    if (button != null) result.button = button;
    if (isDown != null) result.isDown = isDown;
    return result;
  }

  ButtonEvent._();

  factory ButtonEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ButtonEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ButtonEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'porthole.v3'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'gen', fieldType: $pb.PbFieldType.OU3)
    ..aOM<NormalizedPoint>(2, _omitFieldNames ? '' : 'point',
        subBuilder: NormalizedPoint.create)
    ..aE<MouseButton>(3, _omitFieldNames ? '' : 'button',
        enumValues: MouseButton.values)
    ..aOB(4, _omitFieldNames ? '' : 'isDown')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ButtonEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ButtonEvent copyWith(void Function(ButtonEvent) updates) =>
      super.copyWith((message) => updates(message as ButtonEvent))
          as ButtonEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ButtonEvent create() => ButtonEvent._();
  @$core.override
  ButtonEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ButtonEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ButtonEvent>(create);
  static ButtonEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get gen => $_getIZ(0);
  @$pb.TagNumber(1)
  set gen($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGen() => $_has(0);
  @$pb.TagNumber(1)
  void clearGen() => $_clearField(1);

  @$pb.TagNumber(2)
  NormalizedPoint get point => $_getN(1);
  @$pb.TagNumber(2)
  set point(NormalizedPoint value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasPoint() => $_has(1);
  @$pb.TagNumber(2)
  void clearPoint() => $_clearField(2);
  @$pb.TagNumber(2)
  NormalizedPoint ensurePoint() => $_ensure(1);

  @$pb.TagNumber(3)
  MouseButton get button => $_getN(2);
  @$pb.TagNumber(3)
  set button(MouseButton value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasButton() => $_has(2);
  @$pb.TagNumber(3)
  void clearButton() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get isDown => $_getBF(3);
  @$pb.TagNumber(4)
  set isDown($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasIsDown() => $_has(3);
  @$pb.TagNumber(4)
  void clearIsDown() => $_clearField(4);
}

/// `dx`/`dy` are fractions of the video's width and height. Positive `dy`: the finger moved down.
class ScrollEvent extends $pb.GeneratedMessage {
  factory ScrollEvent({
    $core.int? gen,
    NormalizedPoint? point,
    $core.double? dx,
    $core.double? dy,
    ScrollPhase? phase,
    MomentumPhase? momentum,
  }) {
    final result = create();
    if (gen != null) result.gen = gen;
    if (point != null) result.point = point;
    if (dx != null) result.dx = dx;
    if (dy != null) result.dy = dy;
    if (phase != null) result.phase = phase;
    if (momentum != null) result.momentum = momentum;
    return result;
  }

  ScrollEvent._();

  factory ScrollEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ScrollEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ScrollEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'porthole.v3'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'gen', fieldType: $pb.PbFieldType.OU3)
    ..aOM<NormalizedPoint>(2, _omitFieldNames ? '' : 'point',
        subBuilder: NormalizedPoint.create)
    ..aD(3, _omitFieldNames ? '' : 'dx')
    ..aD(4, _omitFieldNames ? '' : 'dy')
    ..aE<ScrollPhase>(5, _omitFieldNames ? '' : 'phase',
        enumValues: ScrollPhase.values)
    ..aE<MomentumPhase>(6, _omitFieldNames ? '' : 'momentum',
        enumValues: MomentumPhase.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScrollEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScrollEvent copyWith(void Function(ScrollEvent) updates) =>
      super.copyWith((message) => updates(message as ScrollEvent))
          as ScrollEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ScrollEvent create() => ScrollEvent._();
  @$core.override
  ScrollEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ScrollEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ScrollEvent>(create);
  static ScrollEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get gen => $_getIZ(0);
  @$pb.TagNumber(1)
  set gen($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGen() => $_has(0);
  @$pb.TagNumber(1)
  void clearGen() => $_clearField(1);

  @$pb.TagNumber(2)
  NormalizedPoint get point => $_getN(1);
  @$pb.TagNumber(2)
  set point(NormalizedPoint value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasPoint() => $_has(1);
  @$pb.TagNumber(2)
  void clearPoint() => $_clearField(2);
  @$pb.TagNumber(2)
  NormalizedPoint ensurePoint() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.double get dx => $_getN(2);
  @$pb.TagNumber(3)
  set dx($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDx() => $_has(2);
  @$pb.TagNumber(3)
  void clearDx() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get dy => $_getN(3);
  @$pb.TagNumber(4)
  set dy($core.double value) => $_setDouble(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDy() => $_has(3);
  @$pb.TagNumber(4)
  void clearDy() => $_clearField(4);

  @$pb.TagNumber(5)
  ScrollPhase get phase => $_getN(4);
  @$pb.TagNumber(5)
  set phase(ScrollPhase value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasPhase() => $_has(4);
  @$pb.TagNumber(5)
  void clearPhase() => $_clearField(5);

  @$pb.TagNumber(6)
  MomentumPhase get momentum => $_getN(5);
  @$pb.TagNumber(6)
  set momentum(MomentumPhase value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasMomentum() => $_has(5);
  @$pb.TagNumber(6)
  void clearMomentum() => $_clearField(6);
}

/// A physical key as a USB HID usage on the keyboard page (0x07); the Mac's layout picks the character.
class KeyEvent extends $pb.GeneratedMessage {
  factory KeyEvent({
    $core.int? gen,
    $core.int? usage,
    $core.bool? isDown,
    $core.int? modifiers,
  }) {
    final result = create();
    if (gen != null) result.gen = gen;
    if (usage != null) result.usage = usage;
    if (isDown != null) result.isDown = isDown;
    if (modifiers != null) result.modifiers = modifiers;
    return result;
  }

  KeyEvent._();

  factory KeyEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory KeyEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'KeyEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'porthole.v3'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'gen', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'usage', fieldType: $pb.PbFieldType.OU3)
    ..aOB(3, _omitFieldNames ? '' : 'isDown')
    ..aI(4, _omitFieldNames ? '' : 'modifiers', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeyEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeyEvent copyWith(void Function(KeyEvent) updates) =>
      super.copyWith((message) => updates(message as KeyEvent)) as KeyEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static KeyEvent create() => KeyEvent._();
  @$core.override
  KeyEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static KeyEvent getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<KeyEvent>(create);
  static KeyEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get gen => $_getIZ(0);
  @$pb.TagNumber(1)
  set gen($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGen() => $_has(0);
  @$pb.TagNumber(1)
  void clearGen() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get usage => $_getIZ(1);
  @$pb.TagNumber(2)
  set usage($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUsage() => $_has(1);
  @$pb.TagNumber(2)
  void clearUsage() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get isDown => $_getBF(2);
  @$pb.TagNumber(3)
  set isDown($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIsDown() => $_has(2);
  @$pb.TagNumber(3)
  void clearIsDown() => $_clearField(3);

  /// Bits: 1 shift, 2 control, 4 option, 8 command.
  @$pb.TagNumber(4)
  $core.int get modifiers => $_getIZ(3);
  @$pb.TagNumber(4)
  set modifiers($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasModifiers() => $_has(3);
  @$pb.TagNumber(4)
  void clearModifiers() => $_clearField(4);
}

/// Text from the on-screen keyboard, typed as-is.
class TextEvent extends $pb.GeneratedMessage {
  factory TextEvent({
    $core.int? gen,
    $core.String? text,
  }) {
    final result = create();
    if (gen != null) result.gen = gen;
    if (text != null) result.text = text;
    return result;
  }

  TextEvent._();

  factory TextEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TextEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TextEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'porthole.v3'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'gen', fieldType: $pb.PbFieldType.OU3)
    ..aOS(2, _omitFieldNames ? '' : 'text')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TextEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TextEvent copyWith(void Function(TextEvent) updates) =>
      super.copyWith((message) => updates(message as TextEvent)) as TextEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TextEvent create() => TextEvent._();
  @$core.override
  TextEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TextEvent getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TextEvent>(create);
  static TextEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get gen => $_getIZ(0);
  @$pb.TagNumber(1)
  set gen($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGen() => $_has(0);
  @$pb.TagNumber(1)
  void clearGen() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get text => $_getSZ(1);
  @$pb.TagNumber(2)
  set text($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasText() => $_has(1);
  @$pb.TagNumber(2)
  void clearText() => $_clearField(2);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
