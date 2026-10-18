import PortholeProtocol
import PortholeSession
import SwiftUI

/// The streamed window, edge to edge, with a small floating bar that tucks itself away.
struct StreamScreen: View {
    @EnvironmentObject private var client: ClientController
    @State private var showsKeyboard = false
    @State private var barOpen = true
    @State private var showsSwitcher = false
    @State private var zoom: CGFloat = 1
    @State private var zoomResetToken = 0
    @State private var tuckTask: Task<Void, Never>?

    private var window: WindowInfo? { client.streamedWindow }

    private var title: String {
        if let stream = client.stream { return stream.title.isEmpty ? stream.appName : stream.title }
        if let app = client.pendingLaunch { return app.name }
        guard let window else { return "" }
        return window.title.isEmpty ? window.appName : window.title
    }

    private var icon: UIImage? {
        client.icon(for: window?.bundleID ?? client.pendingLaunch?.bundleID)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            StreamSurface(track: client.videoTrack,
                          gen: client.stream?.gen,
                          videoSize: videoSize,
                          canControl: client.canControl,
                          showsKeyboard: $showsKeyboard,
                          zoomResetToken: zoomResetToken,
                          onZoomChange: { scale in DispatchQueue.main.async { zoom = scale } },
                          onInteraction: tuckBar,
                          send: client.sendInput)
                // Fill the screen, but move up for the on-screen keyboard instead of hiding the window under it.
                .ignoresSafeArea(.container, edges: .all)
                .opacity(client.stream == nil ? 0 : 1)

            if client.stream == nil {
                OpeningView(title: title, thumbnail: window.flatMap { client.thumbnails[$0.id] }, icon: icon)
                    .transition(.opacity)
            }

            VStack(spacing: 10) {
                controlBar
                if let reason = client.control?.reason, !client.canControl {
                    Label(reason, systemImage: "eye")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.warning)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .glassCard(cornerRadius: 20)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                if client.stream != nil, client.pendingWindowID != nil {
                    HStack(spacing: 10) {
                        ProgressView().tint(.white)
                        Text("Switching…")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .glassCard(cornerRadius: 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
            }
            .padding(.top, 10)
            .animation(.spring(response: 0.42, dampingFraction: 0.82), value: barOpen)
            .animation(.smooth(duration: 0.3), value: client.pendingWindowID)

            if showsSwitcher {
                WindowSwitcher(isShown: $showsSwitcher)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    .zIndex(5)
            }
        }
        .animation(.smooth(duration: 0.3), value: showsSwitcher)
        .animation(.smooth(duration: 0.4), value: client.stream == nil)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear(perform: scheduleTuck)
        .onChange(of: client.stream?.gen) { scheduleTuck() }
        .onDisappear { tuckTask?.cancel() }
    }

    private var videoSize: CGSize {
        guard let size = client.stream?.pixelSize else { return .zero }
        return CGSize(width: size.width, height: size.height)
    }

    // MARK: Control bar

    @ViewBuilder
    private var controlBar: some View {
        if barOpen {
            HStack(spacing: 8) {
                Button(action: client.stopStream) {
                    Image(systemName: "square.grid.2x2")
                }
                .buttonStyle(IconButtonStyle(size: 42))
                .accessibilityLabel("All Windows")

                HStack(spacing: 10) {
                    AppIconView(image: icon, size: 28)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.display(15, .semibold))
                            .lineLimit(1)
                        if let app = window?.appName, app != title {
                            Text(app)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.textTertiary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: 260, alignment: .leading)
                }
                .padding(.horizontal, 8)

                divider

                Button {
                    showsKeyboard.toggle()
                    keepBarOpen()
                } label: {
                    Image(systemName: showsKeyboard ? "keyboard.chevron.compact.down" : "keyboard")
                }
                .buttonStyle(IconButtonStyle(size: 42, isOn: showsKeyboard))
                .disabled(!client.canControl || client.stream == nil)
                .accessibilityLabel(showsKeyboard ? "Hide Keyboard" : "Show Keyboard")

                Button {
                    showsSwitcher = true
                    keepBarOpen()
                } label: {
                    Image(systemName: "rectangle.on.rectangle")
                }
                .buttonStyle(IconButtonStyle(size: 42))
                .accessibilityLabel("Switch Window")

                if zoom > 1.01 {
                    Button {
                        zoomResetToken += 1
                        keepBarOpen()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                            Text(String(format: "%.1f×", zoom)).monospacedDigit()
                        }
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .padding(.horizontal, 12)
                        .frame(height: 42)
                        .background(Capsule().fill(Color.white.opacity(0.1)))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("Zoom to Fit")
                    .transition(.scale.combined(with: .opacity))
                }

                divider

                Button(action: client.disconnect) {
                    Image(systemName: "power")
                }
                .buttonStyle(IconButtonStyle(size: 42))
                .accessibilityLabel("Disconnect")

                Button {
                    barOpen = false
                } label: {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(IconButtonStyle(size: 36))
                .accessibilityLabel("Hide Controls")
            }
            .padding(6)
            .background(Capsule().fill(.ultraThinMaterial).overlay(Capsule().fill(Theme.canvas.opacity(0.45))))
            .overlay(Capsule().strokeBorder(LinearGradient(colors: [.white.opacity(0.28), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom)))
            .shadow(color: .black.opacity(0.5), radius: 22, y: 10)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: zoom > 1.01)
            .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9, anchor: .top)))
        } else {
            Button {
                barOpen = true
                scheduleTuck()
            } label: {
                HStack(spacing: 7) {
                    AppIconView(image: icon, size: 18)
                    Capsule().fill(Color.white.opacity(0.75)).frame(width: 26, height: 4)
                }
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(Capsule().fill(.ultraThinMaterial).overlay(Capsule().fill(Theme.canvas.opacity(0.4))))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.14)))
                .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
                .padding(8)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Show Controls")
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var divider: some View {
        Capsule().fill(Color.white.opacity(0.12)).frame(width: 1, height: 26)
    }

    /// Using the window tucks the bar away so it doesn't cover anything.
    private func tuckBar() {
        tuckTask?.cancel()
        if barOpen, !showsKeyboard { barOpen = false }
    }

    private func keepBarOpen() {
        scheduleTuck()
    }

    private func scheduleTuck() {
        tuckTask?.cancel()
        tuckTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled, !showsSwitcher else { return }
            barOpen = false
        }
    }
}

/// While the first frame is on its way: the window's last still, softly blurred, with the mark turning.
private struct OpeningView: View {
    let title: String
    let thumbnail: UIImage?
    let icon: UIImage?

    var body: some View {
        ZStack {
            Backdrop(intensity: 0.6)
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .blur(radius: 18)
                    .opacity(0.35)
                    .padding(60)
            }
            VStack(spacing: 22) {
                ZStack {
                    RadarRings(size: 240)
                    PortholeMark(size: 84, isActive: true)
                }
                .frame(height: 200)
                HStack(spacing: 12) {
                    AppIconView(image: icon, size: 34)
                    Text("Opening \(title.isEmpty ? "window" : title)")
                        .font(.display(22))
                        .lineLimit(1)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .glassCard(cornerRadius: 22)
            }
            .padding(Theme.gutter)
        }
        .ignoresSafeArea()
    }
}

/// Every window on the Mac, over the stream, to jump to another one.
private struct WindowSwitcher: View {
    @EnvironmentObject private var client: ClientController
    @Binding var isShown: Bool
    @State private var app: String?
    @State private var mode = PickerMode.windows

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { isShown = false }
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(mode == .windows ? "Switch window" : "Open an app")
                            .font(.display(24, .heavy))
                        Text(mode == .windows ? "Pick any window on your Mac" : "It opens on your Mac and shows up here")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    ModeToggle(mode: $mode)
                    Button {
                        isShown = false
                        client.stopStream()
                    } label: {
                        Label("All Windows", systemImage: "square.grid.2x2")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    Button {
                        isShown = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(IconButtonStyle(size: 44))
                    .accessibilityLabel("Close")
                }
                .padding(.horizontal, 22)
                .padding(.top, 22)
                .padding(.bottom, 16)
                switch mode {
                case .windows:
                    WindowGrid(query: "", app: $app, compact: true) { window in
                        isShown = false
                        guard window.id != client.stream?.windowID else { return }
                        client.select(window)
                    }
                case .apps:
                    AppGrid(query: "", compact: true) { app in
                        isShown = false
                        client.launch(app)
                    }
                }
            }
            .frame(maxWidth: 980, maxHeight: 720)
            .glassCard(cornerRadius: 34, highlight: true)
            .padding(.horizontal, 24)
            .padding(.vertical, 40)
        }
        .onAppear { client.setPreviewsVisible(true) }
        .onDisappear { client.setPreviewsVisible(false) }
    }
}
