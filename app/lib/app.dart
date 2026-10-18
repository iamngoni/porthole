import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'client/client_controller.dart';
import 'client/client_scope.dart';
import 'design/theme.dart';
import 'screens/connecting.dart';
import 'screens/host_list.dart';
import 'screens/problem.dart';
import 'screens/window_picker.dart';
import 'stream/stream_screen.dart';

class PortholeApp extends StatelessWidget {
  const PortholeApp({super.key, required this.controller});
  final ClientController controller;

  @override
  Widget build(BuildContext context) => ClientScope(
        controller: controller,
        child: MaterialApp(
          title: 'Porthole',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: const ColorScheme.dark(primary: Palette.accent, surface: Palette.canvas),
            scaffoldBackgroundColor: Palette.canvas,
            textSelectionTheme: const TextSelectionThemeData(cursorColor: Palette.accent),
            splashFactory: NoSplash.splashFactory,
          ),
          home: const AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light,
            child: Material(color: Palette.canvas, child: RootView()),
          ),
        ),
      );
}

/// One screen per phase, cross-fading, with any problem on top.
class RootView extends StatelessWidget {
  const RootView({super.key});

  @override
  Widget build(BuildContext context) {
    final client = ClientScope.of(context);
    final phase = client.phase;
    final screen = switch (phase) {
      Browsing() => const HostListView(key: ValueKey('browsing')),
      Connecting(:final hostName) => ConnectingView(key: const ValueKey('connecting'), hostName: hostName),
      ComparingCode(:final hostName, :final code) => PairingCodeView(key: const ValueKey('pairing'), hostName: hostName, code: code),
      WaitingForMac(:final hostName) => WaitingForMacView(key: const ValueKey('waiting'), hostName: hostName),
      Connected() => const SessionView(key: ValueKey('session')),
    };
    final problem = client.problem;
    return DefaultTextStyle(
      style: body(16),
      child: Stack(children: [
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            switchInCurve: Motion.smooth,
            switchOutCurve: Motion.smooth,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: Tween(begin: 0.985, end: 1.0).animate(animation), child: child),
            ),
            child: screen,
          ),
        ),
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: problem == null ? const SizedBox.shrink() : ProblemOverlay(key: ValueKey(problem.id), problem: problem),
          ),
        ),
      ]),
    );
  }
}

/// Connected: the window grid, or the window itself.
class SessionView extends StatelessWidget {
  const SessionView({super.key});

  @override
  Widget build(BuildContext context) {
    final showing = ClientScope.of(context).isShowingStream;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: child.key == const ValueKey('stream')
            ? ScaleTransition(scale: Tween(begin: 1.03, end: 1.0).animate(animation), child: child)
            : child,
      ),
      child: showing ? const StreamScreen(key: ValueKey('stream')) : const WindowPickerView(key: ValueKey('picker')),
    );
  }
}
