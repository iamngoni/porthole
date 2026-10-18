import SwiftUI

/// Both screens show a code; matching codes prove nobody is sitting between the two devices.
struct PairingCodeView: View {
    @EnvironmentObject private var client: ClientController
    let hostName: String
    let code: String

    var body: some View {
        ZStack {
            Backdrop(intensity: 0.9)
            VStack(spacing: 30) {
                GlowIcon(systemName: "lock.shield", size: 78)
                VStack(spacing: 10) {
                    Text("Pair with \(hostName)")
                        .font(.display(30))
                        .multilineTextAlignment(.center)
                    Text("Your Mac is showing a code too. Make sure it’s exactly this one.")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }
                CodeTiles(code: code)
                VStack(spacing: 12) {
                    Button("Codes Match", action: client.codesMatch)
                        .buttonStyle(PrimaryButtonStyle())
                    Button("They’re Different", action: client.codesDiffer)
                        .buttonStyle(SecondaryButtonStyle(tint: Theme.danger))
                }
                .frame(maxWidth: 360)
                Label("Matching codes prove you’re talking to your own Mac.", systemImage: "checkmark.shield")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(36)
            .frame(maxWidth: 560)
            .glassCard(cornerRadius: 36, highlight: true)
            .padding(Theme.gutter)
        }
    }
}

/// Six digits in two groups of three, each on its own lit tile.
private struct CodeTiles: View {
    let code: String
    @State private var shown = false

    var body: some View {
        let digits = Array(code)
        HStack(spacing: 10) {
            ForEach(Array(digits.enumerated()), id: \.offset) { index, digit in
                if index == 3 { Spacer().frame(width: 14) }
                Text(String(digit))
                    .font(.system(size: 46, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 60, height: 78)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.07))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1))
                    )
                    .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
                    .offset(y: shown ? 0 : 14)
                    .opacity(shown ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(Double(index) * 0.05), value: shown)
            }
        }
        .onAppear { shown = true }
        .accessibilityElement()
        .accessibilityLabel("Code \(code.map(String.init).joined(separator: " "))")
    }
}

struct WaitingForMacView: View {
    @EnvironmentObject private var client: ClientController
    let hostName: String

    var body: some View {
        ZStack {
            Backdrop(intensity: 0.8)
            VStack(spacing: 28) {
                ZStack {
                    RadarRings(size: 280)
                    PortholeMark(size: 92, isActive: true)
                }
                VStack(spacing: 10) {
                    Text("Click Allow on \(hostName)")
                        .font(.display(28))
                        .multilineTextAlignment(.center)
                    Text("Porthole Host is asking whether to pair with this iPad.")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                Button("Cancel", action: client.disconnect)
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(Theme.gutter)
        }
    }
}
