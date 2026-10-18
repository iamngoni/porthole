import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'buttons.dart';
import 'glass.dart';
import 'theme.dart';

/// One choice in an [showActionMenu].
class MenuAction {
  const MenuAction(this.label, this.icon, this.onSelected, {this.destructive = false});
  final String label;
  final IconData icon;
  final VoidCallback onSelected;
  final bool destructive;
}

/// A short list of actions on a glass card, in place of a context menu.
Future<void> showActionMenu(BuildContext context, {required String title, required List<MenuAction> actions}) =>
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Palette.black(0.55),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, _, _) => SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(Metrics.gutter),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Glass(
                radius: 28,
                highlight: true,
                fill: Palette.white(0.08),
                padding: const EdgeInsets.fromLTRB(10, 18, 10, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                      child: Text(title, style: display(17, FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    for (final action in actions)
                      Pressable(
                        onTap: () {
                          Navigator.of(context).pop();
                          action.onSelected();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          child: Row(children: [
                            Icon(action.icon, size: 22, color: action.destructive ? Palette.danger : Palette.textPrimary),
                            const SizedBox(width: 14),
                            Text(action.label, style: body(16, FontWeight.w600, action.destructive ? Palette.danger : Palette.textPrimary)),
                          ]),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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
