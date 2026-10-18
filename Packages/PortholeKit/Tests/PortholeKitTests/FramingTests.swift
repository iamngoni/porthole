import Foundation
import PropertyBased
import Testing
@testable import PortholeProtocol

@Suite(.shrinking)
struct FramingTests {
    static var genPayload: Gen_<Data> { Gen.uint8(in: 0...255).array(of: 0...300).map { Data($0) }.eraseToAny() }

    /// Splits `data` into consecutive chunks using `sizes` cyclically, so every split pattern is reachable.
    static func chunks(of data: Data, sizes: [Int]) -> [Data] {
        var out: [Data] = []
        var offset = data.startIndex
        var i = 0
        while offset < data.endIndex {
            let end = min(data.endIndex, offset + sizes[i % sizes.count])
            out.append(data[offset..<end])
            offset = end
            i += 1
        }
        return out
    }

    // MARK: Properties

    @Test
    func prop_frames_roundtrip_under_any_chunking() async throws {
        await propertyCheck(count: 300, input: Self.genPayload.array(of: 0...8), Gen.int(in: 1...64).array(of: 1...20)) { payloads, sizes in
            let stream = payloads.reduce(into: Data()) { $0.append(Framing.frame($1)) }
            var decoder = FrameDecoder()
            var decoded: [Data] = []
            for chunk in Self.chunks(of: stream, sizes: sizes) {
                decoded += try #require(try? decoder.append(chunk))
            }
            #expect(decoded == payloads)
            #expect(decoder.pendingByteCount == 0)
        }
    }

    @Test
    func prop_truncated_frame_yields_nothing_and_keeps_bytes() async throws {
        await propertyCheck(count: 300, input: Self.genPayload, Gen.int(in: 1...400)) { payload, cut in
            let framed = Framing.frame(payload)
            let kept = framed.prefix(framed.count - min(cut, framed.count))
            var decoder = FrameDecoder()
            let frames = try #require(try? decoder.append(kept))
            #expect(frames.isEmpty)
            #expect(decoder.pendingByteCount == kept.count)
        }
    }

    @Test
    func prop_rejects_any_length_over_the_limit() async throws {
        await propertyCheck(count: 200, input: Gen.int(in: (Framing.maxPayloadLength + 1)...Int(UInt32.max))) { length in
            var header = UInt32(length).bigEndian
            var decoder = FrameDecoder()
            #expect(throws: FramingError.payloadTooLarge(length)) {
                _ = try decoder.append(Data(bytes: &header, count: 4))
            }
        }
    }

    // MARK: Examples

    @Test func empty_payload_is_four_zero_bytes() throws {
        #expect(Framing.frame(Data()) == Data([0, 0, 0, 0]))
        var decoder = FrameDecoder()
        #expect(try decoder.append(Data([0, 0, 0, 0])) == [Data()])
    }

    @Test func two_frames_in_one_read_come_out_in_order() throws {
        let bytes = Data([0, 0, 0, 2, 0x68, 0x69, 0, 0, 0, 1, 0x21])
        var decoder = FrameDecoder()
        #expect(try decoder.append(bytes) == [Data("hi".utf8), Data("!".utf8)])
    }

    @Test func header_split_across_reads_still_decodes() throws {
        var decoder = FrameDecoder()
        #expect(try decoder.append(Data([0, 0])) == [])
        #expect(try decoder.append(Data([0, 1, 0x41])) == [Data("A".utf8)])
    }
}
