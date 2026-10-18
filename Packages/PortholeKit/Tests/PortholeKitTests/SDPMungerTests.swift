import Foundation
import PropertyBased
import Testing
@testable import PortholeProtocol

@Suite(.shrinking)
struct SDPMungerTests {
    static var genParam: Gen_<String> { pick([
        "level-asymmetry-allowed=1", "packetization-mode=1", "profile-level-id=640c34",
        "profile-level-id=42e01f", "profile-level-id=640C29", "profile-level-id=4d0032", "profile-level-id=42e0zz",
        "profile-level-id=640c", "apt=96", "x-google-start-bitrate=1", "x-google-max-bitrate=99", "minptime=10", "",
    ]) }

    static var genLevel: Gen_<H264Level> { pick(H264Level.allCases) }

    /// An SDP-shaped document: a session header and one video section with codecs on unique payload types.
    static var genSDP: Gen_<String> { zip(
        zip(pick(["H264", "h264", "VP8", "VP9", "rtx", "AV1", "red"]), Self.genParam.array(of: 0...4)).array(of: 0...6),
        Gen.bool
    ).map { codecs, crlf -> String in
        let separator = crlf ? "\r\n" : "\n"
        var lines = ["v=0", "o=- 1 2 IN IP4 127.0.0.1", "s=-", "m=video 9 UDP/TLS/RTP/SAVPF"]
        for (index, codec) in codecs.enumerated() {
            let payloadType = 96 + index
            lines.append("a=rtpmap:\(payloadType) \(codec.0)/90000")
            lines.append("a=fmtp:\(payloadType) " + codec.1.joined(separator: ";"))
        }
        return lines.joined(separator: separator) + separator
    }.eraseToAny() }

    static func munge(_ sdp: String) -> String {
        SDPMunger.addingBitrateHints(to: sdp, startKbps: 8000, minKbps: 1000, maxKbps: 25000)
    }

    // MARK: Properties

    @Test
    func prop_munging_is_idempotent() async {
        await propertyCheck(count: 300, input: Self.genSDP) { sdp in
            #expect(Self.munge(Self.munge(sdp)) == Self.munge(sdp))
        }
    }

    @Test
    func prop_only_h264_format_lines_change() async {
        await propertyCheck(count: 300, input: Self.genSDP) { sdp in
            let h264 = SDPMunger.h264PayloadTypes(in: sdp)
            let separator = sdp.contains("\r\n") ? "\r\n" : "\n"
            let before = sdp.components(separatedBy: separator)
            let after = Self.munge(sdp).components(separatedBy: separator)
            #expect(before.count == after.count)
            for (old, new) in zip(before, after) where old != new {
                let payloadType = old.dropFirst("a=fmtp:".count).prefix { $0 != " " }
                #expect(old.hasPrefix("a=fmtp:") && h264.contains(String(payloadType)))
            }
        }
    }

    @Test
    func prop_every_h264_format_line_has_exactly_one_of_each_hint() async {
        await propertyCheck(count: 300, input: Self.genSDP) { sdp in
            let h264 = SDPMunger.h264PayloadTypes(in: sdp)
            for line in Self.munge(sdp).split(whereSeparator: \.isNewline) where line.hasPrefix("a=fmtp:") {
                let payloadType = String(line.dropFirst("a=fmtp:".count).prefix { $0 != " " })
                guard h264.contains(payloadType) else { continue }
                for key in SDPMunger.bitrateKeys {
                    #expect(line.components(separatedBy: key + "=").count == 2, "\(key) should appear once in \(line)")
                }
            }
        }
    }

    // MARK: Properties: raising the level

    @Test
    func prop_raising_reaches_the_level_never_lowers_and_keeps_the_profile() async {
        await propertyCheck(count: 300, input: Self.genSDP, Self.genLevel) { sdp, level in
            let before = Self.profileLevels(in: sdp)
            let after = Self.profileLevels(in: SDPMunger.raisingH264Level(in: sdp, toAtLeast: level))
            #expect(after.map(\.count) == before.map(\.count))
            for (old, new) in zip(before.joined(), after.joined()) {
                #expect(new.profile == old.profile)
                #expect(new.level == max(old.level, level.rawValue))
            }
        }
    }

    @Test
    func prop_raising_only_touches_h264_lines_whose_level_is_too_low() async {
        await propertyCheck(count: 300, input: Self.genSDP, Self.genLevel) { sdp, level in
            let separator = sdp.contains("\r\n") ? "\r\n" : "\n"
            let before = sdp.components(separatedBy: separator)
            let after = SDPMunger.raisingH264Level(in: sdp, toAtLeast: level).components(separatedBy: separator)
            #expect(before.count == after.count)
            for (old, new) in zip(before, after) where old != new {
                let h264 = SDPMunger.h264PayloadTypes(in: sdp)
                #expect(old.hasPrefix("a=fmtp:") && h264.contains(String(old.dropFirst("a=fmtp:".count).prefix { $0 != " " })))
                #expect(Self.profileLevels(onFormatLine: Substring(old)).contains { $0.level < level.rawValue })
            }
        }
    }

    @Test
    func prop_raising_twice_is_raising_once_to_the_higher_level() async {
        await propertyCheck(count: 300, input: Self.genSDP, Self.genLevel, Self.genLevel) { sdp, a, b in
            let twice = SDPMunger.raisingH264Level(in: SDPMunger.raisingH264Level(in: sdp, toAtLeast: a), toAtLeast: b)
            #expect(twice == SDPMunger.raisingH264Level(in: sdp, toAtLeast: max(a, b)))
        }
    }

    @Test
    func prop_raising_and_bitrate_hints_can_go_in_either_order() async {
        await propertyCheck(count: 300, input: Self.genSDP, Self.genLevel) { sdp, level in
            #expect(SDPMunger.raisingH264Level(in: Self.munge(sdp), toAtLeast: level)
                == Self.munge(SDPMunger.raisingH264Level(in: sdp, toAtLeast: level)))
        }
    }

    /// For each line, the well-formed profile-level-ids on it if it's an H.264 format line.
    static func profileLevels(in sdp: String) -> [[(profile: String, level: UInt8)]] {
        let h264 = SDPMunger.h264PayloadTypes(in: sdp)
        return sdp.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map { line in
            guard line.hasPrefix("a=fmtp:"), h264.contains(String(line.dropFirst("a=fmtp:".count).prefix { $0 != " " })) else { return [] }
            return profileLevels(onFormatLine: line)
        }
    }

    /// The well-formed profile-level-ids on one format line: the profile (as written) and the level.
    static func profileLevels(onFormatLine line: Substring) -> [(profile: String, level: UInt8)] {
        guard let space = line.firstIndex(of: " ") else { return [] }
        return line[line.index(after: space)...].split(separator: ";").compactMap { param in
            guard param.hasPrefix("profile-level-id=") else { return nil }
            let value = param.dropFirst("profile-level-id=".count)
            guard value.count == 6, value.allSatisfy(\.isHexDigit), let level = UInt8(value.suffix(2), radix: 16) else { return nil }
            return (String(value.prefix(4)), level)
        }
    }

    // MARK: Examples

    @Test func adds_hints_to_h264_and_leaves_vp8_and_rtx_alone() {
        let sdp = [
            "m=video 9 UDP/TLS/RTP/SAVPF 96 97 98",
            "a=rtpmap:96 H264/90000",
            "a=fmtp:96 level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=640c34",
            "a=rtpmap:97 rtx/90000",
            "a=fmtp:97 apt=96",
            "a=rtpmap:98 VP8/90000",
            "",
        ].joined(separator: "\r\n")
        let expected = [
            "m=video 9 UDP/TLS/RTP/SAVPF 96 97 98",
            "a=rtpmap:96 H264/90000",
            "a=fmtp:96 level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=640c34;x-google-start-bitrate=8000;x-google-min-bitrate=1000;x-google-max-bitrate=25000",
            "a=rtpmap:97 rtx/90000",
            "a=fmtp:97 apt=96",
            "a=rtpmap:98 VP8/90000",
            "",
        ].joined(separator: "\r\n")
        #expect(Self.munge(sdp) == expected)
    }

    @Test func an_android_answer_at_3_1_is_raised_and_the_rest_is_untouched() {
        let answer = [
            "m=video 9 UDP/TLS/RTP/SAVPF 98 99",
            "a=rtpmap:98 H264/90000",
            "a=fmtp:98 level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=42e01f",
            "a=rtpmap:99 rtx/90000",
            "a=fmtp:99 apt=98",
            "",
        ].joined(separator: "\r\n")
        let raised = SDPMunger.raisingH264Level(in: answer, toAtLeast: .level5_2)
        #expect(raised == answer.replacingOccurrences(of: "profile-level-id=42e01f", with: "profile-level-id=42e034"))
    }

    @Test func an_ipad_answer_already_at_5_2_comes_back_byte_for_byte() {
        let answer = "a=rtpmap:96 H264/90000\r\na=fmtp:96 level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=640c34\r\n"
        #expect(SDPMunger.raisingH264Level(in: answer, toAtLeast: .level4_2) == answer)
    }

    @Test func a_malformed_or_missing_profile_is_left_alone() {
        let answer = "a=rtpmap:96 H264/90000\na=fmtp:96 profile-level-id=42e0zz\na=rtpmap:97 H264/90000\na=fmtp:97 packetization-mode=1\n"
        #expect(SDPMunger.raisingH264Level(in: answer, toAtLeast: .level5_2) == answer)
    }

    @Test func sdp_without_h264_is_returned_unchanged() {
        let sdp = "v=0\r\na=rtpmap:96 VP8/90000\r\na=fmtp:96 x\r\n"
        #expect(Self.munge(sdp) == sdp)
    }
}
