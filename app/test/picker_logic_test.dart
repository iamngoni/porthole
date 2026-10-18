import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test, setUp, tearDown;
import 'package:porthole/client/picker_logic.dart';
import 'package:porthole_protocol/porthole_protocol.dart';

import 'support/fakes.dart';

extension PickerAnys on Any {
  Generator<String> get word => choose(const ['', 'Safari', 'safari', 'Notes', 'Xcode', 'Release checklist', 'ZSH — 120×36', 'Ä']);

  /// Windows sorted by app, as the Mac sends them.
  Generator<List<WindowInfo>> get windows => listWithLengthInRange(0, 12, combine2(choose(const ['Safari', 'Notes', 'Xcode', 'Terminal']), word,
          (String app, String title) => (app, title))).map((pairs) {
        final sorted = [...pairs]..sort((a, b) => a.$1.compareTo(b.$1));
        return [
          for (final (index, (app, title)) in sorted.indexed)
            window(index + 1, app: app, bundleId: 'com.example.$app')..title = title,
        ];
      });

  Generator<String> get query => choose(const ['', ' ', 'saf', 'SAF', ' notes ', 'x', 'list', '—', 'zzz']);
}

void main() {
  Glados(any.windows).test('prop_app_runs_cover_every_window_once_in_order', (windows) {
    final runs = appRuns(windows);
    expect(runs.fold<int>(0, (sum, run) => sum + run.count), windows.length);
    expect([for (final run in runs) for (var i = 0; i < run.count; i++) run.name], [for (final w in windows) w.appName]);
    // Sorted input: one run per app.
    expect(runs.map((r) => r.name).toSet().length, runs.length);
  });

  Glados3(any.windows, any.query, any.choose(const [null, 'Safari', 'Notes', 'Nope'])).test(
      'prop_filtering_keeps_order_drops_only_misses_and_is_idempotent', (windows, query, app) {
    final shown = filterWindows(windows, query: query, app: app);
    // A subsequence of the Mac's list.
    var at = 0;
    for (final w in shown) {
      at = windows.indexOf(w, at) + 1;
      expect(at, greaterThan(0));
    }
    expect(filterWindows(shown, query: query, app: app), shown);
    if (app != null) expect(shown.every((w) => w.appName == app), isTrue);
    // Case doesn't matter.
    expect(filterWindows(windows, query: query.toUpperCase(), app: app), shown);
    if (query.trim().isEmpty && app == null) expect(shown, windows);
  });

  Glados2(any.windows, any.query).test('prop_a_longer_search_never_shows_more', (windows, query) {
    final shorter = filterWindows(windows, query: query);
    final longer = filterWindows(windows, query: '${query.trim()}e');
    expect(longer.every(shorter.contains), isTrue);
  });

  test('examples', () {
    final windows = [window(1, app: 'Notes')..title = 'Release checklist', window(2)..title = '', window(3)..title = 'Docs'];
    expect(appRuns(windows).map((r) => (r.name, r.count)), [('Notes', 1), ('Safari', 2)]);
    expect(filterWindows(windows, query: 'CHECK').map((w) => w.id), [1]);
    expect(filterWindows(windows, query: 'safari').map((w) => w.id), [2, 3]);
    expect(windowTitle(windows[1]), 'Safari');
    final apps = [AppInfo(name: 'Maps', bundleId: 'm'), AppInfo(name: 'Music', bundleId: 'u')];
    expect(filterApps(apps, ' ma ').map((a) => a.name), ['Maps']);
    expect(filterApps(apps, ''), apps);
  });
}
