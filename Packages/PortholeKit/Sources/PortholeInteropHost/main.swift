import Foundation
import Network
import PortholeProtocol
import PortholeSession

// A Mac stand-in for the Dart interop test (Protocol/dart/test/interop_test.dart): the real HostLink and
// SignalingConnection on 127.0.0.1, with pairing approved automatically. Not part of any app.
//
// Prints one line per event on stdout ("listening <port>" first, then "code 123456", "paired",
// "established", "deliver hello", "close bad-frame", ...). It answers hello with welcome, an offer
// with an answer that quotes it, and echoes candidates. It exits when stdin closes.

func say(_ line: String) {
    print(line)
    fflush(stdout)
}

final class Session {
    let connection: SignalingConnection
    var link: HostLink

    init(connection: SignalingConnection, link: HostLink) {
        self.connection = connection
        self.link = link
    }

    func start() {
        connection.onEvent = { [self] event in
            switch event {
            case .ready: break
            case .message(let message): apply(link.receive(message))
            case .incompatible(let version, let reason): say("incompatible \(version) \(reason ?? "-")")
            case .closed: say("disconnected"); sessions.removeAll { $0 === self }
            }
        }
        connection.start()
    }

    func apply(_ outputs: [HostLink.Output]) {
        for output in outputs {
            switch output {
            case .send(let message):
                connection.send(message)
            case .askToPair(_, let code):
                say("code \(code)")
                apply(link.approve())
            case .paired(let device):
                pairings[device.pairID] = device
                say("paired \(device.deviceName)")
            case .established:
                say("established")
            case .deliver(let message):
                switch message {
                case .hello(let hello):
                    say("deliver hello \(hello.deviceName) \(hello.viewport.width)x\(hello.viewport.height)")
                    reply(.welcome(HostWelcome(hostName: "Interop Mac")))
                case .offer(let sdp):
                    say("deliver offer")
                    reply(.answer(sdp: "answer to \(sdp)"))
                case .candidate(let candidate):
                    say("deliver candidate")
                    reply(.candidate(candidate))
                case .welcome, .answer:
                    say("deliver other")
                }
            case .close(let reason):
                say("close \(reason.rawValue)")
                connection.close(reason)
            case .peerClosed(let reason):
                say("peer-closed \(reason)")
                connection.close()
            }
        }
    }

    func reply(_ message: SignalMessage) {
        guard let sealed = try? link.seal(message) else { return say("could not seal") }
        connection.send(sealed)
    }
}

var pairings: [String: PairedDevice] = [:]
var sessions: [Session] = []

let parameters = NWParameters.tcp
parameters.requiredInterfaceType = .loopback
parameters.acceptLocalOnly = true
let listener = try NWListener(using: parameters, on: .any)
listener.newConnectionHandler = { raw in
    let link = HostLink(hostID: "interop-host", hostName: "Interop Mac", lookup: { pairings[$0] }, pairingAllowed: { true })
    let session = Session(connection: SignalingConnection(connection: raw), link: link)
    sessions.append(session)
    session.start()
}
listener.stateUpdateHandler = { state in
    switch state {
    case .ready: say("listening \(listener.port!.rawValue)")
    case .failed(let error): say("failed \(error)"); exit(1)
    default: break
    }
}
listener.start(queue: .main)

FileHandle.standardInput.readabilityHandler = { handle in
    if handle.availableData.isEmpty { exit(0) }
}
dispatchMain()
