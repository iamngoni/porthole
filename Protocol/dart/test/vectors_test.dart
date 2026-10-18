import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:fixnum/fixnum.dart';
import 'package:porthole_protocol/porthole_protocol.dart';
import 'package:protobuf/protobuf.dart';
import 'package:test/test.dart';

// Protocol/vectors is written by the Swift tests (ContractVectorsTests.swift) from the code Porthole Host
// runs. Matching it byte for byte is what lets this package talk to the Mac.

Map<String, dynamic> _load(String name) =>
    jsonDecode(File('../vectors/$name').readAsStringSync()) as Map<String, dynamic>;

final _crypto = _load('crypto.json');
final _messages = _load('messages.json');

void main() {
  group('framing', () {
    for (final vector in (_crypto['framing'] as List).cast<Map<String, dynamic>>()) {
      final payload = vector['payload'] as String;
      test('frames ${payload.length ~/ 2} bytes', () {
        expect(toHex(Framing.frame(fromHex(payload))), vector['framed']);
        expect(FrameDecoder().append(fromHex(vector['framed'] as String)).map(toHex), [payload]);
      });
    }
  });

  group('pairing', () {
    for (final vector in (_crypto['pairing'] as List).cast<Map<String, dynamic>>()) {
      String hex(String key) => vector[key] as String;

      test('a device pairs with the Mac and both show ${vector['code']}', () async {
        final device = await DevicePairing.createWith(
          deviceId: vector['deviceID'] as String,
          deviceName: vector['deviceName'] as String,
          privateKey: fromHex(hex('devicePrivateKey')),
          nonce: fromHex(hex('deviceNonce')),
        );
        final request = await device.start();
        expect(toHex(request.commitment), hex('commitment'));

        final challenge = PairChallenge(
          hostId: vector['hostID'] as String,
          hostName: vector['hostName'] as String,
          hostKey: fromHex(hex('hostPublicKey')),
          hostNonce: fromHex(hex('hostNonce')),
        );
        final (reveal, code) = await device.receiveChallenge(challenge);
        expect(toHex(reveal.deviceKey), hex('devicePublicKey'));
        expect(toHex(await PairingCrypto.transcript(request, challenge, reveal)), hex('transcript'));
        expect(code, vector['code']);

        final confirm = await device.confirm();
        expect(toHex(confirm.mac), hex('deviceConfirmation'));

        final host = await device.receiveComplete(PairComplete(pairId: vector['pairID'] as String, mac: fromHex(hex('hostConfirmation'))));
        expect(toHex(host.secret), hex('secret'));
        expect((host.hostId, host.hostName, host.pairId), (vector['hostID'], vector['hostName'], vector['pairID']));
      });

      test('the shared secret and code digits behind ${vector['code']}', () async {
        final hostKeys = await PairingCrypto.keyPair(fromHex(hex('hostPrivateKey')));
        expect(toHex(await PairingCrypto.publicKey(hostKeys)), hex('hostPublicKey'));
        final shared = await PairingCrypto.agree(hostKeys, fromHex(hex('devicePublicKey')));
        expect(toHex(await shared.extractBytes()), hex('sharedSecret'));
        final sas = await PairingCrypto.hkdf(shared, salt: fromHex(hex('transcript')), info: 'porthole-sas-v1', length: 8);
        expect(toHex(sas), hex('sasBytes'));
        // Swift reads these 8 bytes as a UInt64; the cases include one with the top bit set.
        expect(sas.fold(BigInt.zero, (value, byte) => value << 8 | BigInt.from(byte)).toString(), vector['sasUnsigned']);
      });
    }

    test('every low-order key is refused', () async {
      final device = await PairingCrypto.keyPair(List.generate(32, (i) => i));
      for (final key in (_crypto['rejectedPublicKeys'] as List).cast<String>()) {
        await expectLater(PairingCrypto.agree(device, fromHex(key)), throwsA(PairingError.invalidKey), reason: key);
      }
    });
  });

  group('session', () {
    final vector = _crypto['session'] as Map<String, dynamic>;
    final secret = fromHex(vector['secret'] as String);
    final pairId = vector['pairID'] as String;

    Future<(SessionHello, SessionAccept)> handshake() async {
      final hello = await SessionHandshake.helloWith(pairId: pairId, secret: secret, nonce: fromHex(vector['helloNonce'] as String));
      final accept = SessionAccept(nonce: fromHex(vector['acceptNonce'] as String), mac: fromHex(vector['acceptMAC'] as String));
      return (hello, accept);
    }

    test('hello and accept', () async {
      final (hello, accept) = await handshake();
      expect(toHex(hello.mac), vector['helloMAC']);
      expect(await SessionHandshake.isValidAccept(accept, hello, secret), isTrue);
      expect(toHex((await SessionHandshake.accept(hello, secret, nonce: accept.nonce)).mac), vector['acceptMAC']);
    });

    test('the device seals what the Mac opens, and opens what the Mac seals', () async {
      final (hello, accept) = await handshake();
      final channel = await SessionHandshake.channel(role: SessionRole.device, secret: secret, hello: hello, accept: accept);
      for (final frame in (vector['deviceToHost'] as List).cast<Map<String, dynamic>>()) {
        final sealed = channel.seal(fromHex(frame['plaintext'] as String));
        expect((sealed.counter.toInt(), toHex(sealed.box)), (frame['counter'], frame['box']));
      }
      for (final frame in (vector['hostToDevice'] as List).cast<Map<String, dynamic>>()) {
        final sealed = Sealed(counter: Int64(frame['counter'] as int), box: fromHex(frame['box'] as String));
        expect(toHex(channel.open(sealed)), frame['plaintext']);
      }
    });
  });

  group('messages', () {
    final vectors = (_messages['messages'] as List).cast<Map<String, dynamic>>();

    GeneratedMessage decode(Map<String, dynamic> vector) {
      final bytes = fromHex(vector['hex'] as String);
      return switch (vector['kind']) {
        'wire' => (WireCoding.decode(bytes) as WireFrame).wire,
        'signal' => MessageCoding.decodeSignal(bytes),
        'client' => ClientMessage.fromBuffer(bytes),
        _ => MessageCoding.decodeHost(bytes),
      };
    }

    for (final vector in vectors) {
      test('${vector['kind']} ${vector['name']} decodes to the same values and encodes to the same bytes', () {
        final decoded = decode(vector);
        final fromJson = decoded.createEmptyInstance()..mergeFromProto3Json(vector['json']);
        expect(decoded, fromJson);
        expect(toHex(fromJson.writeToBuffer()), vector['hex']);
        expect(const DeepCollectionEquality().equals(decoded.toProto3Json(), vector['json']), isTrue,
            reason: '${jsonEncode(decoded.toProto3Json())} != ${jsonEncode(vector['json'])}');
      });
    }

    test('every message case has a vector', () {
      Set<String> cases(String kind) =>
          {for (final vector in vectors.where((v) => v['kind'] == kind)) _caseName(decode(vector))};
      Set<String> all(List<Enum> values) => {for (final value in values) if (value.name != 'notSet') value.name};
      expect(cases('wire'), all(Wire_Msg.values));
      expect(cases('signal'), all(Signal_Msg.values));
      expect(cases('client'), all(ClientMessage_Msg.values));
      expect(cases('host'), all(HostMessage_Msg.values));
    });
  });
}

String _caseName(GeneratedMessage message) => switch (message) {
      Wire() => message.whichMsg().name,
      Signal() => message.whichMsg().name,
      ClientMessage() => message.whichMsg().name,
      HostMessage() => message.whichMsg().name,
      _ => throw ArgumentError(message),
    };
