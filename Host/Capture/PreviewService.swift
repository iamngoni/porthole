import AppKit
import ImageIO
import os
import PortholeProtocol
import ScreenCaptureKit
import UniformTypeIdentifiers

/// Stills of windows and app icons for the device's window picker.
@MainActor
final class PreviewService {
    /// Thumbnails this recent are sent again instead of captured again.
    static let freshFor: TimeInterval = 2
    static let maxWindowsPerRequest = 40

    private static let log = Logger(subsystem: "dev.iamngoni.porthole", category: "previews")

    private var cache: [UInt32: (jpeg: Data, at: Date, longSide: Int)] = [:]
    private var iconCache: [String: Data] = [:]
    private var isCapturing = false
    private var queued: (ids: [UInt32], longSide: Int, deliver: (UInt32, Data) -> Void)?

    /// Captures each window (only windows the Mac offers) and hands back JPEGs one at a time, so the
    /// first cards fill in while the rest are still being taken. Overlapping requests collapse into the latest.
    func thumbnails(for ids: [UInt32], maxLongSide: Int, deliver: @escaping (UInt32, Data) -> Void) {
        let longSide = min(max(maxLongSide, PreviewSizing.longSideRange.lowerBound), PreviewSizing.longSideRange.upperBound)
        let offered = Set(WindowCatalog.streamableWindows().map(\.id))
        let wanted = Array(ids.filter(offered.contains).prefix(Self.maxWindowsPerRequest))
        guard !isCapturing else {
            queued = (wanted, longSide, deliver)
            return
        }
        isCapturing = true
        Task {
            await capture(wanted, longSide: longSide, deliver: deliver)
            isCapturing = false
            if let next = queued {
                queued = nil
                thumbnails(for: next.ids, maxLongSide: next.longSide, deliver: next.deliver)
            }
        }
    }

    private func capture(_ ids: [UInt32], longSide: Int, deliver: (UInt32, Data) -> Void) async {
        guard !ids.isEmpty else { return }
        let now = Date()
        var stale: [UInt32] = []
        for id in ids {
            if let cached = cache[id], now.timeIntervalSince(cached.at) < Self.freshFor, cached.longSide >= longSide {
                deliver(id, cached.jpeg)
            } else {
                stale.append(id)
            }
        }
        guard !stale.isEmpty,
              let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false) else { return }
        let windows = Dictionary(content.windows.map { ($0.windowID, $0) }, uniquingKeysWith: { first, _ in first })
        for id in stale {
            guard let window = windows[id], window.frame.width >= 1, window.frame.height >= 1 else { continue }
            let pixels = StreamSizing.outputPixelSize(
                windowPoints: PointSize(width: window.frame.width, height: window.frame.height),
                backingScale: 2, maxLongSide: longSide)
            let configuration = SCStreamConfiguration()
            configuration.width = pixels.width
            configuration.height = pixels.height
            configuration.showsCursor = false
            configuration.ignoreShadowsSingleWindow = true
            configuration.scalesToFit = true
            do {
                let image = try await SCScreenshotManager.captureImage(
                    contentFilter: SCContentFilter(desktopIndependentWindow: window), configuration: configuration)
                guard let jpeg = Self.jpeg(image, longSide: longSide) else {
                    Self.log.info("no thumbnail for window \(id): too detailed to fit in a message")
                    continue
                }
                cache[id] = (jpeg, Date(), longSide)
                deliver(id, jpeg)
            } catch {
                Self.log.info("no thumbnail for window \(id): \(error.localizedDescription, privacy: .public)")
            }
        }
        // Forget windows that are gone.
        let alive = Set(windows.keys)
        cache = cache.filter { alive.contains($0.key) }
    }

    /// The app's icon as a 128-pixel PNG, for apps that own a window the Mac offers (`windowApps`), or that
    /// it offered to open (`listed` is where that app is).
    func icon(for bundleID: String, listedAt listed: URL?, windowApps: Set<String>) -> Data? {
        if let cached = iconCache[bundleID] { return cached }
        let url: URL
        if let listed {
            url = listed
        } else {
            guard windowApps.contains(bundleID),
                  let found = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
            url = found
        }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        let side = 128
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8,
                                            samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        icon.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
        NSGraphicsContext.restoreGraphicsState()
        guard let png = bitmap.representation(using: .png, properties: [:]) else { return nil }
        iconCache[bundleID] = png
        return png
    }

    func reset() {
        cache = [:]
        queued = nil
    }

    /// A JPEG small enough for one control message, made smaller or rougher only as far as it has to be.
    private static func jpeg(_ image: CGImage, longSide: Int) -> Data? {
        for attempt in PreviewSizing.attempts(longSide: longSide) {
            guard let still = scaled(image, toLongSide: attempt.longSide),
                  let data = jpeg(still, quality: attempt.quality) else { continue }
            if data.count <= PreviewSizing.maxJPEGBytes { return data }
        }
        return nil
    }

    private static func jpeg(_ image: CGImage, quality: Double) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    /// The image with its long side at most `longSide`. Never scales up.
    private static func scaled(_ image: CGImage, toLongSide longSide: Int) -> CGImage? {
        let factor = Double(longSide) / Double(max(image.width, image.height))
        guard factor < 1 else { return image }
        let width = max(1, Int((Double(image.width) * factor).rounded()))
        let height = max(1, Int((Double(image.height) * factor).rounded()))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}
