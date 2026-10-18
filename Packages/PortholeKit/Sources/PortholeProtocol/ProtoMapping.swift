import Foundation
import SwiftProtobuf

// Converts between the app's message types and their wire form in Protocol/porthole.proto. The app only
// ever sees its own types; these are the one place that knows the protobuf shapes.

/// Why a well-formed protobuf still isn't a valid message.
public enum ProtoError: Error, Equatable, Sendable {
    /// A field the message can't do without, or the message's case, is absent.
    case missing(String)
    /// A number doesn't fit the type it stands for.
    case outOfRange(String)
    /// An enum value this version doesn't know, from a newer peer.
    case unknownValue(String)
}

private func require<T>(_ value: T?, _ field: String) throws -> T {
    guard let value else { throw ProtoError.missing(field) }
    return value
}

// MARK: - Signaling

extension WireMessage {
    var proto: PBWire {
        var wire = PBWire()
        wire.version = UInt32(portholeProtocolVersion)
        switch self {
        case .pairRequest(let m):
            wire.pairRequest = .with { $0.deviceID = m.deviceID; $0.deviceName = m.deviceName; $0.commitment = m.commitment }
        case .pairChallenge(let m):
            wire.pairChallenge = .with { $0.hostID = m.hostID; $0.hostName = m.hostName; $0.hostKey = m.hostKey; $0.hostNonce = m.hostNonce }
        case .pairReveal(let m):
            wire.pairReveal = .with { $0.deviceKey = m.deviceKey; $0.deviceNonce = m.deviceNonce }
        case .pairConfirm(let m):
            wire.pairConfirm = .with { $0.mac = m.mac }
        case .pairComplete(let m):
            wire.pairComplete = .with { $0.pairID = m.pairID; $0.mac = m.mac }
        case .sessionHello(let m):
            wire.sessionHello = .with { $0.pairID = m.pairID; $0.nonce = m.nonce; $0.mac = m.mac }
        case .sessionAccept(let m):
            wire.sessionAccept = .with { $0.nonce = m.nonce; $0.mac = m.mac }
        case .sealed(let m):
            wire.sealed = .with { $0.counter = m.counter; $0.box = m.box }
        case .bye(let reason):
            wire.bye = .with { $0.reason = reason }
        }
        return wire
    }

    init(proto wire: PBWire) throws {
        switch try require(wire.msg, "Wire.msg") {
        case .pairRequest(let m):
            self = .pairRequest(PairRequest(deviceID: m.deviceID, deviceName: m.deviceName, commitment: m.commitment))
        case .pairChallenge(let m):
            self = .pairChallenge(PairChallenge(hostID: m.hostID, hostName: m.hostName, hostKey: m.hostKey, hostNonce: m.hostNonce))
        case .pairReveal(let m):
            self = .pairReveal(PairReveal(deviceKey: m.deviceKey, deviceNonce: m.deviceNonce))
        case .pairConfirm(let m):
            self = .pairConfirm(PairConfirm(mac: m.mac))
        case .pairComplete(let m):
            self = .pairComplete(PairComplete(pairID: m.pairID, mac: m.mac))
        case .sessionHello(let m):
            self = .sessionHello(SessionHello(pairID: m.pairID, nonce: m.nonce, mac: m.mac))
        case .sessionAccept(let m):
            self = .sessionAccept(SessionAccept(nonce: m.nonce, mac: m.mac))
        case .sealed(let m):
            self = .sealed(SealedFrame(counter: m.counter, box: m.box))
        case .bye(let m):
            self = .bye(reason: m.reason)
        }
    }
}

extension SignalMessage {
    var proto: PBSignal {
        var signal = PBSignal()
        switch self {
        case .hello(let hello):
            signal.hello = .with {
                $0.protocolVersion = UInt32(clamping: hello.protocolVersion)
                $0.deviceName = hello.deviceName
                $0.viewport = hello.viewport.proto
                if let fps = hello.maxFramesPerSecond { $0.maxFramesPerSecond = Int64(fps) }
            }
        case .welcome(let welcome):
            signal.welcome = .with { $0.protocolVersion = UInt32(clamping: welcome.protocolVersion); $0.hostName = welcome.hostName }
        case .offer(let sdp):
            signal.offer = sdp
        case .answer(let sdp):
            signal.answer = sdp
        case .candidate(let candidate):
            signal.candidate = .with {
                $0.sdp = candidate.sdp
                $0.sdpMLineIndex = candidate.sdpMLineIndex
                if let mid = candidate.sdpMid { $0.sdpMid = mid }
            }
        }
        return signal
    }

    init(proto signal: PBSignal) throws {
        switch try require(signal.msg, "Signal.msg") {
        case .hello(let m):
            self = .hello(ClientHello(protocolVersion: Int(m.protocolVersion), deviceName: m.deviceName,
                                      viewport: try PixelSize(proto: try require(m.hasViewport ? m.viewport : nil, "ClientHello.viewport")),
                                      maxFramesPerSecond: m.hasMaxFramesPerSecond ? Int(m.maxFramesPerSecond) : nil))
        case .welcome(let m):
            self = .welcome(HostWelcome(protocolVersion: Int(m.protocolVersion), hostName: m.hostName))
        case .offer(let sdp):
            self = .offer(sdp: sdp)
        case .answer(let sdp):
            self = .answer(sdp: sdp)
        case .candidate(let m):
            self = .candidate(IceCandidate(sdp: m.sdp, sdpMLineIndex: m.sdpMLineIndex, sdpMid: m.hasSdpMid ? m.sdpMid : nil))
        }
    }
}

// MARK: - Control channel

extension ClientMessage {
    var proto: PBClientMessage {
        var message = PBClientMessage()
        switch self {
        case .listWindows: message.listWindows = PBNothing()
        case .select(let windowID): message.select = windowID
        case .stopStream: message.stopStream = PBNothing()
        case .viewport(let size): message.viewport = size.proto
        case .ping(let value): message.ping = value
        case .pointer(let e): message.pointer = .with { $0.gen = e.gen; $0.point = e.point.proto }
        case .button(let e):
            message.button = .with { $0.gen = e.gen; $0.point = e.point.proto; $0.button = e.button.proto; $0.isDown = e.isDown }
        case .scroll(let e):
            message.scroll = .with {
                $0.gen = e.gen
                $0.point = e.point.proto
                $0.dx = e.dx
                $0.dy = e.dy
                if let phase = e.phase { $0.phase = phase.proto }
                $0.momentum = e.momentum.proto
            }
        case .key(let e):
            message.key = .with { $0.gen = e.gen; $0.usage = UInt32(e.usage); $0.isDown = e.isDown; $0.modifiers = UInt32(e.modifiers.rawValue) }
        case .text(let e): message.text = .with { $0.gen = e.gen; $0.text = e.text }
        case .releaseAll: message.releaseAll = PBNothing()
        case .thumbnails(let ids, let maxLongSide):
            message.thumbnails = .with { $0.windowIds = ids; $0.maxLongSide = Int64(maxLongSide) }
        case .appIcons(let bundleIDs): message.appIcons = .with { $0.bundleIds = bundleIDs }
        case .listApps: message.listApps = PBNothing()
        case .launch(let bundleID): message.launch = bundleID
        }
        return message
    }

    init(proto message: PBClientMessage) throws {
        switch try require(message.msg, "ClientMessage.msg") {
        case .listWindows: self = .listWindows
        case .select(let windowID): self = .select(windowID: windowID)
        case .stopStream: self = .stopStream
        case .viewport(let size): self = .viewport(try PixelSize(proto: size))
        case .ping(let value): self = .ping(value)
        case .pointer(let e):
            self = .pointer(PointerEvent(gen: e.gen, point: try NormalizedPoint(proto: e.hasPoint ? e.point : nil, "PointerEvent.point")))
        case .button(let e):
            self = .button(ButtonEvent(gen: e.gen, point: try NormalizedPoint(proto: e.hasPoint ? e.point : nil, "ButtonEvent.point"),
                                       button: try MouseButton(proto: e.button), isDown: e.isDown))
        case .scroll(let e):
            self = .scroll(ScrollEvent(gen: e.gen, point: try NormalizedPoint(proto: e.hasPoint ? e.point : nil, "ScrollEvent.point"),
                                       dx: e.dx, dy: e.dy, phase: e.hasPhase ? try ScrollPhase(proto: e.phase) : nil,
                                       momentum: try MomentumPhase(proto: e.momentum)))
        case .key(let e):
            guard let usage = UInt16(exactly: e.usage) else { throw ProtoError.outOfRange("KeyEvent.usage") }
            guard let modifiers = UInt8(exactly: e.modifiers) else { throw ProtoError.outOfRange("KeyEvent.modifiers") }
            self = .key(KeyEvent(gen: e.gen, usage: usage, isDown: e.isDown, modifiers: Modifiers(rawValue: modifiers)))
        case .text(let e): self = .text(TextEvent(gen: e.gen, text: e.text))
        case .releaseAll: self = .releaseAll
        case .thumbnails(let request):
            self = .thumbnails(windowIDs: request.windowIds, maxLongSide: Int(request.maxLongSide))
        case .appIcons(let request): self = .appIcons(bundleIDs: request.bundleIds)
        case .listApps: self = .listApps
        case .launch(let bundleID): self = .launch(bundleID: bundleID)
        }
    }
}

extension HostMessage {
    var proto: PBHostMessage {
        var message = PBHostMessage()
        switch self {
        case .windows(let windows): message.windows = .with { $0.windows = windows.map(\.proto) }
        case .streamStarted(let info): message.streamStarted = info.proto
        case .geometry(let info): message.geometry = info.proto
        case .streamState(let gen, let state): message.streamState = .with { $0.gen = gen; $0.state = state.proto }
        case .error(let code, let text): message.error = .with { $0.code = code; $0.message = text }
        case .pong(let value): message.pong = value
        case .control(let status):
            message.control = .with {
                $0.allowed = status.allowed
                if let reason = status.reason { $0.reason = reason }
            }
        case .thumbnail(let windowID, let jpeg): message.thumbnail = .with { $0.windowID = windowID; $0.jpeg = jpeg }
        case .appIcon(let bundleID, let png): message.appIcon = .with { $0.bundleID = bundleID; $0.png = png }
        case .apps(let apps):
            message.apps = .with { $0.apps = apps.map { app in .with { $0.bundleID = app.bundleID; $0.name = app.name; $0.isRunning = app.isRunning } } }
        }
        return message
    }

    init(proto message: PBHostMessage) throws {
        switch try require(message.msg, "HostMessage.msg") {
        case .windows(let list): self = .windows(try list.windows.map(WindowInfo.init(proto:)))
        case .streamStarted(let info): self = .streamStarted(try StreamInfo(proto: info))
        case .geometry(let info): self = .geometry(try StreamInfo(proto: info))
        case .streamState(let update):
            self = .streamState(gen: update.gen, state: try StreamState(proto: try require(update.hasState ? update.state : nil, "StreamStateUpdate.state")))
        case .error(let problem): self = .error(code: problem.code, message: problem.message)
        case .pong(let value): self = .pong(value)
        case .control(let status): self = .control(ControlStatus(allowed: status.allowed, reason: status.hasReason ? status.reason : nil))
        case .thumbnail(let still): self = .thumbnail(windowID: still.windowID, jpeg: still.jpeg)
        case .appIcon(let icon): self = .appIcon(bundleID: icon.bundleID, png: icon.png)
        case .apps(let list): self = .apps(list.apps.map { AppInfo(bundleID: $0.bundleID, name: $0.name, isRunning: $0.isRunning) })
        }
    }
}

// MARK: - Values

extension PixelSize {
    var proto: PBPixelSize { .with { $0.width = Int64(width); $0.height = Int64(height) } }

    init(proto: PBPixelSize) throws {
        self.init(width: Int(proto.width), height: Int(proto.height))
    }
}

extension PointSize {
    var proto: PBPointSize { .with { $0.width = width; $0.height = height } }

    init(proto: PBPointSize?, _ field: String) throws {
        let proto = try require(proto, field)
        self.init(width: proto.width, height: proto.height)
    }
}

extension NormalizedPoint {
    var proto: PBNormalizedPoint { .with { $0.x = x; $0.y = y } }

    init(proto: PBNormalizedPoint?, _ field: String) throws {
        let proto = try require(proto, field)
        self.init(x: proto.x, y: proto.y)
    }
}

extension WindowInfo {
    var proto: PBWindowInfo {
        .with {
            $0.id = id
            $0.title = title
            $0.appName = appName
            if let bundleID { $0.bundleID = bundleID }
            $0.pid = pid
            $0.size = size.proto
            $0.isOnScreen = isOnScreen
        }
    }

    init(proto: PBWindowInfo) throws {
        self.init(id: proto.id, title: proto.title, appName: proto.appName, bundleID: proto.hasBundleID ? proto.bundleID : nil,
                  pid: proto.pid, size: try PointSize(proto: proto.hasSize ? proto.size : nil, "WindowInfo.size"),
                  isOnScreen: proto.isOnScreen)
    }
}

extension StreamInfo {
    var proto: PBStreamInfo {
        .with {
            $0.gen = gen
            $0.windowID = windowID
            $0.title = title
            $0.appName = appName
            $0.pointSize = pointSize.proto
            $0.pixelSize = pixelSize.proto
            if let framesPerSecond { $0.framesPerSecond = Int64(framesPerSecond) }
        }
    }

    init(proto: PBStreamInfo) throws {
        self.init(gen: proto.gen, windowID: proto.windowID, title: proto.title, appName: proto.appName,
                  pointSize: try PointSize(proto: proto.hasPointSize ? proto.pointSize : nil, "StreamInfo.pointSize"),
                  pixelSize: try PixelSize(proto: try require(proto.hasPixelSize ? proto.pixelSize : nil, "StreamInfo.pixelSize")),
                  framesPerSecond: proto.hasFramesPerSecond ? Int(proto.framesPerSecond) : nil)
    }
}

extension StreamState {
    var proto: PBStreamState {
        .with {
            switch self {
            case .live: $0.live = PBNothing()
            case .paused(let reason): $0.paused = .with { $0.reason = reason }
            case .closed: $0.closed = PBNothing()
            }
        }
    }

    init(proto: PBStreamState) throws {
        switch try require(proto.state, "StreamState.state") {
        case .live: self = .live
        case .paused(let paused): self = .paused(reason: paused.reason)
        case .closed: self = .closed
        }
    }
}

extension MouseButton {
    var proto: PBMouseButton {
        switch self {
        case .left: .left
        case .right: .right
        }
    }

    init(proto: PBMouseButton) throws {
        switch proto {
        case .left: self = .left
        case .right: self = .right
        case .UNRECOGNIZED: throw ProtoError.unknownValue("MouseButton")
        }
    }
}

extension ScrollPhase {
    var proto: PBScrollPhase {
        switch self {
        case .began: .began
        case .changed: .changed
        case .ended: .ended
        case .cancelled: .cancelled
        }
    }

    init(proto: PBScrollPhase) throws {
        switch proto {
        case .began: self = .began
        case .changed: self = .changed
        case .ended: self = .ended
        case .cancelled: self = .cancelled
        case .UNRECOGNIZED: throw ProtoError.unknownValue("ScrollPhase")
        }
    }
}

extension MomentumPhase {
    var proto: PBMomentumPhase {
        switch self {
        case .none: PBMomentumPhase.none
        case .began: .began
        case .changed: .changed
        case .ended: .ended
        }
    }

    init(proto: PBMomentumPhase) throws {
        switch proto {
        case PBMomentumPhase.none: self = .none
        case .began: self = .began
        case .changed: self = .changed
        case .ended: self = .ended
        case .UNRECOGNIZED: throw ProtoError.unknownValue("MomentumPhase")
        }
    }
}
