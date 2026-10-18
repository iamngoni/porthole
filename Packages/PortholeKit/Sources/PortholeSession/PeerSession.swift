@_exported import WebRTC
import CoreVideo
import Foundation
import os
import PortholeProtocol

public enum PeerRole: Sendable {
    /// The Mac: owns the video track and the control channel, and makes the offer.
    case host
    /// The iPad/iPhone: answers and receives.
    case client
}

public enum PeerConnectionState: Sendable, Equatable {
    case new, connecting, connected, disconnected, failed, closed
}

public enum PeerSessionError: Error {
    case noDescription
}

/// One WebRTC connection between a Mac host and a client.
/// Lives on the main actor; WebRTC's callbacks hop onto it in the order they arrive.
/// `pushFrame` may be called from any thread.
@MainActor
public final class PeerSession: NSObject {
    nonisolated public static let controlChannelLabel = "ctl"

    /// Bitrate ceiling on the local network. Text needs a lot of bits to stay crisp at Retina sizes.
    public static let lanMaxBitrateBps = 25_000_000

    nonisolated private static let log = Logger(subsystem: "dev.iamngoni.porthole", category: "peer")

    private static let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        #if os(iOS)
        // Porthole never sends or plays audio; keep WebRTC away from the app's audio session.
        let audio = RTCAudioSession.sharedInstance()
        audio.useManualAudio = true
        audio.isAudioEnabled = false
        #endif
        return RTCPeerConnectionFactory(encoderFactory: PortholeVideoEncoderFactory(), decoderFactory: PortholeVideoDecoderFactory())
    }()

    /// Tests only: keeps ICE on the loopback interface so no local-network permission is involved.
    /// Call before creating any session.
    static func useLoopbackOnlyForTesting() {
        let options = RTCPeerConnectionFactoryOptions()
        options.ignoreLoopbackNetworkAdapter = false
        options.ignoreWiFiNetworkAdapter = true
        options.ignoreEthernetNetworkAdapter = true
        options.ignoreVPNNetworkAdapter = true
        options.ignoreCellularNetworkAdapter = true
        factory.setOptions(options)
    }

    public let role: PeerRole

    public var onLocalCandidate: ((IceCandidate) -> Void)?
    public var onConnectionStateChange: ((PeerConnectionState) -> Void)?
    public var onControlOpen: (() -> Void)?
    public var onControlMessage: ((Data) -> Void)?
    public var onRemoteVideoTrack: ((RTCVideoTrack) -> Void)?

    private var connection: RTCPeerConnection!
    private var controlChannel: RTCDataChannel?
    private var pendingRemoteCandidates: [RTCIceCandidate] = []
    private var hasRemoteDescription = false

    // Host only. Set once in init, then read from the capture thread (both are thread-safe).
    nonisolated(unsafe) private let videoSource: RTCVideoSource?
    nonisolated(unsafe) private let capturer: RTCVideoCapturer?
    private var videoSender: RTCRtpSender?
    private var maxFramesPerSecond = StreamSizing.defaultFramesPerSecond

    public init(role: PeerRole, iceServers: [RTCIceServer] = []) {
        self.role = role
        if role == .host {
            let source = Self.factory.videoSource(forScreenCast: true)
            videoSource = source
            capturer = RTCVideoCapturer(delegate: source)
        } else {
            videoSource = nil
            capturer = nil
        }
        super.init()

        let config = RTCConfiguration()
        config.sdpSemantics = .unifiedPlan
        config.iceServers = iceServers
        config.bundlePolicy = .maxBundle
        config.rtcpMuxPolicy = .require
        config.continualGatheringPolicy = .gatherContinually
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        guard let connection = Self.factory.peerConnection(with: config, constraints: constraints, delegate: self) else {
            preconditionFailure("WebRTC refused to create a peer connection")
        }
        self.connection = connection

        if role == .host, let videoSource {
            let track = Self.factory.videoTrack(with: videoSource, trackId: "window")
            let transceiverInit = RTCRtpTransceiverInit()
            transceiverInit.direction = .sendOnly
            transceiverInit.streamIds = ["porthole"]
            videoSender = connection.addTransceiver(with: track, init: transceiverInit)?.sender

            let channelConfig = RTCDataChannelConfiguration()
            channelConfig.isOrdered = true
            let channel = connection.dataChannel(forLabel: Self.controlChannelLabel, configuration: channelConfig)
            channel?.delegate = self
            controlChannel = channel
        }
    }

    // MARK: Negotiation

    /// Host: creates the offer and applies it locally.
    public func makeOffer() async throws -> String {
        let offer = try await createDescription { self.connection.offer(for: Self.noConstraints, completionHandler: $0) }
        try await apply { self.connection.setLocalDescription(offer, completionHandler: $0) }
        return offer.sdp
    }

    /// Host: applies the answer from a client whose screen is `viewport`, for video at up to
    /// `framesPerSecond`. Raises the H.264 level in it to what streams for that screen need at that rate,
    /// and adds bitrate hints. Returns the level, which bounds how fast big windows can be sent.
    @discardableResult
    public func acceptAnswer(_ sdp: String, viewport: PixelSize,
                             framesPerSecond: Int = StreamSizing.defaultFramesPerSecond) async throws -> H264Level {
        let level = StreamSizing.h264Level(forViewport: viewport, framesPerSecond: framesPerSecond)
        let leveled = SDPMunger.raisingH264Level(in: sdp, toAtLeast: level)
        let tuned = SDPMunger.addingBitrateHints(to: leveled, startKbps: 8_000, minKbps: 1_000, maxKbps: Self.lanMaxBitrateBps / 1000)
        try await setRemote(RTCSessionDescription(type: .answer, sdp: tuned))
        maxFramesPerSecond = framesPerSecond
        applyEncodingParameters()
        return level
    }

    /// Host: the most frames per second the encoder sends. The capture decides the real rate.
    public func setMaxFramesPerSecond(_ framesPerSecond: Int) {
        maxFramesPerSecond = framesPerSecond
        applyEncodingParameters()
    }

    /// Client: applies the host's offer and returns the answer.
    public func acceptOffer(_ sdp: String) async throws -> String {
        try await setRemote(RTCSessionDescription(type: .offer, sdp: sdp))
        let answer = try await createDescription { self.connection.answer(for: Self.noConstraints, completionHandler: $0) }
        try await apply { self.connection.setLocalDescription(answer, completionHandler: $0) }
        return answer.sdp
    }

    public func addRemoteCandidate(_ candidate: IceCandidate) {
        let rtc = RTCIceCandidate(sdp: candidate.sdp, sdpMLineIndex: candidate.sdpMLineIndex, sdpMid: candidate.sdpMid)
        guard hasRemoteDescription else {
            pendingRemoteCandidates.append(rtc)
            return
        }
        add(rtc)
    }

    // MARK: Media and control

    /// Host: hands one captured frame to the encoder.
    nonisolated public func pushFrame(_ pixelBuffer: CVPixelBuffer, timestampNs: Int64) {
        guard let videoSource, let capturer else { return }
        let frame = RTCVideoFrame(buffer: RTCCVPixelBuffer(pixelBuffer: pixelBuffer), rotation: ._0, timeStampNs: timestampNs)
        videoSource.capturer(capturer, didCapture: frame)
    }

    /// Control messages are binary protobuf. `isBinary: false` is only for text, like the debug test feed's JSON.
    public func sendControl(_ data: Data, isBinary: Bool = true) {
        guard let controlChannel, controlChannel.readyState == .open else { return }
        controlChannel.sendData(RTCDataBuffer(data: data, isBinary: isBinary))
    }

    /// Closes the connection. Events WebRTC already queued run against nil callbacks, so nothing reaches a later session.
    public func close() {
        onLocalCandidate = nil
        onConnectionStateChange = nil
        onControlOpen = nil
        onControlMessage = nil
        onRemoteVideoTrack = nil
        controlChannel?.close()
        connection.close()
    }

    // MARK: Private

    private static let noConstraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)

    private func setRemote(_ description: RTCSessionDescription) async throws {
        try await apply { self.connection.setRemoteDescription(description, completionHandler: $0) }
        hasRemoteDescription = true
        let queued = pendingRemoteCandidates
        pendingRemoteCandidates.removeAll()
        queued.forEach(add)
    }

    private func add(_ candidate: RTCIceCandidate) {
        connection.add(candidate) { error in
            if let error { Self.log.error("remote candidate rejected: \(error.localizedDescription, privacy: .public)") }
        }
    }

    private func applyEncodingParameters() {
        guard let videoSender else { return }
        let parameters = videoSender.parameters
        for encoding in parameters.encodings {
            encoding.maxBitrateBps = NSNumber(value: Self.lanMaxBitrateBps)
            encoding.maxFramerate = NSNumber(value: maxFramesPerSecond)
        }
        // Under congestion drop frames, not resolution: blurry text is worse than a lower frame rate.
        parameters.degradationPreference = NSNumber(value: RTCDegradationPreference.maintainResolution.rawValue)
        videoSender.parameters = parameters
    }

    private func createDescription(_ start: (@escaping (RTCSessionDescription?, Error?) -> Void) -> Void) async throws -> RTCSessionDescription {
        try await withCheckedThrowingContinuation { continuation in
            start { description, error in
                if let description {
                    continuation.resume(returning: description)
                } else {
                    continuation.resume(throwing: error ?? PeerSessionError.noDescription)
                }
            }
        }
    }

    private func apply(_ start: (@escaping (Error?) -> Void) -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            start { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    /// FIFO hop to the main actor. Order matters: the control channel must be stored before its first message.
    nonisolated private func onMain(_ work: @escaping @MainActor () -> Void) {
        DispatchQueue.main.async { MainActor.assumeIsolated(work) }
    }
}

// MARK: - RTCPeerConnectionDelegate

extension PeerSession: RTCPeerConnectionDelegate {
    nonisolated public func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    nonisolated public func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    nonisolated public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    nonisolated public func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    nonisolated public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {}
    nonisolated public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    nonisolated public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}

    nonisolated public func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        let local = IceCandidate(sdp: candidate.sdp, sdpMLineIndex: candidate.sdpMLineIndex, sdpMid: candidate.sdpMid)
        onMain { self.onLocalCandidate?(local) }
    }

    nonisolated public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCPeerConnectionState) {
        let state: PeerConnectionState = switch newState {
        case .new: .new
        case .connecting: .connecting
        case .connected: .connected
        case .disconnected: .disconnected
        case .failed: .failed
        case .closed: .closed
        @unknown default: .failed
        }
        Self.log.info("connection state \(String(describing: state), privacy: .public)")
        onMain { self.onConnectionStateChange?(state) }
    }

    nonisolated public func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        guard dataChannel.label == Self.controlChannelLabel else { return }
        // Attach right away: messages that arrive with no delegate are dropped by WebRTC.
        dataChannel.delegate = self
        let isOpen = dataChannel.readyState == .open
        onMain {
            self.controlChannel = dataChannel
            if isOpen { self.onControlOpen?() }
        }
    }

    nonisolated public func peerConnection(_ peerConnection: RTCPeerConnection, didAdd rtpReceiver: RTCRtpReceiver, streams mediaStreams: [RTCMediaStream]) {
        guard let track = rtpReceiver.track as? RTCVideoTrack else { return }
        onMain { self.onRemoteVideoTrack?(track) }
    }
}

// MARK: - RTCDataChannelDelegate

extension PeerSession: RTCDataChannelDelegate {
    nonisolated public func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        guard dataChannel.readyState == .open else { return }
        onMain { self.onControlOpen?() }
    }

    nonisolated public func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        let data = buffer.data
        onMain { self.onControlMessage?(data) }
    }
}
