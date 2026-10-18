import SwiftUI

@main
struct PortholeHostApp: App {
    @StateObject private var host = HostController()

    var body: some Scene {
        MenuBarExtra {
            HostMenuView(host: host)
        } label: {
            // Shows at a glance that a device is connected, and more strongly while it is showing a window.
            Image(systemName: host.streaming != nil ? "rectangle.inset.filled.on.rectangle"
                  : host.clientName != nil ? "ipad.landscape" : "rectangle.on.rectangle")
        }
        .menuBarExtraStyle(.window)
    }
}

struct HostMenuView: View {
    @ObservedObject var host: HostController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Porthole")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                row("This Mac", host.hostName)
                row("Network", host.networkStatus)
                row("Device", host.clientName.map { "\($0) · \(host.connectionStatus)" } ?? host.connectionStatus)
                if let streaming = host.streaming {
                    row("Showing", streaming.title.isEmpty ? streaming.appName : "\(streaming.appName) — \(streaming.title)")
                    row("Video", "\(streaming.pixelSize.width) × \(streaming.pixelSize.height)"
                        + (streaming.framesPerSecond.map { ", up to \($0) fps" } ?? ""))
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        row("Control", controlStatus(at: context.date))
                    }
                }
            }

            if host.streaming != nil || host.clientName != nil {
                HStack {
                    if host.streaming != nil {
                        Button("Stop Showing", action: host.stopStreaming)
                    }
                    if host.clientName != nil {
                        Button("Disconnect", action: host.disconnectClient)
                    }
                }
            }

            if let notice = host.notice {
                HStack(alignment: .firstTextBaseline) {
                    Label(notice, systemImage: "info.circle")
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button {
                        host.notice = nil
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Dismiss")
                }
            }

            Divider()
            pairingSection

            if !host.screenRecordingAllowed {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Label("Screen Recording is off", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Porthole needs it to show your windows on another device. Turn it on, then reopen Porthole Host.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Open Screen Recording Settings", action: host.openScreenRecordingSettings)
                }
            }

            if !host.accessibilityAllowed {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Label("Accessibility is off", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Devices can watch windows but not click or type in them until Porthole Host is allowed under Accessibility.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Open Accessibility Settings", action: host.openAccessibilitySettings)
                }
            }

            Divider()
            Button("Quit Porthole Host") { NSApplication.shared.terminate(nil) }
        }
        .padding(14)
        .frame(width: 320)
        .onAppear(perform: host.refreshPermissions)
    }

    @ViewBuilder
    private var pairingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Paired Devices")
                .font(.subheadline.weight(.semibold))
            if host.pairedDevices.isEmpty {
                Text("None yet")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach(host.pairedDevices, id: \.pairID) { device in
                HStack {
                    Image(systemName: "ipad")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(device.deviceName)
                            .lineLimit(1)
                        Text("Paired \(device.pairedAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Remove") { host.removePairing(device) }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Remove \(device.deviceName)")
                }
                .font(.callout)
            }

            if let until = host.pairingOpenUntil {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let left = max(0, Int(until.timeIntervalSince(context.date).rounded(.up)))
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Open Porthole on your iPad or iPhone and choose this Mac · \(left / 60):\(String(format: "%02d", left % 60))")
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Button("Cancel", action: host.closePairing)
                    }
                }
            } else {
                Button("Pair New Device…", action: host.openPairing)
            }
        }
    }

    private func controlStatus(at date: Date) -> String {
        guard host.accessibilityAllowed else { return "View only (needs Accessibility)" }
        if let last = host.lastInputAt, date.timeIntervalSince(last) < 2 { return "Device is controlling" }
        return "Allowed"
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .lineLimit(2)
        }
        .font(.callout)
    }
}
