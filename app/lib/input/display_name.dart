import 'package:characters/characters.dart';

/// Names that came over the network, made safe to show in a prompt or a list (DisplayName in
/// InputLogic.swift): control and format characters become spaces, runs of space collapse, and long
/// names end in an ellipsis.
abstract final class DisplayName {
  static const maxLength = 40;

  static String clean(String name, {required String fallback}) {
    final visible = String.fromCharCodes(name.runes.map((rune) => _isHidden(rune) ? 0x20 : rune));
    final collapsed = visible.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).join(' ');
    if (collapsed.isEmpty) return fallback;
    // Counted in characters as people see them, so an emoji family is one and is never cut in half.
    final characters = collapsed.characters;
    if (characters.length <= maxLength) return collapsed;
    return '${characters.take(maxLength - 1)}…';
  }

  /// C0 and C1 controls, and format characters (direction overrides, zero-width spaces) except the
  /// zero-width joiner that holds emoji sequences together.
  static bool _isHidden(int rune) =>
      rune < 0x20 ||
      (rune >= 0x7F && rune <= 0x9F) ||
      rune == 0xAD ||
      (rune >= 0x200B && rune <= 0x200F && rune != 0x200D) ||
      (rune >= 0x2028 && rune <= 0x202E) ||
      (rune >= 0x2060 && rune <= 0x206F) ||
      rune == 0xFEFF;
}
