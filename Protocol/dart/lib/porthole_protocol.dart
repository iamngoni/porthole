/// The Porthole wire protocol, version 3, for Dart clients: framing, pairing, the secure channel and
/// every message in Protocol/porthole.proto.
///
/// It mirrors Packages/PortholeKit/Sources/PortholeProtocol. Protocol/vectors pins the bytes both must
/// produce, so a change to either side that the other wouldn't understand fails a test.
library;

export 'src/bytes.dart' show fromHex, toHex;
export 'src/connection.dart';
export 'src/framing.dart';
export 'src/generated/porthole.pb.dart';
export 'src/links.dart';
export 'src/messages.dart';
export 'src/pairing.dart';
export 'src/secure_channel.dart';
export 'src/wire.dart';
