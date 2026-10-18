import Foundation

/// What travels on the signaling connection (Bonjour TCP today, the relay later).
///
/// Pairing and the session handshake are sent in the clear; they are built to be safe that way.
/// Everything after the handshake is a `sealed` frame whose content is a `SignalMessage`.
public enum WireMessage: Codable, Hashable, Sendable {
    case pairRequest(PairRequest)
    case pairChallenge(PairChallenge)
    case pairReveal(PairReveal)
    case pairConfirm(PairConfirm)
    case pairComplete(PairComplete)
    case sessionHello(SessionHello)
    case sessionAccept(SessionAccept)
    case sealed(SealedFrame)
    /// Unauthenticated; it only ever closes a connection, so a forged one can do no more than a dropped packet.
    case bye(reason: String)
}

// MARK: - Pairing messages (device = iPad/iPhone, host = Mac)

/// Device → host. Commits to the device's key before the host reveals anything.
public struct PairRequest: Codable, Hashable, Sendable {
    public var deviceID: String
    public var deviceName: String
    public var commitment: Data

    public init(deviceID: String, deviceName: String, commitment: Data) {
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.commitment = commitment
    }
}

/// Host → device.
public struct PairChallenge: Codable, Hashable, Sendable {
    public var hostID: String
    public var hostName: String
    public var hostKey: Data
    public var hostNonce: Data

    public init(hostID: String, hostName: String, hostKey: Data, hostNonce: Data) {
        self.hostID = hostID
        self.hostName = hostName
        self.hostKey = hostKey
        self.hostNonce = hostNonce
    }
}

/// Device → host. Opens the commitment.
public struct PairReveal: Codable, Hashable, Sendable {
    public var deviceKey: Data
    public var deviceNonce: Data

    public init(deviceKey: Data, deviceNonce: Data) {
        self.deviceKey = deviceKey
        self.deviceNonce = deviceNonce
    }
}

/// Device → host, once the person confirms the codes match. Proves the device derived the same secret.
public struct PairConfirm: Codable, Hashable, Sendable {
    public var mac: Data

    public init(mac: Data) {
        self.mac = mac
    }
}

/// Host → device, once the person at the Mac clicks Allow.
public struct PairComplete: Codable, Hashable, Sendable {
    public var pairID: String
    public var mac: Data

    public init(pairID: String, mac: Data) {
        self.pairID = pairID
        self.mac = mac
    }
}

// MARK: - Session handshake and sealed frames

/// Device → host at the start of every connection from a paired device.
public struct SessionHello: Codable, Hashable, Sendable {
    public var pairID: String
    public var nonce: Data
    public var mac: Data

    public init(pairID: String, nonce: Data, mac: Data) {
        self.pairID = pairID
        self.nonce = nonce
        self.mac = mac
    }
}

/// Host → device. Proves the Mac knows the pairing secret too.
public struct SessionAccept: Codable, Hashable, Sendable {
    public var nonce: Data
    public var mac: Data

    public init(nonce: Data, mac: Data) {
        self.nonce = nonce
        self.mac = mac
    }
}

/// An encrypted `SignalMessage`. `counter` is the nonce; each direction counts from 0 with no gaps.
public struct SealedFrame: Codable, Hashable, Sendable {
    public var counter: UInt64
    public var box: Data

    public init(counter: UInt64, box: Data) {
        self.counter = counter
        self.box = box
    }
}

// MARK: - Versioned framing

/// Every frame is a protobuf `Wire` (Protocol/porthole.proto) carrying the protocol version.
///
/// Version 2 framed JSON instead, `{"v": 2, "msg": {...}}`. A v2 frame starts with `{`, which no v3 frame
/// can, so an old app is recognized and told to update in words it understands (`legacyBye`).
/// Future versions must keep `Wire.version` and `Wire.bye` as they are, for the same reason.
public enum WireCoding {
    public enum Decoded: Equatable, Sendable {
        case message(WireMessage)
        /// The other side runs another protocol version. `reason` is set if it sent a bye.
        case unsupportedVersion(Int, reason: String?)
    }

    public enum DecodeError: Error, Equatable {
        case notAFrame
    }

    /// The last version that framed JSON.
    public static let lastJSONVersion = 2

    public static func encode(_ message: WireMessage) throws -> Data {
        try message.proto.serializedData()
    }

    public static func decode(_ data: Data) throws -> Decoded {
        if data.first == UInt8(ascii: "{") { return try decodeJSON(data) }
        let wire: PBWire
        do {
            wire = try PBWire(serializedBytes: data)
        } catch {
            throw DecodeError.notAFrame
        }
        guard wire.version == portholeProtocolVersion else {
            guard case .bye(let bye)? = wire.msg else { return .unsupportedVersion(Int(wire.version), reason: nil) }
            return .unsupportedVersion(Int(wire.version), reason: bye.reason)
        }
        return .message(try WireMessage(proto: wire))
    }

    /// A bye in the v2 JSON shape, for telling an app that predates v3 why it's being disconnected.
    public static func legacyBye(reason: String) -> Data {
        (try? JSONSerialization.data(withJSONObject: ["v": lastJSONVersion, "msg": ["bye": ["reason": reason]]],
                                     options: [.sortedKeys])) ?? Data()
    }

    // MARK: Version 2

    private struct VersionProbe: Decodable {
        var v: Int
    }

    private struct ByeProbe: Decodable {
        struct Message: Decodable {
            struct Bye: Decodable { var reason: String }
            var bye: Bye
        }
        var msg: Message
    }

    /// Frames from before v3 are only ever read for their version and a bye.
    private static func decodeJSON(_ data: Data) throws -> Decoded {
        guard let probe = try? JSONDecoder().decode(VersionProbe.self, from: data) else {
            throw DecodeError.notAFrame
        }
        let reason = (try? JSONDecoder().decode(ByeProbe.self, from: data))?.msg.bye.reason
        return .unsupportedVersion(probe.v, reason: reason)
    }
}
