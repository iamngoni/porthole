import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:porthole_protocol/porthole_protocol.dart';

/// Every Mac this device is paired with, keyed by host ID, and this install's device ID.
abstract interface class PairingStore {
  /// Sorted by host ID.
  Future<List<PairedHost>> all();
  Future<void> save(PairedHost host);

  /// Forgets a Mac: its pairing and the address it is reached at.
  Future<void> remove(String hostId);

  /// Where to reach each paired Mac when Bonjour can't see it, by host ID, as RemoteAddress.text.
  Future<Map<String, String>> addresses();
  Future<void> saveAddress(String hostId, String address);
  Future<void> removeAddress(String hostId);

  /// Forgets every Mac and the device ID.
  Future<void> removeAll();

  /// Keeps [id] as the device ID from now on: the one the Swift app had, so Macs still know the device.
  Future<void> adoptDeviceId(String id);

  /// A random ID made on first launch and kept from then on. It names this install to the Mac; it is not
  /// a secret and proves nothing (the pairing secret does that).
  Future<String> deviceId();
}

/// How a pairing is written down: JSON with the secret in base64.
abstract final class PairedHostCodec {
  static const secretLength = 32;

  static String encode(PairedHost host) => jsonEncode({
        'hostID': host.hostId,
        'hostName': host.hostName,
        'pairID': host.pairId,
        'secret': base64Encode(host.secret),
      });

  /// Null for anything that isn't a whole pairing, so one damaged item can't hide the others.
  static PairedHost? decode(String text) {
    try {
      if (jsonDecode(text) case {
        'hostID': final String hostId,
        'hostName': final String hostName,
        'pairID': final String pairId,
        'secret': final String secret,
      } when hostId.isNotEmpty && pairId.isNotEmpty) {
        final bytes = base64Decode(secret);
        if (bytes.length != secretLength) return null;
        return PairedHost(hostId: hostId, hostName: hostName, pairId: pairId, secret: bytes);
      }
    } on FormatException {
      // Fall through.
    }
    return null;
  }
}

/// A new random (version 4) UUID, upper case like the iOS app's.
String randomUuid([Random? random]) {
  final source = random ?? Random.secure();
  final bytes = Uint8List.fromList(List.generate(16, (_) => source.nextInt(256)));
  bytes[6] = (bytes[6] & 0x0F) | 0x40;
  bytes[8] = (bytes[8] & 0x3F) | 0x80;
  final hex = toHex(bytes).toUpperCase();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// Keeps pairings in the Keychain on iOS (this device only, readable only while it is unlocked, never
/// synced) and in encrypted storage on Android (left out of backups by the manifest).
final class SecurePairingStore implements PairingStore {
  SecurePairingStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(
                accountName: 'dev.iamngoni.porthole.paired-hosts',
                accessibility: KeychainAccessibility.unlocked_this_device,
                synchronizable: false,
              ),
              aOptions: AndroidOptions(storageNamespace: 'porthole_pairings'),
            );

  final FlutterSecureStorage _storage;
  static const _hostPrefix = 'host.';
  static const _addressPrefix = 'address.';
  static const _deviceIdKey = 'deviceID';

  @override
  Future<List<PairedHost>> all() async {
    final items = await _storage.readAll();
    final keys = items.keys.where((key) => key.startsWith(_hostPrefix)).toList()..sort();
    return [for (final key in keys) ?PairedHostCodec.decode(items[key]!)];
  }

  @override
  Future<void> save(PairedHost host) => _storage.write(key: '$_hostPrefix${host.hostId}', value: PairedHostCodec.encode(host));

  @override
  Future<void> remove(String hostId) async {
    await _storage.delete(key: '$_hostPrefix$hostId');
    await removeAddress(hostId);
  }

  @override
  Future<Map<String, String>> addresses() async {
    final items = await _storage.readAll();
    return {
      for (final MapEntry(:key, :value) in items.entries)
        if (key.startsWith(_addressPrefix)) key.substring(_addressPrefix.length): value,
    };
  }

  @override
  Future<void> saveAddress(String hostId, String address) => _storage.write(key: '$_addressPrefix$hostId', value: address);

  @override
  Future<void> removeAddress(String hostId) => _storage.delete(key: '$_addressPrefix$hostId');

  @override
  Future<void> removeAll() => _storage.deleteAll();

  @override
  Future<void> adoptDeviceId(String id) => _storage.write(key: _deviceIdKey, value: id);

  @override
  Future<String> deviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = randomUuid();
    await _storage.write(key: _deviceIdKey, value: id);
    return id;
  }
}

/// For tests and design previews.
final class MemoryPairingStore implements PairingStore {
  MemoryPairingStore([Iterable<PairedHost> hosts = const []]) {
    for (final host in hosts) {
      _items[host.hostId] = PairedHostCodec.encode(host);
    }
  }

  final _items = <String, String>{};
  final _addresses = <String, String>{};
  var _deviceId = randomUuid();

  @override
  Future<List<PairedHost>> all() async => [for (final key in _items.keys.toList()..sort()) ?PairedHostCodec.decode(_items[key]!)];

  @override
  Future<void> save(PairedHost host) async => _items[host.hostId] = PairedHostCodec.encode(host);

  @override
  Future<void> remove(String hostId) async {
    _items.remove(hostId);
    _addresses.remove(hostId);
  }

  @override
  Future<Map<String, String>> addresses() async => Map.of(_addresses);

  @override
  Future<void> saveAddress(String hostId, String address) async => _addresses[hostId] = address;

  @override
  Future<void> removeAddress(String hostId) async => _addresses.remove(hostId);

  @override
  Future<void> removeAll() async {
    _items.clear();
    _addresses.clear();
    _deviceId = randomUuid();
  }

  @override
  Future<void> adoptDeviceId(String id) async => _deviceId = id;

  @override
  Future<String> deviceId() async => _deviceId;
}

/// What iOS found on this launch. The Keychain outlives deleting an app, so the first launch of an install
/// decides what to keep (Android removes an app's storage when it is uninstalled).
sealed class InstallState {
  const InstallState();

  /// Reads what AppDelegate.swift reports; null if it makes no sense.
  static InstallState? fromPlatform(Object? value) => switch (value) {
        {'state': 'known'} => const KnownInstall(),
        {'state': 'fresh'} => const FreshInstall(),
        {'state': 'upgrade', 'deviceId': final String deviceId, 'pairings': final List<Object?> pairings}
            when deviceId.isNotEmpty =>
          UpdatedFromSwiftApp(deviceId, [for (final record in pairings) ?(record is String ? record : null)]),
        _ => null,
      };
}

/// Launched before; nothing to do.
final class KnownInstall extends InstallState {
  const KnownInstall();
}

/// Installed fresh, maybe after being deleted: pairings left in the Keychain from before are dropped, or
/// reinstalling would bring back control of every Mac.
final class FreshInstall extends InstallState {
  const FreshInstall();
}

/// Installed over the Swift app, which kept pairings as JSON records of its own and its device ID in user
/// defaults. Both carry over, so neither the device nor the Macs need pairing again.
final class UpdatedFromSwiftApp extends InstallState {
  const UpdatedFromSwiftApp(this.deviceId, this.records);
  final String deviceId;
  final List<String> records;
}

/// The Swift app's records that are whole pairings, one per Mac (the later of two for the same Mac).
List<PairedHost> carriedOver(List<String> records) {
  final byHost = <String, PairedHost>{};
  for (final record in records) {
    if (PairedHostCodec.decode(record) case final host?) byHost[host.hostId] = host;
  }
  return byHost.values.toList();
}

/// Settles [state] in [store] before anything reads it.
Future<void> settleInstall(PairingStore store, InstallState state) async {
  switch (state) {
    case KnownInstall():
      return;
    case FreshInstall():
      await store.removeAll();
    case UpdatedFromSwiftApp(:final deviceId, :final records):
      for (final host in carriedOver(records)) {
        await store.save(host);
      }
      await store.adoptDeviceId(deviceId);
  }
}
