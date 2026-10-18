import Foundation

// Each side of a signaling connection is a pure state machine: feed it what arrived, act on what it
// returns. The apps only move bytes, show prompts and save pairings; every decision about who is
// allowed in lives here, where tests can run both sides against each other.

/// Why a side closed the connection, sent as `WireMessage.bye(reason:)`.
public enum CloseReason: String, Sendable, CaseIterable {
    /// The Mac isn't accepting new devices; choose Pair New Device on the Mac first.
    case pairingClosed = "pairing-closed"
    case pairingDenied = "pairing-denied"
    /// The pairing exchange didn't check out, most likely because the codes differed.
    case pairingFailed = "pairing-failed"
    /// Two devices tried to pair at once, so the Mac stopped pairing rather than guess which is yours.
    case pairingContested = "pairing-contested"
    /// The Mac doesn't know this pairing (it was removed there).
    case unknownPairing = "unknown-pairing"
    case handshakeFailed = "handshake-failed"
    case badFrame = "bad-frame"
    case unexpectedMessage = "unexpected-message"
    case replaced = "replaced"
    case disconnected = "disconnected"
    case hostStopped = "host-stopped"
    case versionMismatch = "version-mismatch"
    case timedOut = "timed-out"
}

public enum LinkError: Error, Equatable, Sendable {
    case notEstablished
}

// MARK: - Mac side

public struct HostLink {
    public enum Output: Equatable, Sendable {
        case send(WireMessage)
        /// Show the device's name and the code, with Allow and Don't Allow.
        case askToPair(deviceName: String, code: String)
        /// Save it: this device is paired from now on.
        case paired(PairedDevice)
        /// The device proved it holds the pairing keys; this connection is now that device.
        case established(PairedDevice)
        case deliver(SignalMessage)
        /// Send `bye` with this reason and close.
        case close(CloseReason)
        /// The device said goodbye.
        case peerClosed(reason: String)
    }

    public enum Phase: Equatable, Sendable {
        case handshaking, pairing, established, closed
    }

    private enum Stage {
        case start
        case pairing(HostPairing, showedCode: Bool, approval: (pairID: String, at: Date)?)
        case awaitingHello(justPaired: PairedDevice)
        /// Accept sent; waiting for the first sealed frame, which proves the device derived the keys.
        /// Until then the connection could be a replayed hello, so it must not displace anyone.
        case keyConfirmation(SecureChannel, PairedDevice)
        case established(SecureChannel)
        case closed
    }

    private let hostID: String
    private let hostName: String
    private let lookup: (String) -> PairedDevice?
    private let pairingAllowed: () -> Bool
    private var stage = Stage.start

    /// `lookup` finds a saved pairing by its ID; `pairingAllowed` says whether the Mac is accepting new devices.
    public init(hostID: String, hostName: String,
                lookup: @escaping (String) -> PairedDevice?,
                pairingAllowed: @escaping () -> Bool) {
        self.hostID = hostID
        self.hostName = hostName
        self.lookup = lookup
        self.pairingAllowed = pairingAllowed
    }

    public var phase: Phase {
        switch stage {
        case .start, .awaitingHello, .keyConfirmation: .handshaking
        case .pairing: .pairing
        case .established: .established
        case .closed: .closed
        }
    }

    public mutating func receive(_ message: WireMessage) -> [Output] {
        if case .bye(let reason) = message {
            guard phase != .closed else { return [] }
            stage = .closed
            return [.peerClosed(reason: reason)]
        }
        switch (stage, message) {
        case (.closed, _):
            return []

        case (.start, .pairRequest(let request)):
            guard pairingAllowed() else { return close(.pairingClosed) }
            var pairing = HostPairing(hostID: hostID, hostName: hostName)
            guard let challenge = try? pairing.receive(request) else { return close(.pairingFailed) }
            stage = .pairing(pairing, showedCode: false, approval: nil)
            return [.send(.pairChallenge(challenge))]

        case (.pairing(var pairing, false, nil), .pairReveal(let reveal)):
            guard let code = try? pairing.receive(reveal) else { return close(.pairingFailed) }
            stage = .pairing(pairing, showedCode: true, approval: nil)
            return [.askToPair(deviceName: pairing.deviceName ?? "", code: code)]

        case (.pairing(var pairing, true, let approval), .pairConfirm(let confirm)) where !pairing.isConfirmedByDevice:
            guard (try? pairing.receive(confirm)) != nil else { return close(.pairingFailed) }
            stage = .pairing(pairing, showedCode: true, approval: approval)
            return approval == nil ? [] : completePairing()

        case (.start, .sessionHello(let hello)), (.awaitingHello, .sessionHello(let hello)):
            var device = lookup(hello.pairID)
            if case .awaitingHello(let justPaired) = stage, justPaired.pairID == hello.pairID {
                device = justPaired
            }
            guard let device else { return close(.unknownPairing) }
            guard SessionHandshake.isValid(hello, secret: device.secret) else { return close(.handshakeFailed) }
            let accept = SessionHandshake.accept(hello, secret: device.secret)
            let channel = SessionHandshake.channel(role: .host, secret: device.secret, hello: hello, accept: accept)
            stage = .keyConfirmation(channel, device)
            return [.send(.sessionAccept(accept))]

        case (.keyConfirmation(var channel, let device), .sealed(let frame)):
            guard let message = Self.open(frame, with: &channel) else { return close(.badFrame) }
            stage = .established(channel)
            return [.established(device), .deliver(message)]

        case (.established(var channel), .sealed(let frame)):
            guard let message = Self.open(frame, with: &channel) else { return close(.badFrame) }
            stage = .established(channel)
            return [.deliver(message)]

        case (.pairing, _):
            return close(.pairingFailed)

        default:
            return close(.unexpectedMessage)
        }
    }

    /// The person at the Mac clicked Allow. Pairing completes once the device has confirmed too.
    public mutating func approve(pairID: String = UUID().uuidString, at date: Date = Date()) -> [Output] {
        guard case .pairing(let pairing, true, nil) = stage else { return [] }
        stage = .pairing(pairing, showedCode: true, approval: (pairID, date))
        return pairing.isConfirmedByDevice ? completePairing() : []
    }

    /// The person at the Mac clicked Don't Allow, or let the prompt expire.
    public mutating func deny() -> [Output] {
        guard case .pairing = stage else { return [] }
        return close(.pairingDenied)
    }

    /// Closes from this side, for reasons the link can't see (timeouts, the Mac stopping).
    public mutating func close(_ reason: CloseReason) -> [Output] {
        guard phase != .closed else { return [] }
        stage = .closed
        return [.close(reason)]
    }

    public mutating func seal(_ message: SignalMessage) throws -> WireMessage {
        guard case .established(var channel) = stage else { throw LinkError.notEstablished }
        let frame = try channel.seal(MessageCoding.encode(message))
        stage = .established(channel)
        return .sealed(frame)
    }

    private mutating func completePairing() -> [Output] {
        guard case .pairing(var pairing, true, let approval?) = stage,
              let (message, device) = try? pairing.complete(pairID: approval.pairID, at: approval.at) else {
            return close(.pairingFailed)
        }
        stage = .awaitingHello(justPaired: device)
        return [.send(.pairComplete(message)), .paired(device)]
    }

    fileprivate static func open(_ frame: SealedFrame, with channel: inout SecureChannel) -> SignalMessage? {
        guard let data = try? channel.open(frame) else { return nil }
        return try? MessageCoding.decode(SignalMessage.self, from: data)
    }
}

// MARK: - iPad / iPhone side

public struct DeviceLink {
    public enum Output: Equatable, Sendable {
        case send(WireMessage)
        /// Show the code and ask whether it matches the one on the Mac.
        case showCode(String)
        /// Save it, replacing any earlier pairing with the same Mac.
        case paired(PairedHost)
        /// The Mac proved it holds the pairing keys; sealed messages can flow.
        case established(PairedHost)
        case deliver(SignalMessage)
        /// Send `bye` with this reason and close.
        case close(CloseReason)
        /// The Mac said goodbye.
        case peerClosed(reason: String)
    }

    public enum Phase: Equatable, Sendable {
        case idle, pairing, comparingCodes, handshaking, established, closed
    }

    private enum Stage {
        case idle
        case awaitingChallenge(DevicePairing)
        case comparing(DevicePairing)
        case awaitingComplete(DevicePairing)
        case awaitingAccept(SessionHello, PairedHost)
        case established(SecureChannel)
        case closed
    }

    private let deviceID: String
    private let deviceName: String
    private let pairing: PairedHost?
    private let expectedHostID: String?
    private var stage = Stage.idle

    /// With a saved `pairing` the link reconnects straight away; without one it pairs first.
    /// `expectedHostID` is the ID the chosen Mac advertised; a Mac answering with another ID is refused,
    /// so pairing can't quietly replace the saved pairing of a different Mac.
    public init(deviceID: String, deviceName: String, pairing: PairedHost?, expectedHostID: String? = nil) {
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.pairing = pairing
        self.expectedHostID = expectedHostID
    }

    public var phase: Phase {
        switch stage {
        case .idle: .idle
        case .awaitingChallenge, .awaitingComplete: .pairing
        case .comparing: .comparingCodes
        case .awaitingAccept: .handshaking
        case .established: .established
        case .closed: .closed
        }
    }

    /// Call once the connection is up.
    public mutating func start() -> [Output] {
        guard case .idle = stage else { return [] }
        if let pairing {
            return startSession(with: pairing)
        }
        var devicePairing = DevicePairing(deviceID: deviceID, deviceName: deviceName)
        let request = devicePairing.start()
        stage = .awaitingChallenge(devicePairing)
        return [.send(.pairRequest(request))]
    }

    public mutating func receive(_ message: WireMessage) -> [Output] {
        if case .bye(let reason) = message {
            guard phase != .closed else { return [] }
            stage = .closed
            return [.peerClosed(reason: reason)]
        }
        switch (stage, message) {
        case (.closed, _):
            return []

        case (.awaitingChallenge(var devicePairing), .pairChallenge(let challenge)):
            if let expectedHostID, challenge.hostID != expectedHostID { return close(.pairingFailed) }
            guard let (reveal, code) = try? devicePairing.receive(challenge) else { return close(.pairingFailed) }
            stage = .comparing(devicePairing)
            return [.send(.pairReveal(reveal)), .showCode(code)]

        case (.awaitingComplete(var devicePairing), .pairComplete(let complete)):
            guard let host = try? devicePairing.receive(complete) else { return close(.pairingFailed) }
            return [.paired(host)] + startSession(with: host)

        case (.awaitingAccept(let hello, let host), .sessionAccept(let accept)):
            guard SessionHandshake.isValid(accept, for: hello, secret: host.secret) else { return close(.handshakeFailed) }
            stage = .established(SessionHandshake.channel(role: .device, secret: host.secret, hello: hello, accept: accept))
            return [.established(host)]

        case (.established(var channel), .sealed(let frame)):
            guard let message = HostLink.open(frame, with: &channel) else { return close(.badFrame) }
            stage = .established(channel)
            return [.deliver(message)]

        case (.awaitingChallenge, _), (.comparing, _), (.awaitingComplete, _):
            return close(.pairingFailed)

        default:
            return close(.unexpectedMessage)
        }
    }

    /// The person says the codes match.
    public mutating func codesMatch() -> [Output] {
        guard case .comparing(var devicePairing) = stage, let confirm = try? devicePairing.confirm() else { return [] }
        stage = .awaitingComplete(devicePairing)
        return [.send(.pairConfirm(confirm))]
    }

    /// The person says the codes differ, or cancels.
    public mutating func codesDiffer() -> [Output] {
        guard case .comparing = stage else { return [] }
        return close(.pairingFailed)
    }

    public mutating func close(_ reason: CloseReason) -> [Output] {
        guard phase != .closed else { return [] }
        stage = .closed
        return [.close(reason)]
    }

    public mutating func seal(_ message: SignalMessage) throws -> WireMessage {
        guard case .established(var channel) = stage else { throw LinkError.notEstablished }
        let frame = try channel.seal(MessageCoding.encode(message))
        stage = .established(channel)
        return .sealed(frame)
    }

    private mutating func startSession(with host: PairedHost) -> [Output] {
        let hello = SessionHandshake.hello(pairID: host.pairID, secret: host.secret)
        stage = .awaitingAccept(hello, host)
        return [.send(.sessionHello(hello))]
    }
}
