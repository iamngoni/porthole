import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porthole/design/mark.dart';
import 'package:porthole/design/theme.dart';

// Draws Porthole's home-screen icon from the same mark the app shows, and checks it is fit to be one.
// With APP_ICONS=<folder> it also saves the layers that tool/app_icons.sh turns into the iOS and Android
// icons. no-prop-test: drawing; the checks are on the pixels of the one icon there is.

const _side = 1024.0;

/// The icon's layers. iOS takes the whole icon and rounds its corners itself; Android's adaptive icon
/// takes the background and the mark apart, with the mark inside the circle no launcher crops.
enum IconLayer {
  whole(hasBackground: true, markScale: 0.72),
  background(hasBackground: true, markScale: 0),
  foreground(hasBackground: false, markScale: 0.56);

  const IconLayer({required this.hasBackground, required this.markScale});
  final bool hasBackground;
  final double markScale;
}

class _IconArt extends StatelessWidget {
  const _IconArt(this.layer);
  final IconLayer layer;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: _side,
        child: Stack(children: [
          if (layer.hasBackground) const Positioned.fill(child: CustomPaint(painter: _IconBackground())),
          if (layer.markScale > 0) Center(child: PortholeMark(size: _side * layer.markScale, hasShadow: false)),
        ]),
      );
}

/// Graphite with a soft light from above and a little of the accent below, as behind the Mac list.
class _IconBackground extends CustomPainter {
  const _IconBackground();

  @override
  void paint(Canvas canvas, Size size) {
    final box = Offset.zero & size;
    canvas
      ..drawRect(
          box,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2A2B31), Palette.canvas],
            ).createShader(box))
      ..drawRect(
          box,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(0, -1.15),
              radius: 1.05,
              colors: [Palette.white(0.16), Palette.white(0)],
            ).createShader(box))
      ..drawRect(
          box,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(0, 1.25),
              radius: 0.95,
              colors: [Palette.accent.withValues(alpha: 0.14), Palette.accent.withValues(alpha: 0)],
            ).createShader(box));
  }

  @override
  bool shouldRepaint(_IconBackground old) => false;
}

Future<ui.Image> _render(WidgetTester tester, IconLayer layer) async {
  final key = GlobalKey();
  await tester.binding.setSurfaceSize(const Size(_side, _side));
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: RepaintBoundary(key: key, child: _IconArt(layer))),
  ));
  await tester.pumpAndSettle();
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await tester.runAsync(() => boundary.toImage(pixelRatio: 1)))!;
}

Future<int> _alpha(WidgetTester tester, ui.Image image, int x, int y) async {
  final bytes = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
  return bytes.getUint8((y * image.width + x) * 4 + 3);
}

void main() {
  final folder = Platform.environment['APP_ICONS'];

  for (final layer in IconLayer.values) {
    testWidgets('the ${layer.name} icon layer', (tester) async {
      final image = await _render(tester, layer);
      expect((image.width, image.height), (_side.toInt(), _side.toInt()));
      final last = _side.toInt() - 1;
      final corners = [
        for (final (x, y) in [(0, 0), (last, 0), (0, last), (last, last)]) await _alpha(tester, image, x, y),
      ];
      // App Store icons can't be see-through; an adaptive foreground must be, around the mark.
      expect(corners, everyElement(layer.hasBackground ? 255 : 0));
      if (layer.markScale > 0) expect(await _alpha(tester, image, _side ~/ 2, _side ~/ 2), 255);

      if (folder != null) {
        final png = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.png)))!;
        File('$folder/${layer.name}.png').writeAsBytesSync(png.buffer.asUint8List());
      }
    });
  }
}
