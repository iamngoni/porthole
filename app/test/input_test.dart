import 'package:characters/characters.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test, setUp, tearDown;
import 'package:porthole/input/display_name.dart';
import 'package:porthole/input/keys.dart';
import 'package:porthole/input/momentum.dart';

// Momentum, key mapping and name cleaning, with the same properties as InputLogicTests.swift.

extension InputAnys on Any {
  Generator<Offset> get velocity =>
      combine2(doubleInRange(-20000, 20000), doubleInRange(-20000, 20000), (double x, double y) => Offset(x, y));

  /// Names with what makes a list or a prompt lie: newlines, direction overrides, NUL, zero-width space.
  Generator<String> get name => listWithLengthInRange(
          0, 60, choose(const ['iPad', ' ', '\n', '\u202E', '\u0000', 'Ngoni’s', '👨‍👩‍👧‍👦', '\t', 'a', '\u200B']))
      .map((parts) => parts.join());
}

void main() {
  group('MomentumScroller', () {
    Glados(any.velocity, ExploreConfig(numRuns: 300)).test('prop_momentum_slows_keeps_direction_and_stops', (velocity) {
      final scroller = MomentumScroller(velocity);
      var lastSpeed = double.infinity;
      var steps = 0;
      var travelled = 0.0;
      for (var step = scroller.next(); step != null; step = scroller.next()) {
        expect(step.distance <= lastSpeed, isTrue);
        expect(step.dx * velocity.dx >= 0 && step.dy * velocity.dy >= 0, isTrue);
        lastSpeed = step.distance;
        travelled += step.distance;
        if (++steps > 1000) break;
      }
      expect(steps <= 1000, isTrue);
      // A geometric series: never further than the first step divided by (1 - decay).
      final first = velocity.distance / MomentumScroller.framesPerSecond;
      expect(travelled <= first / (1 - MomentumScroller.decayPerFrame) + 1e-6, isTrue);
    });

    Glados2(any.velocity, any.intInRange(1, 5)).test('prop_several_frames_at_once_go_as_far_as_one_at_a_time', (velocity, n) {
      final batched = MomentumScroller(velocity);
      final single = MomentumScroller(velocity);
      for (var round = 0; round < 40; round++) {
        final together = batched.take(n);
        Offset? apart;
        for (var i = 0; i < n; i++) {
          final step = single.next();
          if (step != null) apart = (apart ?? Offset.zero) + step;
        }
        expect(together == null, apart == null);
        if (together != null) expect((together - apart!).distance < 1e-9, isTrue);
      }
    });

    test('no velocity means no momentum', () {
      expect(MomentumScroller(Offset.zero).next(), isNull);
      expect(MomentumScroller(const Offset(double.nan, double.infinity)).next(), isNull);
    });
  });

  group('keys', () {
    final printable = [for (var code = 32; code <= 126; code++) String.fromCharCode(code), '\n', '\t'];

    Glados(any.choose(printable)).test('prop_every_us_character_maps_to_a_key', (character) {
      final key = usageForCharacter(character);
      expect(key, isNotNull);
      expect(key!.$1 >= 0x04 && key.$1 <= 0x38, isTrue);
    });

    Glados(any.choose('abcdefghijklmnopqrstuvwxyz'.split(''))).test('prop_upper_and_lower_case_share_a_key', (letter) {
      final lower = usageForCharacter(letter)!;
      final upper = usageForCharacter(letter.toUpperCase())!;
      expect((lower.$1, lower.$2, upper.$2), (upper.$1, false, true));
      expect(isLetterUsage(lower.$1), isTrue);
    });

    Glados2(any.listWithLengthInRange(2, 12, any.choose(const ['a', 'Q', '1', ' ', 'é', '👍', '\n'])), any.intInRange(0, 16))
        .test('prop_text_longer_than_one_character_is_never_a_shortcut', (parts, sticky) {
      expect(shortcutFor(parts.join(), sticky), isNull);
    });

    Glados2(any.choose(printable), any.intInRange(0, 16))
        .test('prop_one_character_with_command_option_or_control_is_its_key_with_them', (character, sticky) {
      final shortcut = shortcutFor(character, sticky);
      if (sticky & ~Modifier.shift == 0) {
        expect(shortcut, isNull);
        return;
      }
      final key = usageForCharacter(character)!;
      expect(shortcut!.usage, key.$1);
      expect(shortcut.modifiers & sticky, sticky);
      expect(shortcut.modifiers & ~(sticky | Modifier.shift), 0);
      expect(shortcut.modifiers & Modifier.shift != 0, key.$2 || sticky & Modifier.shift != 0);
    });

    test('a paste with ⌘ on the key bar is text, not a run of shortcuts', () {
      expect(shortcutFor('Quarterly report', Modifier.command), isNull);
      expect(shortcutFor('c', Modifier.command), (usage: 0x06, modifiers: Modifier.command));
      expect(shortcutFor('C', Modifier.command), (usage: 0x06, modifiers: Modifier.command | Modifier.shift));
      expect(shortcutFor('c', Modifier.shift), isNull);
      expect(shortcutFor('é', Modifier.command), isNull);
    });

    test('known keys', () {
      expect(usageForCharacter('a'), (0x04, false));
      expect(usageForCharacter('?'), (0x38, true));
      expect(usageForCharacter('0'), (0x27, false));
      expect(usageForCharacter('\n'), (Usage.returnKey, false));
      expect(usageForCharacter('é'), isNull);
      expect(usageForCharacter('ab'), isNull);
    });
  });

  group('DisplayName', () {
    Glados(any.name, ExploreConfig(numRuns: 400)).test('prop_cleaned_names_are_short_visible_and_never_empty', (name) {
      final cleaned = DisplayName.clean(name, fallback: 'Device');
      expect(cleaned.isNotEmpty && cleaned.characters.length <= DisplayName.maxLength, isTrue);
      expect(cleaned.runes.any((rune) => rune < 0x20 || rune == 0x202E || rune == 0x200B), isFalse);
      expect(cleaned.startsWith(' ') || cleaned.endsWith(' '), isFalse);
    });

    Glados(any.name, ExploreConfig(numRuns: 300)).test('prop_cleaning_twice_changes_nothing', (name) {
      final once = DisplayName.clean(name, fallback: 'Device');
      expect(DisplayName.clean(once, fallback: 'Device'), once);
    });

    test('examples', () {
      expect(DisplayName.clean('  Ngoni’s\niPad ', fallback: 'Device'), 'Ngoni’s iPad');
      expect(DisplayName.clean('\u202E\u0000', fallback: 'Device'), 'Device');
      expect(DisplayName.clean('a' * 50, fallback: 'D'), '${'a' * 39}…');
      expect(DisplayName.clean('👨‍👩‍👧‍👦' * 41, fallback: 'D'), '${'👨‍👩‍👧‍👦' * 39}…');
    });
  });
}
