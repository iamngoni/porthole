import CoreGraphics
import Foundation

/// Where a normalized point lands on the Mac, in global screen points (top-left origin, as CGEvent uses).
public enum InputGeometry {
    public static func globalPoint(_ point: NormalizedPoint, in windowBounds: CGRect) -> CGPoint {
        let p = point.clamped
        // Stay a hair inside the edge so a point at 1.0 still hits the window, not its neighbour.
        let inset = 0.5
        let x = windowBounds.minX + min(max(p.x * windowBounds.width, inset), max(inset, windowBounds.width - inset))
        let y = windowBounds.minY + min(max(p.y * windowBounds.height, inset), max(inset, windowBounds.height - inset))
        return CGPoint(x: x, y: y)
    }

    /// Converts a scroll delta in fractions of the frame into the window's points.
    public static func scrollPoints(dx: Double, dy: Double, windowSize: CGSize) -> (dx: Double, dy: Double) {
        func finite(_ v: Double) -> Double { v.isFinite ? v : 0 }
        return (finite(dx) * windowSize.width, finite(dy) * windowSize.height)
    }
}

/// Scroll events carry whole pixels; this keeps the fractions so slow scrolls don't stall or drift.
public struct ScrollAccumulator: Sendable {
    private var remainderX = 0.0
    private var remainderY = 0.0

    public init() {}

    public mutating func take(dx: Double, dy: Double) -> (dx: Int32, dy: Int32) {
        func step(_ delta: Double, _ remainder: inout Double) -> Int32 {
            let total = remainder + (delta.isFinite ? delta : 0)
            let whole = total.rounded(.towardZero)
            let clamped = min(max(whole, Double(Int32.min)), Double(Int32.max))
            remainder = total - clamped
            return Int32(clamped)
        }
        return (step(dx, &remainderX), step(dy, &remainderY))
    }

    public mutating func reset() {
        remainderX = 0
        remainderY = 0
    }
}

/// Counts clicks the way macOS does, so a double tap becomes a double-click.
public struct ClickTracker: Sendable {
    public static let maxDistance: Double = 4

    private var last: (button: MouseButton, point: CGPoint, time: TimeInterval, count: Int)?

    public init() {}

    /// Call on every button press; returns the click count for it (1 for a single click).
    public mutating func press(_ button: MouseButton, at point: CGPoint, time: TimeInterval, interval: TimeInterval) -> Int {
        var count = 1
        if let last, last.button == button,
           time >= last.time, time - last.time <= interval,
           hypot(point.x - last.point.x, point.y - last.point.y) <= Self.maxDistance {
            count = last.count + 1
        }
        last = (button, point, time, count)
        return count
    }

    public mutating func reset() {
        last = nil
    }
}

/// Keeps a scroll gliding after the finger lifts, slowing like a Mac trackpad.
public struct MomentumScroller: Sendable {
    public static let decayPerFrame = 0.95
    /// Below this speed (points per frame) the glide stops.
    public static let stopSpeed = 0.3

    private var vx: Double
    private var vy: Double

    /// `velocity` is in points per second, as UIPanGestureRecognizer reports it.
    public init(velocity: CGPoint, framesPerSecond: Double = 60) {
        let fps = framesPerSecond.isFinite && framesPerSecond > 0 ? framesPerSecond : 60
        func perFrame(_ v: CGFloat) -> Double { Double(v).isFinite ? Double(v) / fps : 0 }
        vx = perFrame(velocity.x)
        vy = perFrame(velocity.y)
    }

    public var isFinished: Bool { hypot(vx, vy) < Self.stopSpeed }

    /// The next frame's movement, or nil when the glide is over.
    public mutating func next() -> (dx: Double, dy: Double)? {
        guard !isFinished else { return nil }
        let step = (vx, vy)
        vx *= Self.decayPerFrame
        vy *= Self.decayPerFrame
        return step
    }
}

/// What typing a piece of text turns into: runs of characters, plus real Return and Tab key presses
/// (apps treat those as keys, not as characters).
public enum TextSegment: Equatable, Sendable {
    case characters([UInt16])
    case key(usage: UInt16)
}

public enum TextTyping {
    /// The most UTF-16 units one synthetic key event can carry.
    public static let maxUTF16PerEvent = 20

    public static func segments(_ text: String) -> [TextSegment] {
        var segments: [TextSegment] = []
        var run: [UInt16] = []
        func flush() {
            if !run.isEmpty { segments.append(.characters(run)) }
            run = []
        }
        for character in text {
            switch character {
            case "\n", "\r", "\r\n":
                flush()
                segments.append(.key(usage: HIDKeyMap.Usage.returnKey))
            case "\t":
                flush()
                segments.append(.key(usage: HIDKeyMap.Usage.tab))
            default:
                guard !character.unicodeScalars.allSatisfy(\.properties.isControlLike) else { continue }
                let units = Array(String(character).utf16)
                if run.count + units.count > maxUTF16PerEvent { flush() }
                if units.count <= maxUTF16PerEvent {
                    run += units
                } else {
                    // One very long emoji sequence: split between scalars, never inside a surrogate pair.
                    for scalar in character.unicodeScalars {
                        let scalarUnits = Array(String(scalar).utf16)
                        if run.count + scalarUnits.count > maxUTF16PerEvent { flush() }
                        run += scalarUnits
                    }
                }
            }
        }
        flush()
        return segments
    }
}

private extension Unicode.Scalar.Properties {
    /// C0 and C1 controls and DEL, which would type as nothing or as something surprising.
    var isControlLike: Bool { generalCategory == .control }
}

/// Names that came over the network, made safe to show in a prompt or a list.
public enum DisplayName {
    public static let maxLength = 40

    public static func clean(_ name: String, fallback: String) -> String {
        let visible = name.unicodeScalars
            .map { $0.properties.generalCategory == .control || $0.properties.generalCategory == .format && $0 != "\u{200D}" ? " " : String($0) }
            .joined()
        let collapsed = visible.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !collapsed.isEmpty else { return fallback }
        guard collapsed.count > maxLength else { return collapsed }
        return String(collapsed.prefix(maxLength - 1)) + "…"
    }
}

/// How the video sits in its view: scaled to fit, centered, with bars on two sides.
public enum AspectFit {
    /// The rectangle `content` occupies when fitted inside `bounds`.
    public static func rect(content: CGSize, in bounds: CGSize) -> CGRect {
        guard content.width > 0, content.height > 0, bounds.width > 0, bounds.height > 0 else { return .zero }
        let scale = min(bounds.width / content.width, bounds.height / content.height)
        let size = CGSize(width: content.width * scale, height: content.height * scale)
        return CGRect(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2, width: size.width, height: size.height)
    }

    /// Where `point` (in the view) lands on the video, as fractions of its width and height.
    /// Nil on the bars around it, or before there is any video.
    public static func normalized(_ point: CGPoint, content: CGSize, in bounds: CGSize) -> NormalizedPoint? {
        let frame = rect(content: content, in: bounds)
        guard frame.width > 0, frame.height > 0, frame.contains(point) else { return nil }
        return NormalizedPoint(x: (point.x - frame.minX) / frame.width, y: (point.y - frame.minY) / frame.height)
    }
}

/// Pinch-zoom on the device: the fitted video drawn `scale` times bigger and moved by `offset`.
/// It never reaches the Mac; it only changes where on the window a touch lands.
public struct ZoomViewport: Equatable, Sendable {
    public static let maxScale: CGFloat = 5
    /// How far a pinch may go past the limits before it settles back, for a rubber-band feel.
    static let stretch: ClosedRange<CGFloat> = 0.7...(maxScale * 1.3)

    public var scale: CGFloat
    /// From the fitted video's center to the zoomed video's center, in view points.
    public var offset: CGPoint

    public init(scale: CGFloat = 1, offset: CGPoint = .zero) {
        self.scale = scale
        self.offset = offset
    }

    public var isZoomed: Bool { scale > 1.01 }

    /// Where the video is drawn in a view of size `bounds`.
    public func frame(content: CGSize, in bounds: CGSize) -> CGRect {
        let fitted = AspectFit.rect(content: content, in: bounds)
        let size = CGSize(width: fitted.width * scale, height: fitted.height * scale)
        return CGRect(x: fitted.midX + offset.x - size.width / 2, y: fitted.midY + offset.y - size.height / 2,
                      width: size.width, height: size.height)
    }

    /// The spot on the video under `point`, as fractions of its size; outside 0...1 off the video.
    /// Nil before there is any video.
    public func spot(at point: CGPoint, content: CGSize, in bounds: CGSize) -> NormalizedPoint? {
        let frame = frame(content: content, in: bounds)
        guard frame.width > 0, frame.height > 0 else { return nil }
        return NormalizedPoint(x: (point.x - frame.minX) / frame.width, y: (point.y - frame.minY) / frame.height)
    }

    /// The spot under `point`, or nil when the point is off the video.
    public func normalized(_ point: CGPoint, content: CGSize, in bounds: CGSize) -> NormalizedPoint? {
        guard let spot = spot(at: point, content: content, in: bounds), (0...1).contains(spot.x), (0...1).contains(spot.y) else { return nil }
        return spot
    }

    /// Scales by `factor` while the spot under `anchor` stays under it, as a pinch does.
    public func zoomed(by factor: CGFloat, around anchor: CGPoint, content: CGSize, in bounds: CGSize) -> ZoomViewport {
        guard factor.isFinite, factor > 0, anchor.x.isFinite, anchor.y.isFinite else { return self }
        let newScale = min(max(scale * factor, Self.stretch.lowerBound), Self.stretch.upperBound)
        let fitted = AspectFit.rect(content: content, in: bounds)
        let ratio = newScale / scale
        let center = CGPoint(x: fitted.midX + offset.x, y: fitted.midY + offset.y)
        let newCenter = CGPoint(x: anchor.x - (anchor.x - center.x) * ratio, y: anchor.y - (anchor.y - center.y) * ratio)
        return ZoomViewport(scale: newScale, offset: CGPoint(x: newCenter.x - fitted.midX, y: newCenter.y - fitted.midY))
    }

    /// Moved by `translation`, as a two-finger drag does.
    public func panned(by translation: CGPoint) -> ZoomViewport {
        guard translation.x.isFinite, translation.y.isFinite else { return self }
        return ZoomViewport(scale: scale, offset: CGPoint(x: offset.x + translation.x, y: offset.y + translation.y))
    }

    /// What to draw while a gesture is past the limits: the settled view plus part of the overshoot,
    /// so the video gives a little and springs back instead of stopping dead.
    public func resisted(content: CGSize, in bounds: CGSize, give: CGFloat = 0.35) -> ZoomViewport {
        let settled = settled(content: content, in: bounds)
        guard scale.isFinite, offset.x.isFinite, offset.y.isFinite else { return settled }
        func blend(_ rest: CGFloat, _ raw: CGFloat) -> CGFloat { rest + (raw - rest) * give }
        return ZoomViewport(scale: blend(settled.scale, scale),
                            offset: CGPoint(x: blend(settled.offset.x, offset.x), y: blend(settled.offset.y, offset.y)))
    }

    /// Back within limits: between 1× and the maximum, with no gap between the video and the view's edge
    /// on a side where the video is bigger than the view, and centered on a side where it is smaller.
    public func settled(content: CGSize, in bounds: CGSize) -> ZoomViewport {
        let scale = scale.isFinite ? min(max(scale, 1), Self.maxScale) : 1
        let fitted = AspectFit.rect(content: content, in: bounds)
        func limit(_ value: CGFloat, size: CGFloat, view: CGFloat) -> CGFloat {
            let slack = max(0, (size - view) / 2)
            return value.isFinite ? min(max(value, -slack), slack) : 0
        }
        return ZoomViewport(scale: scale, offset: CGPoint(
            x: limit(offset.x, size: fitted.width * scale, view: bounds.width),
            y: limit(offset.y, size: fitted.height * scale, view: bounds.height)))
    }
}
