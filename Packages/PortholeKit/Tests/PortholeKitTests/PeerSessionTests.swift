import CoreMedia
import CoreVideo
import Foundation
import PropertyBased
import Testing
import VideoToolbox
@testable import PortholeProtocol
@testable import PortholeSession

/// Whether this Mac can encode H.264 at 120 frames a second: in hardware, and not in a virtual machine.
/// GitHub's virtual Macs report a hardware encoder but reach 20 to 40 frames a second.
private let encodesH264AtFullSpeed: Bool = {
    var inVirtualMachine: Int32 = 0
    var size = MemoryLayout<Int32>.size
    if sysctlbyname("kern.hv_vmm_present", &inVirtualMachine, &size, nil, 0) == 0, inVirtualMachine != 0 { return false }
    let specification = [kVTVideoEncoderSpecification_RequireHardwareAcceleratedVideoEncoder: kCFBooleanTrue] as CFDictionary
    var encoderID: CFString?
    var properties: CFDictionary?
    return VTCopySupportedPropertyDictionaryForEncoder(
        width: 1280, height: 800, codecType: kCMVideoCodecType_H264, encoderSpecification: specification,
        encoderIDOut: &encoderID, supportedPropertiesOut: &properties) == noErr
}()

/// End-to-end: a host and a client session in one process, connected over loopback,
/// with real H.264 encode/decode and real data channels.
@Suite(.serialized, .shrinking)
@MainActor
struct PeerSessionTests {
    init() {
        PeerSession.useLoopbackOnlyForTesting()
    }

    /// Guards the H.264 level in VideoCodecs.swift: at WebRTC's default level 3.1,
    /// the 2560x1600 and 3840x2160 cases deliver no frames at all.
    @Test(arguments: [
        PixelSize(width: 1280, height: 720),
        PixelSize(width: 2560, height: 1600),
        PixelSize(width: 3840, height: 2160),
    ])
    func frames_arrive_at_full_resolution(size: PixelSize) async throws {
        let pair = Pair()
        defer { pair.close() }
        try await pair.connect()
        let recorder = try await pair.attachRecorder()

        try await pair.stream(size) { recorder.lastSize == size }
        #expect(recorder.lastSize == size)
    }

    /// Stands in for an Android phone: its WebRTC decodes only Constrained Baseline and declares level 3.1.
    /// The host still sends High to iPads, falls back to Baseline here, and raises the level in the answer
    /// to what the phone's screen needs, so a big window arrives at full size.
    @Test(arguments: zip(
        [PixelSize(width: 720, height: 1280), PixelSize(width: 1080, height: 2400)],
        [PixelSize(width: 1280, height: 1280), PixelSize(width: 2400, height: 1500)]
    ))
    func a_baseline_client_at_level_3_1_gets_full_size_frames(viewport: PixelSize, frame: PixelSize) async throws {
        PortholeVideoDecoderFactory.codecsForTesting = [RTCVideoCodecInfo(name: "H264", parameters: [
            "profile-level-id": "42e01f", "level-asymmetry-allowed": "1", "packetization-mode": "1",
        ])]
        defer { PortholeVideoDecoderFactory.codecsForTesting = nil }
        let pair = Pair()
        defer { pair.close() }
        let answer = try await pair.connect(viewport: viewport)
        #expect(answer.contains("profile-level-id=42e01f") && !answer.contains("profile-level-id=640c"),
                "the stand-in client should answer Baseline 3.1 only:\n\(answer)")
        let recorder = try await pair.attachRecorder()

        try await pair.stream(frame) { recorder.lastSize == frame }
        #expect(recorder.lastSize == frame)
    }

    /// A ProMotion client gets more than 60 frames a second when the session allows 120. Software encoding
    /// and virtual Macs can't keep up, so it only runs on a real Mac with a hardware encoder.
    @Test(.enabled(if: encodesH264AtFullSpeed, "needs a real Mac's hardware H.264 encoder"))
    func frames_pushed_at_120_fps_arrive_faster_than_60() async throws {
        let pair = Pair()
        defer { pair.close() }
        try await pair.connect(viewport: PixelSize(width: 1206, height: 2622), framesPerSecond: 120)
        let recorder = try await pair.attachRecorder()
        let size = PixelSize(width: 1280, height: 800)
        try await pair.stream(size, every: .microseconds(8_333)) { recorder.lastSize == size }

        let start = recorder.frameCount
        let clock = ContinuousClock()
        let began = clock.now
        try await pair.stream(size, every: .microseconds(8_333)) { clock.now - began >= .seconds(2) }
        let perSecond = Double(recorder.frameCount - start) / 2
        #expect(perSecond > 85, "only \(perSecond) frames a second arrived")
    }

    @Test func the_host_offers_high_first_then_baseline() async throws {
        let host = PeerSession(role: .host)
        defer { host.close() }
        let offer = try await host.makeOffer()
        let high = try #require(offer.range(of: "profile-level-id=640c34"))
        let baseline = try #require(offer.range(of: "profile-level-id=42e034"))
        #expect(high.lowerBound < baseline.lowerBound)
    }

    @Test func a_new_frame_size_mid_stream_reaches_the_client() async throws {
        let pair = Pair()
        defer { pair.close() }
        try await pair.connect()
        let recorder = try await pair.attachRecorder()

        let small = PixelSize(width: 1280, height: 800)
        let large = PixelSize(width: 2880, height: 1800)
        try await pair.stream(small) { recorder.lastSize == small }
        try await pair.stream(large) { recorder.lastSize == large }
        #expect(recorder.lastSize == large)
    }

    @Test func prop_host_messages_arrive_in_order_and_intact() async throws {
        let pair = Pair()
        defer { pair.close() }
        try await pair.connect()

        await propertyCheck(count: 25, input: genHostMessage.array(of: 1...4)) { messages in
            let start = pair.clientReceived.count
            for message in messages { pair.host.sendControl(try MessageCoding.encode(message)) }
            try await waitUntil("host messages") { pair.clientReceived.count >= start + messages.count }
            let received = try pair.clientReceived[start...].map { try MessageCoding.decode(HostMessage.self, from: $0) }
            #expect(received == messages)
        }
    }

    @Test func prop_client_messages_arrive_in_order_and_intact() async throws {
        let pair = Pair()
        defer { pair.close() }
        try await pair.connect()

        await propertyCheck(count: 25, input: genClientMessage.array(of: 1...4)) { messages in
            let start = pair.hostReceived.count
            for message in messages { pair.client.sendControl(try MessageCoding.encode(message)) }
            try await waitUntil("client messages") { pair.hostReceived.count >= start + messages.count }
            let received = try pair.hostReceived[start...].map { try MessageCoding.decode(ClientMessage.self, from: $0) }
            #expect(received == messages)
        }
    }

    @Test func sending_before_the_channel_opens_is_dropped_not_crashing() {
        let host = PeerSession(role: .host)
        defer { host.close() }
        host.sendControl(Data("early".utf8))
    }
}

// MARK: - Support

struct TimedOut: Error {}

@MainActor
func waitUntil(_ what: String, timeout: Duration = .seconds(15), _ condition: () -> Bool) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now + timeout
    while !condition() {
        guard clock.now < deadline else {
            Issue.record("Timed out waiting for \(what)")
            throw TimedOut()
        }
        try await Task.sleep(for: .milliseconds(20))
    }
}

/// A connected host and client, with their callbacks recorded on the main actor.
@MainActor
final class Pair {
    let host = PeerSession(role: .host)
    let client = PeerSession(role: .client)
    var hostReceived: [Data] = []
    var clientReceived: [Data] = []
    var hostControlOpen = false
    var clientControlOpen = false
    var track: RTCVideoTrack?
    private var recorder: FrameRecorder?

    init() {
        host.onLocalCandidate = { [weak self] in self?.client.addRemoteCandidate($0) }
        client.onLocalCandidate = { [weak self] in self?.host.addRemoteCandidate($0) }
        host.onControlOpen = { [weak self] in self?.hostControlOpen = true }
        client.onControlOpen = { [weak self] in self?.clientControlOpen = true }
        host.onControlMessage = { [weak self] in self?.hostReceived.append($0) }
        client.onControlMessage = { [weak self] in self?.clientReceived.append($0) }
        client.onRemoteVideoTrack = { [weak self] in self?.track = $0 }
    }

    /// Connects as a client with a screen of `viewport` (an iPad Pro's unless given). Returns the client's answer.
    @discardableResult
    func connect(viewport: PixelSize = PixelSize(width: 2752, height: 2064),
                 framesPerSecond: Int = StreamSizing.defaultFramesPerSecond) async throws -> String {
        let offer = try await host.makeOffer()
        let answer = try await client.acceptOffer(offer)
        try await host.acceptAnswer(answer, viewport: viewport, framesPerSecond: framesPerSecond)
        try await waitUntil("both control channels to open") { self.hostControlOpen && self.clientControlOpen }
        return answer
    }

    func attachRecorder() async throws -> FrameRecorder {
        try await waitUntil("the remote video track") { self.track != nil }
        let recorder = FrameRecorder()
        track?.add(recorder)
        self.recorder = recorder
        return recorder
    }

    /// Pushes frames of `size`, one per `interval` (about 30 fps unless given), until `done` holds.
    func stream(_ size: PixelSize, every interval: Duration = .milliseconds(33), until done: () -> Bool) async throws {
        let frames = [makeFrame(size, shade: 0), makeFrame(size, shade: 1)]
        var index = 0
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(20)
        while !done() {
            guard clock.now < deadline else {
                Issue.record("No \(size.width)x\(size.height) frame reached the client; last was \(String(describing: recorder?.lastSize))")
                throw TimedOut()
            }
            // Alternate two frames so every one is a real change, as a scrolling window would be.
            host.pushFrame(frames[index % 2], timestampNs: Int64(DispatchTime.now().uptimeNanoseconds))
            index += 1
            try await Task.sleep(until: clock.now + interval, tolerance: .microseconds(500))
        }
    }

    func close() {
        if let recorder { track?.remove(recorder) }
        host.close()
        client.close()
    }

    private func makeFrame(_ size: PixelSize, shade: Int) -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let attributes = [kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any]()] as CFDictionary
        CVPixelBufferCreate(nil, size.width, size.height, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, attributes, &buffer)
        let frame = buffer!
        CVPixelBufferLockBaseAddress(frame, [])
        for plane in 0..<2 {
            let rows = CVPixelBufferGetHeightOfPlane(frame, plane)
            let stride = CVPixelBufferGetBytesPerRowOfPlane(frame, plane)
            let base = CVPixelBufferGetBaseAddressOfPlane(frame, plane)!.assumingMemoryBound(to: UInt8.self)
            for row in 0..<rows {
                // A vertical gradient so the encoder has real content, chroma neutral.
                memset(base + row * stride, plane == 0 ? Int32((row * 255 / max(rows, 1) + shade * 40) % 256) : 128, stride)
            }
        }
        CVPixelBufferUnlockBaseAddress(frame, [])
        return frame
    }
}

/// Records the client's decoded frames. WebRTC calls it on its render thread.
final class FrameRecorder: NSObject, RTCVideoRenderer, @unchecked Sendable {
    private let lock = NSLock()
    private var size: PixelSize?
    private var count = 0

    var lastSize: PixelSize? { lock.withLock { size } }
    var frameCount: Int { lock.withLock { count } }

    func setSize(_ size: CGSize) {}

    func renderFrame(_ frame: RTCVideoFrame?) {
        guard let frame else { return }
        lock.withLock {
            size = PixelSize(width: Int(frame.width), height: Int(frame.height))
            count += 1
        }
    }
}
