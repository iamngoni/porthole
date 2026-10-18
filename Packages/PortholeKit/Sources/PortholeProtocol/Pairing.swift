import CryptoKit
import Foundation

// Pairing by numeric comparison with a commitment, as in Bluetooth Secure Simple Pairing.
//
//  device                                   host (Mac, pairing window open)
//  pairRequest{deviceID, name, C} ────────▶  C = H(deviceKey ‖ deviceNonce)
//                                 ◀────────  pairChallenge{hostID, name, hostKey, hostNonce}
//  pairReveal{deviceKey, nonce}   ────────▶  checks C
//  both: shared = X25519, T = H(every field above), code = HKDF(shared, T) mod 10^6
//  person compares the 6-digit codes on both screens
//  pairConfirm{MAC(secret, T)}    ────────▶  checks MAC, waits for Allow
//                                 ◀────────  pairComplete{pairID, MAC(secret, T ‖ pairID)}
//
// The commitment forces a man in the middle to pick their key before seeing the device's,
// so they get a single one-in-a-million guess at matching codes per attempt.

public enum PairingError: Error, Equatable, Sendable {
    case invalidKey
    case invalidNonce
    case commitmentMismatch
    case confirmationFailed
    case unexpectedMessage
}

/// What the device keeps after pairing.
public struct PairedHost: Codable, Hashable, Sendable {
    public var hostID: String
    public var hostName: String
    public var pairID: String
    public var secret: Data

    public init(hostID: String, hostName: String, pairID: String, secret: Data) {
        self.hostID = hostID
        self.hostName = hostName
        self.pairID = pairID
        self.secret = secret
    }
}

/// What the Mac keeps after pairing.
public struct PairedDevice: Codable, Hashable, Sendable {
    public var pairID: String
    public var deviceID: String
    public var deviceName: String
    public var secret: Data
    public var pairedAt: Date

    public init(pairID: String, deviceID: String, deviceName: String, secret: Data, pairedAt: Date) {
        self.pairID = pairID
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.secret = secret
        self.pairedAt = pairedAt
    }
}

public enum PairingCrypto {
    public static let nonceLength = 32

    public static func randomNonce() -> Data {
        SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
    }

    static func commitment(deviceKey: Data, deviceNonce: Data) -> Data {
        var hash = LengthPrefixedHash(label: "porthole-commit-v1")
        hash.add(deviceKey)
        hash.add(deviceNonce)
        return hash.digest
    }

    static func transcript(_ request: PairRequest, _ challenge: PairChallenge, _ reveal: PairReveal) -> Data {
        var hash = LengthPrefixedHash(label: "porthole-pair-v1")
        hash.add(request.deviceID)
        hash.add(request.deviceName)
        hash.add(request.commitment)
        hash.add(challenge.hostID)
        hash.add(challenge.hostName)
        hash.add(challenge.hostKey)
        hash.add(challenge.hostNonce)
        hash.add(reveal.deviceKey)
        hash.add(reveal.deviceNonce)
        return hash.digest
    }

    /// The 6 digits both people compare, zero-padded.
    static func code(shared: SharedSecret, transcript: Data) -> String {
        let key = shared.hkdfDerivedSymmetricKey(using: SHA256.self, salt: transcript, sharedInfo: Data("porthole-sas-v1".utf8), outputByteCount: 8)
        let value = key.withUnsafeBytes { $0.reduce(UInt64(0)) { $0 << 8 | UInt64($1) } }
        let digits = String(value % 1_000_000)
        return String(repeating: "0", count: 6 - digits.count) + digits
    }

    static func secret(shared: SharedSecret, transcript: Data) -> Data {
        shared.hkdfDerivedSymmetricKey(using: SHA256.self, salt: transcript, sharedInfo: Data("porthole-pair-secret-v1".utf8), outputByteCount: 32)
            .withUnsafeBytes { Data($0) }
    }

    static func deviceConfirmation(secret: Data, transcript: Data) -> Data {
        mac(secret, "device-confirm", transcript)
    }

    static func hostConfirmation(secret: Data, transcript: Data, pairID: String) -> Data {
        mac(secret, "host-confirm", transcript, Data(pairID.utf8))
    }

    static func mac(_ secret: Data, _ label: String, _ parts: Data...) -> Data {
        var hmac = HMAC<SHA256>(key: SymmetricKey(data: secret))
        var hash = LengthPrefixedHash(label: label)
        parts.forEach { hash.add($0) }
        hmac.update(data: hash.bytes)
        return Data(hmac.finalize())
    }

    static func verify(_ expected: Data, _ actual: Data) -> Bool {
        // Constant-time comparison of equal-length MACs.
        guard expected.count == actual.count else { return false }
        return zip(expected, actual).reduce(UInt8(0)) { $0 | ($1.0 ^ $1.1) } == 0
    }

    static func publicKey(_ data: Data) throws -> Curve25519.KeyAgreement.PublicKey {
        do {
            return try Curve25519.KeyAgreement.PublicKey(rawRepresentation: data)
        } catch {
            throw PairingError.invalidKey
        }
    }

    static func agree(_ privateKey: Curve25519.KeyAgreement.PrivateKey, with peer: Data) throws -> SharedSecret {
        do {
            return try privateKey.sharedSecretFromKeyAgreement(with: try publicKey(peer))
        } catch {
            throw PairingError.invalidKey
        }
    }
}

/// SHA-256 over length-prefixed fields, so no two different field lists hash the same bytes.
struct LengthPrefixedHash {
    private(set) var bytes = Data()

    init(label: String) {
        add(label)
    }

    mutating func add(_ string: String) {
        add(Data(string.utf8))
    }

    mutating func add(_ data: Data) {
        var length = UInt32(data.count).bigEndian
        bytes.append(Data(bytes: &length, count: 4))
        bytes.append(data)
    }

    var digest: Data { Data(SHA256.hash(data: bytes)) }
}

// MARK: - Device side

public struct DevicePairing {
    private enum Stage { case created, requested, revealed, confirmed, done }

    public let deviceID: String
    public let deviceName: String
    private let privateKey: Curve25519.KeyAgreement.PrivateKey
    private let nonce: Data
    private var stage = Stage.created
    private var request: PairRequest?
    private var challenge: PairChallenge?
    private var transcript = Data()
    private var secret = Data()

    /// The code to show once the challenge arrives.
    public private(set) var code: String?

    public init(deviceID: String, deviceName: String,
                privateKey: Curve25519.KeyAgreement.PrivateKey = .init(), nonce: Data = PairingCrypto.randomNonce()) {
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.privateKey = privateKey
        self.nonce = nonce
    }

    public mutating func start() -> PairRequest {
        let commitment = PairingCrypto.commitment(deviceKey: privateKey.publicKey.rawRepresentation, deviceNonce: nonce)
        let request = PairRequest(deviceID: deviceID, deviceName: deviceName, commitment: commitment)
        self.request = request
        stage = .requested
        return request
    }

    /// Returns the reveal to send and the code to show.
    public mutating func receive(_ challenge: PairChallenge) throws -> (reveal: PairReveal, code: String) {
        guard stage == .requested, let request else { throw PairingError.unexpectedMessage }
        guard challenge.hostNonce.count == PairingCrypto.nonceLength else { throw PairingError.invalidNonce }
        let shared = try PairingCrypto.agree(privateKey, with: challenge.hostKey)
        let reveal = PairReveal(deviceKey: privateKey.publicKey.rawRepresentation, deviceNonce: nonce)
        transcript = PairingCrypto.transcript(request, challenge, reveal)
        secret = PairingCrypto.secret(shared: shared, transcript: transcript)
        let code = PairingCrypto.code(shared: shared, transcript: transcript)
        self.challenge = challenge
        self.code = code
        stage = .revealed
        return (reveal, code)
    }

    /// Call only after the person confirms the Mac shows the same code.
    public mutating func confirm() throws -> PairConfirm {
        guard stage == .revealed else { throw PairingError.unexpectedMessage }
        stage = .confirmed
        return PairConfirm(mac: PairingCrypto.deviceConfirmation(secret: secret, transcript: transcript))
    }

    public mutating func receive(_ complete: PairComplete) throws -> PairedHost {
        guard stage == .confirmed, let challenge else { throw PairingError.unexpectedMessage }
        let expected = PairingCrypto.hostConfirmation(secret: secret, transcript: transcript, pairID: complete.pairID)
        guard PairingCrypto.verify(expected, complete.mac) else { throw PairingError.confirmationFailed }
        stage = .done
        return PairedHost(hostID: challenge.hostID, hostName: challenge.hostName, pairID: complete.pairID, secret: secret)
    }
}

// MARK: - Host side

public struct HostPairing {
    private enum Stage { case waitingForRequest, challenged, revealed, confirmed, done }

    public let hostID: String
    public let hostName: String
    private let privateKey: Curve25519.KeyAgreement.PrivateKey
    private let nonce: Data
    private var stage = Stage.waitingForRequest
    private var request: PairRequest?
    private var challenge: PairChallenge?
    private var transcript = Data()
    private var secret = Data()

    /// The code to show next to Allow, once the device reveals its key.
    public private(set) var code: String?
    public var deviceName: String? { request?.deviceName }

    public init(hostID: String, hostName: String,
                privateKey: Curve25519.KeyAgreement.PrivateKey = .init(), nonce: Data = PairingCrypto.randomNonce()) {
        self.hostID = hostID
        self.hostName = hostName
        self.privateKey = privateKey
        self.nonce = nonce
    }

    public mutating func receive(_ request: PairRequest) throws -> PairChallenge {
        guard stage == .waitingForRequest else { throw PairingError.unexpectedMessage }
        guard request.commitment.count == 32 else { throw PairingError.commitmentMismatch }
        let challenge = PairChallenge(hostID: hostID, hostName: hostName, hostKey: privateKey.publicKey.rawRepresentation, hostNonce: nonce)
        self.request = request
        self.challenge = challenge
        stage = .challenged
        return challenge
    }

    /// Checks the commitment and returns the code to show.
    public mutating func receive(_ reveal: PairReveal) throws -> String {
        guard stage == .challenged, let request, let challenge else { throw PairingError.unexpectedMessage }
        guard reveal.deviceNonce.count == PairingCrypto.nonceLength else { throw PairingError.invalidNonce }
        let expected = PairingCrypto.commitment(deviceKey: reveal.deviceKey, deviceNonce: reveal.deviceNonce)
        guard PairingCrypto.verify(expected, request.commitment) else { throw PairingError.commitmentMismatch }
        let shared = try PairingCrypto.agree(privateKey, with: reveal.deviceKey)
        transcript = PairingCrypto.transcript(request, challenge, reveal)
        secret = PairingCrypto.secret(shared: shared, transcript: transcript)
        let code = PairingCrypto.code(shared: shared, transcript: transcript)
        self.code = code
        stage = .revealed
        return code
    }

    public mutating func receive(_ confirm: PairConfirm) throws {
        guard stage == .revealed else { throw PairingError.unexpectedMessage }
        let expected = PairingCrypto.deviceConfirmation(secret: secret, transcript: transcript)
        guard PairingCrypto.verify(expected, confirm.mac) else { throw PairingError.confirmationFailed }
        stage = .confirmed
    }

    /// Call only after the device confirmed and the person at the Mac clicked Allow.
    public mutating func complete(pairID: String, at date: Date = Date()) throws -> (message: PairComplete, device: PairedDevice) {
        guard stage == .confirmed, let request else { throw PairingError.unexpectedMessage }
        stage = .done
        let mac = PairingCrypto.hostConfirmation(secret: secret, transcript: transcript, pairID: pairID)
        let device = PairedDevice(pairID: pairID, deviceID: request.deviceID, deviceName: request.deviceName, secret: secret, pairedAt: date)
        return (PairComplete(pairID: pairID, mac: mac), device)
    }

    public var isConfirmedByDevice: Bool { stage == .confirmed }
}
