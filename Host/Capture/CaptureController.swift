import CoreMedia
import Foundation
import os
import PortholeProtocol
import ScreenCaptureKit

enum CaptureError: LocalizedError {
    case windowNotFound

    var errorDescription: String? {
        switch self {
        case .windowNotFound: "That window is no longer open."
        }
    }
}

/// Captures exactly one window with ScreenCaptureKit and follows it as it resizes.
/// Window mode keeps capturing even when other windows cover it.
///
/// Start, stop and resize run strictly one at a time, and the newest start or stop wins:
/// an operation that has been superseded throws `CancellationError` at its next checkpoint
/// and leaves cleanup to the operation queued after it.
@MainActor
final class CaptureController: NSObject {
    /// Fires when the window changes size. Same `gen`, new sizes.
    var onGeometryChange: ((StreamInfo) -> Void)?
    /// Fires when the window closes or capture stops on its own.
    var onStopped: ((StreamInfo, String) -> Void)?

    let pump = FramePump()
    private(set) var current: StreamInfo?

    private static let log = Logger(subsystem: "dev.iamngoni.porthole", category: "capture")

    private var stream: SCStream?
    private var backingScale: Double = 2
    private var maxLongSide = StreamSizing.minimumCap
    private var frameRate = FrameRatePolicy.standard
    private var gen: UInt32 = 0
    private var watchTimer: Timer?
    /// Bounds seen on the previous poll; a resize is applied once two polls agree.
    private var lastSeenSize: CGSize?

    /// Bumped by every start and stop. An operation is current only while this still matches its own number.
    private var request: UInt64 = 0
    private var tail: Task<Void, Never>?

    /// Starts streaming `windowID`, or switches the running stream to it, at the rate `frameRate` gives its size.
    func start(windowID: UInt32, maxLongSide: Int, frameRate: FrameRatePolicy) async throws -> StreamInfo {
        request &+= 1
        let mine = request
        return try await enqueue {
            try await self.performStart(windowID: windowID, maxLongSide: maxLongSide, frameRate: frameRate, request: mine)
        }
    }

    /// Stops capture. Safe to call at any time, including while a start is still in flight.
    func stop() async {
        request &+= 1
        try? await enqueue { await self.performStop() }
    }

    // MARK: Serialized operations

    private func enqueue<T>(_ work: @escaping @MainActor () async throws -> T) async throws -> T {
        let previous = tail
        let operation = Task { @MainActor in
            await previous?.value
            return try await work()
        }
        tail = Task { _ = try? await operation.value }
        return try await operation.value
    }

    private func ensureCurrent(_ mine: UInt64) throws {
        if request != mine { throw CancellationError() }
    }

    private func performStart(windowID: UInt32, maxLongSide: Int, frameRate: FrameRatePolicy, request mine: UInt64) async throws -> StreamInfo {
        try ensureCurrent(mine)
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
        try ensureCurrent(mine)
        guard let window = content.windows.first(where: { $0.windowID == windowID }) else {
            throw CaptureError.windowNotFound
        }
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let scale = Double(filter.pointPixelScale)
        let points = PointSize(width: filter.contentRect.width, height: filter.contentRect.height)
        let pixels = StreamSizing.outputPixelSize(windowPoints: points, backingScale: scale, maxLongSide: maxLongSide)
        let fps = frameRate.framesPerSecond(for: pixels)
        let configuration = Self.configuration(for: pixels, framesPerSecond: fps)

        if let stream {
            try await stream.updateContentFilter(filter)
            try ensureCurrent(mine)
            try await stream.updateConfiguration(configuration)
        } else {
            let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
            try stream.addStreamOutput(pump, type: .screen, sampleHandlerQueue: pump.queue)
            // Record it before awaiting, so a stop queued behind this start can find it and stop it.
            self.stream = stream
            pump.setActiveStream(stream)
            do {
                try await stream.startCapture()
            } catch {
                self.stream = nil
                pump.setActiveStream(nil)
                throw error
            }
        }
        try ensureCurrent(mine)

        // The previous window's last frame must not be repeated under the new stream's info.
        pump.discardLastFrame()
        backingScale = scale
        self.maxLongSide = maxLongSide
        self.frameRate = frameRate
        gen &+= 1
        let info = StreamInfo(
            gen: gen, windowID: windowID,
            title: window.title ?? "", appName: window.owningApplication?.applicationName ?? "",
            pointSize: points, pixelSize: pixels, framesPerSecond: fps
        )
        current = info
        lastSeenSize = nil
        pump.startRepeating()
        startWatching()
        Self.log.info("streaming window \(windowID, privacy: .public) at \(pixels.width, privacy: .public)x\(pixels.height, privacy: .public), up to \(fps, privacy: .public) fps")
        return info
    }

    private func performStop() async {
        watchTimer?.invalidate()
        watchTimer = nil
        lastSeenSize = nil
        pump.stopRepeating()
        current = nil
        if let stream {
            self.stream = nil
            pump.setActiveStream(nil)
            try? await stream.stopCapture()
        }
        // After stopCapture returns no more frames arrive, so this really is the last one.
        pump.discardLastFrame()
    }

    private func performResize(to points: PointSize, gen expected: UInt32) async {
        guard let stream, let info = current, info.gen == expected else { return }
        let pixels = StreamSizing.outputPixelSize(windowPoints: points, backingScale: backingScale, maxLongSide: maxLongSide)
        // A bigger window may need a slower rate to stay within the H.264 level, a smaller one can go faster.
        let fps = frameRate.framesPerSecond(for: pixels)
        let changed = pixels != info.pixelSize || fps != info.framesPerSecond
        if changed {
            do {
                try await stream.updateConfiguration(Self.configuration(for: pixels, framesPerSecond: fps))
            } catch {
                Self.log.error("resize failed: \(error.localizedDescription, privacy: .public)")
                return
            }
        }
        // Re-read after the await: a switch or stop may have happened meanwhile.
        guard self.stream === stream, var latest = current, latest.gen == expected else { return }
        latest.pointSize = points
        latest.pixelSize = pixels
        latest.framesPerSecond = fps
        current = latest
        if changed { onGeometryChange?(latest) }
    }

    private static func configuration(for size: PixelSize, framesPerSecond: Int) -> SCStreamConfiguration {
        let configuration = SCStreamConfiguration()
        configuration.width = size.width
        configuration.height = size.height
        // NV12 goes straight into the VideoToolbox H.264 encoder with no conversion.
        configuration.pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        configuration.colorSpaceName = CGColorSpace.sRGB
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(framesPerSecond))
        configuration.queueDepth = 5
        // The device is driven by touch: a Mac pointer jumping to every tap would only get in the way.
        configuration.showsCursor = false
        configuration.scalesToFit = true
        configuration.preservesAspectRatio = true
        configuration.ignoreShadowsSingleWindow = true
        return configuration
    }

    // MARK: Following the window

    private func startWatching() {
        watchTimer?.invalidate()
        watchTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkWindow() }
        }
    }

    private func checkWindow() {
        guard let info = current else { return }
        guard let bounds = WindowCatalog.bounds(of: info.windowID) else {
            Task { await stopBecause("The window was closed.", gen: info.gen) }
            return
        }
        let size = bounds.size
        let resized = abs(size.width - info.pointSize.width) >= 1 || abs(size.height - info.pointSize.height) >= 1
        defer { lastSeenSize = size }
        // Apply only once the size holds still for two polls, so a drag doesn't reconfigure the encoder on every step.
        guard resized, size == lastSeenSize else { return }
        let points = PointSize(width: size.width, height: size.height)
        Task { try? await enqueue { await self.performResize(to: points, gen: info.gen) } }
    }

    private func stopBecause(_ reason: String, gen expected: UInt32) async {
        guard let info = current, info.gen == expected else { return }
        await stop()
        onStopped?(info, reason)
    }
}

extension CaptureController: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        let reason = error.localizedDescription
        Task { @MainActor in
            guard self.stream === stream, let info = self.current else { return }
            await self.stopBecause(reason, gen: info.gen)
        }
    }
}

/// Receives frames on the capture queue and forwards them to the encoder.
///
/// ScreenCaptureKit only delivers a frame when the window changes. The encoder needs input to
/// answer keyframe requests, so the last frame is re-sent a few times a second while idle.
final class FramePump: NSObject, SCStreamOutput {
    let queue = DispatchQueue(label: "dev.iamngoni.porthole.capture", qos: .userInteractive)

    private static let idleRepeatInterval: UInt64 = 200_000_000

    // Everything below is confined to `queue`.
    private var sink: (@Sendable (CVPixelBuffer, Int64) -> Void)?
    private var activeStream: SCStream?
    private var lastBuffer: CVPixelBuffer?
    private var lastFrameNs: UInt64 = 0
    private var timer: DispatchSourceTimer?

    func setSink(_ sink: (@Sendable (CVPixelBuffer, Int64) -> Void)?) {
        queue.async { self.sink = sink }
    }

    /// Frames from any other stream (one being stopped or replaced) are dropped.
    func setActiveStream(_ stream: SCStream?) {
        queue.async { self.activeStream = stream }
    }

    func discardLastFrame() {
        queue.async { self.lastBuffer = nil }
    }

    func startRepeating() {
        queue.async { [weak self] in
            guard let self, self.timer == nil else { return }
            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now() + .milliseconds(200), repeating: .milliseconds(200))
            timer.setEventHandler { [weak self] in self?.repeatIfIdle() }
            timer.resume()
            self.timer = timer
        }
    }

    func stopRepeating() {
        queue.async {
            self.timer?.cancel()
            self.timer = nil
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, stream === activeStream, sampleBuffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let rawStatus = attachments.first?[.status] as? Int,
              SCFrameStatus(rawValue: rawStatus) == .complete,
              let pixelBuffer = sampleBuffer.imageBuffer
        else { return }
        deliver(pixelBuffer)
    }

    private func repeatIfIdle() {
        guard let lastBuffer, DispatchTime.now().uptimeNanoseconds - lastFrameNs >= Self.idleRepeatInterval else { return }
        deliver(lastBuffer)
    }

    private func deliver(_ pixelBuffer: CVPixelBuffer) {
        let now = DispatchTime.now().uptimeNanoseconds
        lastBuffer = pixelBuffer
        lastFrameNs = now
        sink?(pixelBuffer, Int64(now))
    }
}
