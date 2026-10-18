import Foundation

/// Length-prefixed framing for byte streams: a 4-byte big-endian length, then the payload.
public enum Framing {
    /// Signaling messages are small (SDP is a few KB); anything bigger is a bug or an attack.
    public static let maxPayloadLength = 1 << 20

    public static func frame(_ payload: Data) -> Data {
        precondition(payload.count <= maxPayloadLength, "payload too large to frame")
        var length = UInt32(payload.count).bigEndian
        var out = Data(bytes: &length, count: 4)
        out.append(payload)
        return out
    }
}

public enum FramingError: Error, Equatable {
    case payloadTooLarge(Int)
}

/// Reassembles frames from arbitrarily chunked stream reads.
public struct FrameDecoder {
    private var buffer = Data()

    public init() {}

    /// Number of bytes received but not yet returned as a complete frame.
    public var pendingByteCount: Int { buffer.count }

    /// Appends newly received bytes and returns every frame they complete, in order.
    public mutating func append(_ bytes: Data) throws -> [Data] {
        buffer.append(bytes)
        var frames: [Data] = []
        while buffer.count >= 4 {
            let start = buffer.startIndex
            let length = buffer[start..<start + 4].reduce(0) { ($0 << 8) | Int($1) }
            guard length <= Framing.maxPayloadLength else {
                throw FramingError.payloadTooLarge(length)
            }
            guard buffer.count >= 4 + length else { break }
            frames.append(Data(buffer[start + 4..<start + 4 + length]))
            buffer = Data(buffer[(start + 4 + length)...])
        }
        return frames
    }
}
