import 'package:flutter/widgets.dart';

import 'client_controller.dart';

/// Hands the controller down the tree; widgets that read it with [of] rebuild when it changes.
class ClientScope extends InheritedNotifier<ClientController> {
  const ClientScope({super.key, required ClientController controller, required super.child}) : super(notifier: controller);

  static ClientController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ClientScope>()!.notifier!;

  /// For callbacks: reads without rebuilding on changes.
  static ClientController read(BuildContext context) => context.getInheritedWidgetOfExactType<ClientScope>()!.notifier!;
}
