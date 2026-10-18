import SwiftUI

@main
struct PortholeApp: App {
    @StateObject private var client = ClientController()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(client)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var client: ClientController

    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()
            Group {
                switch client.phase {
                case .browsing:
                    HostListView()
                case .connecting(let hostName):
                    ConnectingView(hostName: hostName)
                case .comparingCode(let hostName, let code):
                    PairingCodeView(hostName: hostName, code: code)
                case .waitingForMac(let hostName):
                    WaitingForMacView(hostName: hostName)
                case .connected:
                    SessionView()
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.985)))

            if let problem = client.problem {
                ProblemOverlay(problem: problem)
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(.smooth(duration: 0.45), value: client.phase)
        .animation(.smooth(duration: 0.3), value: client.problem)
        .foregroundStyle(Theme.textPrimary)
    }
}

/// Connected: the window grid, or the window itself.
struct SessionView: View {
    @EnvironmentObject private var client: ClientController

    var body: some View {
        ZStack {
            if client.isShowingStream {
                StreamScreen()
                    .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 1.03)), removal: .opacity))
            } else {
                WindowPickerView()
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.4), value: client.isShowingStream)
    }
}

/// Reaching out to the Mac and setting up the secure connection.
struct ConnectingView: View {
    @EnvironmentObject private var client: ClientController
    let hostName: String

    var body: some View {
        ZStack {
            Backdrop(intensity: 0.8)
            VStack(spacing: 30) {
                ZStack {
                    RadarRings(size: 300)
                    PortholeMark(size: 96, isActive: true)
                }
                VStack(spacing: 10) {
                    Text("Connecting to \(hostName)")
                        .font(.display(28))
                        .multilineTextAlignment(.center)
                    Text("Setting up a private, encrypted connection")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
                Button("Cancel", action: client.disconnect)
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(Theme.gutter)
        }
    }
}

/// Replaces system alerts: a card over the current screen, with a way forward when there is one.
struct ProblemOverlay: View {
    @EnvironmentObject private var client: ClientController
    let problem: ClientController.Problem
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture(perform: dismiss)
            VStack(spacing: 22) {
                GlowIcon(systemName: problem.action == .pairAgain ? "lock.trianglebadge.exclamationmark" : "exclamationmark.triangle",
                         size: 68, tint: Theme.warning)
                Text(problem.text)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 12) {
                    switch problem.action {
                    case .tryAgain:
                        Button("Try Again") { client.retry(problem); client.problem = nil }
                            .buttonStyle(PrimaryButtonStyle())
                    case .pairAgain:
                        Button("Pair Again") { client.retry(problem); client.problem = nil }
                            .buttonStyle(PrimaryButtonStyle())
                    case nil:
                        EmptyView()
                    }
                    Button(problem.action == nil ? "OK" : "Not Now", action: dismiss)
                        .buttonStyle(SecondaryButtonStyle())
                }
            }
            .padding(30)
            .frame(maxWidth: 440)
            .glassCard(cornerRadius: 32, highlight: true)
            .padding(Theme.gutter)
            .scaleEffect(appeared ? 1 : 0.92)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) { appeared = true }
        }
    }

    private func dismiss() {
        client.problem = nil
    }
}
