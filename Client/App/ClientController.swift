import Combine
import os
import PortholeProtocol
import PortholeSession
import UIKit

/// Runs the iPad/iPhone side: finds Macs, pairs with them, connects to one, and shows and controls
/// the window the user picks.
@MainActor
final class ClientController: ObservableObject {
    enum Phase: Equatable {
        case browsing
        case connecting(hostName: String)
        /// Both screens show a code; the person checks they match.
        case comparingCode(hostName: String, code: String)
        /// The codes matched here; waiting for Allow on the Mac.
        case waitingForMac(hostName: String)
        case connected(hostName: String)
    }

    /// Something to tell the user, maybe with a way forward.
    struct Problem: Identifiable, Equatable {
        enum Action: Equatable {
            case tryAgain, pairAgain
        }

        let id = UUID()
        var text: String
        var action: Action?
        var host: DiscoveredHost?
    }

    @Published private(set) var phase: Phase = .browsing
    @Published private(set) var hosts: [DiscoveredHost] = []
    @Published private(set) var pairedHosts: [PairedHost] = []
    @Published private(set) var browseStatus: BrowseStatus = .starting
    @Published private(set) var windows: [WindowInfo] = []
    @Published private(set) var stream: StreamInfo?
    @Published private(set) var pendingWindowID: UInt32?
    @Published private(set) var videoTrack: RTCVideoTrack?
    /// Whether the Mac accepts clicks and typing. Nil until it says.
    @Published private(set) var control: ControlStatus?
    /// Stills of the Mac's windows and the icons of their apps, for the window grid.
    @Published private(set) var thumbnails: [UInt32: UIImage] = [:]
    @Published private(set) var appIcons: [String: UIImage] = [:]
    /// The Mac's installed apps, once asked for.
    @Published private(set) var apps: [AppInfo] = []
    /// An app the Mac is opening; its window streams as soon as it appears.
    @Published private(set) var pendingLaunch: AppInfo?
    @Published var problem: Problem?

    var isShowingStream: Bool { stream != nil || pendingWindowID != nil || pendingLaunch != nil }
    var canControl: Bool { control?.allowed ?? true }

    private static let log = Logger(subsystem: "dev.iamngoni.porthole", category: "client")

    private let browser = HostBrowser()
    private let store = PairingStores.pairedHosts()
    private let deviceID = InstallationID.current(key: "porthole.deviceID")
    private var signaling: SignalingConnection?
    private var link: DeviceLink?
    private var peer: PeerSession?
    private var currentHost: DiscoveredHost?
    private var pingTimer: Timer?
    private var pingCounter: UInt64 = 0
    private var previewTimer: Timer?
    private var previewViewers = 0
    private var requestedIcons: Set<String> = []
    private var wantedIcons: Set<String> = []

    /// Thumbnails are this many pixels on the long side: sharp on a card two-fifths of an iPad wide.
    static let thumbnailLongSide = 720

    init() {
        browser.onChange = { [weak self] in self?.hosts = $0 }
        browser.onStatusChange = { [weak self] in self?.browseStatus = $0 }
        #if DEBUG
        // `-preview <screen>` at launch shows a screen filled with sample data, without touching the network.
        if let screen = UserDefaults.standard.string(forKey: "preview") {
            loadPreview(screen)
            return
        }
        #endif
        browser.start()
        reloadPairedHosts()
    }

    // MARK: User actions

    /// The pairing for `host`, by the ID in its Bonjour record and never by name. Another Mac can copy the
    /// ID too, but then it can't finish the handshake without the secret.
    func savedPairing(for host: DiscoveredHost) -> PairedHost? {
        guard let hostID = host.hostID else { return nil }
        return pairedHosts.first { $0.hostID == hostID }
    }

    /// Connects, reusing the saved pairing unless `pairAgain` asks for a fresh one.
    func connect(to host: DiscoveredHost, pairAgain: Bool = false) {
        teardown()
        guard host.hostID != nil else {
            // Every Porthole Host advertises its ID. Pairing holds the Mac to it, so without one a Mac
            // could claim another's ID and take over that Mac's saved pairing.
            fail(Problem(text: "Couldn’t read \(host.name)’s details. Check that Porthole Host is up to date, then try again.",
                         action: .tryAgain, host: host))
            return
        }
        currentHost = host
        phase = .connecting(hostName: host.name)
        link = DeviceLink(deviceID: deviceID, deviceName: UIDevice.current.name,
                          pairing: pairAgain ? nil : savedPairing(for: host), expectedHostID: host.hostID)
        let connection = SignalingConnection(endpoint: host.endpoint)
        signaling = connection
        connection.onEvent = { [weak self, weak connection] event in
            guard let self, let connection, connection === self.signaling else { return }
            self.handle(event)
        }
        connection.start()
    }

    func retry(_ problem: Problem) {
        guard let host = problem.host else { return }
        // Use the latest Bonjour result in case the Mac's address changed.
        let latest = hosts.first { $0.name == host.name } ?? host
        connect(to: latest, pairAgain: problem.action == .pairAgain)
    }

    func codesMatch() {
        guard case .comparingCode(let hostName, _) = phase else { return }
        phase = .waitingForMac(hostName: hostName)
        apply(link?.codesMatch() ?? [])
    }

    func codesDiffer() {
        apply(link?.codesDiffer() ?? [])
    }

    func disconnect() {
        signaling?.close(.disconnected)
        teardown()
    }

    func forget(_ host: PairedHost) {
        try? store.remove(host.hostID)
        reloadPairedHosts()
    }

    func select(_ window: WindowInfo) {
        pendingLaunch = nil
        pendingWindowID = window.id
        sendControl(.releaseAll)
        sendControl(.select(windowID: window.id))
    }

    func stopStream() {
        guard isShowingStream else { return }
        stream = nil
        pendingWindowID = nil
        pendingLaunch = nil
        sendControl(.releaseAll)
        sendControl(.stopStream)
    }

    func refreshApps() {
        sendControl(.listApps)
    }

    /// Opens an app on the Mac and shows its window when it appears.
    func launch(_ app: AppInfo) {
        pendingWindowID = nil
        pendingLaunch = app
        sendControl(.releaseAll)
        sendControl(.launch(bundleID: app.bundleID))
    }

    /// App tiles call this as they come on screen, so a long list only fetches the icons someone sees.
    func wantIcon(for bundleID: String) {
        guard !requestedIcons.contains(bundleID), appIcons[bundleID] == nil else { return }
        let isFirst = wantedIcons.isEmpty
        wantedIcons.insert(bundleID)
        guard isFirst else { return }
        // Gather the tiles that appear together into one request.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let batch = self.wantedIcons.subtracting(self.requestedIcons)
            self.wantedIcons = []
            self.requestedIcons.formUnion(batch)
            for start in stride(from: 0, to: batch.count, by: 40) {
                self.sendControl(.appIcons(bundleIDs: Array(batch.sorted()[start..<min(start + 40, batch.count)])))
            }
        }
    }

    func refreshWindows() {
        sendControl(.listWindows)
        requestPreviews()
    }

    var streamedWindow: WindowInfo? {
        guard let id = stream?.windowID ?? pendingWindowID else { return nil }
        return windows.first { $0.id == id }
    }

    func icon(for bundleID: String?) -> UIImage? {
        bundleID.flatMap { appIcons[$0] }
    }

    /// Window grids call this while on screen, so thumbnails stay fresh only while someone is looking.
    func setPreviewsVisible(_ visible: Bool) {
        previewViewers = max(0, previewViewers + (visible ? 1 : -1))
        if previewViewers > 0, previewTimer == nil {
            requestPreviews()
            previewTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.requestPreviews() }
            }
        } else if previewViewers == 0 {
            previewTimer?.invalidate()
            previewTimer = nil
        }
    }

    private func requestPreviews() {
        guard !windows.isEmpty else { return }
        sendControl(.thumbnails(windowIDs: windows.map(\.id), maxLongSide: Self.thumbnailLongSide))
        let missing = Set(windows.compactMap(\.bundleID)).subtracting(requestedIcons)
        if !missing.isEmpty {
            requestedIcons.formUnion(missing)
            sendControl(.appIcons(bundleIDs: missing.sorted()))
        }
    }

    /// Input from the stream view. The view stamps each event with the stream it was aimed at.
    func sendInput(_ message: ClientMessage) {
        guard canControl else { return }
        sendControl(message)
    }

    // MARK: Signaling

    private var hostName: String { currentHost?.name ?? "the Mac" }

    private func handle(_ event: SignalingConnection.Event) {
        switch event {
        case .ready:
            apply(link?.start() ?? [])
        case .message(let message):
            apply(link?.receive(message) ?? [])
        case .incompatible:
            fail(Problem(text: "\(hostName) runs a different version of Porthole. Update the apps on both devices."))
        case .closed(let error):
            Self.log.info("signaling closed: \(error?.localizedDescription ?? "normally", privacy: .public)")
            if phase != .browsing {
                fail(Problem(text: "Lost the connection to \(hostName).", action: .tryAgain, host: currentHost))
            }
        }
    }

    private func apply(_ outputs: [DeviceLink.Output]) {
        for output in outputs {
            guard signaling != nil else { return }
            switch output {
            case .send(let message):
                signaling?.send(message)
            case .showCode(let code):
                phase = .comparingCode(hostName: hostName, code: code)
            case .paired(let host):
                save(host)
            case .established:
                phase = .connecting(hostName: hostName)
                send(.hello(ClientHello(deviceName: UIDevice.current.name, viewport: Self.screenPixels(),
                                        maxFramesPerSecond: Self.screenRefreshRate())))
            case .deliver(let message):
                handle(message)
            case .close(let reason):
                signaling?.close(reason)
                fail(problem(for: reason, saidByMac: false))
            case .peerClosed(let reason):
                fail(problem(for: CloseReason(rawValue: reason), saidByMac: true))
            }
        }
    }

    private func problem(for reason: CloseReason?, saidByMac: Bool) -> Problem {
        let name = hostName
        let host = currentHost
        switch reason {
        case .pairingClosed:
            return Problem(text: "\(name) isn’t accepting new devices right now. On the Mac, click the Porthole icon in the menu bar, choose Pair New Device, then try again.", action: .tryAgain, host: host)
        case .pairingDenied:
            return Problem(text: "Pairing was declined on \(name).")
        case .pairingFailed where !saidByMac:
            return Problem(text: "Pairing stopped. If the codes didn’t match, another device on this network may be pretending to be \(name). Try again, and if it keeps happening, pair on a network you trust.", action: .tryAgain, host: host)
        case .pairingFailed:
            return Problem(text: "Pairing with \(name) didn’t finish.", action: .tryAgain, host: host)
        case .pairingContested:
            return Problem(text: "Another device tried to pair with \(name) at the same time, so the Mac stopped pairing. Check the Mac, then try again.", action: .tryAgain, host: host)
        // Reasons that arrive before the session is up aren't authenticated, so these say what to check
        // on the Mac rather than taking anyone's word for it.
        case .unknownPairing:
            return Problem(text: "\(name) didn’t recognize this device. If you removed it in the Porthole menu on the Mac, pair again.", action: .pairAgain, host: host)
        case .handshakeFailed:
            return Problem(text: "Couldn’t confirm this is your \(name). If you paired this device again on the Mac, pair again here too. Otherwise, another device may be pretending to be your Mac.", action: .pairAgain, host: host)
        case .replaced:
            return Problem(text: "Another device connected to \(name).", action: .tryAgain, host: host)
        case .disconnected:
            return Problem(text: "\(name) ended the session.")
        case .hostStopped:
            return Problem(text: "Porthole Host quit on \(name).")
        case .versionMismatch:
            return Problem(text: "\(name) runs a different version of Porthole. Update the apps on both devices.")
        case .timedOut:
            return Problem(text: "\(name) didn’t respond in time.", action: .tryAgain, host: host)
        case .badFrame, .unexpectedMessage, nil:
            return Problem(text: "The connection to \(name) was interrupted.", action: .tryAgain, host: host)
        }
    }

    private func save(_ host: PairedHost) {
        var host = host
        host.hostName = DisplayName.clean(host.hostName, fallback: "Mac")
        do {
            try store.save(host, for: host.hostID)
        } catch {
            Self.log.error("could not save pairing: \(String(describing: error), privacy: .public)")
        }
        reloadPairedHosts()
    }

    private func reloadPairedHosts() {
        pairedHosts = store.all()
    }

    private func send(_ message: SignalMessage) {
        guard let wire = try? link?.seal(message) else { return }
        signaling?.send(wire)
    }

    private func handle(_ message: SignalMessage) {
        switch message {
        case .offer(let sdp):
            let peer = self.peer ?? makePeer()
            Task {
                do {
                    let answer = try await peer.acceptOffer(sdp)
                    guard peer === self.peer else { return }
                    send(.answer(sdp: answer))
                } catch {
                    // A bye or a cancel may have closed this peer meanwhile; keep that reason.
                    guard peer === self.peer else { return }
                    fail(Problem(text: "Could not set up the video connection: \(error.localizedDescription)", action: .tryAgain, host: currentHost))
                }
            }
        case .candidate(let candidate):
            peer?.addRemoteCandidate(candidate)
        case .welcome, .hello, .answer:
            break
        }
    }

    private func makePeer() -> PeerSession {
        let peer = PeerSession(role: .client)
        self.peer = peer
        let hostName = self.hostName
        peer.onLocalCandidate = { [weak self] candidate in
            self?.send(.candidate(candidate))
        }
        peer.onConnectionStateChange = { [weak self, weak peer] state in
            guard let self, let peer, peer === self.peer else { return }
            switch state {
            case .connected:
                self.phase = .connected(hostName: hostName)
                UIApplication.shared.isIdleTimerDisabled = true
            case .failed:
                self.fail(Problem(text: "The connection to \(hostName) failed.", action: .tryAgain, host: self.currentHost))
            default:
                break
            }
        }
        peer.onControlOpen = { [weak self] in
            self?.sendControl(.listWindows)
            self?.startPinging()
        }
        peer.onControlMessage = { [weak self] data in
            self?.handleControl(data)
        }
        peer.onRemoteVideoTrack = { [weak self] track in
            self?.videoTrack = track
        }
        return peer
    }

    // MARK: Control channel

    private func handleControl(_ data: Data) {
        guard let hostMessage = try? MessageCoding.decode(HostMessage.self, from: data) else {
            Self.log.error("ignoring unreadable control message")
            return
        }
        switch hostMessage {
        case .windows(let windows):
            let isFirst = self.windows.isEmpty
            self.windows = windows
            let alive = Set(windows.map(\.id))
            thumbnails = thumbnails.filter { alive.contains($0.key) }
            if previewViewers > 0 || isFirst { requestPreviews() }
        case .streamStarted(let info):
            guard pendingWindowID == info.windowID || pendingLaunch != nil || stream != nil else {
                // The user backed out while it was starting; make sure the Mac stops too.
                sendControl(.stopStream)
                return
            }
            stream = info
            pendingWindowID = nil
            pendingLaunch = nil
        case .geometry(let info):
            if info.gen == stream?.gen { stream = info }
        case .streamState(let gen, let state):
            if gen == stream?.gen, state == .closed {
                stream = nil
                problem = Problem(text: "The window was closed on the Mac.")
            }
        case .error(_, let text):
            pendingWindowID = nil
            pendingLaunch = nil
            problem = Problem(text: text)
        case .control(let status):
            control = status
        case .thumbnail(let windowID, let jpeg):
            guard windows.contains(where: { $0.id == windowID }), let image = UIImage(data: jpeg) else { return }
            thumbnails[windowID] = image
        case .appIcon(let bundleID, let png):
            if let image = UIImage(data: png) { appIcons[bundleID] = image }
        case .apps(let apps):
            self.apps = apps
        case .pong:
            break
        }
    }

    private func sendControl(_ message: ClientMessage) {
        guard let data = try? MessageCoding.encode(message) else { return }
        peer?.sendControl(data)
    }

    /// A heartbeat: if it stops, the Mac lets go of any keys or buttons this device was holding.
    private func startPinging() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.pingCounter &+= 1
                self.sendControl(.ping(self.pingCounter))
            }
        }
    }

    // MARK: Helpers

    private func fail(_ problem: Problem) {
        teardown()
        self.problem = problem
    }

    private func teardown() {
        pingTimer?.invalidate()
        pingTimer = nil
        previewTimer?.invalidate()
        previewTimer = nil
        previewViewers = 0
        thumbnails = [:]
        appIcons = [:]
        requestedIcons = []
        wantedIcons = []
        apps = []
        pendingLaunch = nil
        peer?.close()
        peer = nil
        link = nil
        signaling?.onEvent = nil
        signaling?.close()
        signaling = nil
        phase = .browsing
        windows = []
        stream = nil
        pendingWindowID = nil
        videoTrack = nil
        control = nil
        UIApplication.shared.isIdleTimerDisabled = false
    }

    /// 120 on ProMotion screens, 60 elsewhere.
    private static func screenRefreshRate() -> Int {
        UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.screen }.first?.maximumFramesPerSecond ?? 60
    }

    private static func screenPixels() -> PixelSize {
        let screen = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.screen }.first
        guard let size = screen?.nativeBounds.size else { return PixelSize(width: 2752, height: 2064) }
        return PixelSize(width: Int(size.width), height: Int(size.height))
    }
}

#if DEBUG
// MARK: - Design previews

extension ClientController {
    /// Sample state for checking layouts in the simulator. Debug builds only.
    fileprivate func loadPreview(_ screen: String) {
        let host = "Ngonidzashe’s MacBook Pro"
        let samples: [(String, String, String, Bool, UIColor)] = [
            ("Porthole — Apple Developer Documentation", "Safari", "com.apple.Safari", true, .white),
            ("Porthole — StreamView.swift", "Xcode", "com.apple.dt.Xcode", true, UIColor(white: 0.16, alpha: 1)),
            ("Release checklist", "Notes", "com.apple.Notes", true, UIColor(red: 1, green: 0.98, blue: 0.9, alpha: 1)),
            ("Downloads", "Finder", "com.apple.finder", false, UIColor(white: 0.95, alpha: 1)),
            ("zsh — 120×36", "Terminal", "com.apple.Terminal", true, UIColor(white: 0.08, alpha: 1)),
        ]
        windows = samples.enumerated().map { index, sample in
            WindowInfo(id: UInt32(index + 1), title: sample.0, appName: sample.1, bundleID: sample.2, pid: Int32(100 + index),
                       size: PointSize(width: 1280, height: 800), isOnScreen: sample.3)
        }
        thumbnails = Dictionary(uniqueKeysWithValues: samples.enumerated().map { index, sample in
            (UInt32(index + 1), Self.sampleWindow(background: sample.4, seed: index))
        })
        // `-previewIcons <folder>` points at PNGs named by bundle ID, rendered on a Mac the way Porthole Host does.
        if let folder = UserDefaults.standard.string(forKey: "previewIcons") {
            for sample in samples {
                appIcons[sample.2] = UIImage(contentsOfFile: "\(folder)/\(sample.2).png")
            }
        }
        apps = [("Activity Monitor", "com.apple.ActivityMonitor"), ("App Store", "com.apple.AppStore"), ("Calendar", "com.apple.iCal"),
                ("Finder", "com.apple.finder"), ("Maps", "com.apple.Maps"), ("Music", "com.apple.Music"), ("Notes", "com.apple.Notes"),
                ("Photos", "com.apple.Photos"), ("Safari", "com.apple.Safari"), ("System Settings", "com.apple.systempreferences"),
                ("Terminal", "com.apple.Terminal"), ("Xcode", "com.apple.dt.Xcode")]
            .map { name, bundleID in AppInfo(bundleID: bundleID, name: name, isRunning: samples.contains { $0.2 == bundleID }) }
        if let folder = UserDefaults.standard.string(forKey: "previewIcons") {
            for app in apps where appIcons[app.bundleID] == nil {
                appIcons[app.bundleID] = UIImage(contentsOfFile: "\(folder)/\(app.bundleID).png")
            }
        }
        control = ControlStatus(allowed: true)
        switch screen {
        case "connecting": phase = .connecting(hostName: host)
        case "pairing": phase = .comparingCode(hostName: host, code: "482916")
        case "waiting": phase = .waitingForMac(hostName: host)
        case "problem":
            problem = Problem(text: "Lost the connection to \(host).", action: .tryAgain)
        case "opening":
            phase = .connected(hostName: host)
            pendingWindowID = 1
        case "launching":
            phase = .connected(hostName: host)
            pendingLaunch = apps.first { $0.bundleID == "com.apple.Maps" }
        case "stream":
            phase = .connected(hostName: host)
            stream = StreamInfo(gen: 1, windowID: 1, title: samples[0].0, appName: samples[0].1,
                                pointSize: PointSize(width: 1280, height: 800), pixelSize: PixelSize(width: 2560, height: 1600))
        default:
            phase = .connected(hostName: host)
        }
    }

    /// A made-up window: a title bar with its three buttons, a sidebar and a few lines of content.
    private static func sampleWindow(background: UIColor, seed: Int) -> UIImage {
        let size = CGSize(width: 640, height: 400)
        return UIGraphicsImageRenderer(size: size).image { context in
            let dark = background.cgColor.components.map { $0[0] < 0.5 } ?? false
            let ink = dark ? UIColor(white: 1, alpha: 0.16) : UIColor(white: 0, alpha: 0.09)
            background.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            (dark ? UIColor(white: 1, alpha: 0.06) : UIColor(white: 0, alpha: 0.04)).setFill()
            context.fill(CGRect(x: 0, y: 0, width: size.width, height: 36))
            for (index, color) in [UIColor.systemRed, .systemYellow, .systemGreen].enumerated() {
                color.setFill()
                UIBezierPath(ovalIn: CGRect(x: 14 + CGFloat(index) * 20, y: 12, width: 12, height: 12)).fill()
            }
            ink.setFill()
            if seed % 2 == 0 { context.fill(CGRect(x: 0, y: 36, width: 150, height: size.height - 36)) }
            let left: CGFloat = seed % 2 == 0 ? 176 : 28
            for row in 0..<9 {
                let width = (size.width - left - 30) * CGFloat([0.9, 0.6, 0.75, 0.4, 0.85, 0.55, 0.7, 0.3, 0.65][(row + seed) % 9])
                UIBezierPath(roundedRect: CGRect(x: left, y: 64 + CGFloat(row) * 34, width: width, height: 12), cornerRadius: 6).fill()
            }
        }
    }
}
#endif
