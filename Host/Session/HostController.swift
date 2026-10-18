import AppKit
import Combine
import os
import PortholeProtocol
import PortholeSession
import SystemConfiguration

/// Runs the Mac side: advertises on the network, pairs devices, serves one paired device at a time,
/// streams the window it picks and applies its input to that window.
@MainActor
final class HostController: ObservableObject {
    @Published private(set) var networkStatus = "Starting"
    @Published private(set) var clientName: String?
    @Published private(set) var connectionStatus = "No device connected"
    @Published private(set) var streaming: StreamInfo?
    @Published private(set) var screenRecordingAllowed = CGPreflightScreenCaptureAccess()
    @Published private(set) var accessibilityAllowed = InputInjector.isAllowed
    @Published private(set) var pairedDevices: [PairedDevice] = []
    /// While set, a new device may ask to pair until then.
    @Published private(set) var pairingOpenUntil: Date?
    /// Something worth telling the person at the Mac, such as a pairing that went wrong.
    @Published var notice: String?
    /// The last time the device sent input, for the menu's "controlling" indicator.
    @Published private(set) var lastInputAt: Date?

    /// The name from Sharing settings. Host.current() would do a blocking network lookup at launch.
    let hostName = SCDynamicStoreCopyComputerName(nil, nil) as String? ?? "Mac"
    let hostID = InstallationID.current(key: "porthole.hostID")

    static let pairingWindow: TimeInterval = 300
    /// Until the first message: a real device sends it at once.
    static let firstMessageTimeout: TimeInterval = 5
    /// From a pair request to the reveal, which the device sends without waiting on anyone.
    static let pairingExchangeTimeout: TimeInterval = 30
    static let maxPairingFailures = 3
    static let maxPendingConnections = 4
    static let maxPendingPerAddress = 2
    /// With nothing heard from the device for this long, held keys and buttons are let go.
    static let inputSilenceLimit: TimeInterval = 3

    private static let log = Logger(subsystem: "dev.iamngoni.porthole", category: "host")

    private let listener: SignalingListener
    private let store = PairingStores.pairedDevices()
    private let pairingPanel = PairingPanel()
    private let capture = CaptureController()
    private let input = InputInjector()
    private let previews = PreviewService()
    /// Every open connection, including ones still pairing or proving who they are.
    private var connections: [Connection] = []
    /// The paired device being served.
    private var client: Connection?
    private weak var promptConnection: Connection?
    private var pairingFailures = 0
    private var pairingTimer: Timer?
    private var windowListTimer: Timer?
    private var watchdog: Timer?
    private var lastSentWindows: [WindowInfo] = []
    private var lastHeardAt = Date.distantPast
    private var cachedTarget: (target: InputInjector.Target, at: TimeInterval)?
    private var activity: NSObjectProtocol?
    /// The apps last listed for the device, which are the only ones it may open, and where they are.
    private var offeredApps: [String: URL] = [:]
    /// The latest disk scan, reused for a few seconds so repeated requests don't rescan.
    private var appScan: (task: Task<[AppBundle], Never>, startedAt: Date)?
    private var launchTask: Task<Void, Never>?
    private var isLaunching = false
    private var lastLaunchAt = Date.distantPast
    /// Icons already sent this session.
    private var sentIcons: Set<String> = []
    /// Locked screen, or someone else's session on the console: nothing is streamed, opened or typed.
    private var isMacLocked = AppCatalog.isConsoleLocked

    private final class Connection {
        let signaling: SignalingConnection
        var link: HostLink
        var device: PairedDevice?
        var peer: PeerSession?
        var hello: ClientHello?
        /// Set once the answer is applied: how fast this device's streams may run.
        var frameRate = FrameRatePolicy.standard
        var deadline: Timer?
        /// Set once it starts pairing, so a failure can count against the pairing window.
        var isPairingAttempt = false
        let address: String
        let openedAt = Date()

        init(signaling: SignalingConnection, link: HostLink) {
            self.signaling = signaling
            self.link = link
            address = signaling.remoteAddress
        }
    }

    init() {
        #if DEBUG
        SpikeService.startIfAsked()
        #endif
        listener = SignalingListener(serviceName: hostName, hostID: hostID)
        listener.onStateChange = { [weak self] in self?.networkStatus = $0 }
        listener.onConnection = { [weak self] in self?.accept($0) }
        capture.onGeometryChange = { [weak self] info in
            self?.streaming = info
            self?.cachedTarget = nil
            self?.send(.geometry(info))
        }
        capture.onStopped = { [weak self] info, reason in
            Self.log.info("capture stopped: \(reason, privacy: .public)")
            self?.input.releaseAll()
            self?.streaming = nil
            self?.send(.streamState(gen: info.gen, state: .closed))
        }
        let center = DistributedNotificationCenter.default()
        center.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.macLocked() }
        }
        center.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.isMacLocked = AppCatalog.isConsoleLocked }
        }
        reloadPairedDevices()
        do {
            try listener.start()
        } catch {
            networkStatus = "Could not listen: \(error.localizedDescription)"
        }
        if !screenRecordingAllowed {
            // Shows the system prompt the first time and adds Porthole Host to the Screen Recording list.
            screenRecordingAllowed = CGRequestScreenCaptureAccess()
        }
        if !accessibilityAllowed {
            InputInjector.requestPermission()
        }
    }

    var isPairingOpen: Bool { pairingOpenUntil.map { $0 > Date() } ?? false }

    // MARK: Menu actions

    func refreshPermissions() {
        screenRecordingAllowed = CGPreflightScreenCaptureAccess()
        let allowed = InputInjector.isAllowed
        if allowed != accessibilityAllowed {
            accessibilityAllowed = allowed
            sendControlStatus()
        }
    }

    func openScreenRecordingSettings() {
        openSettings("Privacy_ScreenCapture")
    }

    func openAccessibilitySettings() {
        openSettings("Privacy_Accessibility")
    }

    private func openSettings(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Stops capture, including one that is still starting.
    func stopStreaming() {
        launchTask?.cancel()
        launchTask = nil
        isLaunching = false
        let info = streaming
        streaming = nil
        input.releaseAll()
        Task {
            await capture.stop()
            if let info { send(.streamState(gen: info.gen, state: .closed)) }
        }
    }

    func disconnectClient() {
        guard let client else { return }
        client.signaling.close(.disconnected)
        end(client)
    }

    /// Lets a new device ask to pair for the next five minutes.
    func openPairing() {
        pairingFailures = 0
        notice = nil
        pairingOpenUntil = Date().addingTimeInterval(Self.pairingWindow)
        pairingTimer?.invalidate()
        pairingTimer = Timer.scheduledTimer(withTimeInterval: Self.pairingWindow, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.closePairing() }
        }
    }

    func closePairing() {
        pairingOpenUntil = nil
        pairingTimer?.invalidate()
        pairingTimer = nil
    }

    func removePairing(_ device: PairedDevice) {
        do {
            try store.remove(device.pairID)
        } catch {
            notice = "Couldn’t remove \(device.deviceName): \(error)"
        }
        reloadPairedDevices()
        for connection in connections where connection.device?.pairID == device.pairID {
            connection.signaling.close(.unknownPairing)
            end(connection)
        }
    }

    private func reloadPairedDevices() {
        pairedDevices = store.all().sorted { $0.pairedAt > $1.pairedAt }
    }

    // MARK: Connections

    private func accept(_ signaling: SignalingConnection) {
        let pending = connections.filter { $0 !== client }
        let address = signaling.remoteAddress
        guard pending.filter({ $0.address == address }).count < Self.maxPendingPerAddress else {
            signaling.close()
            return
        }
        if pending.count >= Self.maxPendingConnections {
            // Make room by dropping the oldest connection that hasn't started pairing, so idle sockets
            // can't keep the real device out.
            guard let oldest = pending.filter({ !$0.isPairingAttempt }).min(by: { $0.openedAt < $1.openedAt }) else {
                signaling.close()
                return
            }
            apply(oldest.link.close(.timedOut), to: oldest)
        }
        let store = self.store
        let link = HostLink(hostID: hostID, hostName: hostName,
                            lookup: { store.item(for: $0) },
                            pairingAllowed: { [weak self] in self?.isPairingOpen ?? false })
        let connection = Connection(signaling: signaling, link: link)
        connections.append(connection)
        setDeadline(for: connection, after: Self.firstMessageTimeout)
        signaling.onEvent = { [weak self, weak connection] event in
            guard let self, let connection else { return }
            self.handle(event, on: connection)
        }
        signaling.start()
    }

    private func setDeadline(for connection: Connection, after interval: TimeInterval) {
        connection.deadline?.invalidate()
        let id = ObjectIdentifier(connection)
        connection.deadline = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let connection = self.connections.first(where: { ObjectIdentifier($0) == id }),
                      connection.link.phase != .established else { return }
                self.apply(connection.link.close(.timedOut), to: connection)
            }
        }
    }

    private func handle(_ event: SignalingConnection.Event, on connection: Connection) {
        guard connections.contains(where: { $0 === connection }) else { return }
        switch event {
        case .ready:
            break
        case .message(let message):
            let outputs = connection.link.receive(message)
            if connection.link.phase == .pairing, !connection.isPairingAttempt {
                connection.isPairingAttempt = true
                if stopIfContested(by: connection) { return }
                setDeadline(for: connection, after: Self.pairingExchangeTimeout)
            }
            apply(outputs, to: connection)
        case .incompatible(let version, _):
            Self.log.info("a device with protocol \(version) tried to connect")
            notice = "A device with a different version of Porthole tried to connect. Update the apps on both."
            end(connection)
        case .closed(let error):
            Self.log.info("signaling closed: \(error?.localizedDescription ?? "normally", privacy: .public)")
            end(connection)
        }
    }

    private func apply(_ outputs: [HostLink.Output], to connection: Connection) {
        for output in outputs {
            guard connections.contains(where: { $0 === connection }) else { return }
            switch output {
            case .send(let message):
                connection.signaling.send(message)
            case .askToPair(let deviceName, let code):
                askToPair(connection, deviceName: deviceName, code: code)
            case .paired(let device):
                savePairing(device)
                connection.isPairingAttempt = false
            case .established(let device):
                promote(connection, device: device)
            case .deliver(let message):
                handle(message, from: connection)
            case .close(let reason):
                if connection.isPairingAttempt, reason != .pairingDenied { countPairingFailure() }
                connection.signaling.close(reason)
                end(connection)
            case .peerClosed(let reason):
                if connection.isPairingAttempt { countPairingFailure() }
                Self.log.info("device closed: \(reason, privacy: .public)")
                end(connection)
            }
        }
    }

    /// Two devices pairing at once means one of them may be an impostor racing the real one to the
    /// prompt. Rather than guess, stop both and close pairing.
    private func stopIfContested(by newcomer: Connection) -> Bool {
        let others = connections.filter { $0 !== newcomer && $0.isPairingAttempt && $0.link.phase == .pairing }
        guard !others.isEmpty else { return false }
        Self.log.info("two devices tried to pair at once; stopping pairing")
        closePairing()
        notice = "Two devices tried to pair at the same time, so pairing stopped. If you were only pairing one, another device on this network may be trying to get in. Choose Pair New Device to try again."
        for connection in others + [newcomer] {
            connection.isPairingAttempt = false
            apply(connection.link.close(.pairingContested), to: connection)
        }
        return true
    }

    private func askToPair(_ connection: Connection, deviceName: String, code: String) {
        guard promptConnection == nil else {
            connection.isPairingAttempt = false
            apply(connection.link.close(.pairingContested), to: connection)
            return
        }
        // People are involved from here on; give them the whole pairing window.
        setDeadline(for: connection, after: Self.pairingWindow)
        promptConnection = connection
        let name = DisplayName.clean(deviceName, fallback: "A device")
        pairingPanel.show(deviceName: name, code: code) { [weak self, weak connection] allowed in
            guard let self, let connection else { return }
            self.promptConnection = nil
            self.apply(allowed ? connection.link.approve() : connection.link.deny(), to: connection)
        }
    }

    private func savePairing(_ device: PairedDevice) {
        var device = device
        device.deviceName = DisplayName.clean(device.deviceName, fallback: "Device")
        do {
            try store.save(device, for: device.pairID)
        } catch {
            Self.log.error("could not save pairing: \(String(describing: error), privacy: .public)")
            notice = "Paired with \(device.deviceName), but couldn’t save it, so it will need to pair again next time."
        }
        reloadPairedDevices()
        // One device per pairing window, like Bluetooth.
        closePairing()
    }

    private func countPairingFailure() {
        guard isPairingOpen else { return }
        pairingFailures += 1
        if pairingFailures >= Self.maxPairingFailures {
            closePairing()
            notice = "Pairing stopped after \(Self.maxPairingFailures) failed attempts. Choose Pair New Device to try again."
        }
    }

    /// The connection proved it is a paired device: it becomes the one this Mac serves.
    private func promote(_ connection: Connection, device: PairedDevice) {
        connection.deadline?.invalidate()
        connection.deadline = nil
        connection.device = device
        if let existing = client, existing !== connection {
            existing.signaling.close(.replaced)
            end(existing)
        }
        client = connection
        clientName = DisplayName.clean(device.deviceName, fallback: "Device")
        connectionStatus = "Connecting…"
    }

    private func end(_ connection: Connection) {
        connection.deadline?.invalidate()
        connection.deadline = nil
        connection.peer?.close()
        connection.peer = nil
        connection.signaling.onEvent = nil
        connection.signaling.close()
        connections.removeAll { $0 === connection }
        if promptConnection === connection {
            promptConnection = nil
            pairingPanel.dismiss()
        }
        guard connection === client else { return }
        client = nil
        clientName = nil
        connectionStatus = "No device connected"
        input.releaseAll()
        lastInputAt = nil
        cachedTarget = nil
        capture.pump.setSink(nil)
        windowListTimer?.invalidate()
        windowListTimer = nil
        watchdog?.invalidate()
        watchdog = nil
        lastSentWindows = []
        previews.reset()
        launchTask?.cancel()
        launchTask = nil
        isLaunching = false
        offeredApps = [:]
        sentIcons = []
        endActivity()
        streaming = nil
        Task { await capture.stop() }
    }

    // MARK: Signaling (sealed)

    private func handle(_ message: SignalMessage, from connection: Connection) {
        guard connection === client else { return }
        switch message {
        case .hello(let hello):
            guard connection.peer == nil else { return }
            connection.hello = hello
            send(.welcome(HostWelcome(hostName: hostName)), to: connection)
            startPeer(for: connection)
        case .answer(let sdp):
            guard let peer = connection.peer else { return }
            let viewport = connection.hello?.viewport ?? Self.fallbackViewport
            let limit = StreamSizing.frameRateLimit(macRefresh: Self.macRefreshRate, deviceRefresh: connection.hello?.maxFramesPerSecond)
            Task {
                do {
                    let level = try await peer.acceptAnswer(sdp, viewport: viewport, framesPerSecond: limit)
                    connection.frameRate = FrameRatePolicy(limit: limit, level: level)
                    Self.log.info("video up to \(limit, privacy: .public) fps, H.264 level \(level.rawValue, privacy: .public)")
                } catch {
                    guard connection === self.client else { return }
                    Self.log.error("bad answer: \(error.localizedDescription, privacy: .public)")
                    connection.signaling.close(.badFrame)
                    self.end(connection)
                }
            }
        case .candidate(let candidate):
            connection.peer?.addRemoteCandidate(candidate)
        case .welcome, .offer:
            break
        }
    }

    private func send(_ message: SignalMessage, to connection: Connection) {
        do {
            connection.signaling.send(try connection.link.seal(message))
        } catch {
            Self.log.error("could not seal a message: \(String(describing: error), privacy: .public)")
        }
    }

    private func startPeer(for connection: Connection) {
        let peer = PeerSession(role: .host)
        connection.peer = peer
        peer.onLocalCandidate = { [weak self, weak connection] candidate in
            guard let self, let connection else { return }
            self.send(.candidate(candidate), to: connection)
        }
        peer.onConnectionStateChange = { [weak self, weak connection] state in
            guard let self, let connection, connection === self.client else { return }
            self.connectionStatus = switch state {
            case .connected: "Connected"
            case .connecting, .new: "Connecting…"
            case .disconnected: "Connection interrupted"
            case .failed: "Connection failed"
            case .closed: "Disconnected"
            }
            if state == .disconnected { self.input.releaseAll() }
            if state == .failed {
                connection.signaling.close(.disconnected)
                self.end(connection)
            }
        }
        peer.onControlOpen = { [weak self] in
            self?.sendWindowList(force: true)
            self?.sendControlStatus()
        }
        peer.onControlMessage = { [weak self, weak connection] data in
            guard let self, let connection, connection === self.client else { return }
            self.handleControl(data)
        }
        capture.pump.setSink { [weak peer] buffer, timestamp in
            peer?.pushFrame(buffer, timestampNs: timestamp)
        }
        beginActivity()
        startWindowListUpdates()
        startWatchdog()

        Task {
            do {
                let offer = try await peer.makeOffer()
                guard connection === self.client else { return }
                self.send(.offer(sdp: offer), to: connection)
            } catch {
                guard connection === self.client else { return }
                Self.log.error("could not create offer: \(error.localizedDescription, privacy: .public)")
                connection.signaling.close(.disconnected)
                self.end(connection)
            }
        }
    }

    // MARK: Control channel

    private func handleControl(_ data: Data) {
        let message: ClientMessage
        do {
            message = try MessageCoding.decode(ClientMessage.self, from: data)
        } catch {
            Self.log.error("ignoring unreadable control message")
            return
        }
        lastHeardAt = Date()
        switch message {
        case .listWindows:
            sendWindowList(force: true)
        case .select(let windowID):
            launchTask?.cancel()
            select(windowID)
        case .stopStream:
            launchTask?.cancel()
            stopStreaming()
        case .viewport(let viewport):
            client?.hello?.viewport = viewport
        case .ping(let value):
            send(.pong(value))
        case .pointer(let event):
            guard let target = inputTarget(gen: event.gen) else { return }
            input.move(to: event.point, in: target)
        case .button(let event):
            guard let target = inputTarget(gen: event.gen) else { return }
            input.button(event, in: target)
        case .scroll(let event):
            guard let target = inputTarget(gen: event.gen) else { return }
            input.scroll(event, in: target)
        case .key(let event):
            guard let target = inputTarget(gen: event.gen) else { return }
            input.key(event, in: target)
        case .text(let event):
            guard let target = inputTarget(gen: event.gen) else { return }
            input.type(event.text, in: target)
        case .releaseAll:
            input.releaseAll()
        case .thumbnails(let windowIDs, let maxLongSide):
            let session = client
            previews.thumbnails(for: windowIDs, maxLongSide: maxLongSide) { [weak self] id, jpeg in
                guard let self, session === self.client else { return }
                self.send(.thumbnail(windowID: id, jpeg: jpeg))
            }
        case .appIcons(let bundleIDs):
            let wanted = bundleIDs.prefix(40).filter { !sentIcons.contains($0) }
            guard !wanted.isEmpty else { return }
            let windowApps = Set(WindowCatalog.streamableWindows().compactMap(\.bundleID))
            for bundleID in wanted {
                if let png = previews.icon(for: bundleID, listedAt: offeredApps[bundleID], windowApps: windowApps) {
                    sentIcons.insert(bundleID)
                    send(.appIcon(bundleID: bundleID, png: png))
                }
            }
        case .listApps:
            sendAppList()
        case .launch(let bundleID):
            launch(bundleID)
        }
    }

    /// The shared window, if input for stream `gen` should reach it. Input aimed at a window the
    /// device has since switched away from is dropped.
    private func inputTarget(gen: UInt32) -> InputInjector.Target? {
        guard let streaming, streaming.gen == gen, accessibilityAllowed, !isMacLocked else { return nil }
        // Published at most once a second; pointer moves arrive many times a second.
        if lastInputAt.map({ Date().timeIntervalSince($0) > 1 }) ?? true { lastInputAt = Date() }
        let now = ProcessInfo.processInfo.systemUptime
        // The window can move under the pointer; look it up again every few frames.
        if let cached = cachedTarget, cached.target.windowID == streaming.windowID, now - cached.at < 0.05 {
            return cached.target
        }
        guard let target = WindowCatalog.target(of: streaming.windowID) else { return nil }
        cachedTarget = (target, now)
        return target
    }

    private func sendControlStatus() {
        let reason = accessibilityAllowed ? nil : "To control windows, allow Porthole Host under Accessibility in System Settings on the Mac."
        send(.control(ControlStatus(allowed: accessibilityAllowed, reason: reason)))
    }

    /// Lets go of anything held if the device goes quiet, and notices Accessibility being turned on or off.
    private func startWatchdog() {
        watchdog?.invalidate()
        lastHeardAt = Date()
        watchdog = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.input.isHoldingAnything, Date().timeIntervalSince(self.lastHeardAt) > Self.inputSilenceLimit {
                    Self.log.info("device went quiet; releasing held input")
                    self.input.releaseAll()
                }
                self.refreshPermissions()
            }
        }
    }

    private func select(_ windowID: UInt32) {
        guard !refusedWhileLocked() else { return }
        // Only windows this Mac offered: never helper panels, agents or Porthole Host itself.
        guard WindowCatalog.streamableWindows().contains(where: { $0.id == windowID }) else {
            send(.error(code: "window_unavailable", message: "That window is no longer available."))
            return
        }
        input.releaseAll()
        cachedTarget = nil
        let session = client
        let viewport = client?.hello?.viewport ?? Self.fallbackViewport
        Task {
            do {
                let info = try await capture.start(windowID: windowID, maxLongSide: StreamSizing.cap(forViewport: viewport),
                                                   frameRate: session?.frameRate ?? .standard)
                guard session === client else { return }
                streaming = info
                send(.streamStarted(info))
            } catch is CancellationError {
                // A newer select or a stop replaced this one.
            } catch {
                guard session === client else { return }
                refreshPermissions()
                let message = screenRecordingAllowed
                    ? error.localizedDescription
                    : "Allow Porthole Host under Screen Recording in System Settings on the Mac."
                send(.error(code: "capture_failed", message: message))
            }
        }
    }

    // MARK: Apps

    private func sendAppList() {
        let session = client
        if appScan.map({ Date().timeIntervalSince($0.startedAt) > 10 }) ?? true {
            appScan = (Task.detached(priority: .userInitiated) { AppCatalog.scan() }, Date())
        }
        guard let scan = appScan?.task else { return }
        Task {
            let bundles = await scan.value
            guard session === client else { return }
            let catalog = InstalledApps.catalog(bundles, excluding: [Bundle.main.bundleIdentifier ?? ""])
            offeredApps = Dictionary(catalog.map { ($0.bundleID!, URL(fileURLWithPath: $0.path)) }, uniquingKeysWith: { first, _ in first })
            let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
            send(.apps(catalog.map { AppInfo(bundleID: $0.bundleID!, name: $0.name, isRunning: running.contains($0.bundleID!)) }))
        }
    }

    /// Opens an app the device picked from the list, then streams its window: the one it opens, or for an
    /// app that was already open, its frontmost window.
    private func launch(_ bundleID: String) {
        guard !refusedWhileLocked() else { return }
        // Only apps from the list this Mac sent: never a path, a document or arguments from the device.
        guard let url = offeredApps[bundleID] else {
            send(.error(code: "app_unavailable", message: "That app isn’t available on the Mac."))
            return
        }
        // One at a time, and not in a burst.
        guard !isLaunching, Date().timeIntervalSince(lastLaunchAt) > 1 else {
            send(.error(code: "launch_busy", message: "Still opening the last app. Try again in a moment."))
            return
        }
        // The bundle on disk must still be the one that was listed.
        guard AppCatalog.currentBundleID(at: url) == bundleID else {
            send(.error(code: "app_unavailable", message: "That app changed on the Mac. Refresh the list and try again."))
            return
        }
        launchTask?.cancel()
        isLaunching = true
        lastLaunchAt = Date()
        let session = client
        var name = FileManager.default.displayName(atPath: url.path)
        if name.hasSuffix(".app") { name = String(name.dropLast(4)) }
        name = DisplayName.clean(name, fallback: bundleID)
        // Never silently: the Mac says what the device opened.
        notice = "\(clientName ?? "Your device") opened \(name)."
        Self.log.notice("device opened \(bundleID, privacy: .public)")
        let before = Set(WindowCatalog.streamableWindows().filter { $0.bundleID == bundleID }.map(\.id))
        launchTask = Task {
            defer { if session === client { isLaunching = false } }
            if let failure = await AppCatalog.open(url) {
                guard !Task.isCancelled, session === client else { return }
                send(.error(code: "launch_failed", message: "Couldn’t open \(name). \(failure)"))
                return
            }
            let started = Date()
            while Date().timeIntervalSince(started) < 15 {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled, session === client, !isMacLocked else { return }
                let windows = Set(WindowCatalog.streamableWindows().filter { $0.bundleID == bundleID && $0.isOnScreen }.map(\.id))
                // A window it just opened, or once it has had a moment, the frontmost one it already had.
                let fresh = windows.subtracting(before)
                let candidates = fresh.isEmpty ? (Date().timeIntervalSince(started) > 2 ? windows : []) : fresh
                if let window = WindowCatalog.frontToBack().first(where: candidates.contains) {
                    sendWindowList(force: false)
                    select(window)
                    return
                }
            }
            send(.error(code: "no_window", message: before.isEmpty
                ? "\(name) opened, but didn’t show a window."
                : "\(name) is open, but its windows are hidden. Pick one under Windows."))
        }
    }

    /// Tells the device and returns true when the Mac is locked.
    private func refusedWhileLocked() -> Bool {
        isMacLocked = AppCatalog.isConsoleLocked
        guard isMacLocked else { return false }
        send(.error(code: "mac_locked", message: "The Mac is locked. Unlock it to keep going."))
        return true
    }

    /// The screen locked: stop showing and controlling anything until it's unlocked.
    private func macLocked() {
        isMacLocked = true
        input.releaseAll()
        guard streaming != nil || isLaunching else { return }
        stopStreaming()
        send(.error(code: "mac_locked", message: "The Mac locked, so the window stopped showing. Unlock it to keep going."))
    }

    /// Larger messages than libwebrtc's data channel takes would be dropped or close the channel.
    private static let maxControlMessageBytes = 240 * 1024

    /// Stands in for a client's screen until its hello says (an iPad Pro's).
    private static let fallbackViewport = PixelSize(width: 2752, height: 2064)

    /// The fastest of the Mac's displays. A window on a slower one simply draws fewer frames.
    private static var macRefreshRate: Int {
        NSScreen.screens.map(\.maximumFramesPerSecond).max() ?? StreamSizing.defaultFramesPerSecond
    }

    private func send(_ message: HostMessage) {
        guard let peer = client?.peer, let data = try? MessageCoding.encode(message) else { return }
        guard data.count <= Self.maxControlMessageBytes else {
            Self.log.error("dropped a \(data.count)-byte control message, over the limit")
            return
        }
        peer.sendControl(data)
    }

    private func startWindowListUpdates() {
        windowListTimer?.invalidate()
        windowListTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sendWindowList(force: false) }
        }
    }

    private func sendWindowList(force: Bool) {
        let windows = WindowCatalog.streamableWindows()
        guard force || windows != lastSentWindows else { return }
        lastSentWindows = windows
        send(.windows(windows))
    }

    // MARK: Keeping the Mac awake

    private func beginActivity() {
        guard activity == nil else { return }
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleDisplaySleepDisabled],
            reason: "A device is connected to Porthole"
        )
    }

    private func endActivity() {
        if let activity { ProcessInfo.processInfo.endActivity(activity) }
        activity = nil
    }
}
