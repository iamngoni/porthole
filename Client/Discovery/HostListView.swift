import PortholeProtocol
import PortholeSession
import SwiftUI

/// Home: the Macs running Porthole Host nearby, and the ones this device is paired with.
struct HostListView: View {
    @EnvironmentObject private var client: ClientController

    private var away: [PairedHost] {
        client.pairedHosts.filter { paired in !client.hosts.contains { client.savedPairing(for: $0) == paired } }
    }

    var body: some View {
        ZStack {
            Backdrop()
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 44) {
                        hero
                        if client.hosts.isEmpty {
                            SearchingCard(status: client.browseStatus)
                        } else {
                            section("Nearby", count: client.hosts.count) {
                                ForEach(client.hosts) { host in
                                    MacCard(host: host, pairing: client.savedPairing(for: host))
                                }
                            }
                        }
                        if !away.isEmpty {
                            section("Paired, not nearby", count: away.count) {
                                ForEach(away, id: \.hostID) { paired in
                                    AwayMacCard(host: paired)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Theme.gutter)
                    .padding(.vertical, 56)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                    .animation(.smooth(duration: 0.4), value: client.hosts.map(\.id))
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 18) {
            ZStack {
                RadarRings(size: 300, color: client.browseStatus == .localNetworkDenied ? Theme.warning : .white)
                    .opacity(client.hosts.isEmpty ? 1 : 0.45)
                PortholeMark(size: 112, isActive: client.hosts.isEmpty)
            }
            .frame(height: 170)
            VStack(spacing: 8) {
                Text("Porthole")
                    .font(.display(54, .heavy))
                    .foregroundStyle(LinearGradient(colors: [.white, .white.opacity(0.72)], startPoint: .top, endPoint: .bottom))
                Text("Your Mac’s windows, right here.")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private func section<Content: View>(_ title: String, count: Int, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text(title.uppercased())
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(Theme.textTertiary)
                Text("\(count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
            }
            .padding(.leading, 6)
            VStack(spacing: 14, content: content)
        }
    }
}

private struct MacCard: View {
    @EnvironmentObject private var client: ClientController
    let host: DiscoveredHost
    let pairing: PairedHost?

    var body: some View {
        Button {
            client.connect(to: host)
        } label: {
            HStack(spacing: 18) {
                GlowIcon(systemName: "macbook", size: 72)
                VStack(alignment: .leading, spacing: 7) {
                    Text(host.name)
                        .font(.display(21, .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(Theme.textPrimary)
                    HStack(spacing: 7) {
                        StatusDot(color: pairing == nil ? Theme.warning : Theme.positive)
                        Text(pairing == nil ? "New · Tap to pair" : "Paired · Ready")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(pairing == nil ? Theme.textPrimary : Theme.canvas)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white.opacity(pairing == nil ? 0.08 : 0.92)))
            }
            .padding(22)
            .glassCard(highlight: pairing != nil)
            .contentShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .contextMenu {
            if let pairing {
                Button("Pair Again", systemImage: "arrow.triangle.2.circlepath") { client.connect(to: host, pairAgain: true) }
                Button("Forget This Mac", systemImage: "trash", role: .destructive) { client.forget(pairing) }
            }
        }
        .accessibilityHint(pairing == nil ? "Pairs with this Mac" : "Connects to this Mac")
    }
}

private struct AwayMacCard: View {
    @EnvironmentObject private var client: ClientController
    let host: PairedHost

    var body: some View {
        HStack(spacing: 16) {
            GlowIcon(systemName: "macbook", size: 50, tint: Theme.textTertiary)
            VStack(alignment: .leading, spacing: 4) {
                Text(host.hostName)
                    .font(.display(17, .semibold))
                    .lineLimit(1)
                Text("Not on this network")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
            Menu {
                Button("Forget This Mac", systemImage: "trash", role: .destructive) { client.forget(host) }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.06)))
            }
            .foregroundStyle(Theme.textSecondary)
            .accessibilityLabel("More for \(host.hostName)")
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
        .opacity(0.8)
    }
}

/// Nothing found yet: what's happening, and what to check.
private struct SearchingCard: View {
    let status: BrowseStatus

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 10) {
                Text(status == .localNetworkDenied ? "Porthole can’t see your network" : "Looking for your Mac…")
                    .font(.display(26))
                    .multilineTextAlignment(.center)
                Text(hint)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }
            if status == .localNetworkDenied, let settings = URL(string: UIApplication.openSettingsURLString) {
                Link(destination: settings) {
                    Label("Open Settings", systemImage: "gear")
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 280)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    tip("1", "Open Porthole Host on your Mac.")
                    tip("2", "Keep both on the same Wi-Fi.")
                    tip("3", "New here? Choose Pair New Device in the Mac’s menu bar.")
                }
                .padding(20)
                .frame(maxWidth: 460, alignment: .leading)
                .glassCard(cornerRadius: 22)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var hint: String {
        switch status {
        case .localNetworkDenied:
            "Turn on Local Network for Porthole in Settings so it can find your Mac."
        case .problem(let detail):
            "Can’t search the network right now (\(detail)). Trying again…"
        case .starting, .searching:
            "Macs running Porthole Host show up here on their own."
        }
    }

    private func tip(_ number: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(number)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.canvas)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.white.opacity(0.9)))
            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
