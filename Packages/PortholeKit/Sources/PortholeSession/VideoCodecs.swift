import Foundation
import WebRTC

/// H.264 only, advertised at level 5.2 on both sides.
///
/// WebRTC's defaults declare level 3.1, which tells the sender not to exceed roughly 1280x720.
/// Each side receives at the level it declares (level asymmetry is allowed), so the host's
/// encoder and the client's decoder both need the higher level for Retina-sized windows.
/// Clients that declare less (Android's WebRTC always does) get their level raised by the host;
/// see `StreamSizing.h264Level(forViewport:)`.
enum PortholeCodecs {
    /// Constrained High (profile 0x64, constraint flags 0x0c), level 5.2 (0x34). Preferred: better
    /// quality for the bits, and what iPads and iPhones decode in hardware.
    static let h264High = h264(profileLevelID: "640c34")

    /// Constrained Baseline (profile 0x42, constraint flags 0xe0), level 5.2. Every hardware decoder takes
    /// it. Android's WebRTC offers High only on some chips (Qualcomm and Exynos), so without this many
    /// phones would get no video at all.
    static let h264Baseline = h264(profileLevelID: "42e034")

    private static func h264(profileLevelID: String) -> RTCVideoCodecInfo {
        RTCVideoCodecInfo(name: "H264", parameters: [
            "profile-level-id": profileLevelID,
            "level-asymmetry-allowed": "1",
            "packetization-mode": "1",
        ])
    }
}

final class PortholeVideoEncoderFactory: NSObject, RTCVideoEncoderFactory {
    func createEncoder(_ info: RTCVideoCodecInfo) -> (any RTCVideoEncoder)? {
        RTCVideoEncoderH264(codecInfo: info)
    }

    func supportedCodecs() -> [RTCVideoCodecInfo] {
        [PortholeCodecs.h264High, PortholeCodecs.h264Baseline]
    }
}

final class PortholeVideoDecoderFactory: NSObject, RTCVideoDecoderFactory {
    /// Tests only: what the client claims to decode, to stand in for another platform's WebRTC.
    /// Set before creating the session.
    nonisolated(unsafe) static var codecsForTesting: [RTCVideoCodecInfo]?

    func createDecoder(_ info: RTCVideoCodecInfo) -> (any RTCVideoDecoder)? {
        RTCVideoDecoderH264()
    }

    func supportedCodecs() -> [RTCVideoCodecInfo] {
        Self.codecsForTesting ?? [PortholeCodecs.h264High]
    }
}
