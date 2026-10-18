import Foundation
import PropertyBased
import SwiftProtobuf
import Testing
@testable import PortholeProtocol

@Suite(.shrinking)
struct StreamSizingTests {
    static var genScale: Gen_<Double> { pick([1.0, 1.5, 2.0, 3.0]) }
    static var genCap: Gen_<Int> { Gen.int(in: 0...5000).eraseToAny() }

    // MARK: Properties

    @Test
    func prop_output_is_even_positive_and_within_cap() async {
        await propertyCheck(count: 500, input: genPointSize, Self.genScale, Self.genCap) { points, scale, cap in
            let out = StreamSizing.outputPixelSize(windowPoints: points, backingScale: scale, maxLongSide: cap)
            #expect(out.width >= 2 && out.height >= 2)
            #expect(out.width % 2 == 0 && out.height % 2 == 0)
            #expect(out.longSide <= max(2, cap))
        }
    }

    @Test
    func prop_never_upscales_past_native_pixels() async {
        await propertyCheck(count: 500, input: genPointSize, Self.genScale, Self.genCap) { points, scale, cap in
            let out = StreamSizing.outputPixelSize(windowPoints: points, backingScale: scale, maxLongSide: cap)
            #expect(Double(out.width) <= max(2, max(1, points.width) * scale))
            #expect(Double(out.height) <= max(2, max(1, points.height) * scale))
        }
    }

    @Test
    func prop_keeps_aspect_ratio_within_rounding() async {
        // Only windows big enough that 2 px of rounding is a small fraction of each side.
        let genWindow = zip(Gen.double(in: 200...4000), Gen.double(in: 200...4000)).map { PointSize(width: $0, height: $1) }
        await propertyCheck(count: 500, input: genWindow, Self.genScale, Gen.int(in: 1280...3840)) { points, scale, cap in
            let out = StreamSizing.outputPixelSize(windowPoints: points, backingScale: scale, maxLongSide: cap)
            let expected = points.width / points.height
            let actual = Double(out.width) / Double(out.height)
            let tolerance = expected * (3.0 / Double(min(out.width, out.height)) + 3.0 / Double(max(out.width, out.height)))
            #expect(abs(actual - expected) <= tolerance)
        }
    }

    @Test
    func prop_larger_cap_never_gives_smaller_video() async {
        await propertyCheck(count: 500, input: genPointSize, Self.genScale, Self.genCap, Gen.int(in: 0...2000)) { points, scale, cap, extra in
            let small = StreamSizing.outputPixelSize(windowPoints: points, backingScale: scale, maxLongSide: cap)
            let large = StreamSizing.outputPixelSize(windowPoints: points, backingScale: scale, maxLongSide: cap + extra)
            #expect(large.width >= small.width && large.height >= small.height)
        }
    }

    @Test
    func prop_viewport_cap_stays_in_bounds_and_is_monotonic() async {
        await propertyCheck(count: 500, input: genPixelSize, Gen.int(in: 0...4000)) { viewport, extra in
            let cap = StreamSizing.cap(forViewport: viewport)
            #expect((StreamSizing.minimumCap...StreamSizing.absoluteMaxLongSide).contains(cap))
            let bigger = PixelSize(width: viewport.width + extra, height: viewport.height + extra)
            #expect(StreamSizing.cap(forViewport: bigger) >= cap)
        }
    }

    // MARK: Examples

    @Test func retina_window_scaled_to_ipad_pro_screen() {
        let out = StreamSizing.outputPixelSize(windowPoints: PointSize(width: 1600, height: 1000), backingScale: 2, maxLongSide: 2752)
        #expect(out == PixelSize(width: 2752, height: 1720))
    }

    @Test func small_window_is_sent_at_native_size() {
        let out = StreamSizing.outputPixelSize(windowPoints: PointSize(width: 800, height: 600), backingScale: 1, maxLongSide: 3840)
        #expect(out == PixelSize(width: 800, height: 600))
    }

    @Test func odd_sizes_round_down_to_even() {
        let out = StreamSizing.outputPixelSize(windowPoints: PointSize(width: 801, height: 601), backingScale: 1, maxLongSide: 3840)
        #expect(out == PixelSize(width: 800, height: 600))
    }

    @Test func garbage_input_still_gives_a_valid_size() {
        let out = StreamSizing.outputPixelSize(windowPoints: PointSize(width: .nan, height: -5), backingScale: .infinity, maxLongSide: -1)
        #expect(out == PixelSize(width: 2, height: 2))
    }

    @Test func iphone_viewport_gets_minimum_cap() {
        #expect(StreamSizing.cap(forViewport: PixelSize(width: 1179, height: 1206)) == 1280)
        #expect(StreamSizing.cap(forViewport: PixelSize(width: 6016, height: 3384)) == 3840)
    }
}

@Suite(.shrinking)
struct H264LevelTests {
    static var genLevel: Gen_<H264Level> { pick(H264Level.allCases) }
    static var genFPS: Gen_<Int> { Gen.int(in: 1...120).eraseToAny() }
    static var genLimit: Gen_<Int> { Gen.int(in: 30...120).eraseToAny() }

    // MARK: Properties

    @Test
    func prop_a_higher_level_allows_everything_a_lower_one_does() async {
        await propertyCheck(count: 500, input: genPixelSize, Self.genFPS, Self.genLevel, Self.genLevel) { size, fps, a, b in
            let (low, high) = (min(a, b), max(a, b))
            if low.allows(size, framesPerSecond: fps) {
                #expect(high.allows(size, framesPerSecond: fps))
            }
        }
    }

    @Test
    func prop_the_lowest_level_fits_the_stream_and_no_lower_one_does() async {
        await propertyCheck(count: 500, input: genPixelSize, Self.genFPS) { size, fps in
            let level = H264Level.lowest(for: size, framesPerSecond: fps)
            #expect(level.allows(size, framesPerSecond: fps) || level == .level5_2)
            #expect(H264Level.allCases.filter { $0 < level }.allSatisfy { !$0.allows(size, framesPerSecond: fps) })
        }
    }

    @Test
    func prop_bigger_or_faster_streams_never_need_a_lower_level() async {
        await propertyCheck(count: 500, input: genPixelSize, Self.genFPS, Gen.int(in: 0...2000), Gen.int(in: 0...60)) { size, fps, grow, faster in
            let level = H264Level.lowest(for: size, framesPerSecond: fps)
            let bigger = PixelSize(width: size.width + grow, height: size.height + grow / 2)
            #expect(H264Level.lowest(for: bigger, framesPerSecond: fps + faster) >= level)
        }
    }

    @Test
    func prop_every_frame_the_host_sends_fits_the_level_unless_it_is_too_big_even_at_60() async {
        await propertyCheck(count: 500, input: genPixelSize, genPointSize, StreamSizingTests.genScale, Self.genLimit) { viewport, window, scale, limit in
            let policy = FrameRatePolicy(limit: limit, level: StreamSizing.h264Level(forViewport: viewport, framesPerSecond: limit))
            let frame = StreamSizing.outputPixelSize(windowPoints: window, backingScale: scale, maxLongSide: StreamSizing.cap(forViewport: viewport))
            let fps = policy.framesPerSecond(for: frame)
            #expect(policy.level.allows(frame, framesPerSecond: fps) || (policy.level == .level5_2 && fps == min(limit, 60)))
        }
    }

    @Test
    func prop_a_bigger_screen_never_gets_a_lower_level() async {
        await propertyCheck(count: 500, input: genPixelSize, Gen.int(in: 0...4000)) { viewport, extra in
            let bigger = PixelSize(width: viewport.width + extra, height: viewport.height)
            #expect(StreamSizing.h264Level(forViewport: bigger) >= StreamSizing.h264Level(forViewport: viewport))
        }
    }

    // MARK: Examples (Table A-1)

    @Test func common_formats_get_the_levels_the_standard_gives_them() {
        #expect(H264Level.lowest(for: PixelSize(width: 1280, height: 720), framesPerSecond: 30) == .level3_1)
        #expect(H264Level.lowest(for: PixelSize(width: 1920, height: 1080), framesPerSecond: 30) == .level4)
        #expect(H264Level.lowest(for: PixelSize(width: 1920, height: 1080), framesPerSecond: 60) == .level4_2)
        #expect(H264Level.lowest(for: PixelSize(width: 3840, height: 2160), framesPerSecond: 30) == .level5_1)
        #expect(H264Level.lowest(for: PixelSize(width: 3840, height: 2160), framesPerSecond: 60) == .level5_2)
    }

    @Test func faster_screens_need_higher_levels() {
        #expect(StreamSizing.h264Level(forViewport: PixelSize(width: 720, height: 1280), framesPerSecond: 120) == .level5_1)
        #expect(StreamSizing.h264Level(forViewport: PixelSize(width: 720, height: 1280), framesPerSecond: 30) == .level4)
    }

    @Test func a_small_phone_gets_4_2_and_a_big_one_5_2() {
        #expect(StreamSizing.h264Level(forViewport: PixelSize(width: 720, height: 1280)) == .level4_2)
        #expect(StreamSizing.h264Level(forViewport: PixelSize(width: 1080, height: 1920)) == .level5_1)
        #expect(StreamSizing.h264Level(forViewport: PixelSize(width: 1080, height: 2400)) == .level5_2)
        #expect(StreamSizing.h264Level(forViewport: PixelSize(width: 2752, height: 2064)) == .level5_2)
    }
}

@Suite(.shrinking)
struct PreviewSizingTests {
    // MARK: Properties

    @Test
    func prop_attempts_start_with_what_was_asked_and_only_get_cheaper() async {
        await propertyCheck(count: 500, input: Gen.int(in: -100...2000)) { asked in
            let attempts = PreviewSizing.attempts(longSide: asked)
            let range = PreviewSizing.longSideRange
            #expect(attempts.first == .init(longSide: min(max(asked, range.lowerBound), range.upperBound), quality: PreviewSizing.quality))
            for (previous, next) in zip(attempts, attempts.dropFirst()) {
                #expect(next.longSide <= previous.longSide && next.quality <= previous.quality)
                #expect(next != previous)
            }
        }
    }

    @Test
    func prop_attempts_stay_in_range_and_end_at_the_smallest_still() async {
        await propertyCheck(count: 500, input: Gen.int(in: -100...2000)) { asked in
            let attempts = PreviewSizing.attempts(longSide: asked)
            #expect(attempts.allSatisfy { PreviewSizing.longSideRange.contains($0.longSide) })
            #expect(attempts.last == .init(longSide: PreviewSizing.longSideRange.lowerBound, quality: PreviewSizing.fallbackQuality))
        }
    }

    // MARK: Examples

    @Test func an_800_pixel_still_steps_down_to_160() {
        #expect(PreviewSizing.attempts(longSide: 800).map(\.longSide) == [800, 800, 600, 400, 160])
        #expect(PreviewSizing.attempts(longSide: 160) == [.init(longSide: 160, quality: 0.62), .init(longSide: 160, quality: 0.45)])
    }

    @Test func the_largest_still_fits_one_control_message_after_base64() {
        let base64 = (PreviewSizing.maxJPEGBytes + 2) / 3 * 4
        #expect(base64 + 1024 <= 240 * 1024)
    }
}

@Suite(.shrinking)
struct FrameRateTests {
    static var genRefresh: Gen_<Int> { Gen.int(in: -10...500).eraseToAny() }

    // MARK: Properties

    @Test
    func prop_the_limit_is_what_both_screens_show_within_30_to_120() async {
        await propertyCheck(count: 500, input: Self.genRefresh, Self.genRefresh.optional) { mac, device in
            let limit = StreamSizing.frameRateLimit(macRefresh: mac, deviceRefresh: device)
            #expect((30...120).contains(limit))
            if mac >= 30 { #expect(limit <= mac) }
            if let device, device >= 30 { #expect(limit <= device) }
            if device == nil { #expect(limit <= 60) }
        }
    }

    @Test
    func prop_the_rate_stays_between_60_and_the_limit() async {
        await propertyCheck(count: 500, input: genPixelSize, H264LevelTests.genLimit, H264LevelTests.genLevel) { size, limit, level in
            let fps = FrameRatePolicy(limit: limit, level: level).framesPerSecond(for: size)
            #expect(fps <= limit && fps >= min(limit, 60))
            if fps > 60 { #expect(level.allows(size, framesPerSecond: fps)) }
        }
    }

    @Test
    func prop_a_smaller_window_never_runs_slower() async {
        await propertyCheck(count: 500, input: genPixelSize, Gen.int(in: 0...3000), H264LevelTests.genLimit, H264LevelTests.genLevel) { size, grow, limit, level in
            let policy = FrameRatePolicy(limit: limit, level: level)
            let bigger = PixelSize(width: size.width + grow, height: size.height + grow / 3)
            #expect(policy.framesPerSecond(for: size) >= policy.framesPerSecond(for: bigger))
        }
    }

    // MARK: Examples

    @Test func an_iphone_on_a_100_hz_mac_gets_100_and_an_ipad_air_60() {
        #expect(StreamSizing.frameRateLimit(macRefresh: 100, deviceRefresh: 120) == 100)
        #expect(StreamSizing.frameRateLimit(macRefresh: 100, deviceRefresh: 60) == 60)
        #expect(StreamSizing.frameRateLimit(macRefresh: 120, deviceRefresh: nil) == 60)
        #expect(StreamSizing.frameRateLimit(macRefresh: 240, deviceRefresh: 144) == 120)
    }

    @Test func a_window_too_big_for_120_steps_down_to_a_rate_that_fits() {
        let policy = FrameRatePolicy(limit: 120, level: .level5_2)
        #expect(policy.framesPerSecond(for: PixelSize(width: 2560, height: 1600)) == 120)
        #expect(policy.framesPerSecond(for: PixelSize(width: 2752, height: 2064)) == 90)
        #expect(policy.framesPerSecond(for: PixelSize(width: 3840, height: 2400)) == 60)
        #expect(FrameRatePolicy.standard.framesPerSecond(for: PixelSize(width: 3840, height: 2400)) == 60)
    }

    @Test func a_hello_from_before_120_fps_support_still_decodes() throws {
        var old = PBSignal()
        old.hello = .with { $0.protocolVersion = 3; $0.deviceName = "iPad"; $0.viewport = .with { $0.width = 2360; $0.height = 1640 } }
        guard case .hello(let hello) = try MessageCoding.decode(SignalMessage.self, from: old.serializedData()) else {
            Issue.record("not a hello")
            return
        }
        #expect(hello.maxFramesPerSecond == nil && hello.viewport == PixelSize(width: 2360, height: 1640))
    }
}
