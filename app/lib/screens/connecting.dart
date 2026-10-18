import 'package:flutter/material.dart';

import '../client/client_scope.dart';
import '../design/backdrop.dart';
import '../design/buttons.dart';
import '../design/glass.dart';
import '../design/mark.dart';
import '../design/pieces.dart';
import '../design/theme.dart';

/// The logo with rings rippling out, a title and a line under it, and a way out.
class _Reaching extends StatelessWidget {
  const _Reaching({required this.title, required this.subtitle, this.rings = 300, this.mark = 96});
  final String title;
  final String subtitle;
  final double rings;
  final double mark;

  @override
  Widget build(BuildContext context) => Stack(children: [
        const Positioned.fill(child: Backdrop(intensity: 0.8)),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Metrics.gutter),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  height: rings * 0.75,
                  child: Stack(alignment: Alignment.center, children: [
                    OverflowBox(maxWidth: rings, maxHeight: rings, child: RadarRings(size: rings)),
                    PortholeMark(size: mark, isActive: true),
                  ]),
                ),
                const SizedBox(height: 30),
                Text(title, style: display(28), textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text(subtitle, style: body(16, FontWeight.w500, Palette.textSecondary), textAlign: TextAlign.center),
                const SizedBox(height: 30),
                SecondaryButton('Cancel', onPressed: ClientScope.read(context).disconnect),
              ]),
            ),
          ),
        ),
      ]);
}

/// Reaching out to the Mac and setting up the secure connection.
class ConnectingView extends StatelessWidget {
  const ConnectingView({super.key, required this.hostName});
  final String hostName;

  @override
  Widget build(BuildContext context) =>
      _Reaching(title: 'Connecting to $hostName', subtitle: 'Setting up a private, encrypted connection');
}

/// The codes matched here; the Mac asks its person to allow this device.
class WaitingForMacView extends StatelessWidget {
  const WaitingForMacView({super.key, required this.hostName});
  final String hostName;

  @override
  Widget build(BuildContext context) => _Reaching(
        title: 'Click Allow on $hostName',
        subtitle: 'Porthole Host is asking whether to pair with this device.',
        rings: 280,
        mark: 92,
      );
}

/// Both screens show a code; matching codes prove nobody is sitting between the two devices.
class PairingCodeView extends StatelessWidget {
  const PairingCodeView({super.key, required this.hostName, required this.code});
  final String hostName;
  final String code;

  @override
  Widget build(BuildContext context) {
    final client = ClientScope.read(context);
    return Stack(children: [
      const Positioned.fill(child: Backdrop(intensity: 0.9)),
      SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Metrics.gutter),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Glass(
                radius: 36,
                highlight: true,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const GlowIcon(Icons.shield_outlined, size: 78),
                  const SizedBox(height: 30),
                  Text('Pair with $hostName', style: display(30), textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Text('Your Mac is showing a code too. Make sure it’s exactly this one.',
                        style: body(17, FontWeight.w500, Palette.textSecondary), textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 30),
                  CodeTiles(code: code),
                  const SizedBox(height: 30),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Column(children: [
                      PrimaryButton('Codes Match', onPressed: client.codesMatch),
                      const SizedBox(height: 12),
                      SecondaryButton('They’re Different', onPressed: client.codesDiffer, tint: Palette.danger, expand: true),
                    ]),
                  ),
                  const SizedBox(height: 30),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.verified_user_outlined, size: 16, color: Palette.textTertiary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text('Matching codes prove you’re talking to your own Mac.',
                          style: body(13, FontWeight.w500, Palette.textTertiary), textAlign: TextAlign.center),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// Six digits in two groups of three, each on its own lit tile, rising in one after another.
class CodeTiles extends StatefulWidget {
  const CodeTiles({super.key, required this.code});
  final String code;

  @override
  State<CodeTiles> createState() => _CodeTilesState();
}

class _CodeTilesState extends State<CodeTiles> with SingleTickerProviderStateMixin {
  late final _rise = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();

  @override
  void dispose() {
    _rise.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final digits = widget.code.split('');
    // Narrow phones get smaller tiles, so all six fit on one line.
    return LayoutBuilder(builder: (context, constraints) {
      final tile = ((constraints.maxWidth - 14 - 10 * 5) / 6).clamp(36.0, 60.0);
      return Semantics(
        label: 'Code ${digits.join(' ')}',
        child: ExcludeSemantics(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (final (index, digit) in digits.indexed) ...[
              if (index > 0) SizedBox(width: index == 3 ? 24 : 10),
              AnimatedBuilder(
                animation: _rise,
                builder: (context, child) {
                  final start = index * 0.06;
                  final t = Curves.easeOutBack.transform(((_rise.value - start) / (1 - 0.3)).clamp(0.0, 1.0));
                  return Opacity(
                    opacity: t.clamp(0.0, 1.0),
                    child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child),
                  );
                },
                child: Container(
                  width: tile,
                  height: tile * 1.3,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Palette.white(0.07),
                    borderRadius: BorderRadius.circular(tile * 0.3),
                    border: Border.all(color: Palette.white(0.16)),
                    boxShadow: [BoxShadow(color: Palette.black(0.35), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Text(digit,
                      style: display(tile * 0.77, FontWeight.w600).copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                ),
              ),
            ],
          ]),
        ),
      );
    });
  }
}
