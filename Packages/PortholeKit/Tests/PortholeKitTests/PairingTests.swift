import CryptoKit
import Foundation
import PropertyBased
import Testing
@testable import PortholeProtocol

@Suite(.shrinking)
struct PairingTests {
    struct Names: Sendable {
        var deviceID: String
        var deviceName: String
        var hostID: String
        var hostName: String
    }

    static var genNames: Gen_<Names> {
        zip(genText, genText, genText, genText).map { Names(deviceID: $0, deviceName: $1, hostID: $2, hostName: $3) }.eraseToAny()
    }

    struct Run {
        var device: DevicePairing
        var host: HostPairing
        var request: PairRequest
        var challenge: PairChallenge
        var reveal: PairReveal
        var deviceCode: String
        var hostCode: String
    }

    /// Runs an honest exchange up to the point where both screens show a code.
    static func exchange(_ names: Names) throws -> Run {
        var device = DevicePairing(deviceID: names.deviceID, deviceName: names.deviceName)
        var host = HostPairing(hostID: names.hostID, hostName: names.hostName)
        let request = device.start()
        let challenge = try host.receive(request)
        let (reveal, deviceCode) = try device.receive(challenge)
        let hostCode = try host.receive(reveal)
        return Run(device: device, host: host, request: request, challenge: challenge, reveal: reveal, deviceCode: deviceCode, hostCode: hostCode)
    }

    static func flipOneBit(_ data: Data, at index: Int) -> Data {
        var copy = data
        let position = copy.startIndex + index % max(copy.count, 1)
        copy[position] ^= 1 << UInt8(index % 8)
        return copy
    }

    // MARK: Properties

    @Test func prop_honest_pairing_shows_the_same_code_and_ends_with_the_same_secret() async throws {
        await propertyCheck(count: 100, input: Self.genNames) { names in
            var run = try Self.exchange(names)
            #expect(run.deviceCode == run.hostCode)

            try run.host.receive(try run.device.confirm())
            let (complete, device) = try run.host.complete(pairID: "pair-1")
            let host = try run.device.receive(complete)

            #expect(host.secret == device.secret)
            #expect(host.secret.count == 32)
            #expect(host.pairID == "pair-1" && device.pairID == "pair-1")
            #expect(host.hostID == names.hostID && device.deviceID == names.deviceID)
            #expect(device.deviceName == names.deviceName && host.hostName == names.hostName)
        }
    }

    @Test func prop_code_is_always_six_digits() async throws {
        await propertyCheck(count: 200, input: Self.genNames) { names in
            let code = try Self.exchange(names).deviceCode
            #expect(code.count == 6 && code.allSatisfy(\.isASCII) && code.allSatisfy(\.isNumber))
        }
    }

    @Test func prop_reveal_that_does_not_match_the_commitment_is_rejected() async throws {
        await propertyCheck(count: 200, input: Self.genNames, Gen.int(in: 0...511), Gen.bool) { names, bit, tamperKey in
            var device = DevicePairing(deviceID: names.deviceID, deviceName: names.deviceName)
            var host = HostPairing(hostID: names.hostID, hostName: names.hostName)
            let challenge = try host.receive(device.start())
            var (reveal, _) = try device.receive(challenge)
            if tamperKey {
                reveal.deviceKey = Self.flipOneBit(reveal.deviceKey, at: bit)
            } else {
                reveal.deviceNonce = Self.flipOneBit(reveal.deviceNonce, at: bit)
            }
            #expect(throws: PairingError.commitmentMismatch) { try host.receive(reveal) }
        }
    }

    @Test func prop_man_in_the_middle_ends_up_with_different_codes() async throws {
        // The attacker pairs with each side separately and relays the names. Matching codes would need
        // a one-in-a-million coincidence, so across 100 runs this fails with probability about 1e-4.
        await propertyCheck(count: 100, input: Self.genNames) { names in
            var device = DevicePairing(deviceID: names.deviceID, deviceName: names.deviceName)
            var host = HostPairing(hostID: names.hostID, hostName: names.hostName)
            var fakeHost = HostPairing(hostID: names.hostID, hostName: names.hostName)
            var fakeDevice = DevicePairing(deviceID: names.deviceID, deviceName: names.deviceName)

            let deviceRequest = device.start()
            let toDevice = try fakeHost.receive(deviceRequest)
            let realChallenge = try host.receive(fakeDevice.start())
            let (deviceReveal, deviceCode) = try device.receive(toDevice)
            _ = try fakeHost.receive(deviceReveal)
            let (fakeReveal, _) = try fakeDevice.receive(realChallenge)
            let hostCode = try host.receive(fakeReveal)

            #expect(deviceCode != hostCode)
        }
    }

    @Test func prop_confirmation_from_another_pairing_is_rejected() async throws {
        await propertyCheck(count: 100, input: Self.genNames) { names in
            var first = try Self.exchange(names)
            var second = try Self.exchange(names)
            #expect(throws: PairingError.confirmationFailed) { try second.host.receive(try first.device.confirm()) }
        }
    }

    @Test func prop_completion_for_another_pair_id_is_rejected() async throws {
        await propertyCheck(count: 100, input: Self.genNames, genText) { names, otherID in
            var run = try Self.exchange(names)
            try run.host.receive(try run.device.confirm())
            var (complete, _) = try run.host.complete(pairID: "real")
            guard otherID != "real" else { return }
            complete.pairID = otherID
            #expect(throws: PairingError.confirmationFailed) { try run.device.receive(complete) }
        }
    }

    // MARK: Examples

    @Test func host_cannot_complete_before_the_device_confirms() throws {
        var run = try Self.exchange(Names(deviceID: "d", deviceName: "iPad", hostID: "h", hostName: "Mac"))
        #expect(throws: PairingError.unexpectedMessage) { _ = try run.host.complete(pairID: "p") }
    }

    @Test func device_cannot_confirm_before_seeing_a_code() {
        var device = DevicePairing(deviceID: "d", deviceName: "iPad")
        _ = device.start()
        #expect(throws: PairingError.unexpectedMessage) { _ = try device.confirm() }
    }

    @Test func a_garbage_host_key_is_rejected() throws {
        var device = DevicePairing(deviceID: "d", deviceName: "iPad")
        _ = device.start()
        let challenge = PairChallenge(hostID: "h", hostName: "Mac", hostKey: Data([1, 2, 3]), hostNonce: PairingCrypto.randomNonce())
        #expect(throws: PairingError.invalidKey) { _ = try device.receive(challenge) }
    }

    /// Pins the derivation: changing a label, field order or KDF breaks pairing between app versions.
    @Test func known_answer_for_fixed_keys_and_nonces() throws {
        let deviceKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: Data(repeating: 0x11, count: 32))
        let hostKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: Data(repeating: 0x22, count: 32))
        var device = DevicePairing(deviceID: "device-1", deviceName: "iPad", privateKey: deviceKey, nonce: Data(repeating: 0x33, count: 32))
        var host = HostPairing(hostID: "host-1", hostName: "Mac", privateKey: hostKey, nonce: Data(repeating: 0x44, count: 32))
        let challenge = try host.receive(device.start())
        let (reveal, code) = try device.receive(challenge)
        #expect(try host.receive(reveal) == code)
        #expect(code == KnownAnswer.code)
    }
}

/// Recorded from the first run of `known_answer_for_fixed_keys_and_nonces`. Never edit to make it pass.
enum KnownAnswer {
    static let code = "584379"
}
