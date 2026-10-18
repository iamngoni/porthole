import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porthole/app.dart';
import 'package:porthole/client/client_controller.dart';
import 'package:porthole/client/pairing_store.dart';
import 'package:porthole/design/theme.dart';
import 'package:porthole/preview.dart';

import 'support/fakes.dart';

// Every screen at iPad and phone sizes, with the sample data the design previews use: no overflow, no
// exceptions. With SCREENSHOTS=<folder> each one is also saved as a PNG to look at.
// no-prop-test: layout smoke test; the screens have no logic of their own beyond the tested controller.

const _sizes = {'ipad': Size(1376, 1032), 'ipad-portrait': Size(1032, 1376), 'phone': Size(402, 874)};
const _screens = ['browsing', 'searching', 'connecting', 'pairing', 'waiting', 'problem', 'windows', 'apps', 'opening', 'stream'];

Future<void> _loadFonts() async {
  Future<void> load(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    await loader.load();
  }

  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  await load('MaterialIcons', '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  // The Mac's own rounded face stands in for the system font, so the pictures read like the device.
  await load('Roboto', '/System/Library/Fonts/SFNSRounded.ttf');
  Typeface.family = 'Roboto';
}

void main() {
  final folder = Platform.environment['SCREENSHOTS'];

  setUpAll(() async {
    await _loadFonts();
    // No WebRTC in tests: the video view stays empty.
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in ['FlutterWebRTC.Method', 'FlutterWebRTC.Event']) {
      messenger.setMockMethodCallHandler(MethodChannel(name), (call) async => null);
    }
  });

  for (final MapEntry(key: sizeName, value: size) in _sizes.entries) {
    for (final screen in _screens) {
      testWidgets('$screen on $sizeName', (tester) async {
        tester.view.physicalSize = size * 2;
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        final controller = ClientController(
          deviceId: 'd',
          deviceName: 'Test iPad',
          store: MemoryPairingStore(),
          makePeer: FakePeer.new,
          keepAwake: (_) async {},
        );
        addTearDown(controller.dispose);
        await tester.runAsync(() => loadPreview(controller, screen == 'windows' ? 'connected' : screen));
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(key: key, child: PortholeApp(controller: controller)));
        // Let the images decode and the entrances finish; the backdrop and rings keep moving, so no settle.
        for (var i = 0; i < 8; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(tester.takeException(), isNull);
        if (folder != null) {
          await tester.runAsync(() async {
            final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1);
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            File('$folder/$screen-$sizeName.png').writeAsBytesSync(png!.buffer.asUint8List());
          });
        }
      });
    }
  }
}
