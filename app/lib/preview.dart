import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:porthole_protocol/porthole_protocol.dart';

import 'client/client_controller.dart';
import 'client/host_browser.dart';

/// Sample state for checking layouts without a Mac: `--dart-define=PREVIEW=<screen>`, and optionally
/// `--dart-define=PREVIEW_ICONS=<folder>` with PNGs named by bundle ID, rendered on a Mac the way Porthole
/// Host does.
// no-prop-test: sample data for looking at screens.
Future<void> loadPreview(ClientController controller, String screen) async {
  const samples = [
    ('Porthole — Apple Developer Documentation', 'Safari', 'com.apple.Safari', true, Color(0xFFFFFFFF)),
    ('Porthole — StreamView.swift', 'Xcode', 'com.apple.dt.Xcode', true, Color(0xFF292929)),
    ('Release checklist', 'Notes', 'com.apple.Notes', true, Color(0xFFFFFAE6)),
    ('Downloads', 'Finder', 'com.apple.finder', false, Color(0xFFF2F2F2)),
    ('zsh — 120×36', 'Terminal', 'com.apple.Terminal', true, Color(0xFF141414)),
  ];
  final windows = [
    for (final (index, sample) in samples.indexed)
      WindowInfo(
        id: index + 1,
        title: sample.$1,
        appName: sample.$2,
        bundleId: sample.$3,
        pid: 100 + index,
        size: PointSize(width: 1280, height: 800),
        isOnScreen: sample.$4,
      ),
  ];
  final thumbnails = <int, ImageProvider>{
    for (final (index, sample) in samples.indexed) index + 1: MemoryImage(await _sampleWindow(sample.$5, index)),
  };
  const appList = [
    ('Activity Monitor', 'com.apple.ActivityMonitor'), ('App Store', 'com.apple.AppStore'), ('Calendar', 'com.apple.iCal'),
    ('Finder', 'com.apple.finder'), ('Maps', 'com.apple.Maps'), ('Music', 'com.apple.Music'), ('Notes', 'com.apple.Notes'),
    ('Photos', 'com.apple.Photos'), ('Safari', 'com.apple.Safari'), ('System Settings', 'com.apple.systempreferences'),
    ('Terminal', 'com.apple.Terminal'), ('Xcode', 'com.apple.dt.Xcode'),
  ];
  final apps = [
    for (final (name, bundleId) in appList)
      AppInfo(bundleId: bundleId, name: name, isRunning: samples.any((s) => s.$3 == bundleId)),
  ];
  const folder = String.fromEnvironment('PREVIEW_ICONS');
  final icons = <String, ImageProvider>{
    if (folder.isNotEmpty)
      for (final (_, bundleId) in appList)
        if (File('$folder/$bundleId.png').existsSync()) bundleId: FileImage(File('$folder/$bundleId.png')),
  };
  controller.loadPreview(
    screen,
    windows: windows,
    apps: apps,
    thumbnails: thumbnails,
    icons: icons,
    hosts: screen == 'searching'
        ? const []
        : const [
            DiscoveredHost(name: 'Ngonidzashe’s MacBook Pro', hostId: 'h1', port: 1),
            DiscoveredHost(name: 'Studio Mac mini', hostId: 'h2', port: 1),
          ],
    paired: [
      PairedHost(hostId: 'h1', hostName: 'Ngonidzashe’s MacBook Pro', pairId: 'p1', secret: Uint8List(32)),
      PairedHost(hostId: 'h3', hostName: 'Office iMac', pairId: 'p3', secret: Uint8List(32)),
    ],
  );
}

/// A made-up window: a title bar with its three buttons, a sidebar and a few lines of content.
Future<Uint8List> _sampleWindow(Color background, int seed) async {
  const size = Size(640, 400);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final dark = background.computeLuminance() < 0.5;
  final ink = dark ? const Color(0x29FFFFFF) : const Color(0x17000000);
  canvas.drawRect(Offset.zero & size, Paint()..color = background);
  canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 36), Paint()..color = dark ? const Color(0x0FFFFFFF) : const Color(0x0A000000));
  for (final (index, color) in const [Color(0xFFFF5F57), Color(0xFFFEBC2E), Color(0xFF28C840)].indexed) {
    canvas.drawCircle(Offset(20 + index * 20.0, 18), 6, Paint()..color = color);
  }
  final paint = Paint()..color = ink;
  if (seed.isEven) canvas.drawRect(Rect.fromLTWH(0, 36, 150, size.height - 36), paint);
  final left = seed.isEven ? 176.0 : 28.0;
  const widths = [0.9, 0.6, 0.75, 0.4, 0.85, 0.55, 0.7, 0.3, 0.65];
  for (var row = 0; row < 9; row++) {
    final width = (size.width - left - 30) * widths[(row + seed) % 9];
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(left, 64 + row * 34.0, width, 12), const Radius.circular(6)), paint);
  }
  final image = await recorder.endRecording().toImage(size.width.toInt(), size.height.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}
