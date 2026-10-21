import 'package:flutter/material.dart';
import 'package:porthole_protocol/porthole_protocol.dart' show PairedHost;

import '../client/client_scope.dart';
import '../client/host_browser.dart';
import '../client/system.dart';
import '../design/backdrop.dart';
import '../design/buttons.dart';
import '../design/glass.dart';
import '../design/mark.dart';
import '../design/menu.dart';
import '../design/pieces.dart';
import '../design/theme.dart';
import '../input/display_name.dart';
import 'address_sheet.dart';

/// Home: the Macs running Porthole Host nearby, and the ones this device is paired with.
class HostListView extends StatelessWidget {
  const HostListView({super.key});

  @override
  Widget build(BuildContext context) {
    final client = ClientScope.of(context);
    final hosts = client.hosts;
    final nearby = {for (final host in hosts) client.savedPairing(host)?.hostId};
    final away = client.pairedHosts.where((paired) => !nearby.contains(paired.hostId)).toList();
    return Stack(children: [
      const Positioned.fill(child: Backdrop()),
      LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top, bottom: MediaQuery.paddingOf(context).bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - MediaQuery.paddingOf(context).vertical),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Metrics.gutter, vertical: 56),
                  child: AnimatedSize(
                    duration: Motion.fade,
                    curve: Motion.smooth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Hero(searching: hosts.isEmpty, denied: client.browseStatus == BrowseStatus.localNetworkDenied),
                        const SizedBox(height: 44),
                        if (hosts.isEmpty)
                          _SearchingCard(status: client.browseStatus)
                        else
                          _Section(
                            title: 'Nearby',
                            count: hosts.length,
                            children: [for (final host in hosts) _MacCard(host: host, pairing: client.savedPairing(host))],
                          ),
                        if (away.isNotEmpty) ...[
                          const SizedBox(height: 44),
                          _Section(
                            title: 'Paired, not nearby',
                            count: away.length,
                            children: [for (final paired in away) _AwayMacCard(host: paired)],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.searching, required this.denied});
  final bool searching;
  final bool denied;

  @override
  Widget build(BuildContext context) => Column(children: [
        SizedBox(
          height: 170,
          child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
            AnimatedOpacity(
              opacity: searching ? 1 : 0.45,
              duration: Motion.fade,
              child: OverflowBox(
                maxWidth: 300,
                maxHeight: 300,
                child: RadarRings(size: 300, color: denied ? Palette.warning : const Color(0xFFFFFFFF)),
              ),
            ),
            PortholeMark(size: 112, isActive: searching),
          ]),
        ),
        const SizedBox(height: 18),
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFFFFFFFF), Palette.white(0.72)],
          ).createShader(bounds),
          child: Text('Porthole', style: display(54, FontWeight.w800, const Color(0xFFFFFFFF))),
        ),
        const SizedBox(height: 8),
        Text('Your Mac’s windows, right here.', style: body(18, FontWeight.w500, Palette.textSecondary), textAlign: TextAlign.center),
      ]);
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.count, required this.children});
  final String title;
  final int count;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 14),
          child: Row(children: [
            SectionTitle(title),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: Palette.white(0.08), borderRadius: BorderRadius.circular(20)),
              child: Text('$count', style: display(12, FontWeight.w700, Palette.textSecondary)),
            ),
          ]),
        ),
        for (final (index, child) in children.indexed) ...[if (index > 0) const SizedBox(height: 14), child],
      ]);
}

/// Small capitals over a group of cards.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: display(13, FontWeight.w700, Palette.textTertiary).copyWith(letterSpacing: 1.4),
      );
}

class _MacCard extends StatelessWidget {
  const _MacCard({required this.host, required this.pairing});
  final DiscoveredHost host;
  final PairedHost? pairing;

  @override
  Widget build(BuildContext context) {
    final paired = pairing != null;
    // A paired Mac goes by the name it gave over the authenticated connection: another Mac can copy its
    // ID, but not that.
    final name = pairing?.hostName ?? DisplayName.clean(host.name, fallback: 'Mac');
    void menu() {
      final pairing = this.pairing;
      if (pairing == null) return;
      final client = ClientScope.read(context);
      showActionMenu(context, title: name, actions: [
        MenuAction('Pair Again', Icons.sync_rounded, () => client.connect(host, pairAgain: true)),
        MenuAction('Remote Address…', Icons.public_rounded, () async {
          final address = await showAddressSheet(context, macName: name, current: client.addressOf(pairing));
          if (address != null) await client.setAddress(pairing, address);
        }),
        MenuAction('Forget This Mac', Icons.delete_outline_rounded, () => client.forget(pairing), destructive: true),
      ]);
    }

    return Semantics(
      hint: paired ? 'Connects to this Mac' : 'Pairs with this Mac',
      child: Pressable(
        onTap: () => ClientScope.read(context).connect(host),
        onLongPress: paired ? menu : null,
        child: Glass(
          highlight: paired,
          padding: const EdgeInsets.all(22),
          child: Row(children: [
            const GlowIcon(Icons.laptop_mac_rounded, size: 72),
            const SizedBox(width: 18),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: display(21, FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 7),
                Row(children: [
                  StatusDot(color: paired ? Palette.positive : Palette.warning),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(paired ? 'Paired · Ready' : 'New · Tap to pair',
                        style: body(14, FontWeight.w500, Palette.textSecondary), maxLines: 1),
                  ),
                ]),
              ]),
            ),
            const SizedBox(width: 8),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Palette.white(paired ? 0.92 : 0.08)),
              child: Icon(Icons.arrow_forward_rounded, size: 20, color: paired ? Palette.canvas : Palette.textPrimary),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A paired Mac that isn't on this network. With an address saved, it connects there (over Tailscale, say);
/// without one, tapping asks for it.
class _AwayMacCard extends StatelessWidget {
  const _AwayMacCard({required this.host});
  final PairedHost host;

  Future<void> _askForAddress(BuildContext context, {required bool connect}) async {
    final client = ClientScope.read(context);
    final address = await showAddressSheet(context,
        macName: host.hostName, current: client.addressOf(host), saveLabel: connect ? 'Connect' : 'Save');
    if (address == null) return;
    await client.setAddress(host, address);
    if (connect) client.connectRemotely(host);
  }

  @override
  Widget build(BuildContext context) {
    final client = ClientScope.of(context);
    final address = client.addressOf(host);
    void menu() => showActionMenu(context, title: host.hostName, actions: [
          if (address == null)
            MenuAction('Connect from Anywhere…', Icons.public_rounded, () => _askForAddress(context, connect: true))
          else ...[
            MenuAction('Change Remote Address…', Icons.edit_rounded, () => _askForAddress(context, connect: false)),
            MenuAction('Remove Remote Address', Icons.public_off_rounded, () => client.setAddress(host, null)),
          ],
          MenuAction('Forget This Mac', Icons.delete_outline_rounded, () => client.forget(host), destructive: true),
        ]);

    return Semantics(
      hint: address == null ? 'Asks where to reach this Mac' : 'Connects to this Mac at ${address.text}',
      child: Pressable(
        onTap: address == null ? () => _askForAddress(context, connect: true) : () => client.connectRemotely(host),
        onLongPress: menu,
        child: Opacity(
          opacity: address == null ? 0.8 : 1,
          child: Glass(
            radius: 22,
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              GlowIcon(Icons.laptop_mac_rounded, size: 50, tint: address == null ? Palette.textTertiary : Palette.textPrimary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(host.hostName, style: display(17, FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(children: [
                    if (address != null) ...[const StatusDot(color: Palette.accent), const SizedBox(width: 7)],
                    Flexible(
                      child: Text(
                        address == null ? 'Not on this network · Tap to reach it remotely' : 'Remote · ${address.text}',
                        style: body(13, FontWeight.w500, Palette.textTertiary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                ]),
              ),
              CircleButton(Icons.more_horiz_rounded, size: 36, label: 'More for ${host.hostName}', onPressed: menu),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Nothing found yet: what's happening, and what to check.
class _SearchingCard extends StatelessWidget {
  const _SearchingCard({required this.status});
  final BrowseStatus status;

  @override
  Widget build(BuildContext context) {
    final denied = status == BrowseStatus.localNetworkDenied;
    final hint = switch (status) {
      BrowseStatus.localNetworkDenied => 'Turn on Local Network for Porthole in Settings so it can find your Mac.',
      BrowseStatus.problem => 'Can’t search the network right now. Trying again…',
      BrowseStatus.starting || BrowseStatus.searching => 'Macs running Porthole Host show up here on their own.',
    };
    return Column(children: [
      Text(denied ? 'Porthole can’t see your network' : 'Looking for your Mac…', style: display(26), textAlign: TextAlign.center),
      const SizedBox(height: 10),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Text(hint, style: body(16, FontWeight.w500, Palette.textSecondary), textAlign: TextAlign.center),
      ),
      const SizedBox(height: 24),
      if (denied)
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: PrimaryButton('Open Settings', icon: Icons.settings_rounded, onPressed: System.openSettings),
        )
      else
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Glass(
            radius: 22,
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _Tip('1', 'Open Porthole Host on your Mac.'),
              const SizedBox(height: 12),
              const _Tip('2', 'Keep both on the same Wi‑Fi.'),
              const SizedBox(height: 12),
              const _Tip('3', 'New here? Choose Pair New Device in the Mac’s menu bar.'),
            ]),
          ),
        ),
    ]);
  }
}

class _Tip extends StatelessWidget {
  const _Tip(this.number, this.text);
  final String number;
  final String text;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Palette.white(0.9)),
          child: Text(number, style: display(13, FontWeight.w700, Palette.canvas)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(text, style: body(15, FontWeight.w500, Palette.textSecondary)),
          ),
        ),
      ]);
}
