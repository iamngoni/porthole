import Foundation
import PropertyBased
import Testing
@testable import PortholeProtocol

@Suite(.shrinking)
struct SecureChannelTests {
    static let pairID = "pair-123"

    static var genSecret: Gen_<Data> {
        Gen.uint8(in: 0...255).array(of: 32).map { Data($0) }.eraseToAny()
    }

    static var genPayloads: Gen_<[Data]> {
        Gen.uint8(in: 0...255).array(of: 0...200).map { Data($0) }.array(of: 1...8).eraseToAny()
    }

    /// Both ends of a connection after an honest handshake.
    static func connected(secret: Data) -> (device: SecureChannel, host: SecureChannel) {
        let hello = SessionHandshake.hello(pairID: pairID, secret: secret)
        let accept = SessionHandshake.accept(hello, secret: secret)
        return (
            SessionHandshake.channel(role: .device, secret: secret, hello: hello, accept: accept),
            SessionHandshake.channel(role: .host, secret: secret, hello: hello, accept: accept)
        )
    }

    // MARK: Properties

    @Test func prop_messages_roundtrip_in_both_directions() async throws {
        await propertyCheck(count: 200, input: Self.genSecret, Self.genPayloads) { secret, payloads in
            var (device, host) = Self.connected(secret: secret)
            for payload in payloads {
                let toHost = try device.seal(payload)
                #expect(try host.open(toHost) == payload)
                let toDevice = try host.seal(payload)
                #expect(try device.open(toDevice) == payload)
            }
        }
    }

    @Test func prop_any_flipped_bit_is_rejected() async throws {
        await propertyCheck(count: 300, input: Self.genSecret, Gen.uint8(in: 0...255).array(of: 0...64), Gen.int(in: 0...10_000)) { secret, bytes, bit in
            var (device, host) = Self.connected(secret: secret)
            var frame = try device.seal(Data(bytes))
            let index = frame.box.startIndex + (bit / 8) % frame.box.count
            frame.box[index] ^= 1 << UInt8(bit % 8)
            #expect(throws: SecureChannelError.authenticationFailed) { try host.open(frame) }
        }
    }

    @Test func prop_replayed_or_skipped_frames_are_rejected() async throws {
        await propertyCheck(count: 200, input: Self.genSecret, Self.genPayloads, Gen.int(in: 0...7)) { secret, payloads, pick in
            var (device, host) = Self.connected(secret: secret)
            let frames = try payloads.map { try device.seal($0) }
            let opened = pick % frames.count
            for frame in frames[...opened] { _ = try host.open(frame) }
            // Replaying any frame already seen fails, and so does jumping ahead.
            #expect(throws: SecureChannelError.self) { try host.open(frames[pick % (opened + 1)]) }
            if opened + 2 < frames.count {
                #expect(throws: SecureChannelError.outOfOrder(expected: UInt64(opened + 1), received: UInt64(opened + 2))) {
                    try host.open(frames[opened + 2])
                }
            }
        }
    }

    @Test func prop_a_side_cannot_open_its_own_frames() async throws {
        // Directions use separate keys, so a frame reflected back to its sender is rejected.
        await propertyCheck(count: 100, input: Self.genSecret, Gen.uint8(in: 0...255).array(of: 0...64)) { secret, bytes in
            var (device, _) = Self.connected(secret: secret)
            let frame = try device.seal(Data(bytes))
            #expect(throws: SecureChannelError.authenticationFailed) { try device.open(frame) }
        }
    }

    @Test func prop_handshake_with_the_wrong_secret_fails_both_ways() async throws {
        await propertyCheck(count: 200, input: Self.genSecret, Self.genSecret) { real, wrong in
            guard real != wrong else { return }
            let forged = SessionHandshake.hello(pairID: Self.pairID, secret: wrong)
            #expect(!SessionHandshake.isValid(forged, secret: real))

            let hello = SessionHandshake.hello(pairID: Self.pairID, secret: real)
            #expect(SessionHandshake.isValid(hello, secret: real))
            let fakeAccept = SessionHandshake.accept(hello, secret: wrong)
            #expect(!SessionHandshake.isValid(fakeAccept, for: hello, secret: real))
        }
    }

    @Test func prop_a_replayed_hello_yields_keys_the_replayer_cannot_use() async throws {
        // An eavesdropper can resend an old hello, but the host answers with a fresh nonce,
        // so frames sealed under the old connection's keys don't open on the new one.
        await propertyCheck(count: 100, input: Self.genSecret, Gen.uint8(in: 0...255).array(of: 1...64)) { secret, bytes in
            let hello = SessionHandshake.hello(pairID: Self.pairID, secret: secret)
            let firstAccept = SessionHandshake.accept(hello, secret: secret)
            var oldDevice = SessionHandshake.channel(role: .device, secret: secret, hello: hello, accept: firstAccept)
            let secondAccept = SessionHandshake.accept(hello, secret: secret)
            var newHost = SessionHandshake.channel(role: .host, secret: secret, hello: hello, accept: secondAccept)
            #expect(throws: SecureChannelError.authenticationFailed) { try newHost.open(try oldDevice.seal(Data(bytes))) }
        }
    }

    // MARK: Examples

    @Test func a_hello_for_another_pairing_is_rejected() {
        let secret = Data(repeating: 7, count: 32)
        var hello = SessionHandshake.hello(pairID: "a", secret: secret)
        hello.pairID = "b"
        #expect(!SessionHandshake.isValid(hello, secret: secret))
    }

    @Test func a_short_nonce_is_rejected() {
        let secret = Data(repeating: 7, count: 32)
        let hello = SessionHandshake.hello(pairID: "a", secret: secret, nonce: Data([1, 2, 3]))
        #expect(!SessionHandshake.isValid(hello, secret: secret))
    }

    @Test func a_truncated_box_is_rejected() {
        var (_, host) = Self.connected(secret: Data(repeating: 1, count: 32))
        #expect(throws: SecureChannelError.authenticationFailed) { try host.open(SealedFrame(counter: 0, box: Data([1, 2]))) }
    }
}
