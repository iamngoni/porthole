import Foundation
import PropertyBased
import SwiftProtobuf
import Testing
@testable import PortholeProtocol

@Suite(.shrinking)
struct WireTests {
    @Test func prop_wire_messages_roundtrip() async throws {
        await propertyCheck(count: 300, input: genWireMessage) { message in
            let data = try WireCoding.encode(message)
            #expect(try WireCoding.decode(data) == .message(message))
        }
    }

    @Test func prop_any_json_frame_is_an_old_version_never_a_message() async throws {
        await propertyCheck(count: 200, input: Gen.int(in: -5...50), genText) { version, reason in
            let json = try JSONSerialization.data(withJSONObject: ["v": version, "msg": ["bye": ["reason": reason]]])
            #expect(try WireCoding.decode(json) == .unsupportedVersion(version, reason: reason))
        }
    }

    @Test func prop_any_other_protobuf_version_is_reported_not_misread() async throws {
        await propertyCheck(count: 200, input: Gen.uint32(in: 0...1000), genText) { (version: UInt32, reason: String) throws in
            guard version != portholeProtocolVersion else { return }
            var wire = PBWire()
            wire.version = version
            wire.bye = .with { $0.reason = reason }
            #expect(try WireCoding.decode(wire.serializedData()) == .unsupportedVersion(Int(version), reason: reason))
        }
    }

    // MARK: Examples (pin the bytes other implementations must match)

    @Test func frame_wire_format() throws {
        let bytes = Data([0x08, 0x03, 0x52, 0x06, 0x0A, 0x04]) + Data("done".utf8)
        #expect(try WireCoding.encode(.bye(reason: "done")) == bytes)
        #expect(try WireCoding.decode(bytes) == .message(.bye(reason: "done")))
    }

    @Test func an_app_from_before_v3_is_recognized_and_told_in_json() throws {
        let old = #"{"v":2,"msg":{"offer":{"sdp":"v=0"}}}"#
        #expect(try WireCoding.decode(Data(old.utf8)) == .unsupportedVersion(2, reason: nil))
        // What a v2 app reads: its own frame shape, with a reason it maps to "update needed".
        let bye = try #require(JSONSerialization.jsonObject(with: WireCoding.legacyBye(reason: "version-mismatch")) as? [String: Any])
        #expect(bye["v"] as? Int == 2)
        #expect(((bye["msg"] as? [String: Any])?["bye"] as? [String: Any])?["reason"] as? String == "version-mismatch")
    }

    @Test func future_version_without_bye_is_still_reported() throws {
        #expect(try WireCoding.decode(Data([0x08, 0x04, 0x2A, 0x00])) == .unsupportedVersion(4, reason: nil))
    }

    @Test func a_frame_without_a_message_is_rejected() {
        #expect(throws: ProtoError.missing("Wire.msg")) { _ = try WireCoding.decode(Data([0x08, 0x03])) }
    }

    @Test func garbage_and_phase_one_json_are_not_frames() {
        #expect(throws: WireCoding.DecodeError.notAFrame) { _ = try WireCoding.decode(Data([0xFF, 0xFF, 0xFF])) }
        let json = #"{"offer":{"sdp":"v=0"}}"#
        #expect(throws: WireCoding.DecodeError.notAFrame) { _ = try WireCoding.decode(Data(json.utf8)) }
    }
}
