#if DEBUG
import AppKit
import CoreText
import CoreVideo
import Network
import os
import PortholeProtocol
import PortholeSession
import VideoToolbox

/// Development only, for the Flutter trial run: streams a synthetic test pattern to whoever connects on
/// TCP port 47800, with plain JSON signaling (no pairing, nothing sealed). Starts only in debug builds
/// launched with `-spike`. It never shows a real window and never clicks or types on the Mac: input from
/// the device only moves marks on the pattern. Remove once the Flutter client speaks the real protocol.
@MainActor
final class SpikeService {
    static let port: NWEndpoint.Port = 47800
    private static var shared: SpikeService?
    nonisolated static let log = Logger(subsystem: "dev.iamngoni.porthole", category: "spike")

    static func startIfAsked() {
        guard CommandLine.arguments.contains("-spike"), shared == nil else { return }
        shared = SpikeService()
    }

    private var listener: NWListener?
    private var connection: NWConnection?
    private var decoder = FrameDecoder()
    private var peer: PeerSession?
    private var viewport = PixelSize(width: 2752, height: 2064)
    private let pattern = SpikePattern()

    private init() {
        do {
            let tcp = NWProtocolTCP.Options()
            tcp.noDelay = true
            let listener = try NWListener(using: NWParameters(tls: nil, tcp: tcp), on: Self.port)
            listener.newConnectionHandler = { [weak self] connection in
                MainActor.assumeIsolated { self?.accept(connection) }
            }
            listener.stateUpdateHandler = { state in
                Self.log.notice("spike listener: \(String(describing: state), privacy: .public)")
            }
            listener.start(queue: .main)
            self.listener = listener
        } catch {
            Self.log.error("spike listener failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: Signaling

    /// One device at a time; a new one replaces the old.
    private func accept(_ new: NWConnection) {
        endSession()
        Self.log.notice("spike: device connected from \(new.endpoint.debugDescription, privacy: .public)")
        connection = new
        decoder = FrameDecoder()
        new.stateUpdateHandler = { [weak self] state in
            MainActor.assumeIsolated {
                guard let self, self.connection === new else { return }
                switch state {
                case .failed, .cancelled: self.endSession()
                default: break
                }
            }
        }
        new.start(queue: .main)
        receive(on: new)
    }

    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            MainActor.assumeIsolated {
                guard let self, self.connection === connection else { return }
                if let data, !data.isEmpty {
                    do {
                        for frame in try self.decoder.append(data) {
                            guard let message = try JSONSerialization.jsonObject(with: frame) as? [String: Any] else { continue }
                            self.handle(message)
                        }
                    } catch {
                        Self.log.error("spike: bad signaling data: \(String(describing: error), privacy: .public)")
                        self.endSession()
                        return
                    }
                }
                if error != nil || isComplete {
                    self.endSession()
                } else {
                    self.receive(on: connection)
                }
            }
        }
    }

    private func send(_ message: [String: Any]) {
        guard let connection, let data = try? JSONSerialization.data(withJSONObject: message) else { return }
        connection.send(content: Framing.frame(data), completion: .contentProcessed { _ in })
    }

    private func handle(_ message: [String: Any]) {
        if let hello = message["hello"] as? [String: Any] {
            if let width = hello["width"] as? Int, let height = hello["height"] as? Int, width > 0, height > 0 {
                viewport = PixelSize(width: width, height: height)
            }
            Self.log.notice("spike: hello from \(hello["name"] as? String ?? "?", privacy: .public), screen \(self.viewport.width)x\(self.viewport.height) at \(hello["refreshRate"] as? Int ?? 0) Hz")
            startPeer()
        } else if let sdp = message["answer"] as? String, let peer {
            let viewport = viewport
            Task {
                do {
                    // The pattern decides the real rate; let the encoder go as fast as it asks.
                    try await peer.acceptAnswer(sdp, viewport: viewport, framesPerSecond: StreamSizing.absoluteMaxFramesPerSecond)
                    Self.log.notice("spike: answer applied; codec line: \(Self.h264Line(in: sdp), privacy: .public)")
                } catch {
                    Self.log.error("spike: bad answer: \(error.localizedDescription, privacy: .public)")
                    self.endSession()
                }
            }
        } else if let candidate = message["candidate"] as? [String: Any], let sdp = candidate["candidate"] as? String {
            peer?.addRemoteCandidate(IceCandidate(sdp: sdp, sdpMLineIndex: Int32(candidate["sdpMLineIndex"] as? Int ?? 0),
                                                  sdpMid: candidate["sdpMid"] as? String))
        }
    }

    private func startPeer() {
        peer?.close()
        let peer = PeerSession(role: .host)
        self.peer = peer
        peer.onLocalCandidate = { [weak self] candidate in
            self?.send(["candidate": ["candidate": candidate.sdp, "sdpMLineIndex": Int(candidate.sdpMLineIndex),
                                      "sdpMid": candidate.sdpMid ?? "0"]])
        }
        peer.onConnectionStateChange = { [weak self] state in
            Self.log.notice("spike: peer \(String(describing: state), privacy: .public)")
            if state == .connected { self?.pattern.start(pushingTo: peer) }
            if state == .failed || state == .closed { self?.pattern.stop() }
        }
        peer.onControlMessage = { [weak self] data in self?.control(data) }
        Task {
            do {
                send(["offer": try await peer.makeOffer()])
            } catch {
                Self.log.error("spike: no offer: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func control(_ data: Data) {
        guard let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = message["t"] as? String else { return }
        switch type {
        case "ping":
            reply(["t": "pong", "at": message["at"] ?? 0])
        case "tap":
            pattern.tap(x: message["x"] as? Double ?? 0, y: message["y"] as? Double ?? 0, kind: message["kind"] as? String ?? "tap")
        case "scroll":
            pattern.scroll(by: message["dy"] as? Double ?? 0)
        case "key":
            pattern.key(usage: message["usage"] as? Int ?? 0, down: message["down"] as? Bool ?? false)
        case "text":
            pattern.type(message["s"] as? String ?? "")
        case "pattern":
            pattern.configure(width: message["w"] as? Int, height: message["h"] as? Int, fps: message["fps"] as? Int)
            if let fps = message["fps"] as? Int, (1...StreamSizing.absoluteMaxFramesPerSecond).contains(fps) {
                peer?.setMaxFramesPerSecond(fps)
            }
            Self.log.notice("spike: pattern now \(String(describing: message), privacy: .public)")
        case "stats":
            // The device reports what it measured, so it can be read from the Mac's log.
            let text = (try? JSONSerialization.data(withJSONObject: message, options: [.sortedKeys])).flatMap { String(data: $0, encoding: .utf8) } ?? ""
            Self.log.notice("spike stats: \(text, privacy: .public)")
        default:
            break
        }
    }

    private func reply(_ message: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: message) else { return }
        peer?.sendControl(data, isBinary: false)
    }

    private func endSession() {
        pattern.stop()
        peer?.close()
        peer = nil
        connection?.cancel()
        connection = nil
    }

    private static func h264Line(in sdp: String) -> String {
        sdp.split(whereSeparator: \.isNewline).first { $0.contains("profile-level-id") }.map(String.init) ?? "none"
    }
}

/// Draws the test pattern on its own queue and hands each frame to the encoder: scrolling text, a frame
/// counter, a bar sweeping across every two seconds (judder and dropped frames show as jumps), and the
/// last few taps.
final class SpikePattern: @unchecked Sendable {
    private let queue = DispatchQueue(label: "dev.iamngoni.porthole.spike-pattern", qos: .userInteractive)
    private let lock = NSLock()
    private var size = PixelSize(width: 2560, height: 1600)
    private var fps = 60
    private var scrollY = 0.0
    private var taps: [(x: Double, y: Double, kind: String, at: Double)] = []
    private var typed = ""
    private var lastKey = "none"

    // Only touched on `queue`.
    private var timer: DispatchSourceTimer?
    private var frameNumber = 0
    private var started = 0.0
    private var drawPool: CVPixelBufferPool?
    private var videoPool: CVPixelBufferPool?
    private var poolSize: PixelSize?
    private var transfer: VTPixelTransferSession?
    private var lines: (fontSize: CGFloat, lines: [CTLine])?
    /// The scrolling text, drawn once per scroll position: at 120 fps there's no time to lay it out every frame.
    private var body: (size: PixelSize, scrollY: Double, image: CGImage)?
    private var renderTime: (total: Double, frames: Int) = (0, 0)

    private static let lineTexts: [String] = (1...400).map { number in
        let phrases = ["The quick brown fox jumps over the lazy dog.", "func render(frame: Int) -> CVPixelBuffer { … }",
                       "Porthole streams one Mac window to a phone or tablet.", "0123456789 !@#$%^&*() []{} <> ~ | \\ / ? ;:",
                       "Thin lines and small text show blur first: iiiillll1111 ||||", "Ünïcödé ✓ — “quotes” · ellipsis… ½ ⌘⌥⇧"]
        return String(format: "%04d  ", number) + phrases[number % phrases.count] + "  " + phrases[(number * 7) % phrases.count]
    }

    func start(pushingTo peer: PeerSession) {
        queue.async { [self, weak peer] in
            stopTimer()
            started = CACurrentMediaTime()
            let fps = lock.withLock { self.fps }
            let timer = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
            timer.schedule(deadline: .now(), repeating: .nanoseconds(1_000_000_000 / max(1, fps)), leeway: .microseconds(500))
            timer.setEventHandler { [weak self, weak peer] in
                guard let self, let peer, let frame = self.render() else { return }
                peer.pushFrame(frame, timestampNs: Int64(DispatchTime.now().uptimeNanoseconds))
            }
            timer.resume()
            self.timer = timer
        }
    }

    func stop() {
        queue.async { [self] in stopTimer() }
    }

    func configure(width: Int?, height: Int?, fps: Int?) {
        let restart: Bool = lock.withLock {
            if let width, let height, (16...4096).contains(width), (16...4096).contains(height) {
                size = PixelSize(width: width & ~1, height: height & ~1)
            }
            let changed = fps.map { (1...120).contains($0) && $0 != self.fps } ?? false
            if let fps, changed { self.fps = fps }
            return changed
        }
        if restart {
            queue.async { [self] in
                guard let timer else { return }
                let fps = lock.withLock { self.fps }
                timer.schedule(deadline: .now(), repeating: .nanoseconds(1_000_000_000 / fps), leeway: .microseconds(500))
            }
        }
    }

    func tap(x: Double, y: Double, kind: String) {
        lock.withLock {
            taps.append((min(max(x, 0), 1), min(max(y, 0), 1), kind, CACurrentMediaTime()))
            taps = Array(taps.suffix(6))
        }
    }

    func scroll(by dy: Double) {
        guard dy.isFinite else { return }
        lock.withLock { scrollY = max(0, scrollY + dy) }
    }

    func key(usage: Int, down: Bool) {
        lock.withLock { lastKey = String(format: "0x%02X %@", usage, down ? "down" : "up") }
    }

    func type(_ text: String) {
        lock.withLock { typed = String((typed + text).suffix(80)) }
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }

    // MARK: Drawing

    private func render() -> CVPixelBuffer? {
        let (size, scrollY, taps, typed, lastKey, fps) = lock.withLock { (self.size, self.scrollY, self.taps, self.typed, self.lastKey, self.fps) }
        if poolSize != size { makePools(size) }
        guard let drawPool, let videoPool, let transfer else { return nil }
        var drawBuffer: CVPixelBuffer?
        var videoBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, drawPool, &drawBuffer)
        CVPixelBufferPoolCreatePixelBuffer(nil, videoPool, &videoBuffer)
        guard let drawBuffer, let videoBuffer else { return nil }

        CVPixelBufferLockBaseAddress(drawBuffer, [])
        let context = CGContext(data: CVPixelBufferGetBaseAddress(drawBuffer), width: size.width, height: size.height,
                                bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(drawBuffer),
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        if let context {
            let began = CACurrentMediaTime()
            draw(in: context, size: size, scrollY: scrollY, taps: taps, typed: typed, lastKey: lastKey, fps: fps, now: began)
            frameNumber += 1
            renderTime = (renderTime.total + CACurrentMediaTime() - began, renderTime.frames + 1)
            if renderTime.frames == 240 {
                let milliseconds = renderTime.total / 240 * 1000
                SpikeService.log.notice("spike: drawing a frame takes \(milliseconds, format: .fixed(precision: 2)) ms at \(size.width)x\(size.height)")
                renderTime = (0, 0)
            }
        }
        CVPixelBufferUnlockBaseAddress(drawBuffer, [])
        guard context != nil else { return nil }
        // The encoder takes the same 4:2:0 frames ScreenCaptureKit gives the real stream.
        return VTPixelTransferSessionTransferImage(transfer, from: drawBuffer, to: videoBuffer) == noErr ? videoBuffer : nil
    }

    private func draw(in context: CGContext, size: PixelSize, scrollY: Double, taps: [(x: Double, y: Double, kind: String, at: Double)],
                      typed: String, lastKey: String, fps: Int, now: Double) {
        let width = CGFloat(size.width), height = CGFloat(size.height)
        // CoreGraphics puts the origin at the bottom left; `top` converts from top-left coordinates.
        func top(_ y: CGFloat) -> CGFloat { height - y }

        let fontSize = max(10, (height / 52).rounded())
        let headerHeight = fontSize * 3.2
        if let image = bodyImage(size: size, scrollY: scrollY, fontSize: fontSize, headerHeight: headerHeight) {
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }

        // Header: frame counter and time, redrawn every frame.
        context.setFillColor(CGColor(srgbRed: 0.14, green: 0.15, blue: 0.18, alpha: 1))
        context.fill(CGRect(x: 0, y: top(headerHeight), width: width, height: headerHeight))
        let elapsed = now - started
        let header = String(format: "frame %06d   t %8.3f s   %d×%d @ %d fps   key %@   scroll %.0f",
                            frameNumber, elapsed, size.width, size.height, fps, lastKey, scrollY)
        drawText(header, at: CGPoint(x: fontSize, y: top(headerHeight * 0.62)), size: fontSize * 1.1, color: .white, in: context)

        // Sweeping bar: one pass every two seconds.
        let phase = CGFloat(elapsed.truncatingRemainder(dividingBy: 2) / 2)
        context.setFillColor(CGColor(srgbRed: 0.47, green: 0.66, blue: 1, alpha: 0.85))
        context.fill(CGRect(x: phase * (width - width / 60), y: 0, width: width / 60, height: top(headerHeight)))

        // Taps, fading over 1.5 s.
        for tap in taps {
            let age = now - tap.at
            guard age < 1.5 else { continue }
            let alpha = CGFloat(1 - age / 1.5)
            let radius = height / 28
            let center = CGPoint(x: CGFloat(tap.x) * width, y: top(CGFloat(tap.y) * height))
            let color = tap.kind == "secondary" ? CGColor(srgbRed: 1, green: 0.62, blue: 0.3, alpha: alpha) : CGColor(srgbRed: 1, green: 1, blue: 1, alpha: alpha)
            context.setStrokeColor(color)
            context.setLineWidth(radius / 6)
            context.strokeEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            context.setFillColor(color)
            context.fillEllipse(in: CGRect(x: center.x - radius / 5, y: center.y - radius / 5, width: radius / 2.5, height: radius / 2.5))
        }

        // What was typed.
        context.setFillColor(CGColor(srgbRed: 0.14, green: 0.15, blue: 0.18, alpha: 0.92))
        context.fill(CGRect(x: 0, y: 0, width: width, height: headerHeight))
        drawText("typed: " + typed, at: CGPoint(x: fontSize, y: headerHeight * 0.38), size: fontSize * 1.1, color: .white, in: context)
    }

    /// The background and scrolling text for this scroll position, drawn only when it changes.
    private func bodyImage(size: PixelSize, scrollY: Double, fontSize: CGFloat, headerHeight: CGFloat) -> CGImage? {
        if let body, body.size == size, body.scrollY == scrollY { return body.image }
        let width = CGFloat(size.width), height = CGFloat(size.height)
        guard let context = CGContext(data: nil, width: size.width, height: size.height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        else { return nil }
        context.setFillColor(CGColor(srgbRed: 0.08, green: 0.085, blue: 0.1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let textLines = cachedLines(fontSize: fontSize)
        let lineHeight = fontSize * 1.55
        let first = Int(scrollY / lineHeight)
        let shift = CGFloat(scrollY.truncatingRemainder(dividingBy: lineHeight))
        var y = headerHeight + lineHeight - shift
        var index = first
        while y < height + lineHeight {
            context.textPosition = CGPoint(x: fontSize, y: height - y)
            CTLineDraw(textLines[index % textLines.count], context)
            y += lineHeight
            index += 1
        }
        guard let image = context.makeImage() else { return nil }
        body = (size, scrollY, image)
        return image
    }

    private func cachedLines(fontSize: CGFloat) -> [CTLine] {
        if let lines, lines.fontSize == fontSize { return lines.lines }
        let font = CTFontCreateWithName("Menlo" as CFString, fontSize, nil)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: CGColor(srgbRed: 0.86, green: 0.88, blue: 0.92, alpha: 1)]
        let made = Self.lineTexts.map { CTLineCreateWithAttributedString(NSAttributedString(string: $0, attributes: attributes)) }
        lines = (fontSize, made)
        return made
    }

    private func drawText(_ text: String, at point: CGPoint, size: CGFloat, color: NSColor, in context: CGContext) {
        let font = CTFontCreateWithName("Menlo-Bold" as CFString, size, nil)
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color.cgColor]))
        context.textPosition = point
        CTLineDraw(line, context)
    }

    private func makePools(_ size: PixelSize) {
        func pool(_ format: OSType) -> CVPixelBufferPool? {
            let attributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: format,
                kCVPixelBufferWidthKey as String: size.width,
                kCVPixelBufferHeightKey as String: size.height,
                kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
            ]
            var pool: CVPixelBufferPool?
            CVPixelBufferPoolCreate(nil, nil, attributes as CFDictionary, &pool)
            return pool
        }
        drawPool = pool(kCVPixelFormatType_32BGRA)
        videoPool = pool(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
        if transfer == nil {
            var session: VTPixelTransferSession?
            VTPixelTransferSessionCreate(allocator: nil, pixelTransferSessionOut: &session)
            transfer = session
        }
        poolSize = size
    }
}
#endif
