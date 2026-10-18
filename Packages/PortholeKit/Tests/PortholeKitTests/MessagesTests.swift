import Foundation
import PropertyBased
import SwiftProtobuf
import Testing
@testable import PortholeProtocol

@Suite(.shrinking)
struct MessagesTests {
    // MARK: Properties

    @Test
    func prop_signal_message_roundtrips_through_json() async throws {
        await propertyCheck(count: 300, input: genSignalMessage) { message in
            let data = try MessageCoding.encode(message)
            #expect(try MessageCoding.decode(SignalMessage.self, from: data) == message)
        }
    }

    @Test
    func prop_host_message_roundtrips_through_json() async throws {
        await propertyCheck(count: 300, input: genHostMessage) { message in
            let data = try MessageCoding.encode(message)
            #expect(try MessageCoding.decode(HostMessage.self, from: data) == message)
        }
    }

    @Test
    func prop_client_message_roundtrips_through_json() async throws {
        await propertyCheck(count: 300, input: genClientMessage) { message in
            let data = try MessageCoding.encode(message)
            #expect(try MessageCoding.decode(ClientMessage.self, from: data) == message)
        }
    }

    @Test
    func prop_framed_signal_message_roundtrips() async throws {
        await propertyCheck(count: 200, input: genSignalMessage.array(of: 1...5)) { messages in
            var stream = Data()
            for message in messages { stream.append(Framing.frame(try MessageCoding.encode(message))) }
            var decoder = FrameDecoder()
            let decoded = try decoder.append(stream).map { try MessageCoding.decode(SignalMessage.self, from: $0) }
            #expect(decoded == messages)
        }
    }

    // MARK: Examples (pin the bytes other implementations must match)

    @Test func offer_wire_format() throws {
        let bytes = Data([0x1A, 0x03]) + Data("v=0".utf8)
        #expect(try MessageCoding.encode(SignalMessage.offer(sdp: "v=0")) == bytes)
        #expect(try MessageCoding.decode(SignalMessage.self, from: bytes) == .offer(sdp: "v=0"))
    }

    @Test func select_wire_format() throws {
        #expect(try MessageCoding.encode(ClientMessage.select(windowID: 42)) == Data([0x10, 0x2A]))
        #expect(try MessageCoding.decode(ClientMessage.self, from: Data([0x10, 0x2A])) == .select(windowID: 42))
    }

    @Test func list_windows_wire_format() throws {
        #expect(try MessageCoding.encode(ClientMessage.listWindows) == Data([0x0A, 0x00]))
        #expect(try MessageCoding.decode(ClientMessage.self, from: Data([0x0A, 0x00])) == .listWindows)
    }

    @Test func unknown_message_is_rejected_not_misread() {
        // Field 99 is nothing this version knows: it decodes to a message with no case.
        #expect(throws: ProtoError.missing("ClientMessage.msg")) {
            _ = try MessageCoding.decode(ClientMessage.self, from: Data([0x98, 0x06, 0x01]))
        }
        #expect(throws: ProtoError.missing("ClientMessage.msg")) { _ = try MessageCoding.decode(ClientMessage.self, from: Data()) }
    }

    @Test func numbers_too_big_for_their_field_are_rejected() throws {
        var key = PBClientMessage()
        key.key = .with { $0.usage = 0x1_0000 }
        #expect(throws: ProtoError.outOfRange("KeyEvent.usage")) {
            _ = try MessageCoding.decode(ClientMessage.self, from: key.serializedData())
        }
    }

    @Test func a_message_missing_a_part_it_needs_is_rejected() throws {
        var pointer = PBClientMessage()
        pointer.pointer = .with { $0.gen = 1 }
        #expect(throws: ProtoError.missing("PointerEvent.point")) {
            _ = try MessageCoding.decode(ClientMessage.self, from: pointer.serializedData())
        }
    }
}
