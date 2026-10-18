import Foundation

/// Decides the pixel size of the video for a streamed window.
public enum StreamSizing {
    /// Hard ceiling for the encoder regardless of client screen (4K UHD long side).
    public static let absoluteMaxLongSide = 3840
    /// Even small phones get at least this, so zooming in still shows readable text.
    public static let minimumCap = 1280
    /// The host never captures faster than this, whatever the screens can show.
    public static let absoluteMaxFramesPerSecond = 120
    /// For clients that don't say how fast their screen is: every one before 120 fps support showed 60.
    public static let defaultFramesPerSecond = 60
    /// Slower than this isn't worth asking for.
    public static let minimumFramesPerSecond = 30

    /// The fastest rate worth sending: what both the Mac's and the device's screens can show.
    public static func frameRateLimit(macRefresh: Int, deviceRefresh: Int?) -> Int {
        let device = deviceRefresh.flatMap { $0 > 0 ? $0 : nil } ?? defaultFramesPerSecond
        let mac = macRefresh > 0 ? macRefresh : defaultFramesPerSecond
        return min(absoluteMaxFramesPerSecond, max(minimumFramesPerSecond, min(mac, device)))
    }

    /// Longest side the host may send to a client with this screen.
    public static func cap(forViewport viewport: PixelSize) -> Int {
        min(absoluteMaxLongSide, max(minimumCap, viewport.longSide))
    }

    /// The H.264 level a client with this screen has to accept: enough for the largest frame the host may
    /// send it (a square window at the cap, since the window can change shape mid-stream) at `framesPerSecond`.
    /// If no level is enough, the highest, and `FrameRatePolicy` slows big streams down to fit it.
    ///
    /// Android's WebRTC declares a fixed low level whatever its decoder can do, so the host raises the level
    /// in the client's answer to this. No higher than needed: some decoders refuse a stream whose level is
    /// above their own.
    public static func h264Level(forViewport viewport: PixelSize, framesPerSecond: Int = defaultFramesPerSecond) -> H264Level {
        let cap = cap(forViewport: viewport)
        return H264Level.lowest(for: PixelSize(width: cap, height: cap), framesPerSecond: framesPerSecond)
    }

    /// The window's native pixel size, scaled down to fit `maxLongSide` with the aspect ratio kept.
    /// Both sides are even (required by 4:2:0 video) and at least 2. Never scales up.
    public static func outputPixelSize(windowPoints: PointSize, backingScale: Double, maxLongSide: Int) -> PixelSize {
        let scale = backingScale.isFinite && backingScale > 0 ? backingScale : 1
        let rawWidth = sanitized(windowPoints.width) * scale
        let rawHeight = sanitized(windowPoints.height) * scale
        let cap = max(2, maxLongSide & ~1)
        let factor = min(1, Double(cap) / max(rawWidth, rawHeight))
        return PixelSize(width: evenFloor(rawWidth * factor), height: evenFloor(rawHeight * factor))
    }

    private static func sanitized(_ value: Double) -> Double {
        value.isFinite && value >= 1 ? value : 1
    }

    private static func evenFloor(_ value: Double) -> Int {
        max(2, Int(value.rounded(.down)) & ~1)
    }
}

/// H.264 levels from 3.1 up, with the two limits from Table A-1 of the standard that a stream's size and
/// frame rate run into. Raw values are level_idc, the last byte of an SDP profile-level-id.
public enum H264Level: UInt8, CaseIterable, Comparable, Sendable {
    case level3_1 = 31, level3_2 = 32, level4 = 40, level4_1 = 41, level4_2 = 42, level5 = 50, level5_1 = 51, level5_2 = 52

    /// Macroblocks (16×16 pixels) in one frame.
    public var maxFrameMacroblocks: Int {
        switch self {
        case .level3_1: 3_600
        case .level3_2: 5_120
        case .level4, .level4_1: 8_192
        case .level4_2: 8_704
        case .level5: 22_080
        case .level5_1, .level5_2: 36_864
        }
    }

    public var maxMacroblocksPerSecond: Int {
        switch self {
        case .level3_1: 108_000
        case .level3_2: 216_000
        case .level4, .level4_1: 245_760
        case .level4_2: 522_240
        case .level5: 589_824
        case .level5_1: 983_040
        case .level5_2: 2_073_600
        }
    }

    /// Whether a stream of `size` frames at `framesPerSecond` stays within this level.
    public func allows(_ size: PixelSize, framesPerSecond: Int) -> Bool {
        let columns = (max(size.width, 1) + 15) / 16
        let rows = (max(size.height, 1) + 15) / 16
        let frame = columns * rows
        // Neither side may be longer than √(8 × the frame limit) macroblocks.
        let longest = max(columns, rows)
        return frame <= maxFrameMacroblocks
            && longest * longest <= 8 * maxFrameMacroblocks
            && frame * max(framesPerSecond, 1) <= maxMacroblocksPerSecond
    }

    /// The lowest level that allows `size` at `framesPerSecond`, or the highest one if none does.
    public static func lowest(for size: PixelSize, framesPerSecond: Int) -> H264Level {
        allCases.first { $0.allows(size, framesPerSecond: framesPerSecond) } ?? .level5_2
    }

    public static func < (lhs: H264Level, rhs: H264Level) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// How fast one session's streams run: at the limit both screens can show, unless a window is too big for
/// the negotiated H.264 level at that rate.
public struct FrameRatePolicy: Hashable, Sendable {
    public var limit: Int
    public var level: H264Level

    /// What every session got before 120 fps support.
    public static let standard = FrameRatePolicy(limit: StreamSizing.defaultFramesPerSecond, level: .level5_2)

    /// Rates to step down through, so a too-big window lands on one that displays evenly.
    static let steps = [120, 100, 90, 60]

    public init(limit: Int, level: H264Level) {
        self.limit = limit
        self.level = level
    }

    /// The rate to capture a stream of `size` at: the limit, or the fastest step below it that the level
    /// allows at this size. Never below 60 (or the limit, if that's lower), the rate streams always had.
    public func framesPerSecond(for size: PixelSize) -> Int {
        let floor = min(limit, StreamSizing.defaultFramesPerSecond)
        let candidates = [limit] + Self.steps.filter { $0 < limit && $0 > floor }
        return candidates.first { level.allows(size, framesPerSecond: $0) } ?? floor
    }
}

/// How the host fits a window's still into one control message.
public enum PreviewSizing {
    /// Long sides a device may ask for.
    public static let longSideRange = 160...800
    /// The control channel carries messages up to 240 KiB, and JSON spells bytes in base64 (4 characters
    /// for every 3 bytes), so a still this size leaves room for the rest of the message.
    public static let maxJPEGBytes = 160 * 1024
    public static let quality = 0.62
    public static let fallbackQuality = 0.45

    public struct Attempt: Equatable, Sendable {
        public var longSide: Int
        public var quality: Double
    }

    /// What to try, in order, until a JPEG is small enough: the size asked for at normal quality, then at
    /// lower quality, then smaller and smaller, down to the smallest long side.
    public static func attempts(longSide: Int) -> [Attempt] {
        let asked = min(max(longSide, longSideRange.lowerBound), longSideRange.upperBound)
        var sides: [Int] = []
        for side in [asked, asked * 3 / 4, asked / 2, longSideRange.lowerBound]
        where side >= longSideRange.lowerBound && side < (sides.last ?? .max) {
            sides.append(side)
        }
        return [Attempt(longSide: asked, quality: quality)] + sides.map { Attempt(longSide: $0, quality: fallbackQuality) }
    }
}
