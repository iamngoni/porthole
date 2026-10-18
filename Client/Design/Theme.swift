import SwiftUI

/// Porthole's look: graphite, frosted glass and rounded type, with one quiet accent.
/// Color is kept for meaning: the accent marks what's selected or live, and the status colors
/// only ever appear small.
enum Theme {
    static let canvas = Color(red: 0.039, green: 0.041, blue: 0.047)
    static let surface = Color.white.opacity(0.05)
    static let surfaceRaised = Color.white.opacity(0.08)
    static let stroke = Color.white.opacity(0.09)

    static let textPrimary = Color.white.opacity(0.95)
    static let textSecondary = Color.white.opacity(0.6)
    static let textTertiary = Color.white.opacity(0.36)

    /// The one accent: focus, selection, what's on screen now.
    static let accent = Color(red: 0.47, green: 0.66, blue: 1.0)

    static let positive = Color(red: 0.42, green: 0.82, blue: 0.6)
    static let warning = Color(red: 0.98, green: 0.76, blue: 0.4)
    static let danger = Color(red: 1.0, green: 0.45, blue: 0.42)

    static let radius: CGFloat = 26
    static let gutter: CGFloat = 28
}

extension Font {
    /// Rounded display type for titles and numbers.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Background

/// Graphite with a soft light falling from above, drifting slowly enough to feel alive without being noticed.
struct Backdrop: View {
    var intensity: Double = 1
    @State private var drift = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                Theme.canvas
                Ellipse()
                    .fill(RadialGradient(colors: [Color.white.opacity(0.085 * intensity), .clear],
                                         center: .center, startRadius: 0, endRadius: size.width * 0.6))
                    .frame(width: size.width * 1.3, height: size.height * 0.8)
                    .offset(x: drift ? size.width * 0.06 : -size.width * 0.06, y: -size.height * 0.42)
                Ellipse()
                    .fill(RadialGradient(colors: [Theme.accent.opacity(0.05 * intensity), .clear],
                                         center: .center, startRadius: 0, endRadius: size.width * 0.5))
                    .frame(width: size.width, height: size.height * 0.7)
                    .offset(x: drift ? -size.width * 0.1 : size.width * 0.1, y: size.height * 0.35)
            }
            .frame(width: size.width, height: size.height)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 18).repeatForever(autoreverses: true)) { drift = true }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Glass

struct GlassBackground: View {
    var cornerRadius: CGFloat = Theme.radius
    var highlight = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(.ultraThinMaterial)
            .overlay(shape.fill(Theme.surface))
            .overlay(
                shape.strokeBorder(
                    LinearGradient(colors: [Color.white.opacity(highlight ? 0.24 : 0.13), Color.white.opacity(0.03)],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 24, y: 14)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = Theme.radius, highlight: Bool = false) -> some View {
        background(GlassBackground(cornerRadius: cornerRadius, highlight: highlight))
    }
}

// MARK: - Buttons

/// The one thing to do next: a solid white capsule.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.display(17, .semibold))
            .foregroundStyle(Theme.canvas)
            .padding(.horizontal, 26)
            .frame(minHeight: 54)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(Color.white.opacity(configuration.isPressed ? 0.82 : 0.95)))
            .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.textPrimary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.display(16, .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 22)
            .frame(minHeight: 50)
            .background(Capsule().fill(.ultraThinMaterial).overlay(Capsule().strokeBorder(Theme.stroke)))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Round glass button for toolbars. When on, it turns solid white.
struct IconButtonStyle: ButtonStyle {
    var size: CGFloat = 44
    var isOn = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(isOn ? Theme.canvas : Theme.textPrimary)
            .frame(width: size, height: size)
            .background(
                Circle().fill(isOn ? Color.white.opacity(0.92) : Color.white.opacity(configuration.isPressed ? 0.18 : 0.08))
            )
            .contentShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Whole cards that are tappable: they sink slightly under the finger.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .brightness(configuration.isPressed ? 0.03 : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

// MARK: - Small pieces

struct StatusDot: View {
    var color: Color
    var pulsing = false
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .overlay(
                Circle().stroke(color.opacity(pulsing ? 0.5 : 0), lineWidth: 1.5)
                    .scaleEffect(pulse ? 2.6 : 1)
                    .opacity(pulse ? 0 : 1)
            )
            .onAppear {
                guard pulsing else { return }
                withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { pulse = true }
            }
            .accessibilityHidden(true)
    }
}

struct Chip: View {
    var text: String
    var color: Color = Theme.textSecondary

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.13)))
    }
}

/// An icon in a frosted circle, for the top of a screen or a card.
struct GlowIcon: View {
    var systemName: String
    var size: CGFloat = 64
    var tint: Color = Theme.textPrimary

    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)], startPoint: .top, endPoint: .bottom))
            Circle().strokeBorder(LinearGradient(colors: [Color.white.opacity(0.22), Color.white.opacity(0.04)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
            Image(systemName: systemName)
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
