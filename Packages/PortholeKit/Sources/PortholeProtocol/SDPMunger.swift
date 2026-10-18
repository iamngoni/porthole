import Foundation

/// Small, targeted edits to WebRTC session descriptions.
public enum SDPMunger {
    static let bitrateKeys = ["x-google-start-bitrate", "x-google-min-bitrate", "x-google-max-bitrate"]

    /// Payload types the SDP maps to H.264.
    public static func h264PayloadTypes(in sdp: String) -> Set<String> {
        var types = Set<String>()
        for line in lines(of: sdp).lines where line.hasPrefix("a=rtpmap:") {
            let body = line.dropFirst("a=rtpmap:".count)
            guard let space = body.firstIndex(of: " ") else { continue }
            let encoding = body[body.index(after: space)...]
            if encoding.lowercased().hasPrefix("h264/") {
                types.insert(String(body[..<space]))
            }
        }
        return types
    }

    /// Sets x-google bitrate hints (kbps) on every H.264 format line, replacing any already there.
    /// Without them WebRTC starts near 300 kbps and the first seconds of a large window are blurry.
    public static func addingBitrateHints(to sdp: String, startKbps: Int, minKbps: Int, maxKbps: Int) -> String {
        let hints = ["x-google-start-bitrate=\(startKbps)", "x-google-min-bitrate=\(minKbps)", "x-google-max-bitrate=\(maxKbps)"]
        return editingH264Formats(in: sdp) { params in
            params.filter { !bitrateKeys.contains(key(of: $0)) } + hints
        }
    }

    /// Raises the level in every H.264 profile-level-id to at least `level`, keeping the profile and its
    /// constraint flags. Never lowers a level. A format line without a well-formed profile-level-id is left
    /// alone, and so is every line whose level is already high enough.
    public static func raisingH264Level(in sdp: String, toAtLeast level: H264Level) -> String {
        editingH264Formats(in: sdp) { params in
            params.map { param in
                guard key(of: param) == "profile-level-id",
                      let value = param.split(separator: "=", maxSplits: 1).last, value.count == 6,
                      value.allSatisfy(\.isHexDigit),
                      let current = UInt8(value.suffix(2), radix: 16), current < level.rawValue else { return param }
                return "profile-level-id=" + value.prefix(4) + String(format: "%02x", level.rawValue)
            }
        }
    }

    /// Runs `edit` over the parameters of each H.264 format line. A line comes back exactly as it was
    /// unless `edit` changed its parameters.
    private static func editingH264Formats(in sdp: String, _ edit: ([String]) -> [String]) -> String {
        let h264 = h264PayloadTypes(in: sdp)
        guard !h264.isEmpty else { return sdp }
        let (allLines, separator) = lines(of: sdp)
        let edited = allLines.map { line -> String in
            guard line.hasPrefix("a=fmtp:") else { return line }
            let body = line.dropFirst("a=fmtp:".count)
            let space = body.firstIndex(of: " ")
            let payloadType = String(space.map { body[..<$0] } ?? body)
            guard h264.contains(payloadType) else { return line }
            let existing = space.map { body[body.index(after: $0)...] }.map(String.init) ?? ""
            let params = existing.split(separator: ";").map(String.init).filter { !$0.isEmpty }
            let changed = edit(params)
            return changed == params ? line : "a=fmtp:\(payloadType) " + changed.joined(separator: ";")
        }
        return edited.joined(separator: separator)
    }

    private static func key(of param: String) -> String {
        param.split(separator: "=", maxSplits: 1).first.map(String.init) ?? param
    }

    private static func lines(of sdp: String) -> (lines: [String], separator: String) {
        let separator = sdp.contains("\r\n") ? "\r\n" : "\n"
        return (sdp.components(separatedBy: separator), separator)
    }
}
