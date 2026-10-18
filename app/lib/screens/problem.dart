import 'package:flutter/material.dart';

import '../client/client_controller.dart';
import '../client/client_scope.dart';
import '../design/buttons.dart';
import '../design/glass.dart';
import '../design/pieces.dart';
import '../design/theme.dart';

/// In place of system alerts: a card over the current screen, with a way forward when there is one.
class ProblemOverlay extends StatelessWidget {
  const ProblemOverlay({super.key, required this.problem});
  final Problem problem;

  @override
  Widget build(BuildContext context) {
    final client = ClientScope.read(context);
    final action = problem.action;
    void forward() {
      client.dismissProblem();
      client.retry(problem);
    }

    return Stack(children: [
      Positioned.fill(
        child: GestureDetector(
          onTap: client.dismissProblem,
          child: ColoredBox(color: Palette.black(0.7)),
        ),
      ),
      SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Metrics.gutter),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutBack,
              builder: (context, t, child) => Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: Transform.scale(scale: 0.92 + 0.08 * t, child: child),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Glass(
                  radius: 32,
                  highlight: true,
                  padding: const EdgeInsets.all(30),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    GlowIcon(
                      action == ProblemAction.pairAgain ? Icons.lock_reset_rounded : Icons.warning_amber_rounded,
                      size: 68,
                      tint: Palette.warning,
                    ),
                    const SizedBox(height: 22),
                    Text(problem.text, style: body(17), textAlign: TextAlign.center),
                    const SizedBox(height: 22),
                    if (action != null) ...[
                      PrimaryButton(action == ProblemAction.pairAgain ? 'Pair Again' : 'Try Again', onPressed: forward),
                      const SizedBox(height: 12),
                    ],
                    SecondaryButton(action == null ? 'OK' : 'Not Now', onPressed: client.dismissProblem, expand: true),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}
