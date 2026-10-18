import 'dart:async';
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/material.dart';

import 'spike_link.dart';
import 'stream_screen.dart';

void main() => runApp(const SpikeApp());

class SpikeApp extends StatelessWidget {
  const SpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Porthole Spike',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0C),
        colorScheme: const ColorScheme.dark(primary: Color(0xFF78A8FF)),
      ),
      home: const FindMacScreen(),
    );
  }
}

/// Lists Macs running Porthole Host (found over Bonjour) and connects to the test feed on the one you tap.
/// Bonjour doesn't reach the Android emulator; type 10.0.2.2 there.
class FindMacScreen extends StatefulWidget {
  const FindMacScreen({super.key});

  @override
  State<FindMacScreen> createState() => _FindMacScreenState();
}

class _FindMacScreenState extends State<FindMacScreen> {
  final _discovery = BonsoirDiscovery(type: '_porthole._tcp');
  final _found = <String, BonsoirService>{};
  final _address = TextEditingController();
  String _discoveryStatus = 'Looking for Macs…';
  StreamSubscription<BonsoirDiscoveryEvent>? _events;

  @override
  void initState() {
    super.initState();
    _startDiscovery();
  }

  Future<void> _startDiscovery() async {
    try {
      await _discovery.initialize();
      _events = _discovery.eventStream?.listen((event) {
        switch (event) {
          case BonsoirDiscoveryServiceFoundEvent():
            event.service.resolve(_discovery.serviceResolver);
            setState(() => _found[event.service.name] = event.service);
          case BonsoirDiscoveryServiceResolvedEvent(:final service):
            setState(() => _found[service.name] = service);
          case BonsoirDiscoveryServiceUpdatedEvent(:final service):
            setState(() => _found[service.name] = service);
          case BonsoirDiscoveryServiceLostEvent():
            setState(() => _found.remove(event.service.name));
          default:
            break;
        }
      });
      await _discovery.start();
    } catch (e) {
      setState(() => _discoveryStatus = 'Bonjour failed: $e');
    }
  }

  @override
  void dispose() {
    _events?.cancel();
    _discovery.stop();
    super.dispose();
  }

  void _open(String host) {
    final view = View.of(context);
    final link = SpikeLink(
      host: host,
      deviceName: '${Platform.operatingSystem} ${Platform.localHostname}',
      screen: view.physicalSize,
      refreshRate: view.display.refreshRate.round(),
    );
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => StreamScreen(link: link)));
  }

  /// Where to reach a Mac: an IPv4 address if Bonjour found one (link-local IPv6 needs a scope Dart sockets
  /// don't keep), else its .local name.
  static String? _addressOf(BonsoirService service) =>
      service.hostAddresses.where((address) => InternetAddress.tryParse(address)?.type == InternetAddressType.IPv4).firstOrNull ??
      service.hostname ??
      service.hostAddress;

  Widget _macCard(BonsoirService service) {
    final address = _addressOf(service);
    return Card(
      color: Colors.white.withValues(alpha: 0.06),
      child: ListTile(
        leading: const Icon(Icons.laptop_mac),
        title: Text(service.name),
        subtitle: Text(address ?? 'resolving…'),
        trailing: const Icon(Icons.arrow_forward),
        enabled: address != null,
        onTap: () => _open(address!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 24),
            const Text('Porthole Spike', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('Start Porthole Host with -spike, then pick the Mac.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
            const SizedBox(height: 28),
            if (_found.isEmpty)
              Row(children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Text(_discoveryStatus),
              ]),
            for (final service in _found.values)
              _macCard(service),
            const SizedBox(height: 28),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _address,
                  decoration: const InputDecoration(
                    labelText: 'Or type the Mac\'s address',
                    hintText: '10.0.2.2 on the Android emulator',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                  onSubmitted: (value) => value.trim().isEmpty ? null : _open(value.trim()),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () => _address.text.trim().isEmpty ? null : _open(_address.text.trim()),
                child: const Text('Connect'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
