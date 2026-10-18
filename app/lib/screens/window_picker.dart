import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:porthole_protocol/porthole_protocol.dart' show AppInfo, WindowInfo;

import '../client/client_controller.dart';
import '../client/client_scope.dart';
import '../client/picker_logic.dart';
import '../design/backdrop.dart';
import '../design/buttons.dart';
import '../design/glass.dart';
import '../design/pieces.dart';
import '../design/theme.dart';
import 'host_list.dart' show SectionTitle;

enum PickerMode { windows, apps }

/// The Mac's open windows as live cards, or its installed apps to open one, filterable by searching.
class WindowPickerView extends StatefulWidget {
  const WindowPickerView({super.key});

  @override
  State<WindowPickerView> createState() => _WindowPickerViewState();
}

class _WindowPickerViewState extends State<WindowPickerView> {
  late var _mode = ClientScope.read(context).previewScreen == 'apps' ? PickerMode.apps : PickerMode.windows;
  var _query = '';
  String? _app;

  @override
  Widget build(BuildContext context) {
    final client = ClientScope.of(context);
    final hostName = switch (client.phase) {
      Connected(:final hostName) => hostName,
      _ => 'Mac',
    };
    return Stack(children: [
      const Positioned.fill(child: Backdrop(intensity: 0.7)),
      SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Metrics.gutter, 18, Metrics.gutter, 14),
            child: _Header(
              hostName: hostName,
              mode: _mode,
              query: _query,
              onMode: (mode) => setState(() => _mode = mode),
              onQuery: (query) => setState(() => _query = query),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: switch (_mode) {
                PickerMode.windows => WindowGrid(
                    key: const ValueKey('windows'),
                    query: _query,
                    app: _app,
                    onApp: (app) => setState(() => _app = app),
                    onSelect: client.select,
                  ),
                PickerMode.apps => AppGrid(key: const ValueKey('apps'), query: _query, onLaunch: client.launch),
              },
            ),
          ),
        ]),
      ),
    ]);
  }
}

/// One row when it fits; on a narrower screen the toggle and search move under the Mac's name.
class _Header extends StatelessWidget {
  const _Header({required this.hostName, required this.mode, required this.query, required this.onMode, required this.onQuery});
  final String hostName;
  final PickerMode mode;
  final String query;
  final ValueChanged<PickerMode> onMode;
  final ValueChanged<String> onQuery;

  @override
  Widget build(BuildContext context) {
    final client = ClientScope.of(context);
    final count = client.windows.length;
    final windows = count == 1 ? '1 window' : '$count windows';
    final title = Row(mainAxisSize: MainAxisSize.min, children: [
      CircleButton(Icons.chevron_left_rounded, size: 46, label: 'Disconnect', onPressed: client.disconnect),
      const SizedBox(width: 14),
      Flexible(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(hostName, style: display(30, FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Row(children: [
            StatusDot(color: client.canControl ? Palette.positive : Palette.warning, pulsing: true),
            const SizedBox(width: 7),
            Flexible(
              child: Text(client.canControl ? 'Connected · $windows' : 'View only · $windows',
                  style: body(14, FontWeight.w500, Palette.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ]),
        ]),
      ),
    ]);
    final refresh = CircleButton(Icons.refresh_rounded,
        size: 46, label: 'Refresh', onPressed: mode == PickerMode.windows ? client.refreshWindows : client.refreshApps);
    List<Widget> tools({required bool stretch}) => [
          ModeToggle(mode: mode, onChanged: onMode),
          const SizedBox(width: 12),
          stretch
              ? Expanded(child: SearchField(value: query, onChanged: onQuery, prompt: _prompt))
              : SizedBox(width: 260, child: SearchField(value: query, onChanged: onQuery, prompt: _prompt)),
          const SizedBox(width: 12),
          refresh,
        ];
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= 820) {
        return Row(children: [Expanded(child: title), const SizedBox(width: 12), ...tools(stretch: false)]);
      }
      if (constraints.maxWidth >= 560) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          title,
          const SizedBox(height: 16),
          Row(children: tools(stretch: true)),
        ]);
      }
      // A phone: the search gets a row of its own.
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        title,
        const SizedBox(height: 16),
        Row(children: [ModeToggle(mode: mode, onChanged: onMode), const Spacer(), refresh]),
        const SizedBox(height: 12),
        SearchField(value: query, onChanged: onQuery, prompt: _prompt),
      ]);
    });
  }

  String get _prompt => mode == PickerMode.windows ? 'Search windows' : 'Search apps';
}

/// Cards for every window, with a row of app filters on top. Shared by the picker and the in-stream switcher.
class WindowGrid extends StatefulWidget {
  const WindowGrid({
    super.key,
    required this.query,
    required this.app,
    required this.onApp,
    required this.onSelect,
    this.compact = false,
  });

  final String query;
  final String? app;
  final ValueChanged<String?> onApp;
  final ValueChanged<WindowInfo> onSelect;
  final bool compact;

  @override
  State<WindowGrid> createState() => _WindowGridState();
}

class _WindowGridState extends State<WindowGrid> {
  ClientController? _client;

  /// Thumbnails stay fresh only while a grid is on screen.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final client = ClientScope.read(context);
    if (!identical(client, _client)) {
      _client?.setPreviewsVisible(false);
      _client = client..setPreviewsVisible(true);
    }
  }

  @override
  void dispose() {
    _client?.setPreviewsVisible(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final client = ClientScope.of(context);
    if (client.windows.isEmpty) return const _EmptyWindows();
    final runs = appRuns(client.windows);
    final shown = filterWindows(client.windows, query: widget.query, app: widget.app);
    final gutter = widget.compact ? 20.0 : Metrics.gutter;
    final spacing = widget.compact ? 16.0 : 22.0;
    return Column(children: [
      if (runs.length > 1)
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: gutter, vertical: 4),
            children: [
              _FilterChip(title: 'All', count: client.windows.length, isOn: widget.app == null, onTap: () => widget.onApp(null)),
              for (final run in runs) ...[
                const SizedBox(width: 10),
                _FilterChip(
                  title: run.name,
                  icon: client.icon(run.bundleId),
                  count: run.count,
                  isOn: widget.app == run.name,
                  onTap: () => widget.onApp(widget.app == run.name ? null : run.name),
                ),
              ],
            ],
          ),
        ),
      if (runs.length > 1) const SizedBox(height: 14),
      Expanded(
        child: RefreshIndicator(
          color: Palette.canvas,
          backgroundColor: Palette.white(0.92),
          onRefresh: () async => client.refreshWindows(),
          child: LayoutBuilder(builder: (context, constraints) {
            final minimum = widget.compact ? 220.0 : 280.0;
            final width = constraints.maxWidth - gutter * 2;
            final columns = math.max(1, ((width + spacing) / (minimum + spacing)).floor());
            final cardWidth = math.min(460.0, (width - spacing * (columns - 1)) / columns);
            final cardHeight = (cardWidth - 24) * 10 / 16 + 24 + 14 + 40;
            if (shown.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 40),
                Text('No windows match “${widget.query}”',
                    style: body(16, FontWeight.w500, Palette.textSecondary), textAlign: TextAlign.center),
              ]);
            }
            return GridView.builder(
              padding: EdgeInsets.fromLTRB(gutter, 6, gutter, 40 + MediaQuery.paddingOf(context).bottom),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: spacing,
                mainAxisSpacing: widget.compact ? 18 : 26,
                mainAxisExtent: cardHeight,
              ),
              itemCount: shown.length,
              itemBuilder: (context, index) {
                final window = shown[index];
                return WindowCard(
                  key: ValueKey(window.id),
                  window: window,
                  thumbnail: client.thumbnails[window.id],
                  icon: client.icon(window.hasBundleId() ? window.bundleId : null),
                  isPending: client.pendingWindowId == window.id,
                  isCurrent: client.stream?.windowId == window.id,
                  onTap: client.pendingWindowId == null ? () => widget.onSelect(window) : null,
                );
              },
            );
          }),
        ),
      ),
    ]);
  }
}

/// One window: a live still of it, its app's icon on the corner as in Mission Control, and its title.
class WindowCard extends StatelessWidget {
  const WindowCard({
    super.key,
    required this.window,
    required this.thumbnail,
    required this.icon,
    required this.onTap,
    this.isPending = false,
    this.isCurrent = false,
  });

  final WindowInfo window;
  final ImageProvider? thumbnail;
  final ImageProvider? icon;
  final VoidCallback? onTap;
  final bool isPending;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final lit = isPending || isCurrent;
    return Semantics(
      label: '${window.appName}, ${window.title}',
      hint: window.isOnScreen ? 'Shows this window' : 'Brings this window forward and shows it',
      child: Pressable(
        onTap: onTap,
        child: Stack(children: [
          Glass(
            radius: 24,
            highlight: lit,
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Stack(clipBehavior: Clip.none, children: [
                _Preview(thumbnail: thumbnail, isPending: isPending),
                Positioned(
                  left: 8,
                  bottom: -26,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: [BoxShadow(color: Palette.black(0.55), blurRadius: 10, offset: const Offset(0, 5))],
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: AppIconView(image: icon, size: 56),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(children: [
                  const SizedBox(width: 62),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(windowTitle(window), style: display(15, FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(window.appName, style: body(12.5, FontWeight.w500, Palette.textTertiary), maxLines: 1),
                    ]),
                  ),
                  if (isCurrent)
                    const Pill('Showing', color: Palette.accent)
                  else if (!window.isOnScreen)
                    const Pill('Hidden'),
                ]),
              ),
            ]),
          ),
          if (lit)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Palette.accent.withValues(alpha: 0.9), width: 1.5),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.thumbnail, required this.isPending});
  final ImageProvider? thumbnail;
  final bool isPending;

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 16 / 10,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(fit: StackFit.expand, children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Palette.white(0.06), Palette.white(0.02)],
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: thumbnail == null
                  ? const Center(child: SizedBox(width: 110, height: 6, child: ShimmerBar()))
                  : Padding(
                      key: const ValueKey('still'),
                      padding: const EdgeInsets.all(10),
                      child: Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            boxShadow: [BoxShadow(color: Palette.black(0.45), blurRadius: 10, offset: const Offset(0, 6))],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image(image: thumbnail!, fit: BoxFit.contain, gaplessPlayback: true,
                                filterQuality: FilterQuality.medium, errorBuilder: (_, _, _) => const SizedBox()),
                          ),
                        ),
                      ),
                    ),
            ),
            if (isPending) ...[
              ColoredBox(color: Palette.black(0.45)),
              const Center(child: SizedBox.square(dimension: 32, child: CircularProgressIndicator(color: Color(0xFFFFFFFF), strokeWidth: 3))),
            ],
          ]),
        ),
      );
}

/// An app's icon from the Mac, or a soft placeholder until it arrives.
class AppIconView extends StatelessWidget {
  const AppIconView({super.key, required this.image, this.size = 32});
  final ImageProvider? image;
  final double size;

  @override
  Widget build(BuildContext context) {
    final placeholder = Padding(
      padding: EdgeInsets.all(size * 0.08),
      child: Container(
        decoration: BoxDecoration(color: Palette.white(0.1), borderRadius: BorderRadius.circular(size * 0.24)),
        child: Icon(Icons.web_asset_rounded, size: size * 0.45, color: Palette.white(0.8)),
      ),
    );
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: image == null
            ? placeholder
            : Image(image: image!, fit: BoxFit.contain, filterQuality: FilterQuality.high, gaplessPlayback: true,
                errorBuilder: (_, _, _) => placeholder),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.title, required this.count, required this.isOn, required this.onTap, this.icon});
  final String title;
  final ImageProvider? icon;
  final int count;
  final bool isOn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: isOn,
        child: Pressable(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Palette.white(isOn ? 0.92 : 0.07),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: Palette.white(isOn ? 0 : 0.08)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[AppIconView(image: icon, size: 20), const SizedBox(width: 8)],
              Text(title, style: display(14, FontWeight.w600, isOn ? Palette.canvas : Palette.textSecondary)),
              const SizedBox(width: 8),
              Text('$count',
                  style: display(12, FontWeight.w700, isOn ? Palette.canvas.withValues(alpha: 0.55) : Palette.textTertiary)
                      .copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
            ]),
          ),
        ),
      );
}

class SearchField extends StatefulWidget {
  const SearchField({super.key, required this.value, required this.onChanged, this.prompt = 'Search windows'});
  final String value;
  final ValueChanged<String> onChanged;
  final String prompt;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final _controller = TextEditingController(text: widget.value);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Palette.white(focused ? 0.11 : 0.07),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
          color: focused ? Palette.accent.withValues(alpha: 0.8) : Palette.white(0.08),
          width: focused ? 1.5 : 1,
        ),
      ),
      child: Row(children: [
        const Icon(Icons.search_rounded, size: 20, color: Palette.textTertiary),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            onChanged: widget.onChanged,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.search,
            cursorColor: Palette.accent,
            style: body(15),
            decoration: InputDecoration.collapsed(hintText: widget.prompt, hintStyle: body(15, FontWeight.w500, Palette.textTertiary)),
          ),
        ),
        if (widget.value.isNotEmpty)
          Pressable(
            label: 'Clear search',
            onTap: () {
              _controller.clear();
              widget.onChanged('');
            },
            child: const Icon(Icons.cancel_rounded, size: 18, color: Palette.textTertiary),
          ),
      ]),
    );
  }
}

/// A faint moving highlight, for a card whose still hasn't arrived yet.
class ShimmerBar extends StatefulWidget {
  const ShimmerBar({super.key});

  @override
  State<ShimmerBar> createState() => _ShimmerBarState();
}

class _ShimmerBarState extends State<ShimmerBar> with SingleTickerProviderStateMixin {
  late final _phase = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();

  @override
  void dispose() {
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: AnimatedBuilder(
            animation: _phase,
            builder: (context, _) {
              final x = -1 + 2.2 * _phase.value;
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: Palette.white(0.08),
                  gradient: LinearGradient(
                    begin: Alignment(x - 0.6, 0),
                    end: Alignment(x + 0.6, 0),
                    colors: [Palette.white(0.08), Palette.white(0.35), Palette.white(0.08)],
                  ),
                ),
              );
            },
          ),
        ),
      );
}

class _EmptyWindows extends StatelessWidget {
  const _EmptyWindows();

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Metrics.gutter),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Glass(
              radius: 30,
              padding: const EdgeInsets.all(34),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const GlowIcon(Icons.filter_none_rounded, size: 80),
                const SizedBox(height: 18),
                Text('No windows to show', style: display(24), textAlign: TextAlign.center),
                const SizedBox(height: 18),
                Text(
                  'Open an app on your Mac. If it’s already open, allow Porthole Host under Screen & System Audio '
                  'Recording in the Mac’s System Settings.',
                  style: body(16, FontWeight.w500, Palette.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ]),
            ),
          ),
        ),
      );
}

/// Windows or Apps, as a small glass segmented control.
class ModeToggle extends StatelessWidget {
  const ModeToggle({super.key, required this.mode, required this.onChanged});
  final PickerMode mode;
  final ValueChanged<PickerMode> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget segment(String title, IconData icon, PickerMode value) {
      final on = mode == value;
      return Semantics(
        selected: on,
        child: Pressable(
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: Palette.white(on ? 0.92 : 0), borderRadius: BorderRadius.circular(19)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 17, color: on ? Palette.canvas : Palette.textSecondary),
              const SizedBox(width: 6),
              Text(title, style: display(14, FontWeight.w600, on ? Palette.canvas : Palette.textSecondary)),
            ]),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Palette.white(0.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Palette.white(0.08)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        segment('Windows', Icons.filter_none_rounded, PickerMode.windows),
        const SizedBox(width: 2),
        segment('Apps', Icons.apps_rounded, PickerMode.apps),
      ]),
    );
  }
}

/// The Mac's installed apps as icons, the open ones first. Tapping one opens it on the Mac and shows its window.
class AppGrid extends StatefulWidget {
  const AppGrid({super.key, required this.query, required this.onLaunch, this.compact = false});
  final String query;
  final ValueChanged<AppInfo> onLaunch;
  final bool compact;

  @override
  State<AppGrid> createState() => _AppGridState();
}

class _AppGridState extends State<AppGrid> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ClientScope.read(context).refreshApps();
    });
  }

  @override
  Widget build(BuildContext context) {
    final client = ClientScope.of(context);
    if (client.apps.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox.square(dimension: 34, child: CircularProgressIndicator(color: Color(0xFFFFFFFF), strokeWidth: 3)),
          const SizedBox(height: 16),
          Text('Looking for apps on your Mac…', style: body(16, FontWeight.w500, Palette.textSecondary)),
        ]),
      );
    }
    final shown = filterApps(client.apps, widget.query);
    final open = shown.where((a) => a.isRunning).toList();
    final gutter = widget.compact ? 20.0 : Metrics.gutter;
    final size = widget.compact ? 62.0 : 72.0;
    final searching = widget.query.trim().isNotEmpty;

    Widget section(String title, List<AppInfo> apps) => SliverMainAxisGroup(slivers: [
          SliverPadding(
            padding: const EdgeInsets.only(left: 6, bottom: 12),
            sliver: SliverToBoxAdapter(child: SectionTitle(title)),
          ),
          SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: widget.compact ? 120 : 150,
              mainAxisExtent: size + 76,
              crossAxisSpacing: widget.compact ? 8 : 12,
              mainAxisSpacing: widget.compact ? 6 : 10,
            ),
            itemCount: apps.length,
            itemBuilder: (context, index) {
              final app = apps[index];
              client.wantIcon(app.bundleId);
              return _AppTile(
                app: app,
                icon: client.appIcons[app.bundleId],
                size: size,
                isLaunching: client.pendingLaunch?.bundleId == app.bundleId,
                onTap: client.pendingLaunch == null ? () => widget.onLaunch(app) : null,
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 30)),
        ]);

    return RefreshIndicator(
      color: Palette.canvas,
      backgroundColor: Palette.white(0.92),
      onRefresh: () async => client.refreshApps(),
      child: CustomScrollView(slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(gutter, 6, gutter, 40 + MediaQuery.paddingOf(context).bottom),
          sliver: SliverMainAxisGroup(slivers: [
            if (!searching && open.isNotEmpty) section('Open now', open),
            if (shown.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Text('No apps match “${widget.query}”',
                      style: body(16, FontWeight.w500, Palette.textSecondary), textAlign: TextAlign.center),
                ),
              )
            else
              section(searching ? 'Results' : 'All apps', shown),
          ]),
        ),
      ]),
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({required this.app, required this.icon, required this.onTap, this.size = 72, this.isLaunching = false});
  final AppInfo app;
  final ImageProvider? icon;
  final VoidCallback? onTap;
  final double size;
  final bool isLaunching;

  @override
  Widget build(BuildContext context) => Semantics(
        label: app.isRunning ? '${app.name}, open' : app.name,
        hint: 'Opens it on your Mac and shows its window',
        child: Pressable(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            child: Column(children: [
              Stack(alignment: Alignment.center, children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(size * 0.22),
                    boxShadow: [BoxShadow(color: Palette.black(0.45), blurRadius: 10, offset: const Offset(0, 6))],
                  ),
                  child: AppIconView(image: icon, size: size),
                ),
                if (isLaunching)
                  const SizedBox.square(dimension: 24, child: CircularProgressIndicator(color: Color(0xFFFFFFFF), strokeWidth: 2.5)),
              ]),
              const SizedBox(height: 9),
              SizedBox(
                height: 34,
                child: Text(app.name, style: body(13), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(height: 4),
              // An open app gets a dot, as in the Dock.
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(shape: BoxShape.circle, color: app.isRunning ? Palette.textSecondary : null),
              ),
            ]),
          ),
        ),
      );
}
