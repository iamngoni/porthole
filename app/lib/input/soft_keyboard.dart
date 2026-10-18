import 'dart:math' as math;

/// What the invisible field behind the on-screen keyboard holds between edits, so there is always
/// something for Delete to take. Zero-width spaces: the keyboard doesn't treat them as words or
/// sentences, so nothing gets capitalized or corrected.
const keyboardSentinel = '​​​​';

/// What the person did to the field: how many characters they took away, then what they typed. The Mac
/// gets that many Deletes and then the text, wherever the field's own cursor happened to be.
typedef KeyboardEdit = ({int deletes, String typed});

KeyboardEdit keyboardEdit(String before, String after) {
  final shorter = math.min(before.length, after.length);
  var prefix = 0;
  while (prefix < shorter && before.codeUnitAt(prefix) == after.codeUnitAt(prefix)) {
    prefix++;
  }
  var suffix = 0;
  while (suffix < shorter - prefix &&
      before.codeUnitAt(before.length - 1 - suffix) == after.codeUnitAt(after.length - 1 - suffix)) {
    suffix++;
  }
  // Never split a surrogate pair: back the shared part off it.
  if (prefix > 0 && prefix < after.length && _isLowSurrogate(after.codeUnitAt(prefix))) prefix--;
  if (suffix > 0 && suffix < after.length - prefix && _isHighSurrogate(after.codeUnitAt(after.length - suffix - 1))) {
    suffix--;
  }
  return (deletes: before.length - prefix - suffix, typed: after.substring(prefix, after.length - suffix));
}

/// The text worth sending: the field's own filler taken out.
String typedText(String typed) => typed.replaceAll('​', '');

bool _isLowSurrogate(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;
bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;
