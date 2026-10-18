import 'package:flutter/widgets.dart';

import 'glass.dart';
import 'theme.dart';

/// Anything tappable sinks slightly under the finger.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, required this.onTap, this.scale = 0.975, this.label, this.onLongPress});

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;

  /// What a screen reader says, when the child doesn't say it.
  final String? label;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  var _pressed = false;

  void _set(bool pressed) {
    if (pressed != _pressed && mounted) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _pressed ? widget.scale : 1,
          duration: Motion.press,
          curve: Motion.pressCurve,
          child: AnimatedOpacity(opacity: enabled ? 1 : 0.4, duration: Motion.press, child: widget.child),
        ),
      ),
    );
  }
}

/// The one thing to do next: a solid white capsule.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton(this.label, {super.key, required this.onPressed, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onPressed,
        scale: 0.97,
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 26),
          decoration: BoxDecoration(
            color: Palette.white(0.95),
            borderRadius: BorderRadius.circular(27),
            boxShadow: [BoxShadow(color: Palette.black(0.35), blurRadius: 14, offset: const Offset(0, 6))],
          ),
          alignment: Alignment.center,
          child: _Label(label, icon: icon, style: display(17, FontWeight.w600, Palette.canvas)),
        ),
      );
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton(this.label, {super.key, required this.onPressed, this.icon, this.tint = Palette.textPrimary, this.expand = false});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color tint;
  final bool expand;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onPressed,
        scale: 0.97,
        child: Glass(
          radius: 25,
          shadow: false,
          child: Container(
            constraints: const BoxConstraints(minHeight: 50),
            width: expand ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            alignment: expand ? Alignment.center : null,
            child: Center(widthFactor: 1, child: _Label(label, icon: icon, style: display(16, FontWeight.w600, tint))),
          ),
        ),
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text, {required this.style, this.icon});
  final String text;
  final TextStyle style;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: style.fontSize! * 1.1, color: style.color), const SizedBox(width: 8)],
          Flexible(child: Text(text, style: style, textAlign: TextAlign.center, maxLines: 2)),
        ],
      );
}

/// A round button for toolbars. When on, it turns solid white.
class CircleButton extends StatelessWidget {
  const CircleButton(this.icon, {super.key, required this.onPressed, required this.label, this.size = 44, this.isOn = false});

  final IconData icon;
  final VoidCallback? onPressed;
  final String label;
  final double size;
  final bool isOn;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onPressed,
        scale: 0.92,
        label: label,
        child: AnimatedContainer(
          duration: Motion.press,
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Palette.white(isOn ? 0.92 : 0.08)),
          child: Icon(icon, size: size * 0.42, color: isOn ? Palette.canvas : Palette.textPrimary),
        ),
      );
}
