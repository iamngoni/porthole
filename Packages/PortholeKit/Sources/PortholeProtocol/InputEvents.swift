import Foundation

// Input from the client, sent on the control channel. Positions are normalized to the video frame
// (0...1, top-left origin) and carry the stream's `gen`, so input aimed at a window the user just
// switched away from is dropped instead of landing on the new one.

public struct NormalizedPoint: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    /// Clamped into the frame; non-finite values go to the center.
    public var clamped: NormalizedPoint {
        func clamp(_ value: Double) -> Double { value.isFinite ? min(1, max(0, value)) : 0.5 }
        return NormalizedPoint(x: clamp(x), y: clamp(y))
    }
}

public enum MouseButton: String, Codable, Hashable, Sendable {
    case left, right
}

public struct Modifiers: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let shift = Modifiers(rawValue: 1 << 0)
    public static let control = Modifiers(rawValue: 1 << 1)
    public static let option = Modifiers(rawValue: 1 << 2)
    public static let command = Modifiers(rawValue: 1 << 3)
}

/// Mirrors the Mac's trackpad scroll phases so apps see a natural gesture with momentum.
public enum ScrollPhase: String, Codable, Hashable, Sendable {
    case began, changed, ended, cancelled
}

public enum MomentumPhase: String, Codable, Hashable, Sendable {
    case none, began, changed, ended
}

/// The pointer moved (hover, or a drag while a button is held).
public struct PointerEvent: Codable, Hashable, Sendable {
    public var gen: UInt32
    public var point: NormalizedPoint

    public init(gen: UInt32, point: NormalizedPoint) {
        self.gen = gen
        self.point = point
    }
}

public struct ButtonEvent: Codable, Hashable, Sendable {
    public var gen: UInt32
    public var point: NormalizedPoint
    public var button: MouseButton
    public var isDown: Bool

    public init(gen: UInt32, point: NormalizedPoint, button: MouseButton, isDown: Bool) {
        self.gen = gen
        self.point = point
        self.button = button
        self.isDown = isDown
    }
}

/// `dx`/`dy` are fractions of the video's width and height, so the host can turn them into the
/// window's own points and the content moves exactly as far as the finger did.
/// Positive `dy` means the finger moved down (content follows it down).
public struct ScrollEvent: Codable, Hashable, Sendable {
    public var gen: UInt32
    public var point: NormalizedPoint
    public var dx: Double
    public var dy: Double
    public var phase: ScrollPhase?
    public var momentum: MomentumPhase

    public init(gen: UInt32, point: NormalizedPoint, dx: Double, dy: Double, phase: ScrollPhase?, momentum: MomentumPhase) {
        self.gen = gen
        self.point = point
        self.dx = dx
        self.dy = dy
        self.phase = phase
        self.momentum = momentum
    }
}

/// A physical key, as a USB HID usage (keyboard page 0x07). Layout-independent: the Mac's own
/// keyboard layout decides which character it produces.
public struct KeyEvent: Codable, Hashable, Sendable {
    public var gen: UInt32
    public var usage: UInt16
    public var isDown: Bool
    public var modifiers: Modifiers

    public init(gen: UInt32, usage: UInt16, isDown: Bool, modifiers: Modifiers) {
        self.gen = gen
        self.usage = usage
        self.isDown = isDown
        self.modifiers = modifiers
    }
}

/// Text from the on-screen keyboard, typed as-is regardless of the Mac's layout.
public struct TextEvent: Codable, Hashable, Sendable {
    public var gen: UInt32
    public var text: String

    public init(gen: UInt32, text: String) {
        self.gen = gen
        self.text = text
    }
}
