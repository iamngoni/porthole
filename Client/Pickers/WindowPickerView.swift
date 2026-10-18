import PortholeProtocol
import SwiftUI

/// The Mac's open windows as live cards, or its installed apps to open one, filterable by searching.
struct WindowPickerView: View {
    @EnvironmentObject private var client: ClientController
    @State private var query = ""
    @State private var app: String?
    #if DEBUG
    @State private var mode: PickerMode = UserDefaults.standard.string(forKey: "preview") == "apps" ? .apps : .windows
    #else
    @State private var mode = PickerMode.windows
    #endif

    private var hostName: String {
        if case .connected(let name) = client.phase { return name }
        return "Mac"
    }

    var body: some View {
        ZStack {
            Backdrop(intensity: 0.7)
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, Theme.gutter)
                    .padding(.top, 18)
                    .padding(.bottom, 14)
                switch mode {
                case .windows:
                    WindowGrid(query: query, app: $app) { window in client.select(window) }
                        .transition(.opacity)
                case .apps:
                    AppGrid(query: query) { app in client.launch(app) }
                        .transition(.opacity)
                }
            }
            .animation(.smooth(duration: 0.3), value: mode)
        }
        .onAppear { client.setPreviewsVisible(true) }
        .onDisappear { client.setPreviewsVisible(false) }
    }

    /// One row when it fits; on a narrower screen the toggle and search move under the Mac's name.
    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) {
                backAndTitle.fixedSize()
                Spacer(minLength: 12)
                tools
            }
            VStack(alignment: .leading, spacing: 16) {
                backAndTitle
                HStack(spacing: 12) {
                    tools
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var backAndTitle: some View {
        HStack(spacing: 14) {
            Button(action: client.disconnect) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(IconButtonStyle(size: 46))
            .accessibilityLabel("Disconnect")
            VStack(alignment: .leading, spacing: 3) {
                Text(hostName)
                    .font(.display(30, .heavy))
                    .lineLimit(1)
                HStack(spacing: 7) {
                    StatusDot(color: client.canControl ? Theme.positive : Theme.warning, pulsing: true)
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            }
        }
    }

    @ViewBuilder
    private var tools: some View {
        ModeToggle(mode: $mode)
            .fixedSize()
        SearchField(text: $query, prompt: mode == .windows ? "Search windows" : "Search apps")
            .frame(minWidth: 220, maxWidth: 280)
        Button(action: mode == .windows ? client.refreshWindows : client.refreshApps) {
            Image(systemName: "arrow.clockwise")
        }
        .buttonStyle(IconButtonStyle(size: 46))
        .accessibilityLabel("Refresh")
    }

    private var subtitle: String {
        let count = client.windows.count
        let windows = count == 1 ? "1 window" : "\(count) windows"
        return client.canControl ? "Connected · \(windows)" : "View only · \(windows)"
    }
}

/// Cards for every window, with a row of app filters on top. Shared by the picker and the in-stream switcher.
struct WindowGrid: View {
    @EnvironmentObject private var client: ClientController
    var query: String
    @Binding var app: String?
    var compact = false
    let onSelect: (WindowInfo) -> Void

    private var apps: [(name: String, bundleID: String?, count: Int)] {
        // The host sends windows sorted by app, so consecutive runs are one app.
        client.windows.reduce(into: []) { apps, window in
            if apps.last?.name == window.appName {
                apps[apps.count - 1].count += 1
            } else {
                apps.append((window.appName, window.bundleID, 1))
            }
        }
    }

    private var shown: [WindowInfo] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        return client.windows.filter { window in
            (app == nil || window.appName == app)
                && (needle.isEmpty || window.title.localizedCaseInsensitiveContains(needle) || window.appName.localizedCaseInsensitiveContains(needle))
        }
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: compact ? 220 : 280, maximum: 460), spacing: compact ? 16 : 22)]
    }

    var body: some View {
        if client.windows.isEmpty {
            EmptyWindowsView()
        } else {
            VStack(spacing: 0) {
                if apps.count > 1 {
                    filters
                }
                ScrollView {
                    LazyVGrid(columns: columns, spacing: compact ? 18 : 26) {
                        ForEach(shown) { window in
                            WindowCard(window: window,
                                       thumbnail: client.thumbnails[window.id],
                                       icon: client.icon(for: window.bundleID),
                                       isPending: client.pendingWindowID == window.id,
                                       isCurrent: client.stream?.windowID == window.id) {
                                onSelect(window)
                            }
                            .disabled(client.pendingWindowID != nil)
                        }
                    }
                    .padding(.horizontal, compact ? 20 : Theme.gutter)
                    .padding(.top, 6)
                    .padding(.bottom, 40)
                    .animation(.smooth(duration: 0.35), value: shown.map(\.id))
                    if shown.isEmpty {
                        Text("No windows match “\(query)”")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.top, 40)
                    }
                }
                .scrollIndicators(.hidden)
                .refreshable { client.refreshWindows() }
            }
        }
    }

    private var filters: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                FilterChip(title: "All", icon: nil, count: client.windows.count, isOn: app == nil) { app = nil }
                ForEach(apps, id: \.name) { entry in
                    FilterChip(title: entry.name, icon: client.icon(for: entry.bundleID), count: entry.count, isOn: app == entry.name) {
                        app = app == entry.name ? nil : entry.name
                    }
                }
            }
            .padding(.horizontal, compact ? 20 : Theme.gutter)
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        .padding(.bottom, 14)
        .animation(.smooth(duration: 0.25), value: app)
    }
}

/// One window: a live still of it, its app's icon and its title.
struct WindowCard: View {
    let window: WindowInfo
    let thumbnail: UIImage?
    let icon: UIImage?
    var isPending = false
    var isCurrent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // The app's icon sits on the window's corner, as in Mission Control.
                preview
                    .overlay(alignment: .bottomLeading) {
                        AppIconView(image: icon, size: 56)
                            .shadow(color: .black.opacity(0.55), radius: 10, y: 5)
                            .offset(x: 8, y: 26)
                    }
                HStack(spacing: 10) {
                    Color.clear.frame(width: 62, height: 1)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(window.title.isEmpty ? window.appName : window.title)
                            .font(.display(15, .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                        Text(window.appName)
                            .font(.system(size: 12.5, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textTertiary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if isCurrent {
                        Chip(text: "Showing", color: Theme.accent)
                    } else if !window.isOnScreen {
                        Chip(text: "Hidden", color: Theme.textSecondary)
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding(12)
            .glassCard(cornerRadius: 24, highlight: isPending || isCurrent)
            .overlay {
                if isPending || isCurrent {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Theme.accent.opacity(0.9), lineWidth: 1.5)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(window.appName), \(window.title)")
        .accessibilityHint(window.isOnScreen ? "Shows this window" : "Brings this window forward and shows it")
    }

    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(colors: [Color.white.opacity(0.06), Color.white.opacity(0.02)], startPoint: .top, endPoint: .bottom))
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: .black.opacity(0.45), radius: 10, y: 6)
                    .padding(10)
                    .transition(.opacity)
            } else {
                ShimmerBar()
                    .frame(width: 110, height: 6)
            }
            if isPending {
                Color.black.opacity(0.45)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
            }
        }
        .aspectRatio(16 / 10, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(.smooth(duration: 0.3), value: thumbnail != nil)
    }
}

/// An app's icon from the Mac, or a soft placeholder until it arrives.
struct AppIconView: View {
    let image: UIImage?
    var size: CGFloat = 32

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .fill(Color.white.opacity(0.1))
                    .overlay(Image(systemName: "macwindow").font(.system(size: size * 0.45, weight: .medium)).foregroundStyle(.white.opacity(0.8)))
                    .padding(size * 0.08)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct FilterChip: View {
    let title: String
    let icon: UIImage?
    let count: Int
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(uiImage: icon).resizable().scaledToFit().frame(width: 20, height: 20)
                }
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Text("\(count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isOn ? Theme.canvas.opacity(0.55) : Theme.textTertiary)
            }
            .foregroundStyle(isOn ? Theme.canvas : Theme.textSecondary)
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(
                Capsule().fill(Color.white.opacity(isOn ? 0.92 : 0.07))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(isOn ? 0 : 0.08)))
            )
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

private struct SearchField: View {
    @Binding var text: String
    var prompt = "Search windows"
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.textTertiary)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($focused)
                .submitLabel(.search)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.textTertiary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 46)
        .background(
            Capsule().fill(Color.white.opacity(focused ? 0.11 : 0.07))
                .overlay(Capsule().strokeBorder(focused ? Theme.accent.opacity(0.8) : Color.white.opacity(0.08), lineWidth: focused ? 1.5 : 1))
        )
        .animation(.smooth(duration: 0.2), value: focused)
    }
}

/// A faint moving highlight, for a card whose still hasn't arrived yet.
private struct ShimmerBar: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { proxy in
            Capsule().fill(Color.white.opacity(0.08))
                .overlay(
                    LinearGradient(colors: [.clear, .white.opacity(0.35), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: proxy.size.width * 0.6)
                        .offset(x: phase * proxy.size.width)
                )
                .clipShape(Capsule())
        }
        .onAppear {
            withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) { phase = 1.2 }
        }
        .accessibilityHidden(true)
    }
}

private struct EmptyWindowsView: View {
    var body: some View {
        VStack(spacing: 18) {
            GlowIcon(systemName: "macwindow.on.rectangle", size: 80)
            Text("No windows to show")
                .font(.display(24))
            Text("Open an app on your Mac. If it’s already open, allow Porthole Host under Screen & System Audio Recording in the Mac’s System Settings.")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
        }
        .padding(34)
        .glassCard(cornerRadius: 30)
        .padding(Theme.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Apps

enum PickerMode: Hashable {
    case windows, apps
}

/// Windows or Apps, as a small glass segmented control.
struct ModeToggle: View {
    @Binding var mode: PickerMode
    @Namespace private var selection

    var body: some View {
        HStack(spacing: 2) {
            segment("Windows", icon: "macwindow.on.rectangle", value: .windows)
            segment("Apps", icon: "square.grid.3x3.fill", value: .apps)
        }
        .padding(3)
        .background(Capsule().fill(Color.white.opacity(0.07)).overlay(Capsule().strokeBorder(Color.white.opacity(0.08))))
    }

    private func segment(_ title: String, icon: String, value: PickerMode) -> some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { mode = value }
        } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(mode == value ? Theme.canvas : Theme.textSecondary)
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background {
                    if mode == value {
                        Capsule().fill(Color.white.opacity(0.92)).matchedGeometryEffect(id: "segment", in: selection)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(mode == value ? .isSelected : [])
    }
}

/// The Mac's installed apps as icons, the open ones first. Tapping one opens it on the Mac and shows its window.
struct AppGrid: View {
    @EnvironmentObject private var client: ClientController
    var query: String
    var compact = false
    let onLaunch: (AppInfo) -> Void

    private var shown: [AppInfo] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        return needle.isEmpty ? client.apps : client.apps.filter { $0.name.localizedCaseInsensitiveContains(needle) }
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: compact ? 104 : 124, maximum: 160), spacing: compact ? 8 : 12)]
    }

    var body: some View {
        Group {
            if client.apps.isEmpty {
                VStack(spacing: 16) {
                    ProgressView().controlSize(.large).tint(.white)
                    Text("Looking for apps on your Mac…")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 30) {
                        let open = shown.filter(\.isRunning)
                        if query.isEmpty, !open.isEmpty {
                            section("Open now", apps: open)
                        }
                        if shown.isEmpty {
                            Text("No apps match “\(query)”")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        } else {
                            section(query.isEmpty ? "All apps" : "Results", apps: shown)
                        }
                    }
                    .padding(.horizontal, compact ? 20 : Theme.gutter)
                    .padding(.top, 6)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
                .refreshable { client.refreshApps() }
            }
        }
        .onAppear { client.refreshApps() }
    }

    private func section(_ title: String, apps: [AppInfo]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(Theme.textTertiary)
                .padding(.leading, 6)
            LazyVGrid(columns: columns, spacing: compact ? 6 : 10) {
                ForEach(apps) { app in
                    AppTile(app: app, icon: client.appIcons[app.bundleID], size: compact ? 62 : 72,
                            isLaunching: client.pendingLaunch?.bundleID == app.bundleID) {
                        onLaunch(app)
                    }
                    .disabled(client.pendingLaunch != nil)
                    .onAppear { client.wantIcon(for: app.bundleID) }
                }
            }
        }
    }
}

private struct AppTile: View {
    let app: AppInfo
    let icon: UIImage?
    var size: CGFloat = 72
    var isLaunching = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 9) {
                AppIconView(image: icon, size: size)
                    .shadow(color: .black.opacity(0.45), radius: 10, y: 6)
                    .overlay {
                        if isLaunching { ProgressView().tint(.white) }
                    }
                Text(app.name)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2, reservesSpace: true)
                // An open app gets a dot, as in the Dock.
                Circle()
                    .fill(app.isRunning ? Theme.textSecondary : .clear)
                    .frame(width: 4, height: 4)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(app.isRunning ? "\(app.name), open" : app.name)
        .accessibilityHint("Opens it on your Mac and shows its window")
    }
}

