import 'package:porthole_protocol/porthole_protocol.dart';

/// One app's run of windows in the Mac's list, for the filter chips.
typedef AppRun = ({String name, String? bundleId, int count});

/// The Mac sends windows sorted by app, so consecutive windows of one app are one run.
List<AppRun> appRuns(List<WindowInfo> windows) {
  final runs = <AppRun>[];
  for (final window in windows) {
    final last = runs.lastOrNull;
    if (last != null && last.name == window.appName) {
      runs[runs.length - 1] = (name: last.name, bundleId: last.bundleId, count: last.count + 1);
    } else {
      runs.add((name: window.appName, bundleId: window.hasBundleId() ? window.bundleId : null, count: 1));
    }
  }
  return runs;
}

bool _matches(String text, String needle) => text.toLowerCase().contains(needle);

/// The windows to show for a search and an app filter, in the Mac's order.
List<WindowInfo> filterWindows(List<WindowInfo> windows, {String query = '', String? app}) {
  final needle = query.trim().toLowerCase();
  return windows
      .where((w) => (app == null || w.appName == app) && (needle.isEmpty || _matches(w.title, needle) || _matches(w.appName, needle)))
      .toList();
}

/// The apps whose names match a search, in the Mac's order.
List<AppInfo> filterApps(List<AppInfo> apps, String query) {
  final needle = query.trim().toLowerCase();
  return needle.isEmpty ? apps : apps.where((a) => _matches(a.name, needle)).toList();
}

/// How a window card is titled: untitled windows go by their app's name.
String windowTitle(WindowInfo window) => window.title.isEmpty ? window.appName : window.title;
