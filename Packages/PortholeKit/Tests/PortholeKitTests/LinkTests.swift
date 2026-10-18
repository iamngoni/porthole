import Foundation
import PropertyBased
import Testing
@testable import PortholeProtocol

@Suite(.shrinking)
struct LinkTests {
    /// Carries messages between a device and a Mac until neither has anything left to send,
    /// and keeps everything each side said or sent.
    struct Harness {
        var device: DeviceLink
        var host: HostLink
        var deviceOutputs: [DeviceLink.Output] = []
        var hostOutputs: [HostLink.Output] = []
        var deviceToHost: [WireMessage] = []

        mutating func pump(device fromDevice: [DeviceLink.Output] = [], host fromHost: [HostLink.Output] = []) {
            var toHost: [WireMessage] = []
            var toDevice: [WireMessage] = []
            absorb(fromDevice, into: &toHost)
            absorb(fromHost, into: &toDevice)
            while !toHost.isEmpty || !toDevice.isEmpty {
                if !toHost.isEmpty {
                    let message = toHost.removeFirst()
                    deviceToHost.append(message)
                    absorb(host.receive(message), into: &toDevice)
                }
                if !toDevice.isEmpty {
                    absorb(device.receive(toDevice.removeFirst()), into: &toHost)
                }
            }
        }

        private mutating func absorb(_ outputs: [DeviceLink.Output], into wire: inout [WireMessage]) {
            for output in outputs {
                deviceOutputs.append(output)
                if case .send(let message) = output { wire.append(message) }
                if case .close(let reason) = output { wire.append(.bye(reason: reason.rawValue)) }
            }
        }

        private mutating func absorb(_ outputs: [HostLink.Output], into wire: inout [WireMessage]) {
            for output in outputs {
                hostOutputs.append(output)
                if case .send(let message) = output { wire.append(message) }
                if case .close(let reason) = output { wire.append(.bye(reason: reason.rawValue)) }
            }
        }

        var deviceDelivered: [SignalMessage] {
            deviceOutputs.compactMap { if case .deliver(let m) = $0 { m } else { nil } }
        }

        var hostDelivered: [SignalMessage] {
            hostOutputs.compactMap { if case .deliver(let m) = $0 { m } else { nil } }
        }

        var hostEstablishedCount: Int {
            hostOutputs.filter { if case .established = $0 { true } else { false } }.count
        }
    }

    struct Saved: Sendable {
        var host: PairedHost
        var device: PairedDevice
    }

    static var genSecret: Gen_<Data> {
        Gen.uint8(in: 0...255).array(of: 32).map { Data($0) }.eraseToAny()
    }

    /// A pairing both sides saved earlier.
    static var genSaved: Gen_<Saved> {
        zip(genText, genText, genSecret).map { pairID, name, secret in
            Saved(host: PairedHost(hostID: "host", hostName: "Mac", pairID: pairID, secret: secret),
                  device: PairedDevice(pairID: pairID, deviceID: "device", deviceName: name, secret: secret, pairedAt: .distantPast))
        }.eraseToAny()
    }

    static func newPairing(allowed: Bool = true) -> Harness {
        Harness(device: DeviceLink(deviceID: "device", deviceName: "iPad", pairing: nil),
                host: HostLink(hostID: "host", hostName: "Mac", lookup: { _ in nil }, pairingAllowed: { allowed }))
    }

    static func reconnect(_ saved: Saved) -> Harness {
        Harness(device: DeviceLink(deviceID: "device", deviceName: saved.device.deviceName, pairing: saved.host),
                host: HostLink(hostID: "host", hostName: "Mac",
                               lookup: { $0 == saved.device.pairID ? saved.device : nil },
                               pairingAllowed: { false }))
    }

    static func isEstablished(_ output: HostLink.Output) -> Bool {
        if case .established = output { true } else { false }
    }

    static func letsSomeoneIn(_ output: HostLink.Output) -> Bool {
        switch output {
        case .established, .deliver, .paired: true
        default: false
        }
    }

    static func letsSomeoneIn(_ output: DeviceLink.Output) -> Bool {
        switch output {
        case .established, .deliver, .paired: true
        default: false
        }
    }

    // MARK: Properties

    @Test func prop_pairing_then_messages_arrive_intact_and_in_order() async throws {
        await propertyCheck(count: 60, input: genSignalMessage.array(of: 1...6), genSignalMessage.array(of: 1...6), Gen.bool) { up, down, deviceFirst in
            var h = Self.newPairing()
            h.pump(device: h.device.start())

            let shown = h.deviceOutputs.compactMap { if case .showCode(let c) = $0 { c } else { nil } }
            let asked = h.hostOutputs.compactMap { if case .askToPair(_, let c) = $0 { c } else { nil } }
            #expect(shown.count == 1 && shown == asked)

            if deviceFirst {
                h.pump(device: h.device.codesMatch())
                h.pump(host: h.host.approve(pairID: "pair"))
            } else {
                h.pump(host: h.host.approve(pairID: "pair"))
                h.pump(device: h.device.codesMatch())
            }

            let host = try #require(h.deviceOutputs.compactMap { if case .paired(let p) = $0 { p } else { nil } }.first)
            let device = try #require(h.hostOutputs.compactMap { if case .paired(let p) = $0 { p } else { nil } }.first)
            #expect(host.secret == device.secret && host.pairID == "pair" && device.pairID == "pair")
            #expect(h.device.phase == .established)

            for message in up { h.pump(device: [.send(try h.device.seal(message))]) }
            for message in down { h.pump(host: [.send(try h.host.seal(message))]) }
            #expect(h.hostDelivered == up)
            #expect(h.deviceDelivered == down)
            #expect(h.hostEstablishedCount == 1)
        }
    }

    @Test func prop_saved_pairing_reconnects_without_codes() async throws {
        await propertyCheck(count: 100, input: Self.genSaved, genSignalMessage) { saved, first in
            var h = Self.reconnect(saved)
            h.pump(device: h.device.start())
            #expect(h.device.phase == .established)
            #expect(h.host.phase == .handshaking)

            h.pump(device: [.send(try h.device.seal(first))])
            #expect(h.hostOutputs.contains(.established(saved.device)))
            #expect(h.hostDelivered == [first])
            #expect(!h.deviceOutputs.contains { if case .showCode = $0 { true } else { false } })
        }
    }

    @Test func prop_a_replayed_session_never_gets_in() async throws {
        // Someone records a whole session off the network and plays the device's half to the Mac later.
        await propertyCheck(count: 100, input: Self.genSaved, genSignalMessage.array(of: 1...4)) { saved, messages in
            var original = Self.reconnect(saved)
            original.pump(device: original.device.start())
            for message in messages { original.pump(device: [.send(try original.device.seal(message))]) }

            var replayed = Self.reconnect(saved).host
            var outputs: [HostLink.Output] = []
            for message in original.deviceToHost { outputs += replayed.receive(message) }
            #expect(!outputs.contains(where: Self.letsSomeoneIn))
            #expect(outputs.contains(.close(.badFrame)))
        }
    }

    @Test func prop_a_tampered_frame_is_never_delivered() async throws {
        await propertyCheck(count: 200, input: Self.genSaved, genSignalMessage, Gen.int(in: 0...4095), Gen.bool) { saved, message, bit, tamperCounter in
            var h = Self.reconnect(saved)
            h.pump(device: h.device.start())
            guard case .sealed(var frame) = try h.device.seal(message) else {
                Issue.record("seal did not produce a sealed frame")
                return
            }
            if tamperCounter {
                frame.counter ^= 1 << UInt64(bit % 64)
            } else {
                frame.box = PairingTests.flipOneBit(frame.box, at: bit)
            }
            let outputs = h.host.receive(.sealed(frame))
            #expect(outputs == [.close(.badFrame)])
        }
    }

    @Test func prop_strangers_never_get_in() async throws {
        // Without the secret, no sequence of messages earns a pairing, a session or a delivered message,
        // even when the Mac is accepting new devices and recognizes every pair ID.
        await propertyCheck(count: 300, input: genWireMessage.array(of: 1...12), Self.genSaved, Gen.bool) { messages, saved, allowPairing in
            var host = HostLink(hostID: "host", hostName: "Mac", lookup: { _ in saved.device }, pairingAllowed: { allowPairing })
            var outputs: [HostLink.Output] = []
            for message in messages { outputs += host.receive(message) }
            #expect(!outputs.contains(where: Self.letsSomeoneIn))
        }
    }

    @Test func prop_a_fake_mac_never_gets_in() async throws {
        await propertyCheck(count: 300, input: genWireMessage.array(of: 1...12), Self.genSaved, Gen.bool) { messages, saved, isPaired in
            var device = DeviceLink(deviceID: "device", deviceName: "iPad", pairing: isPaired ? saved.host : nil)
            var outputs = device.start()
            for message in messages {
                outputs += device.receive(message)
                outputs += device.codesMatch()
            }
            #expect(!outputs.contains(where: Self.letsSomeoneIn))
        }
    }

    // MARK: Examples

    @Test func a_mac_not_accepting_devices_says_so() {
        var h = Self.newPairing(allowed: false)
        h.pump(device: h.device.start())
        #expect(h.deviceOutputs.last == .peerClosed(reason: CloseReason.pairingClosed.rawValue))
        #expect(h.device.phase == .closed && h.host.phase == .closed)
    }

    @Test func dont_allow_on_the_mac_ends_pairing() {
        var h = Self.newPairing()
        h.pump(device: h.device.start())
        h.pump(device: h.device.codesMatch())
        h.pump(host: h.host.deny())
        #expect(h.deviceOutputs.last == .peerClosed(reason: CloseReason.pairingDenied.rawValue))
        #expect(!h.deviceOutputs.contains(where: Self.letsSomeoneIn) && !h.hostOutputs.contains(where: Self.letsSomeoneIn))
    }

    @Test func codes_that_differ_end_pairing_on_both_sides() {
        var h = Self.newPairing()
        h.pump(device: h.device.start())
        h.pump(device: h.device.codesDiffer())
        h.pump(host: h.host.approve())
        #expect(h.hostOutputs.contains(.peerClosed(reason: CloseReason.pairingFailed.rawValue)))
        #expect(!h.hostOutputs.contains(where: Self.letsSomeoneIn))
    }

    @Test func a_pairing_removed_on_the_mac_is_reported_as_unknown() {
        let saved = Saved(host: PairedHost(hostID: "host", hostName: "Mac", pairID: "gone", secret: Data(repeating: 1, count: 32)),
                          device: PairedDevice(pairID: "other", deviceID: "device", deviceName: "iPad", secret: Data(), pairedAt: .distantPast))
        var h = Self.reconnect(saved)
        h.pump(device: h.device.start())
        #expect(h.deviceOutputs.last == .peerClosed(reason: CloseReason.unknownPairing.rawValue))
    }

    @Test func a_mismatched_secret_fails_the_handshake() {
        var h = Harness(
            device: DeviceLink(deviceID: "device", deviceName: "iPad",
                               pairing: PairedHost(hostID: "host", hostName: "Mac", pairID: "p", secret: Data(repeating: 1, count: 32))),
            host: HostLink(hostID: "host", hostName: "Mac",
                           lookup: { _ in PairedDevice(pairID: "p", deviceID: "device", deviceName: "iPad", secret: Data(repeating: 2, count: 32), pairedAt: .distantPast) },
                           pairingAllowed: { false }))
        h.pump(device: h.device.start())
        #expect(h.hostOutputs == [.close(.handshakeFailed)])
        #expect(h.device.phase == .closed)
    }

    @Test func nothing_is_sealed_before_the_session_is_up() {
        var device = DeviceLink(deviceID: "d", deviceName: "iPad", pairing: nil)
        _ = device.start()
        #expect(throws: LinkError.notEstablished) { _ = try device.seal(.welcome(HostWelcome(hostName: "Mac"))) }
        var host = HostLink(hostID: "h", hostName: "Mac", lookup: { _ in nil }, pairingAllowed: { true })
        #expect(throws: LinkError.notEstablished) { _ = try host.seal(.welcome(HostWelcome(hostName: "Mac"))) }
    }

    @Test func approving_before_the_code_is_shown_does_nothing() {
        var h = Self.newPairing()
        let request = h.device.start()
        guard case .send(let message) = request.first else {
            Issue.record("device did not send a pair request")
            return
        }
        _ = h.host.receive(message)
        #expect(h.host.approve().isEmpty)
        #expect(h.host.phase == .pairing)
    }
}

extension LinkTests {
    @Test func a_mac_answering_with_another_id_is_refused() {
        var h = Harness(device: DeviceLink(deviceID: "device", deviceName: "iPad", pairing: nil, expectedHostID: "the-mac-i-tapped"),
                        host: HostLink(hostID: "someone-else", hostName: "Mac", lookup: { _ in nil }, pairingAllowed: { true }))
        h.pump(device: h.device.start())
        #expect(h.deviceOutputs.last == .close(.pairingFailed))
        #expect(!h.deviceOutputs.contains { if case .showCode = $0 { true } else { false } })
    }

    @Test func the_mac_i_tapped_pairs_normally() {
        var h = Harness(device: DeviceLink(deviceID: "device", deviceName: "iPad", pairing: nil, expectedHostID: "host"),
                        host: HostLink(hostID: "host", hostName: "Mac", lookup: { _ in nil }, pairingAllowed: { true }))
        h.pump(device: h.device.start())
        #expect(h.device.phase == .comparingCodes)
    }
}
