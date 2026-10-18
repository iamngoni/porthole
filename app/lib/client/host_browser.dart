import 'dart:async';
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:porthole_protocol/porthole_protocol.dart';

/// A Mac found on the local network.
@immutable
final class DiscoveredHost {
  const DiscoveredHost({required this.name, this.hostId, this.addresses = const [], this.hostname, required this.port});

  final String name;

  /// The Mac's stable ID from its Bonjour record. Unauthenticated: only used to pick which pairing to try.
  final String? hostId;
  final List<String> addresses;
  final String? hostname;
  final int port;

  /// Where to connect, best first: IPv4 addresses, then the Mac's .local name, then IPv6 (link-local
  /// addresses need a scope that doesn't always survive the trip from the plugin).
  List<String> get targets {
    final v4 = addresses.where((a) => InternetAddress.tryParse(a)?.type == InternetAddressType.IPv4);
    final v6 = addresses.where((a) => InternetAddress.tryParse(a)?.type != InternetAddressType.IPv4);
    return {...v4, ?hostname, ...v6}.toList();
  }

  DiscoveredHost copyWith({String? hostId}) =>
      DiscoveredHost(name: name, hostId: hostId ?? this.hostId, addresses: addresses, hostname: hostname, port: port);

  @override
  bool operator ==(Object other) =>
      other is DiscoveredHost &&
      other.name == name &&
      other.hostId == hostId &&
      const ListEquality<String>().equals(other.addresses, addresses) &&
      other.hostname == hostname &&
      other.port == port;

  @override
  int get hashCode => Object.hash(name, hostId, Object.hashAll(addresses), hostname, port);

  @override
  String toString() => 'DiscoveredHost($name, $hostId, $targets:$port)';
}

/// The Macs found so far: one per name, sorted by name the way people read them.
final class HostDirectory {
  final _byName = <String, DiscoveredHost>{};

  List<DiscoveredHost> get hosts => _byName.values.sorted(_byNameOrder);

  /// A record resolved or changed. Returns whether the list changed.
  bool resolved(DiscoveredHost host) {
    final existing = _byName[host.name];
    // The same Mac can answer once per network interface; a record without the ID doesn't drop the one we know.
    final merged = host.hostId == null && existing?.hostId != null ? host.copyWith(hostId: existing!.hostId) : host;
    if (existing == merged) return false;
    _byName[host.name] = merged;
    return true;
  }

  /// Returns whether the list changed.
  bool lost(String name) => _byName.remove(name) != null;

  bool clear() {
    final hadAny = _byName.isNotEmpty;
    _byName.clear();
    return hadAny;
  }

  static int _byNameOrder(DiscoveredHost a, DiscoveredHost b) {
    final folded = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return folded != 0 ? folded : a.name.compareTo(b.name);
  }
}

enum BrowseStatus {
  starting,
  searching,

  /// The user turned off Local Network access for the app.
  localNetworkDenied,
  problem,
}

/// Finds Porthole hosts on the local network.
final class HostBrowser extends ChangeNotifier {
  final _directory = HostDirectory();
  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _events;
  Timer? _restart;
  var _isRunning = false;
  var _isDenied = false;

  BrowseStatus _status = BrowseStatus.starting;
  String? _problem;

  List<DiscoveredHost> get hosts => _directory.hosts;
  BrowseStatus get status => _isDenied ? BrowseStatus.localNetworkDenied : _status;

  /// What went wrong, when [status] is [BrowseStatus.problem].
  String? get problem => _problem;

  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;
    await _begin();
  }

  Future<void> stop() async {
    _isRunning = false;
    await _end();
  }

  /// iOS says when Local Network access is off; the plugin only sees a browse that never finds anything.
  set localNetworkDenied(bool denied) {
    if (denied == _isDenied) return;
    _isDenied = denied;
    notifyListeners();
  }

  @override
  void dispose() {
    _isRunning = false;
    _end();
    super.dispose();
  }

  Future<void> _begin() async {
    final discovery = BonsoirDiscovery(type: portholeBonjourType);
    _discovery = discovery;
    try {
      await discovery.initialize();
      if (!identical(discovery, _discovery)) return;
      _events = discovery.eventStream?.listen((event) => _handle(discovery, event), onError: (Object error) => _failed(error));
      await discovery.start();
    } catch (error) {
      _failed(error);
    }
  }

  Future<void> _end() async {
    _restart?.cancel();
    _restart = null;
    await _events?.cancel();
    _events = null;
    final discovery = _discovery;
    _discovery = null;
    try {
      await discovery?.stop();
    } catch (_) {
      // Already stopped by the system.
    }
  }

  void _handle(BonsoirDiscovery discovery, BonsoirDiscoveryEvent event) {
    if (!identical(discovery, _discovery)) return;
    switch (event) {
      case BonsoirDiscoveryStartedEvent():
        _setStatus(BrowseStatus.searching);
      case BonsoirDiscoveryServiceFoundEvent(:final service):
        service.resolve(discovery.serviceResolver);
      case BonsoirDiscoveryServiceResolvedEvent(:final service) || BonsoirDiscoveryServiceUpdatedEvent(:final service):
        if (service.port > 0 && _directory.resolved(_host(service))) notifyListeners();
      case BonsoirDiscoveryServiceLostEvent(:final service):
        if (_directory.lost(service.name)) notifyListeners();
      case BonsoirDiscoveryStoppedEvent():
        // Browses stop when the app is suspended for a while; a stopped one can't be reused.
        if (_isRunning) _restartSoon();
      case BonsoirDiscoveryServiceResolveFailedEvent() || BonsoirDiscoveryUnknownEvent():
        break;
    }
  }

  void _failed(Object error) {
    _problem = error is PlatformException ? error.message ?? error.code : '$error';
    _setStatus(BrowseStatus.problem);
    if (_isRunning) _restartSoon();
  }

  void _restartSoon() {
    if (_restart != null) return;
    _events?.cancel();
    _events = null;
    _discovery = null;
    _restart = Timer(const Duration(seconds: 2), () {
      _restart = null;
      if (_isRunning && _discovery == null) _begin();
    });
  }

  void _setStatus(BrowseStatus status) {
    if (status == _status) return;
    _status = status;
    notifyListeners();
  }

  static DiscoveredHost _host(BonsoirService service) => DiscoveredHost(
        name: service.name,
        hostId: service.attributes[portholeHostIdKey]?.trim().nonEmpty,
        addresses: service.hostAddresses,
        hostname: service.hostname,
        port: service.port,
      );
}

extension on String {
  String? get nonEmpty => isEmpty ? null : this;
}
