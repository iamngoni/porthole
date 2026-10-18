import SwiftUI

/// The Porthole logo: a brushed-metal ring around a small window, like looking through a ship's porthole at your Mac.
struct PortholeMark: View {
    var size: CGFloat = 56
    /// Turns the ring's sheen slowly, for moments when something is happening.
    var isActive = false
    @State private var angle = Angle.zero

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(white: 0.13), Theme.canvas], center: .center, startRadius: 0, endRadius: size / 2))
            Circle()
                .strokeBorder(
                    AngularGradient(colors: [.white.opacity(0.95), .white.opacity(0.3), .white.opacity(0.75), .white.opacity(0.22), .white.opacity(0.95)],
                                    center: .center, angle: angle),
                    lineWidth: size * 0.075)
            Circle()
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                .padding(size * 0.11)
            window
            // A glint across the glass.
            Circle()
                .trim(from: 0.58, to: 0.7)
                .stroke(Color.white.opacity(0.45), style: StrokeStyle(lineWidth: size * 0.03, lineCap: .round))
                .padding(size * 0.2)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.5), radius: size * 0.18, y: size * 0.06)
        .onAppear(perform: spinIfActive)
        .onChange(of: isActive) { spinIfActive() }
        .accessibilityHidden(true)
    }

    private var window: some View {
        let width = size * 0.4
        let height = size * 0.3
        return VStack(spacing: 0) {
            HStack(spacing: size * 0.022) {
                ForEach([0.75, 0.5, 0.35], id: \.self) { opacity in
                    Circle().fill(Color.white.opacity(opacity)).frame(width: size * 0.033, height: size * 0.033)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, size * 0.03)
            .frame(height: height * 0.26)
            .background(Color.white.opacity(0.16))
            LinearGradient(colors: [Theme.accent.opacity(0.85), Theme.accent.opacity(0.45)], startPoint: .top, endPoint: .bottom)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.05, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: size * 0.05, style: .continuous).strokeBorder(Color.white.opacity(0.3), lineWidth: 0.75))
    }

    private func spinIfActive() {
        if isActive {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) { angle = .degrees(360) }
        } else {
            withAnimation(.easeOut(duration: 0.6)) { angle = .zero }
        }
    }
}

/// Rings rippling out from the logo while Porthole looks for, or reaches out to, a Mac.
struct RadarRings: View {
    var size: CGFloat = 220
    var color: Color = .white
    @State private var expand = false

    var body: some View {
        ZStack {
            ForEach(0..<3) { index in
                Circle()
                    .stroke(color.opacity(0.22), lineWidth: 1)
                    .scaleEffect(expand ? 1 : 0.3)
                    .opacity(expand ? 0 : 0.9)
                    .animation(.easeOut(duration: 3.2).repeatForever(autoreverses: false).delay(Double(index) * 1.05), value: expand)
            }
        }
        .frame(width: size, height: size)
        .onAppear { expand = true }
        .accessibilityHidden(true)
    }
}
