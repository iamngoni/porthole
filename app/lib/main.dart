import 'dart:io';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'client/client_controller.dart';
import 'client/host_browser.dart';
import 'client/pairing_store.dart';
import 'client/system.dart';
import 'input/display_name.dart';
import 'preview.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color(0x00000000),
    systemNavigationBarColor: Color(0x00000000),
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));

  const preview = String.fromEnvironment('PREVIEW');
  final store = preview.isEmpty ? SecurePairingStore() : MemoryPairingStore();
  if (preview.isEmpty) {
    final install = await System.install();
    if (install != null && install is! KnownInstall) {
      await settleInstall(store, install);
      await System.finishInstall();
    }
  }
  final browser = preview.isEmpty ? HostBrowser() : null;
  final controller = ClientController(
    deviceId: await store.deviceId(),
    deviceName: await _deviceName(),
    store: store,
    browser: browser,
    screen: _screen,
  );
  if (preview.isNotEmpty) {
    await loadPreview(controller, preview);
  } else if (Platform.isIOS) {
    System.watchLocalNetwork((denied) => browser?.localNetworkDenied = denied);
  }
  runApp(PortholeApp(controller: controller));
}

/// What the Mac shows when this device asks to pair.
Future<String> _deviceName() async {
  final info = DeviceInfoPlugin();
  try {
    if (Platform.isIOS) return DisplayName.clean((await info.iosInfo).name, fallback: 'iPad');
    if (Platform.isAndroid) {
      final android = await info.androidInfo;
      return DisplayName.clean(android.name.isNotEmpty ? android.name : android.model, fallback: 'Android');
    }
  } catch (_) {
    // Fall through to a generic name.
  }
  return 'Device';
}

/// The screen in physical pixels, and how often it refreshes (120 on ProMotion and fast Android screens).
ScreenInfo _screen() {
  final display = PlatformDispatcher.instance.displays.firstOrNull;
  final size = display?.size ?? const Size(2752, 2064);
  final refresh = display?.refreshRate ?? 60;
  return (width: size.width.round(), height: size.height.round(), refreshRate: refresh.round().clamp(30, 240));
}
