import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test, setUp, tearDown;
import 'package:porthole/input/soft_keyboard.dart';

extension KeyboardAnys on Any {
  /// Edits a keyboard can make to the field: typing (emoji included), deleting, replacing a word.
  Generator<String> get fieldText => listWithLengthInRange(0, 10, choose(const ['​', 'a', 'é', ' ', '\n', '😀', '👨‍👩‍👧', '.', 'Z']))
      .map((parts) => parts.join());
}

void main() {
  Glados2(any.fieldText, any.fieldText, ExploreConfig(numRuns: 400))
      .test('prop_deleting_then_typing_turns_the_old_text_into_the_new', (before, after) {
    final edit = keyboardEdit(before, after);
    expect(edit.deletes, inInclusiveRange(0, before.length));
    final kept = before.length - edit.deletes;
    // The new text is the old one with a stretch replaced by what was typed.
    final rebuilt = [for (var p = 0; p <= kept; p++) before.substring(0, p) + edit.typed + before.substring(p + edit.deletes)];
    expect(rebuilt, contains(after));
    // Typed text never starts or ends inside an emoji.
    if (edit.typed.isNotEmpty) {
      expect(edit.typed.codeUnitAt(0) >= 0xDC00 && edit.typed.codeUnitAt(0) <= 0xDFFF, isFalse);
      final last = edit.typed.codeUnitAt(edit.typed.length - 1);
      expect(last >= 0xD800 && last <= 0xDBFF, isFalse);
    }
  });

  Glados(any.fieldText).test('prop_no_change_is_no_edit', (text) {
    expect(keyboardEdit(text, text), (deletes: 0, typed: ''));
  });

  test('typing, deleting and autocorrect from the filler', () {
    expect(keyboardEdit(keyboardSentinel, '${keyboardSentinel}h'), (deletes: 0, typed: 'h'));
    expect(keyboardEdit(keyboardSentinel, keyboardSentinel.substring(1)), (deletes: 1, typed: ''));
    expect(keyboardEdit('${keyboardSentinel}teh', '${keyboardSentinel}the '), (deletes: 2, typed: 'he '));
    expect(keyboardEdit(keyboardSentinel, '$keyboardSentinel😀'), (deletes: 0, typed: '😀'));
    expect(typedText('​hi​'), 'hi');
  });
}
