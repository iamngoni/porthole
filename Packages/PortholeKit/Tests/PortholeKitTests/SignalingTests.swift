import Foundation
import Network
import Testing
@testable import PortholeProtocol
@testable import PortholeSession

/// Pairing and sealed signaling over a real TCP socket on loopback, with the same connection class the apps use.
/// Loopback needs no Local Network permission, so this runs anywhere.
@Suite(.serialized)
@MainActor
struct SignalingTests {
    /// Listens on 127.0.0.1 and hands each new connection to `onConnection`.
    @MainActor
    final class LoopbackListener {
        let listener: NWListener
        var onConnection: ((NWConnection) -> Void)?

        init() throws {
            let parameters = NWParameters.tcp
            parameters.requiredInterfaceType = .loopback
            parameters.acceptLocalOnly = true
            listener = try NWListener(using: parameters, on: .any)
            listener.newConnectionHandler = { [weak self] connection in
                MainActor.assumeIsolated { self?.onConnection?(connection) }
            }
        }

        func start() async throws -> NWEndpoint {
            listener.start(queue: .main)
            try await waitUntil("listener ready") { listener.port != nil && listener.state == .ready }
            return .hostPort(host: "127.0.0.1", port: listener.port!)
        }

        deinit { listener.cancel() }
    }

    /// Runs both links over the two ends of one socket and records what happened.
    @MainActor
    final class Session {
        var hostLink: HostLink
        var deviceLink: DeviceLink
        var hostConnection: SignalingConnection?
        let deviceConnection: SignalingConnection
        var hostCode: String?
        var deviceCode: String?
        var pairedHost: PairedHost?
        var pairedDevice: PairedDevice?
        var hostDelivered: [SignalMessage] = []
        var deviceDelivered: [SignalMessage] = []
        var deviceEvents: [String] = []
        var deviceClosed = false

        init(hostLink: HostLink, deviceLink: DeviceLink, endpoint: NWEndpoint) {
            self.hostLink = hostLink
            self.deviceLink = deviceLink
            deviceConnection = SignalingConnection(endpoint: endpoint)
        }

        func attachHost(_ raw: NWConnection) {
            let connection = SignalingConnection(connection: raw)
            hostConnection = connection
            connection.onEvent = { [unowned self] event in
                if case .message(let message) = event { self.applyHost(self.hostLink.receive(message)) }
            }
            connection.start()
        }

        func startDevice() {
            deviceConnection.onEvent = { [unowned self] event in
                switch event {
                case .ready:
                    self.applyDevice(self.deviceLink.start())
                case .message(let message):
                    if case .bye(let reason) = message { self.deviceEvents.append("bye:\(reason)") }
                    self.applyDevice(self.deviceLink.receive(message))
                case .incompatible(let version, let reason):
                    self.deviceEvents.append("incompatible:\(version):\(reason ?? "-")")
                case .closed:
                    self.deviceEvents.append("closed")
                    self.deviceClosed = true
                }
            }
            deviceConnection.start()
        }

        private func applyHost(_ outputs: [HostLink.Output]) {
            for output in outputs {
                switch output {
                case .send(let message):
                    hostConnection?.send(message)
                case .askToPair(_, let code):
                    hostCode = code
                    applyHost(hostLink.approve(pairID: "pair"))
                case .paired(let device):
                    pairedDevice = device
                case .established:
                    break
                case .deliver(let message):
                    hostDelivered.append(message)
                    if case .hello = message {
                        hostConnection?.send(try! hostLink.seal(.welcome(HostWelcome(hostName: "Mac"))))
                        hostConnection?.send(try! hostLink.seal(.offer(sdp: "v=0")))
                    }
                case .close(let reason):
                    hostConnection?.close(reason)
                case .peerClosed:
                    hostConnection?.close()
                }
            }
        }

        private func applyDevice(_ outputs: [DeviceLink.Output]) {
            for output in outputs {
                switch output {
                case .send(let message):
                    deviceConnection.send(message)
                case .showCode(let code):
                    deviceCode = code
                    applyDevice(deviceLink.codesMatch())
                case .paired(let host):
                    pairedHost = host
                case .established:
                    deviceConnection.send(try! deviceLink.seal(.hello(ClientHello(deviceName: "iPad", viewport: PixelSize(width: 2752, height: 2064)))))
                case .deliver(let message):
                    deviceDelivered.append(message)
                case .close(let reason):
                    deviceConnection.close(reason)
                case .peerClosed:
                    break
                }
            }
        }
    }

    @Test func pairing_then_sealed_messages_cross_a_real_socket() async throws {
        let listener = try LoopbackListener()
        let endpoint = try await listener.start()
        let session = Session(
            hostLink: HostLink(hostID: "host", hostName: "Mac", lookup: { _ in nil }, pairingAllowed: { true }),
            deviceLink: DeviceLink(deviceID: "device", deviceName: "iPad", pairing: nil),
            endpoint: endpoint)
        listener.onConnection = { session.attachHost($0) }
        session.startDevice()

        try await waitUntil("welcome and offer on the device") { session.deviceDelivered.count == 2 }
        #expect(session.deviceCode != nil && session.deviceCode == session.hostCode)
        #expect(session.pairedHost?.secret == session.pairedDevice?.secret)
        #expect(session.hostDelivered == [.hello(ClientHello(deviceName: "iPad", viewport: PixelSize(width: 2752, height: 2064)))])
        #expect(session.deviceDelivered == [.welcome(HostWelcome(hostName: "Mac")), .offer(sdp: "v=0")])
        session.deviceConnection.close(.disconnected)
    }

    @Test func the_reason_for_closing_arrives_before_the_close() async throws {
        let listener = try LoopbackListener()
        let endpoint = try await listener.start()
        let session = Session(
            hostLink: HostLink(hostID: "host", hostName: "Mac", lookup: { _ in nil }, pairingAllowed: { false }),
            deviceLink: DeviceLink(deviceID: "device", deviceName: "iPad", pairing: nil),
            endpoint: endpoint)
        listener.onConnection = { session.attachHost($0) }
        session.startDevice()

        try await waitUntil("the device to see the close") { session.deviceClosed }
        #expect(session.deviceEvents == ["bye:pairing-closed", "closed"])
    }

    @Test func a_frame_from_another_version_is_reported_with_its_reason() async throws {
        let listener = try LoopbackListener()
        let endpoint = try await listener.start()
        let session = Session(
            hostLink: HostLink(hostID: "host", hostName: "Mac", lookup: { _ in nil }, pairingAllowed: { true }),
            deviceLink: DeviceLink(deviceID: "device", deviceName: "iPad", pairing: nil),
            endpoint: endpoint)
        var raw: NWConnection?
        listener.onConnection = { connection in
            raw = connection
            connection.start(queue: .main)
            let future = Data(#"{"v":99,"msg":{"bye":{"reason":"update"}}}"#.utf8)
            connection.send(content: Framing.frame(future), completion: .idempotent)
        }
        session.startDevice()

        try await waitUntil("the device to see the close") { session.deviceClosed }
        #expect(session.deviceEvents == ["incompatible:99:update", "closed"])
        raw?.cancel()
    }
}
