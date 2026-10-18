import CryptoKit
import Foundation

// Every connection from a paired device starts with a mutual proof of the pairing secret,
// then derives fresh keys for that connection only:
//
//  device: sessionHello{pairID, nD, MAC(secret, pairID ‖ nD)}
//  host:   sessionAccept{nM, MAC(secret, pairID ‖ nD ‖ nM)}
//  keys:   HKDF(secret, salt nD ‖ nM, "d2m" / "m2d")
//
// After that, each SignalMessage is sealed with ChaCha20-Poly1305. The nonce is a per-direction
// counter that must arrive in order with no gaps, which rejects replayed, reordered and dropped frames.
// The SDP inside carries WebRTC's DTLS fingerprint, so media and data channels are authenticated end to end.

public enum SecureChannelError: Error, Equatable, Sendable {
    case outOfOrder(expected: UInt64, received: UInt64)
    case authenticationFailed
    case exhausted
}

public enum SessionRole: Sendable {
    case device, host
}

public enum SessionHandshake {
    public static func hello(pairID: String, secret: Data, nonce: Data = PairingCrypto.randomNonce()) -> SessionHello {
        SessionHello(pairID: pairID, nonce: nonce, mac: helloMAC(pairID: pairID, nonce: nonce, secret: secret))
    }

    public static func isValid(_ hello: SessionHello, secret: Data) -> Bool {
        hello.nonce.count == PairingCrypto.nonceLength
            && PairingCrypto.verify(helloMAC(pairID: hello.pairID, nonce: hello.nonce, secret: secret), hello.mac)
    }

    public static func accept(_ hello: SessionHello, secret: Data, nonce: Data = PairingCrypto.randomNonce()) -> SessionAccept {
        SessionAccept(nonce: nonce, mac: acceptMAC(hello: hello, nonce: nonce, secret: secret))
    }

    public static func isValid(_ accept: SessionAccept, for hello: SessionHello, secret: Data) -> Bool {
        accept.nonce.count == PairingCrypto.nonceLength
            && PairingCrypto.verify(acceptMAC(hello: hello, nonce: accept.nonce, secret: secret), accept.mac)
    }

    /// The channel for one side of a connection whose handshake both sides have verified.
    public static func channel(role: SessionRole, secret: Data, hello: SessionHello, accept: SessionAccept) -> SecureChannel {
        let master = SymmetricKey(data: secret)
        let salt = hello.nonce + accept.nonce
        func key(_ info: String) -> SymmetricKey {
            HKDF<SHA256>.deriveKey(inputKeyMaterial: master, salt: salt, info: Data(info.utf8), outputByteCount: 32)
        }
        let deviceToHost = key("porthole-d2m-v1")
        let hostToDevice = key("porthole-m2d-v1")
        let d2mData = Data("porthole-v2|\(hello.pairID)|d2m".utf8)
        let m2dData = Data("porthole-v2|\(hello.pairID)|m2d".utf8)
        switch role {
        case .device:
            return SecureChannel(sendKey: deviceToHost, sendAAD: d2mData, receiveKey: hostToDevice, receiveAAD: m2dData)
        case .host:
            return SecureChannel(sendKey: hostToDevice, sendAAD: m2dData, receiveKey: deviceToHost, receiveAAD: d2mData)
        }
    }

    private static func helloMAC(pairID: String, nonce: Data, secret: Data) -> Data {
        PairingCrypto.mac(secret, "session-hello", Data(pairID.utf8), nonce)
    }

    private static func acceptMAC(hello: SessionHello, nonce: Data, secret: Data) -> Data {
        PairingCrypto.mac(secret, "session-accept", Data(hello.pairID.utf8), hello.nonce, nonce)
    }
}

/// One direction pair of a secured connection. Not thread-safe; use from one queue.
public struct SecureChannel {
    private let sendKey: SymmetricKey
    private let sendAAD: Data
    private let receiveKey: SymmetricKey
    private let receiveAAD: Data
    private var sendCounter: UInt64 = 0
    private var receiveCounter: UInt64 = 0

    init(sendKey: SymmetricKey, sendAAD: Data, receiveKey: SymmetricKey, receiveAAD: Data) {
        self.sendKey = sendKey
        self.sendAAD = sendAAD
        self.receiveKey = receiveKey
        self.receiveAAD = receiveAAD
    }

    public mutating func seal(_ plaintext: Data) throws -> SealedFrame {
        guard sendCounter < .max else { throw SecureChannelError.exhausted }
        let counter = sendCounter
        let sealed = try ChaChaPoly.seal(plaintext, using: sendKey, nonce: Self.nonce(counter), authenticating: sendAAD)
        sendCounter += 1
        return SealedFrame(counter: counter, box: sealed.ciphertext + sealed.tag)
    }

    public mutating func open(_ frame: SealedFrame) throws -> Data {
        guard frame.counter == receiveCounter else {
            throw SecureChannelError.outOfOrder(expected: receiveCounter, received: frame.counter)
        }
        guard frame.box.count >= 16 else { throw SecureChannelError.authenticationFailed }
        do {
            let box = try ChaChaPoly.SealedBox(nonce: Self.nonce(frame.counter), ciphertext: frame.box.dropLast(16), tag: frame.box.suffix(16))
            let plaintext = try ChaChaPoly.open(box, using: receiveKey, authenticating: receiveAAD)
            receiveCounter += 1
            return plaintext
        } catch {
            throw SecureChannelError.authenticationFailed
        }
    }

    private static func nonce(_ counter: UInt64) -> ChaChaPoly.Nonce {
        var big = counter.bigEndian
        let bytes = Data(repeating: 0, count: 4) + Data(bytes: &big, count: 8)
        return try! ChaChaPoly.Nonce(data: bytes)
    }
}
