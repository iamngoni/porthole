import Foundation
import Network
import os
import PortholeProtocol

private let log = Logger(subsystem: "dev.iamngoni.porthole", category: "signaling")

private func signalingParameters() -> NWParameters {
    let tcp = NWProtocolTCP.Options()
    tcp.noDelay = true
    tcp.enableKeepalive = true
    tcp.keepaliveIdle = 10
    return NWParameters(tls: nil, tcp: tcp)
}

/// The Bonjour TXT key that carries the Mac's stable ID, so a device knows which pairing to use.
public let portholeHostIDKey = "id"

/// A framed connection carrying versioned `WireMessage`s. Everything runs on the main queue.
public final class SignalingConnection {
    public enum Event {
        case ready
        case message(WireMessage)
        /// The other side speaks another protocol version; the connection is closing.
        case incompatible(version: Int, reason: String?)
        case closed(Error?)
    }

    public var onEvent: ((Event) -> Void)?

    private let connection: NWConnection
    private var decoder = FrameDecoder()
    private var isReady = false
    private var isClosed = false
    private var isClosing = false

    /// How long to wait for an unreachable Mac (say, a stale Bonjour record) before giving up.
    private static let connectTimeout: TimeInterval = 10

    public init(connection: NWConnection) {
        self.connection = connection
    }

    public convenience init(endpoint: NWEndpoint) {
        self.init(connection: NWConnection(to: endpoint, using: signalingParameters()))
    }

    public var remoteDescription: String { connection.endpoint.debugDescription }

    /// The other side's address without its port, for limiting connections per device.
    public var remoteAddress: String {
        if case .hostPort(let host, _) = connection.endpoint { return "\(host)" }
        return connection.endpoint.debugDescription
    }

    public func start() {
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.isReady = true
                self.onEvent?(.ready)
            case .waiting(let error):
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.connectTimeout) { [weak self] in
                    guard let self, !self.isReady, !self.isClosed else { return }
                    self.finish(error)
                    self.connection.cancel()
                }
            case .failed(let error):
                self.finish(error)
            case .cancelled:
                self.finish(nil)
            default:
                break
            }
        }
        connection.start(queue: .main)
        receive()
    }

    public func send(_ message: WireMessage) {
        guard !isClosed, !isClosing else { return }
        do {
            let frame = Framing.frame(try WireCoding.encode(message))
            connection.send(content: frame, completion: .contentProcessed { [weak self] error in
                if let error { self?.finish(error) }
            })
        } catch {
            log.error("could not encode signaling message: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func close() {
        // A graceful close is already delivering its last message; let it finish.
        guard !isClosing else { return }
        connection.cancel()
    }

    /// Says why, then closes once that has gone out.
    public func close(_ reason: CloseReason) {
        close(sendingFirst: .bye(reason: reason.rawValue))
    }

    /// Sends one last message, then closes once it has gone out.
    /// Cancelling straight after a send can drop the send, and the other side would only see "lost connection".
    public func close(sendingFirst message: WireMessage) {
        guard let payload = try? WireCoding.encode(message) else {
            close()
            return
        }
        close(sendingRaw: payload)
    }

    /// Sends one last, already encoded frame, then closes.
    func close(sendingRaw payload: Data) {
        guard !isClosed, !isClosing, !payload.isEmpty else {
            close()
            return
        }
        isClosing = true
        let connection = self.connection
        connection.send(content: Framing.frame(payload), contentContext: .finalMessage, isComplete: true, completion: .contentProcessed { _ in
            connection.cancel()
        })
        // Backstop if the other side never reads.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { connection.cancel() }
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self, !self.isClosed else { return }
            if let data, !data.isEmpty {
                do {
                    for frame in try self.decoder.append(data) {
                        switch try WireCoding.decode(frame) {
                        case .message(let message):
                            self.onEvent?(.message(message))
                        case .unsupportedVersion(let version, let reason):
                            self.onEvent?(.incompatible(version: version, reason: reason))
                            if version <= WireCoding.lastJSONVersion {
                                // An app from before v3 only reads JSON; tell it in its own format.
                                self.close(sendingRaw: WireCoding.legacyBye(reason: CloseReason.versionMismatch.rawValue))
                            } else {
                                self.close(.versionMismatch)
                            }
                            return
                        }
                        // A handler may have closed the connection; stop delivering what's left.
                        if self.isClosed || self.isClosing { return }
                    }
                } catch {
                    log.error("dropping connection after bad signaling data: \(String(describing: error), privacy: .public)")
                    self.finish(error)
                    self.connection.cancel()
                    return
                }
            }
            if let error {
                self.finish(error)
            } else if isComplete {
                self.finish(nil)
                self.connection.cancel()
            } else {
                self.receive()
            }
        }
    }

    private func finish(_ error: Error?) {
        guard !isClosed else { return }
        isClosed = true
        onEvent?(.closed(error))
    }
}

/// Mac side: advertises the host on Bonjour and accepts signaling connections.
public final class SignalingListener {
    public var onConnection: ((SignalingConnection) -> Void)?
    public var onStateChange: ((String) -> Void)?

    private let serviceName: String
    private let hostID: String
    private var listener: NWListener?
    private var isRunning = false

    public init(serviceName: String, hostID: String) {
        self.serviceName = serviceName
        self.hostID = hostID
    }

    public func start() throws {
        isRunning = true
        try makeListener()
    }

    public func stop() {
        isRunning = false
        listener?.cancel()
        listener = nil
    }

    private func makeListener() throws {
        let listener = try NWListener(using: signalingParameters())
        listener.service = NWListener.Service(name: serviceName, type: portholeBonjourType, domain: nil,
                                              txtRecord: NWTXTRecord([portholeHostIDKey: hostID]))
        listener.newConnectionHandler = { [weak self] connection in
            self?.onConnection?(SignalingConnection(connection: connection))
        }
        listener.stateUpdateHandler = { [weak self] state in
            let text: String = switch state {
            case .ready: "Listening"
            case .failed(let error): "Listener failed: \(error.localizedDescription)"
            case .waiting(let error): "Waiting: \(error.localizedDescription)"
            case .cancelled: "Stopped"
            default: "Starting"
            }
            log.info("listener: \(text, privacy: .public)")
            self?.onStateChange?(text)
            if case .failed = state { self?.restartSoon() }
        }
        listener.start(queue: .main)
        self.listener = listener
    }

    /// A failed listener can't be reused; make a new one so the Mac becomes discoverable again.
    private func restartSoon() {
        listener?.cancel()
        listener = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self, self.isRunning, self.listener == nil else { return }
            do {
                try self.makeListener()
            } catch {
                self.onStateChange?("Could not listen: \(error.localizedDescription)")
            }
        }
    }
}

/// A Mac found on the local network.
public struct DiscoveredHost: Identifiable, Hashable {
    public var id: String { name }
    public let name: String
    /// The Mac's stable ID from its Bonjour record. Unauthenticated: only used to pick which pairing to try.
    public let hostID: String?
    public let endpoint: NWEndpoint
}

public enum BrowseStatus: Equatable, Sendable {
    case starting
    case searching
    /// The user turned off Local Network access for the app.
    case localNetworkDenied
    case problem(String)
}

/// Client side: finds Porthole hosts on the local network.
public final class HostBrowser {
    public var onChange: (([DiscoveredHost]) -> Void)?
    public var onStatusChange: ((BrowseStatus) -> Void)?

    private var browser: NWBrowser?
    private var isRunning = false

    public init() {}

    public func start() {
        isRunning = true
        makeBrowser()
    }

    public func stop() {
        isRunning = false
        browser?.cancel()
        browser = nil
    }

    private func makeBrowser() {
        let browser = NWBrowser(for: .bonjourWithTXTRecord(type: portholeBonjourType, domain: nil), using: signalingParameters())
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            // The same Mac can appear once per network interface; keep one entry per name.
            var byName: [String: DiscoveredHost] = [:]
            for result in results {
                guard case let .service(name, _, _, _) = result.endpoint else { continue }
                var hostID: String?
                if case .bonjour(let txt) = result.metadata { hostID = txt[portholeHostIDKey] }
                if let existing = byName[name], existing.hostID != nil || hostID == nil { continue }
                byName[name] = DiscoveredHost(name: name, hostID: hostID, endpoint: result.endpoint)
            }
            self?.onChange?(byName.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
        }
        browser.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.onStatusChange?(.searching)
            case .waiting(let error):
                self.onStatusChange?(Self.isLocalNetworkDenied(error) ? .localNetworkDenied : .problem(error.localizedDescription))
            case .failed(let error):
                self.onStatusChange?(Self.isLocalNetworkDenied(error) ? .localNetworkDenied : .problem(error.localizedDescription))
                // Browses often fail after the app is suspended; a failed browser can't be reused.
                self.restartSoon()
            default:
                self.onStatusChange?(.starting)
            }
        }
        browser.start(queue: .main)
        self.browser = browser
    }

    private func restartSoon() {
        browser?.cancel()
        browser = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self, self.isRunning, self.browser == nil else { return }
            self.makeBrowser()
        }
    }

    private static func isLocalNetworkDenied(_ error: NWError) -> Bool {
        // kDNSServiceErr_PolicyDenied
        if case .dns(let code) = error { return code == -65570 }
        return false
    }
}
