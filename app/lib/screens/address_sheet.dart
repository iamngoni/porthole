import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:porthole_protocol/porthole_protocol.dart' show portholeSignalingPort;

import '../client/remote_address.dart';
import '../design/buttons.dart';
import '../design/glass.dart';
import '../design/theme.dart';

/// Asks where to reach a paired Mac from anywhere: its Tailscale name or address. Returns what was saved,
/// or null if the person backed out.
Future<RemoteAddress?> showAddressSheet(BuildContext context,
        {required String macName, RemoteAddress? current, String saveLabel = 'Save'}) =>
    showGeneralDialog<RemoteAddress>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Palette.black(0.55),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, _, _) => _AddressSheet(macName: macName, current: current, saveLabel: saveLabel),
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 6 * animation.value, sigmaY: 6 * animation.value),
          child: FadeTransition(
            opacity: curved,
            child: SlideTransition(position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(curved), child: child),
          ),
        );
      },
    );

class _AddressSheet extends StatefulWidget {
  const _AddressSheet({required this.macName, required this.current, required this.saveLabel});
  final String macName;
  final RemoteAddress? current;
  final String saveLabel;

  @override
  State<_AddressSheet> createState() => _AddressSheetState();
}

class _AddressSheetState extends State<_AddressSheet> {
  late final _controller = TextEditingController(text: widget.current?.text ?? '');
  final _focus = FocusNode();
  var _showsError = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _save() {
    final address = RemoteAddress.parse(_controller.text);
    if (address == null) {
      setState(() => _showsError = true);
      return;
    }
    Navigator.of(context).pop(address);
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    final invalid = _showsError && RemoteAddress.parse(_controller.text) == null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(Metrics.gutter),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Material(
                type: MaterialType.transparency,
                child: Glass(
                  radius: 28,
                  highlight: true,
                  fill: Palette.white(0.08),
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text('Connect from anywhere', style: display(20, FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(
                      'Enter ${widget.macName}’s Tailscale name or address. It works wherever both are on Tailscale, '
                      'or the same VPN.',
                      style: body(15, FontWeight.w500, Palette.textSecondary),
                    ),
                    const SizedBox(height: 18),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Palette.white(focused ? 0.11 : 0.07),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: invalid
                              ? Palette.danger.withValues(alpha: 0.8)
                              : focused
                                  ? Palette.accent.withValues(alpha: 0.8)
                                  : Palette.white(0.08),
                          width: focused || invalid ? 1.5 : 1,
                        ),
                      ),
                      child: Row(children: [
                        const Icon(Icons.public_rounded, size: 20, color: Palette.textTertiary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focus,
                            autofocus: true,
                            autocorrect: false,
                            enableSuggestions: false,
                            keyboardType: TextInputType.url,
                            textInputAction: TextInputAction.done,
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) => _save(),
                            cursorColor: Palette.accent,
                            style: body(16),
                            decoration: InputDecoration.collapsed(
                              hintText: 'studio-mac or 100.101.102.103',
                              hintStyle: body(16, FontWeight.w500, Palette.textTertiary),
                            ),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      invalid
                          ? 'That isn’t a name or address. Try something like studio-mac or 100.101.102.103.'
                          : 'Pair on the same Wi‑Fi first. The Mac listens on port $portholeSignalingPort; add :port '
                              'for another.',
                      style: body(13, FontWeight.w500, invalid ? Palette.danger : Palette.textTertiary),
                    ),
                    const SizedBox(height: 18),
                    Row(children: [
                      Expanded(child: SecondaryButton('Cancel', expand: true, onPressed: () => Navigator.of(context).pop())),
                      const SizedBox(width: 12),
                      Expanded(child: PrimaryButton(widget.saveLabel, onPressed: _controller.text.trim().isEmpty ? null : _save)),
                    ]),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
