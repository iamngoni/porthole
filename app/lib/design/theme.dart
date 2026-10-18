import 'package:flutter/widgets.dart';

/// Porthole's look (Theme.swift): graphite, frosted glass and rounded type, with one quiet accent.
/// Color is kept for meaning: the accent marks what's selected or live, and the status colors only ever
/// appear small.
abstract final class Palette {
  static const canvas = Color(0xFF0A0A0C);
  static const surface = Color(0x0DFFFFFF);
  static const surfaceRaised = Color(0x14FFFFFF);
  static const stroke = Color(0x17FFFFFF);

  static const textPrimary = Color(0xF2FFFFFF);
  static const textSecondary = Color(0x99FFFFFF);
  static const textTertiary = Color(0x5CFFFFFF);

  /// The one accent: focus, selection, what's on screen now.
  static const accent = Color(0xFF78A8FF);

  static const positive = Color(0xFF6BD199);
  static const warning = Color(0xFFFAC266);
  static const danger = Color(0xFFFF736B);

  static Color white(double opacity) => Color.fromRGBO(255, 255, 255, opacity);
  static Color black(double opacity) => Color.fromRGBO(0, 0, 0, opacity);
}

abstract final class Metrics {
  static const radius = 26.0;
  static const gutter = 28.0;
}

/// The typeface. Null is the system face (SF on iOS, Roboto on Android); a bundled rounded face would
/// match the iOS app exactly. Tests set one, since they have no system face.
abstract final class Typeface {
  static String? family;
}

/// Display type for titles and numbers.
TextStyle display(double size, [FontWeight weight = FontWeight.w700, Color color = Palette.textPrimary]) => TextStyle(
      fontFamily: Typeface.family,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1.15,
      letterSpacing: size >= 24 ? -0.4 : -0.1,
    );

/// Running text.
TextStyle body(double size, [FontWeight weight = FontWeight.w500, Color color = Palette.textPrimary]) =>
    TextStyle(fontFamily: Typeface.family, fontSize: size, fontWeight: weight, color: color, height: 1.3);

/// SwiftUI's spring(response:dampingFraction:) as the curves the app uses.
abstract final class Motion {
  static const press = Duration(milliseconds: 220);
  static const pressCurve = Curves.easeOutBack;
  static const fade = Duration(milliseconds: 350);
  static const smooth = Curves.easeInOutCubic;
}
