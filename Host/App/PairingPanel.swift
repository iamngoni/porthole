import AppKit
import SwiftUI

/// The "Pair this device?" prompt. A floating panel rather than a modal alert, so the network
/// keeps running while it is up.
@MainActor
final class PairingPanel: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private var onAnswer: ((Bool) -> Void)?

    var isShowing: Bool { panel != nil }

    func show(deviceName: String, code: String, answer: @escaping (Bool) -> Void) {
        dismiss()
        onAnswer = answer
        let prompt = PairingPrompt(deviceName: deviceName, code: code) { [weak self] allowed in
            self?.finish(allowed)
        }
        let panel = NSPanel(contentRect: .zero, styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        panel.title = "Pair Device"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentViewController = NSHostingController(rootView: prompt)
        panel.delegate = self
        panel.center()
        self.panel = panel
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
    }

    /// Takes the prompt down without an answer, for when the device went away.
    func dismiss() {
        onAnswer = nil
        let panel = self.panel
        self.panel = nil
        panel?.delegate = nil
        panel?.close()
    }

    private func finish(_ allowed: Bool) {
        let answer = onAnswer
        dismiss()
        answer?(allowed)
    }

    func windowWillClose(_ notification: Notification) {
        // Closing the panel with its close button counts as Don't Allow.
        if panel != nil { finish(false) }
    }
}

private struct PairingPrompt: View {
    let deviceName: String
    let code: String
    let answer: (Bool) -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "ipad.and.iphone")
                .font(.system(size: 34))
                .foregroundStyle(.tint)
            Text("Pair “\(deviceName)” with this Mac?")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Check that \(deviceName) shows the same code:")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(Self.grouped(code))
                .font(.system(size: 36, weight: .semibold, design: .monospaced))
                .padding(.vertical, 4)
                .accessibilityLabel(code.map(String.init).joined(separator: " "))
            Text("A paired device can see and control the windows you share from this Mac. Only allow devices you own.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button("Don’t Allow") { answer(false) }
                    .keyboardShortcut(.cancelAction)
                // No default button: allowing a device takes a deliberate click, never a stray Return.
                Button("Allow") { answer(true) }
            }
            .controlSize(.large)
            .padding(.top, 4)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(width: 340)
    }

    static func grouped(_ code: String) -> String {
        guard code.count == 6 else { return code }
        return "\(code.prefix(3)) \(code.suffix(3))"
    }
}
