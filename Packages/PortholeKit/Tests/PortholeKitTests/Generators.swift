import Foundation
import PropertyBased
@testable import PortholeProtocol

/// Generators are type-erased and computed so they can be shared across tests under strict concurrency.
typealias Gen_<T> = Generator<T, AnySequence<Any>>

/// Picks one of the given values. Gen.element yields an optional, which is never nil for a non-empty list.
func pick<T: Sendable>(_ values: [T]) -> Gen_<T> {
    precondition(!values.isEmpty)
    return Gen<T?>.element(of: values).map { $0! }.eraseToAny()
}

/// Short strings that mix plain text with the characters most likely to break encoders.
var genText: Gen_<String> {
    Gen.oneOf(
        Gen.letterOrNumber.string(of: 0...12).eraseToAny(),
        pick(["", " ", "é", "🪟 Window", "日本語", "\"quoted\"", "back\\slash", "line\r\nbreak", "tab\there", "\u{0}"])
    ).eraseToAny()
}

var genPixelSize: Gen_<PixelSize> {
    zip(Gen.int(in: 0...8000), Gen.int(in: 0...8000)).map { PixelSize(width: $0, height: $1) }.eraseToAny()
}

var genPointSize: Gen_<PointSize> {
    zip(Gen.double(in: 0...6000), Gen.double(in: 0...6000)).map { PointSize(width: $0, height: $1) }.eraseToAny()
}

var genWindowInfo: Gen_<WindowInfo> {
    zip(
        zip(Gen.uint32(in: 1...UInt32.max), genText, genText),
        zip(genText.optional, Gen.int32(in: 1...99_999), genPointSize, Gen.bool)
    ).map { head, tail in
        WindowInfo(id: head.0, title: head.1, appName: head.2, bundleID: tail.0, pid: tail.1, size: tail.2, isOnScreen: tail.3)
    }.eraseToAny()
}

var genStreamInfo: Gen_<StreamInfo> {
    zip(
        zip(Gen.uint32(in: 0...UInt32.max), Gen.uint32(in: 0...UInt32.max), genText),
        zip(genText, genPointSize, genPixelSize, Gen.int(in: 1...240).optional)
    ).map { head, tail in
        StreamInfo(gen: head.0, windowID: head.1, title: head.2, appName: tail.0, pointSize: tail.1, pixelSize: tail.2,
                   framesPerSecond: tail.3)
    }.eraseToAny()
}

var genIceCandidate: Gen_<IceCandidate> {
    zip(genText, Gen.int32(in: 0...16), genText.optional)
        .map { IceCandidate(sdp: $0, sdpMLineIndex: $1, sdpMid: $2) }
        .eraseToAny()
}

var genSignalMessage: Gen_<SignalMessage> {
    Gen.oneOf(
        zip(genText, genPixelSize, Gen.int(in: -1...240).optional)
            .map { SignalMessage.hello(ClientHello(deviceName: $0, viewport: $1, maxFramesPerSecond: $2)) }.eraseToAny(),
        genText.map { SignalMessage.welcome(HostWelcome(hostName: $0)) }.eraseToAny(),
        genText.map { SignalMessage.offer(sdp: $0) }.eraseToAny(),
        genText.map { SignalMessage.answer(sdp: $0) }.eraseToAny(),
        genIceCandidate.map { SignalMessage.candidate($0) }.eraseToAny()
    ).eraseToAny()
}

var genStreamState: Gen_<StreamState> {
    Gen.oneOf(
        Gen.always(StreamState.live).eraseToAny(),
        Gen.always(StreamState.closed).eraseToAny(),
        genText.map { StreamState.paused(reason: $0) }.eraseToAny()
    ).eraseToAny()
}

var genHostMessage: Gen_<HostMessage> {
    Gen.oneOf(
        genWindowInfo.array(of: 0...6).map { HostMessage.windows($0) }.eraseToAny(),
        genStreamInfo.map { HostMessage.streamStarted($0) }.eraseToAny(),
        genStreamInfo.map { HostMessage.geometry($0) }.eraseToAny(),
        zip(Gen.uint32(in: 0...UInt32.max), genStreamState).map { HostMessage.streamState(gen: $0, state: $1) }.eraseToAny(),
        zip(genText, genText).map { HostMessage.error(code: $0, message: $1) }.eraseToAny(),
        Gen.uint64(in: 0...UInt64.max).map { HostMessage.pong($0) }.eraseToAny(),
        zip(Gen.bool, genText.optional).map { HostMessage.control(ControlStatus(allowed: $0, reason: $1)) }.eraseToAny(),
        zip(Gen.uint32(in: 0...UInt32.max), genBytes).map { HostMessage.thumbnail(windowID: $0, jpeg: $1) }.eraseToAny(),
        zip(genText, genBytes).map { HostMessage.appIcon(bundleID: $0, png: $1) }.eraseToAny(),
        zip(genText, genText, Gen.bool).map { AppInfo(bundleID: $0, name: $1, isRunning: $2) }.array(of: 0...6)
            .map { HostMessage.apps($0) }.eraseToAny()
    ).eraseToAny()
}

var genNormalizedPoint: Gen_<NormalizedPoint> {
    zip(Gen.double(in: -0.5...1.5), Gen.double(in: -0.5...1.5)).map { NormalizedPoint(x: $0, y: $1) }.eraseToAny()
}

var genModifiers: Gen_<Modifiers> {
    Gen.uint8(in: 0...15).map { Modifiers(rawValue: $0) }.eraseToAny()
}

var genInputMessage: Gen_<ClientMessage> {
    Gen.oneOf(
        zip(Gen.uint32(in: 0...9), genNormalizedPoint).map { ClientMessage.pointer(PointerEvent(gen: $0, point: $1)) }.eraseToAny(),
        zip(Gen.uint32(in: 0...9), genNormalizedPoint, pick([MouseButton.left, .right]), Gen.bool)
            .map { ClientMessage.button(ButtonEvent(gen: $0, point: $1, button: $2, isDown: $3)) }.eraseToAny(),
        zip(
            zip(Gen.uint32(in: 0...9), genNormalizedPoint, Gen.double(in: -1...1), Gen.double(in: -1...1)),
            zip(pick([ScrollPhase.began, .changed, .ended, .cancelled]).optional, pick([MomentumPhase.none, .began, .changed, .ended]))
        ).map { a, b in ClientMessage.scroll(ScrollEvent(gen: a.0, point: a.1, dx: a.2, dy: a.3, phase: b.0, momentum: b.1)) }.eraseToAny(),
        zip(Gen.uint32(in: 0...9), Gen.uint16(in: 0...0xFF), Gen.bool, genModifiers)
            .map { ClientMessage.key(KeyEvent(gen: $0, usage: $1, isDown: $2, modifiers: $3)) }.eraseToAny(),
        zip(Gen.uint32(in: 0...9), genText).map { ClientMessage.text(TextEvent(gen: $0, text: $1)) }.eraseToAny(),
        Gen.always(ClientMessage.releaseAll).eraseToAny(),
        zip(Gen.uint32(in: 0...UInt32.max).array(of: 0...6), Gen.int(in: 0...4000))
            .map { ClientMessage.thumbnails(windowIDs: $0, maxLongSide: $1) }.eraseToAny(),
        genText.array(of: 0...4).map { ClientMessage.appIcons(bundleIDs: $0) }.eraseToAny()
    ).eraseToAny()
}

var genClientMessage: Gen_<ClientMessage> {
    Gen.oneOf(
        Gen.always(ClientMessage.listWindows).eraseToAny(),
        Gen.always(ClientMessage.stopStream).eraseToAny(),
        Gen.uint32(in: 0...UInt32.max).map { ClientMessage.select(windowID: $0) }.eraseToAny(),
        genPixelSize.map { ClientMessage.viewport($0) }.eraseToAny(),
        Gen.uint64(in: 0...UInt64.max).map { ClientMessage.ping($0) }.eraseToAny(),
        Gen.always(ClientMessage.listApps).eraseToAny(),
        genText.map { ClientMessage.launch(bundleID: $0) }.eraseToAny(),
        genInputMessage
    ).eraseToAny()
}

/// Window list entries drawn from a small pool so duplicates, shared pids and untitled helpers all occur.
var genWindowRecord: Gen_<WindowRecord> {
    zip(
        zip(Gen.uint32(in: 1...30), pick(["", "Inbox", "Untitled", "Report.pdf", "é"]), pick(["Safari", "Mail", "notes", "Xcode"])),
        zip(Gen.int32(in: 1...6), pick([0, 0, 0, 3, 25]), pick([0.0, 0.5, 1.0, 1.0])),
        zip(genPointSize, Gen.bool, Gen.bool(0.8))
    ).map { a, b, c in
        WindowRecord(
            id: a.0, title: a.1, appName: a.2, bundleID: "com.example.\(a.2)", pid: b.0,
            layer: b.1, alpha: b.2, size: c.0, isOnScreen: c.1, isRegularApp: c.2
        )
    }.eraseToAny()
}

var genBytes: Gen_<Data> {
    Gen.uint8(in: 0...255).array(of: 0...40).map { Data($0) }.eraseToAny()
}

var genWireMessage: Gen_<WireMessage> {
    Gen.oneOf(
        zip(genText, genText, genBytes).map { WireMessage.pairRequest(PairRequest(deviceID: $0, deviceName: $1, commitment: $2)) }.eraseToAny(),
        zip(genText, genText, genBytes, genBytes).map { WireMessage.pairChallenge(PairChallenge(hostID: $0, hostName: $1, hostKey: $2, hostNonce: $3)) }.eraseToAny(),
        zip(genBytes, genBytes).map { WireMessage.pairReveal(PairReveal(deviceKey: $0, deviceNonce: $1)) }.eraseToAny(),
        genBytes.map { WireMessage.pairConfirm(PairConfirm(mac: $0)) }.eraseToAny(),
        zip(genText, genBytes).map { WireMessage.pairComplete(PairComplete(pairID: $0, mac: $1)) }.eraseToAny(),
        zip(genText, genBytes, genBytes).map { WireMessage.sessionHello(SessionHello(pairID: $0, nonce: $1, mac: $2)) }.eraseToAny(),
        zip(genBytes, genBytes).map { WireMessage.sessionAccept(SessionAccept(nonce: $0, mac: $1)) }.eraseToAny(),
        zip(Gen.uint64(in: 0...UInt64.max), genBytes).map { WireMessage.sealed(SealedFrame(counter: $0, box: $1)) }.eraseToAny(),
        genText.map { WireMessage.bye(reason: $0) }.eraseToAny()
    ).eraseToAny()
}
