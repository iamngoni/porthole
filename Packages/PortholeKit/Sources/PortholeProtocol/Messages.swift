import Foundation

/// Bumped whenever the wire format changes incompatibly. 3: protobuf (Protocol/porthole.proto); 2 was JSON.
public let portholeProtocolVersion = 3

/// Bonjour service type the Mac host advertises on the local network.
public let portholeBonjourType = "_porthole._tcp"

/// The port the Mac listens on, so a device that can't see it on Bonjour (over Tailscale or another VPN)
/// can still reach it by name or address. If another app holds it, the Mac takes any port and can only be
/// found nearby.
public let portholeSignalingPort: UInt16 = 47801

// MARK: - Shared value types

public struct PixelSize: Codable, Hashable, Sendable {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    public var longSide: Int { max(width, height) }
}

public struct PointSize: Codable, Hashable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

/// A Mac window the client can choose to stream.
public struct WindowInfo: Codable, Hashable, Sendable, Identifiable {
    public var id: UInt32
    public var title: String
    public var appName: String
    public var bundleID: String?
    public var pid: Int32
    public var size: PointSize
    public var isOnScreen: Bool

    public init(id: UInt32, title: String, appName: String, bundleID: String?, pid: Int32, size: PointSize, isOnScreen: Bool) {
        self.id = id
        self.title = title
        self.appName = appName
        self.bundleID = bundleID
        self.pid = pid
        self.size = size
        self.isOnScreen = isOnScreen
    }
}

/// Describes the window currently on the video track.
/// `gen` increases every time the streamed window changes, so stale input can be dropped.
public struct StreamInfo: Codable, Hashable, Sendable {
    public var gen: UInt32
    public var windowID: UInt32
    public var title: String
    public var appName: String
    public var pointSize: PointSize
    public var pixelSize: PixelSize
    /// The most frames per second the Mac sends; fewer while the window doesn't change. Absent from hosts
    /// before 120 fps support, which sent 60.
    public var framesPerSecond: Int?

    public init(gen: UInt32, windowID: UInt32, title: String, appName: String, pointSize: PointSize, pixelSize: PixelSize,
                framesPerSecond: Int? = nil) {
        self.gen = gen
        self.windowID = windowID
        self.title = title
        self.appName = appName
        self.pointSize = pointSize
        self.pixelSize = pixelSize
        self.framesPerSecond = framesPerSecond
    }
}

public enum StreamState: Codable, Hashable, Sendable {
    case live
    case paused(reason: String)
    case closed
}

public struct IceCandidate: Codable, Hashable, Sendable {
    public var sdp: String
    public var sdpMLineIndex: Int32
    public var sdpMid: String?

    public init(sdp: String, sdpMLineIndex: Int32, sdpMid: String?) {
        self.sdp = sdp
        self.sdpMLineIndex = sdpMLineIndex
        self.sdpMid = sdpMid
    }
}

// MARK: - Signaling (Bonjour TCP connection, later the internet relay)

public struct ClientHello: Codable, Hashable, Sendable {
    public var protocolVersion: Int
    public var deviceName: String
    /// The client's screen in pixels; the host never sends video larger than this.
    public var viewport: PixelSize
    /// How many times a second the client's screen can refresh (120 on ProMotion). Absent from clients
    /// before 120 fps support, which get 60.
    public var maxFramesPerSecond: Int?

    public init(protocolVersion: Int = portholeProtocolVersion, deviceName: String, viewport: PixelSize,
                maxFramesPerSecond: Int? = nil) {
        self.protocolVersion = protocolVersion
        self.deviceName = deviceName
        self.viewport = viewport
        self.maxFramesPerSecond = maxFramesPerSecond
    }
}

public struct HostWelcome: Codable, Hashable, Sendable {
    public var protocolVersion: Int
    public var hostName: String

    public init(protocolVersion: Int = portholeProtocolVersion, hostName: String) {
        self.protocolVersion = protocolVersion
        self.hostName = hostName
    }
}

/// Carried inside sealed frames once a session is established. Closing is `WireMessage.bye`.
public enum SignalMessage: Codable, Hashable, Sendable {
    case hello(ClientHello)
    case welcome(HostWelcome)
    case offer(sdp: String)
    case answer(sdp: String)
    case candidate(IceCandidate)
}

// MARK: - Control (WebRTC data channel "ctl")

public enum ClientMessage: Codable, Hashable, Sendable {
    case listWindows
    case select(windowID: UInt32)
    case stopStream
    case viewport(PixelSize)
    /// Sent every second while connected. The host releases held keys and buttons if these stop.
    case ping(UInt64)
    case pointer(PointerEvent)
    case button(ButtonEvent)
    case scroll(ScrollEvent)
    case key(KeyEvent)
    case text(TextEvent)
    /// Lift every key and button the host is holding down for this client.
    case releaseAll
    /// Ask for fresh thumbnails of these windows, at most `maxLongSide` pixels on the long side.
    case thumbnails(windowIDs: [UInt32], maxLongSide: Int)
    /// Ask for the icons of these apps.
    case appIcons(bundleIDs: [String])
    /// Ask for the apps installed on the Mac.
    case listApps
    /// Open one of the listed apps (or ask it for a window if it's already open) and stream its window.
    case launch(bundleID: String)
}

public enum HostMessage: Codable, Hashable, Sendable {
    case windows([WindowInfo])
    case streamStarted(StreamInfo)
    case geometry(StreamInfo)
    case streamState(gen: UInt32, state: StreamState)
    case error(code: String, message: String)
    case pong(UInt64)
    /// Whether this client may control the Mac right now, and why not if it can't.
    case control(ControlStatus)
    /// A still of one window, as JPEG.
    case thumbnail(windowID: UInt32, jpeg: Data)
    /// An app's icon, as PNG.
    case appIcon(bundleID: String, png: Data)
    /// The apps the device may open, sorted by name.
    case apps([AppInfo])
}

/// An app installed on the Mac that the device can open.
public struct AppInfo: Codable, Hashable, Sendable, Identifiable {
    public var bundleID: String
    public var name: String
    public var isRunning: Bool

    public var id: String { bundleID }

    public init(bundleID: String, name: String, isRunning: Bool) {
        self.bundleID = bundleID
        self.name = name
        self.isRunning = isRunning
    }
}

public struct ControlStatus: Codable, Hashable, Sendable {
    public var allowed: Bool
    public var reason: String?

    public init(allowed: Bool, reason: String? = nil) {
        self.allowed = allowed
        self.reason = reason
    }
}

// MARK: - Coding helpers

/// Encodes the messages inside sealed frames and on the control channel as protobuf (Protocol/porthole.proto).
public enum MessageCoding {
    public static func encode(_ message: SignalMessage) throws -> Data { try message.proto.serializedData() }
    public static func encode(_ message: ClientMessage) throws -> Data { try message.proto.serializedData() }
    public static func encode(_ message: HostMessage) throws -> Data { try message.proto.serializedData() }

    public static func decode(_ type: SignalMessage.Type, from data: Data) throws -> SignalMessage {
        try SignalMessage(proto: PBSignal(serializedBytes: data))
    }

    public static func decode(_ type: ClientMessage.Type, from data: Data) throws -> ClientMessage {
        try ClientMessage(proto: PBClientMessage(serializedBytes: data))
    }

    public static func decode(_ type: HostMessage.Type, from data: Data) throws -> HostMessage {
        try HostMessage(proto: PBHostMessage(serializedBytes: data))
    }
}
