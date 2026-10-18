// Keys travel as USB HID usages on the keyboard page (0x07); the Mac's own layout picks the character.
// The same tables as HIDKeyMap.swift.

/// HID usages the app sends by name.
abstract final class Usage {
  static const returnKey = 0x28;
  static const escape = 0x29;
  static const deleteBackward = 0x2A;
  static const tab = 0x2B;
  static const space = 0x2C;
  static const capsLock = 0x39;
  static const rightArrow = 0x4F;
  static const leftArrow = 0x50;
  static const downArrow = 0x51;
  static const upArrow = 0x52;
}

/// `KeyEvent.modifiers` bits.
abstract final class Modifier {
  static const shift = 1 << 0;
  static const control = 1 << 1;
  static const option = 1 << 2;
  static const command = 1 << 3;
}

/// The key that types [character] on a US layout, and whether it needs Shift. Null for characters that
/// aren't on the keyboard, which travel as text instead.
(int usage, bool shift)? usageForCharacter(String character) {
  if (character.length != 1) return null;
  final code = character.codeUnitAt(0);
  if (code >= 0x61 && code <= 0x7A) return (0x04 + code - 0x61, false); // a–z
  if (code >= 0x41 && code <= 0x5A) return (0x04 + code - 0x41, true); // A–Z
  if (code >= 0x31 && code <= 0x39) return (0x1E + code - 0x31, false); // 1–9
  if (code == 0x30) return (0x27, false); // 0
  return _punctuation[character];
}

/// The shortcut that on-screen keyboard text makes with [sticky] modifiers from the key bar, or null when
/// it goes as text. One character with ⌘, ⌥ or ⌃ is a shortcut (⌘ then "c" is Copy); anything longer, a
/// paste or dictation, is text, or "Quarterly" would be ⌘Q.
({int usage, int modifiers})? shortcutFor(String text, int sticky) {
  if (sticky & ~Modifier.shift == 0) return null;
  final key = usageForCharacter(text);
  if (key == null) return null;
  return (usage: key.$1, modifiers: key.$2 ? sticky | Modifier.shift : sticky);
}

const _punctuation = <String, (int, bool)>{
  '\n': (0x28, false), '\r': (0x28, false), '\t': (0x2B, false), ' ': (0x2C, false),
  '!': (0x1E, true), '@': (0x1F, true), '#': (0x20, true), r'$': (0x21, true), '%': (0x22, true),
  '^': (0x23, true), '&': (0x24, true), '*': (0x25, true), '(': (0x26, true), ')': (0x27, true),
  '-': (0x2D, false), '_': (0x2D, true), '=': (0x2E, false), '+': (0x2E, true),
  '[': (0x2F, false), '{': (0x2F, true), ']': (0x30, false), '}': (0x30, true),
  r'\': (0x31, false), '|': (0x31, true), ';': (0x33, false), ':': (0x33, true),
  "'": (0x34, false), '"': (0x34, true), '`': (0x35, false), '~': (0x35, true),
  ',': (0x36, false), '<': (0x36, true), '.': (0x37, false), '>': (0x37, true),
  '/': (0x38, false), '?': (0x38, true),
};

/// Letters, the keys Caps Lock affects.
bool isLetterUsage(int usage) => usage >= 0x04 && usage <= 0x1D;
