import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'pairing_store.dart';

/// What the app asks of the phone or tablet itself, through a small channel in AppDelegate.swift and
/// MainActivity.kt.
// no-prop-test: platform glue with no logic of its own; each call is checked on devices.
abstract final class System {
  static const _channel = MethodChannel('dev.iamngoni.porthole/system');

  /// Keeps the screen on while a window is streaming.
  static Future<void> keepAwake(bool on) => _call('keepAwake', on);

  /// Android: keeps the back gesture off the middle of the side edges, so a drag that starts there
  /// reaches the Mac. Elsewhere it does nothing.
  static Future<void> claimEdges(bool on) => _call('claimEdges', on);

  /// Opens this app's page in Settings, where Local Network access is turned on.
  static Future<void> openSettings() => _call('openSettings', null);

  /// iOS: reports whether Local Network access is off, which the Bonjour plugin can't tell.
  static Future<void> watchLocalNetwork(void Function(bool denied) onChange) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'localNetwork') onChange(call.arguments == 'denied');
    });
    return _call('watchLocalNetwork', null);
  }

  /// iOS: what this launch found (see [InstallState]). Null elsewhere.
  static Future<InstallState?> install() async {
    try {
      return InstallState.fromPlatform(await _channel.invokeMethod<Object?>('install'));
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      debugPrint('install failed: ${error.message}');
      return null;
    }
  }

  /// iOS: records that this install's first launch has been settled, and removes the Swift app's own
  /// pairing records.
  static Future<void> finishInstall() => _call('finishInstall', null);

  static Future<void> _call(String method, Object? argument) async {
    try {
      await _channel.invokeMethod<void>(method, argument);
    } on MissingPluginException {
      // Tests and platforms without the channel.
    } on PlatformException catch (error) {
      debugPrint('$method failed: ${error.message}');
    }
  }
}
