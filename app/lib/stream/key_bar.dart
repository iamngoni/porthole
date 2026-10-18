import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../design/buttons.dart';
import '../design/theme.dart';
import '../input/keys.dart';

/// Esc, Tab, arrows and sticky modifier keys above the on-screen keyboard. A modifier applies to the
/// next key only.
class KeyBar extends StatelessWidget {
  const KeyBar({super.key, required this.sticky, required this.onKey, required this.onToggle, required this.onHide});

  static const height = 52.0;

  /// The modifiers toggled on, as `KeyEvent.modifiers` bits.
  final int sticky;
  final ValueChanged<int> onKey;
  final ValueChanged<int> onToggle;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    Widget key(String title, String label, int usage) => _Key(title: title, label: label, onTap: () => onKey(usage));
    Widget modifier(String title, String label, int bit) =>
        _Key(title: title, label: label, isOn: sticky & bit != 0, onTap: () => onToggle(bit));
    final keys = [
      key('esc', 'Escape', Usage.escape),
      key('tab', 'Tab', Usage.tab),
      modifier('⌘', 'Command', Modifier.command),
      modifier('⌥', 'Option', Modifier.option),
      modifier('⌃', 'Control', Modifier.control),
      modifier('⇧', 'Shift', Modifier.shift),
      key('←', 'Left Arrow', Usage.leftArrow),
      key('↑', 'Up Arrow', Usage.upArrow),
      key('↓', 'Down Arrow', Usage.downArrow),
      key('→', 'Right Arrow', Usage.rightArrow),
      _Key(icon: Icons.keyboard_hide_rounded, label: 'Hide Keyboard', onTap: onHide),
    ];
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1F).withValues(alpha: 0.85),
            border: Border(top: BorderSide(color: Palette.white(0.08))),
          ),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            children: [
              for (final (index, key) in keys.indexed) ...[if (index > 0) const SizedBox(width: 8), key],
            ],
          ),
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({this.title, this.icon, required this.label, required this.onTap, this.isOn = false});
  final String? title;
  final IconData? icon;
  final String label;
  final VoidCallback onTap;
  final bool isOn;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: isOn,
        child: Pressable(
          onTap: onTap,
          scale: 0.94,
          label: label,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            constraints: const BoxConstraints(minWidth: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isOn ? Palette.accent : Palette.white(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: icon != null
                ? Icon(icon, size: 20, color: const Color(0xFFFFFFFF))
                : ExcludeSemantics(child: Text(title!, style: display(16, FontWeight.w600, const Color(0xFFFFFFFF)))),
          ),
        ),
      );
}
