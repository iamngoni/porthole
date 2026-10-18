import CoreGraphics
import Foundation
import PropertyBased
import Testing
@testable import PortholeProtocol

@Suite(.shrinking)
struct InputLogicTests {
    static var genBounds: Gen_<CGRect> {
        zip(Gen.double(in: -3000...3000), Gen.double(in: -2000...2000), Gen.double(in: 100...4000), Gen.double(in: 100...3000))
            .map { CGRect(x: $0, y: $1, width: $2, height: $3) }.eraseToAny()
    }

    // MARK: Geometry

    @Test func prop_every_point_lands_inside_the_window() async {
        await propertyCheck(count: 500, input: genNormalizedPoint, Self.genBounds) { point, bounds in
            let global = InputGeometry.globalPoint(point, in: bounds)
            #expect(bounds.contains(global))
        }
    }

    @Test func prop_moving_right_in_the_video_moves_right_on_the_mac() async {
        await propertyCheck(count: 300, input: Gen.double(in: 0...1), Gen.double(in: 0...1), Gen.double(in: 0...1), Self.genBounds) { a, b, y, bounds in
            let left = InputGeometry.globalPoint(NormalizedPoint(x: min(a, b), y: y), in: bounds)
            let right = InputGeometry.globalPoint(NormalizedPoint(x: max(a, b), y: y), in: bounds)
            #expect(left.x <= right.x)
            #expect(left.y == right.y)
        }
    }

    @Test func center_maps_to_window_center() {
        let point = InputGeometry.globalPoint(NormalizedPoint(x: 0.5, y: 0.5), in: CGRect(x: 100, y: 50, width: 800, height: 600))
        #expect(point == CGPoint(x: 500, y: 350))
    }

    @Test func garbage_points_go_to_the_center() {
        let point = InputGeometry.globalPoint(NormalizedPoint(x: .nan, y: .infinity), in: CGRect(x: 0, y: 0, width: 200, height: 100))
        #expect(point == CGPoint(x: 100, y: 50))
    }

    // MARK: Scroll accumulation

    @Test func prop_accumulated_pixels_never_drift_more_than_one_from_the_input() async {
        await propertyCheck(count: 300, input: Gen.double(in: -40...40).array(of: 1...60), Gen.double(in: -40...40).array(of: 1...60)) { xs, ys in
            var accumulator = ScrollAccumulator()
            var inX = 0.0, inY = 0.0, outX = 0.0, outY = 0.0
            for (dx, dy) in zip(xs, ys) {
                let step = accumulator.take(dx: dx, dy: dy)
                inX += dx; inY += dy
                outX += Double(step.dx); outY += Double(step.dy)
                #expect(abs(inX - outX) < 1 && abs(inY - outY) < 1)
            }
        }
    }

    @Test func slow_scroll_still_moves() {
        var accumulator = ScrollAccumulator()
        // Quarter-pixel steps are exact in binary, so twelve of them are exactly three pixels.
        let moved = (0..<12).map { _ in accumulator.take(dx: 0, dy: 0.25).dy }.reduce(0, +)
        #expect(moved == 3)
    }

    // MARK: Click counting

    @Test func prop_click_count_is_at_least_one_and_grows_by_at_most_one() async {
        let genPress = zip(pick([MouseButton.left, .right]), Gen.double(in: 0...10), Gen.double(in: 0...10), Gen.double(in: 0...0.8))
        await propertyCheck(count: 300, input: genPress.array(of: 1...30)) { presses in
            var tracker = ClickTracker()
            var time = 0.0
            var previous = 0
            for (button, x, y, gap) in presses {
                time += gap
                let count = tracker.press(button, at: CGPoint(x: x, y: y), time: time, interval: 0.5)
                #expect(count >= 1 && count <= previous + 1)
                previous = count
            }
        }
    }

    @Test func prop_a_slow_second_press_starts_over() async {
        await propertyCheck(count: 200, input: Gen.double(in: 0.51...5)) { gap in
            var tracker = ClickTracker()
            _ = tracker.press(.left, at: .zero, time: 1, interval: 0.5)
            #expect(tracker.press(.left, at: .zero, time: 1 + gap, interval: 0.5) == 1)
        }
    }

    @Test func two_quick_taps_in_place_are_a_double_click_and_three_a_triple() {
        var tracker = ClickTracker()
        #expect(tracker.press(.left, at: CGPoint(x: 10, y: 10), time: 0, interval: 0.5) == 1)
        #expect(tracker.press(.left, at: CGPoint(x: 11, y: 12), time: 0.2, interval: 0.5) == 2)
        #expect(tracker.press(.left, at: CGPoint(x: 10, y: 11), time: 0.4, interval: 0.5) == 3)
    }

    @Test func a_quick_tap_elsewhere_or_with_another_button_is_a_new_click() {
        var tracker = ClickTracker()
        _ = tracker.press(.left, at: .zero, time: 0, interval: 0.5)
        #expect(tracker.press(.left, at: CGPoint(x: 20, y: 0), time: 0.1, interval: 0.5) == 1)
        #expect(tracker.press(.right, at: CGPoint(x: 20, y: 0), time: 0.2, interval: 0.5) == 1)
    }

    // MARK: Momentum

    @Test func prop_momentum_slows_keeps_direction_and_stops() async {
        let genVelocity = zip(Gen.double(in: -20_000...20_000), Gen.double(in: -20_000...20_000)).map { CGPoint(x: $0, y: $1) }
        await propertyCheck(count: 300, input: genVelocity) { velocity in
            var scroller = MomentumScroller(velocity: velocity)
            var lastSpeed = Double.infinity
            var steps = 0
            var travelled = 0.0
            while let step = scroller.next() {
                let speed = hypot(step.dx, step.dy)
                #expect(speed <= lastSpeed)
                #expect(step.dx * Double(velocity.x) >= 0 && step.dy * Double(velocity.y) >= 0)
                lastSpeed = speed
                travelled += speed
                steps += 1
                if steps > 1_000 { break }
            }
            #expect(steps <= 1_000)
            // A geometric series: never further than the first step divided by (1 - decay).
            let first = hypot(Double(velocity.x), Double(velocity.y)) / 60
            #expect(travelled <= first / (1 - MomentumScroller.decayPerFrame) + 1e-6)
        }
    }

    @Test func no_velocity_means_no_momentum() {
        var scroller = MomentumScroller(velocity: .zero)
        #expect(scroller.next() == nil)
    }
}

@Suite(.shrinking)
struct HIDKeyMapTests {
    @Test func every_mapped_key_has_its_own_mac_key() {
        let keys = HIDKeyMap.allUsages.compactMap(HIDKeyMap.virtualKey(forUsage:))
        #expect(Set(keys).count == keys.count)
    }

    @Test func prop_every_us_character_maps_to_a_real_mac_key() async {
        let printable = (32...126).map { Character(UnicodeScalar(UInt8($0))) } + ["\n", "\t"]
        await propertyCheck(count: 300, input: pick(printable)) { character in
            let key = try #require(HIDKeyMap.usage(forCharacter: character))
            #expect(HIDKeyMap.virtualKey(forUsage: key.usage) != nil)
        }
    }

    @Test func prop_upper_and_lower_case_share_a_key() async {
        await propertyCheck(count: 100, input: pick(Array("abcdefghijklmnopqrstuvwxyz"))) { letter in
            let lower = try #require(HIDKeyMap.usage(forCharacter: letter))
            let upper = try #require(HIDKeyMap.usage(forCharacter: Character(letter.uppercased())))
            #expect(lower.usage == upper.usage && !lower.shift && upper.shift)
        }
    }

    @Test func known_keys() {
        #expect(HIDKeyMap.virtualKey(forUsage: 0x04) == 0x00) // A
        #expect(HIDKeyMap.virtualKey(forUsage: 0x28) == 0x24) // Return
        #expect(HIDKeyMap.virtualKey(forUsage: 0x2A) == 0x33) // Delete
        #expect(HIDKeyMap.virtualKey(forUsage: 0x52) == 0x7E) // Up
        #expect(HIDKeyMap.virtualKey(forUsage: 0xE3) == 0x37) // Command
        #expect(HIDKeyMap.modifier(forUsage: 0xE7) == .command)
        #expect(HIDKeyMap.usage(forCharacter: "?")! == (0x38, true))
        #expect(HIDKeyMap.usage(forCharacter: "é") == nil)
    }
}

@Suite(.shrinking)
struct TextTypingTests {
    /// Text people actually type, plus line breaks, tabs, controls and long emoji sequences.
    static var genTypedText: Gen_<String> {
        pick(["a", "Z", " ", "é", "ß", "中", "😀", "👍🏽", "🇿🇼", "👨‍👩‍👧‍👦", "\n", "\r\n", "\r", "\t", "\u{7}", "\u{7F}",
              "👨‍👩‍👧‍👦👨‍👩‍👧‍👦👨‍👩‍👧‍👦", "e\u{301}"])
            .array(of: 0...40).map { $0.joined() }.eraseToAny()
    }

    /// The expected result, built independently: line breaks become "\n", controls disappear.
    static func normalized(_ text: String) -> String {
        String(text.map { character -> String in
            switch character {
            case "\r\n", "\r", "\n": "\n"
            case "\t": "\t"
            default: character.unicodeScalars.allSatisfy { $0.properties.generalCategory == .control } ? "" : String(character)
            }
        }.joined())
    }

    static func retyped(_ segments: [TextSegment]) -> String {
        segments.map { segment -> String in
            switch segment {
            case .characters(let units): String(decoding: units, as: UTF16.self)
            case .key(HIDKeyMap.Usage.returnKey): "\n"
            case .key(HIDKeyMap.Usage.tab): "\t"
            case .key: "?"
            }
        }.joined()
    }

    @Test func prop_typing_reproduces_the_text() async {
        await propertyCheck(count: 400, input: Self.genTypedText) { text in
            #expect(Self.retyped(TextTyping.segments(text)) == Self.normalized(text))
        }
    }

    @Test func prop_every_event_fits_and_holds_whole_scalars() async {
        await propertyCheck(count: 400, input: Self.genTypedText) { text in
            for case .characters(let units) in TextTyping.segments(text) {
                #expect(!units.isEmpty && units.count <= TextTyping.maxUTF16PerEvent)
                #expect(!UTF16.isLeadSurrogate(units.last!) && !UTF16.isTrailSurrogate(units.first!))
            }
        }
    }

    @Test func line_breaks_and_tabs_are_keys() {
        #expect(TextTyping.segments("hi\r\nyo\tz") == [
            .characters(Array("hi".utf16)), .key(usage: 0x28), .characters(Array("yo".utf16)), .key(usage: 0x2B), .characters(Array("z".utf16)),
        ])
    }

    @Test func long_text_is_split_into_events_of_twenty() {
        let segments = TextTyping.segments(String(repeating: "x", count: 45))
        #expect(segments.map { if case .characters(let u) = $0 { u.count } else { 0 } } == [20, 20, 5])
    }
}

@Suite(.shrinking)
struct DisplayNameTests {
    static var genName: Gen_<String> {
        pick(["iPad", " ", "\n", "\u{202E}", "\u{0}", "Ngoni’s", "👨‍👩‍👧‍👦", "\t", "a", "\u{200B}"])
            .array(of: 0...60).map { $0.joined() }.eraseToAny()
    }

    @Test func prop_cleaned_names_are_short_visible_and_never_empty() async {
        await propertyCheck(count: 400, input: Self.genName) { name in
            let cleaned = DisplayName.clean(name, fallback: "Device")
            #expect(!cleaned.isEmpty && cleaned.count <= DisplayName.maxLength)
            #expect(!cleaned.unicodeScalars.contains { [.control, .lineSeparator, .paragraphSeparator].contains($0.properties.generalCategory) })
            #expect(!cleaned.contains("\u{202E}") && !cleaned.hasPrefix(" ") && !cleaned.hasSuffix(" "))
        }
    }

    @Test func prop_cleaning_twice_changes_nothing() async {
        await propertyCheck(count: 300, input: Self.genName) { name in
            let once = DisplayName.clean(name, fallback: "Device")
            #expect(DisplayName.clean(once, fallback: "Device") == once)
        }
    }

    @Test func examples() {
        #expect(DisplayName.clean("  Ngoni’s\niPad ", fallback: "Device") == "Ngoni’s iPad")
        #expect(DisplayName.clean("\u{202E}\u{0}", fallback: "Device") == "Device")
        #expect(DisplayName.clean(String(repeating: "a", count: 50), fallback: "D") == String(repeating: "a", count: 39) + "…")
    }
}

@Suite(.shrinking)
struct ShortcutPolicyTests {
    @Test func prop_without_command_or_control_every_key_is_allowed() async {
        await propertyCheck(count: 400, input: pick(HIDKeyMap.allUsages), Gen.bool, Gen.bool) { usage, shift, option in
            var modifiers: Modifiers = []
            if shift { modifiers.insert(.shift) }
            if option { modifiers.insert(.option) }
            #expect(ShortcutPolicy.allows(usage: usage, modifiers: modifiers))
        }
    }

    @Test func prop_adding_modifiers_never_unblocks_a_shortcut() async {
        await propertyCheck(count: 400, input: pick(HIDKeyMap.allUsages), genModifiers, genModifiers) { usage, base, extra in
            if !ShortcutPolicy.allows(usage: usage, modifiers: base) {
                #expect(!ShortcutPolicy.allows(usage: usage, modifiers: base.union(extra)))
            }
        }
    }

    @Test func system_shortcuts_are_blocked_and_app_shortcuts_are_not() {
        typealias U = HIDKeyMap.Usage
        #expect(!ShortcutPolicy.allows(usage: U.space, modifiers: .command))
        #expect(!ShortcutPolicy.allows(usage: U.tab, modifiers: .command))
        #expect(!ShortcutPolicy.allows(usage: U.tab, modifiers: [.command, .shift]))
        #expect(!ShortcutPolicy.allows(usage: U.escape, modifiers: [.command, .option]))
        #expect(!ShortcutPolicy.allows(usage: U.q, modifiers: [.command, .control]))
        #expect(!ShortcutPolicy.allows(usage: U.q, modifiers: [.command, .shift]))
        #expect(!ShortcutPolicy.allows(usage: U.upArrow, modifiers: .control))
        #expect(ShortcutPolicy.allows(usage: U.q, modifiers: .command))         // quit the shared app
        #expect(ShortcutPolicy.allows(usage: 0x06, modifiers: .command))        // ⌘C
        #expect(ShortcutPolicy.allows(usage: U.tab, modifiers: .control))       // next tab
        #expect(ShortcutPolicy.allows(usage: U.leftArrow, modifiers: .command)) // line start
        #expect(ShortcutPolicy.allows(usage: U.escape, modifiers: []))
    }
}

extension ShortcutPolicyTests {
    /// The shrunk counterexample from the first run: a `where` on a shared case guarded only its last pattern.
    @Test func plain_arrow_keys_are_allowed() {
        for usage in [HIDKeyMap.Usage.leftArrow, HIDKeyMap.Usage.rightArrow, HIDKeyMap.Usage.upArrow, HIDKeyMap.Usage.downArrow] {
            #expect(ShortcutPolicy.allows(usage: usage, modifiers: []))
        }
    }
}

@Suite(.shrinking)
struct AspectFitTests {
    static var genSize: Gen_<CGSize> {
        zip(Gen.double(in: 1...5000), Gen.double(in: 1...5000)).map { CGSize(width: $0, height: $1) }.eraseToAny()
    }

    @Test func prop_fitted_video_keeps_its_shape_fills_one_side_and_is_centered() async {
        await propertyCheck(count: 500, input: Self.genSize, Self.genSize) { content, bounds in
            let r = AspectFit.rect(content: content, in: bounds)
            let tolerance = 1e-6 * max(bounds.width, bounds.height)
            #expect(r.minX >= -tolerance && r.minY >= -tolerance)
            #expect(r.maxX <= bounds.width + tolerance && r.maxY <= bounds.height + tolerance)
            #expect(abs(r.width / r.height - content.width / content.height) <= 1e-9 * content.width / content.height)
            #expect(abs(r.width - bounds.width) <= tolerance || abs(r.height - bounds.height) <= tolerance)
            #expect(abs(r.midX - bounds.width / 2) <= tolerance && abs(r.midY - bounds.height / 2) <= tolerance)
        }
    }

    @Test func prop_a_spot_on_the_video_maps_back_to_itself() async {
        await propertyCheck(count: 500, input: Self.genSize, Self.genSize, Gen.double(in: 0.001...0.999), Gen.double(in: 0.001...0.999)) { content, bounds, x, y in
            let r = AspectFit.rect(content: content, in: bounds)
            let point = CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height)
            let mapped = try #require(AspectFit.normalized(point, content: content, in: bounds))
            #expect(abs(mapped.x - x) < 1e-6 && abs(mapped.y - y) < 1e-6)
        }
    }

    @Test func prop_the_bars_around_the_video_map_to_nothing() async {
        await propertyCheck(count: 300, input: Self.genSize, Self.genSize, Gen.double(in: 0...1), Gen.double(in: 0...1)) { content, bounds, x, y in
            let point = CGPoint(x: x * bounds.width, y: y * bounds.height)
            let r = AspectFit.rect(content: content, in: bounds)
            #expect((AspectFit.normalized(point, content: content, in: bounds) != nil) == r.contains(point))
        }
    }

    @Test func wide_video_on_a_square_view_has_bars_top_and_bottom() {
        #expect(AspectFit.rect(content: CGSize(width: 1600, height: 900), in: CGSize(width: 800, height: 800))
                == CGRect(x: 0, y: 175, width: 800, height: 450))
        #expect(AspectFit.normalized(CGPoint(x: 400, y: 100), content: CGSize(width: 1600, height: 900), in: CGSize(width: 800, height: 800)) == nil)
        #expect(AspectFit.rect(content: .zero, in: CGSize(width: 10, height: 10)) == .zero)
    }
}

extension ShortcutPolicyTests {
    @Test func control_with_a_function_key_is_blocked_and_function_keys_alone_are_not() {
        for usage in [UInt16(0x3A), 0x3B, 0x45, 0x68, 0x6F] {
            #expect(!ShortcutPolicy.allows(usage: usage, modifiers: .control))
            #expect(ShortcutPolicy.allows(usage: usage, modifiers: []))
        }
    }
}

@Suite(.shrinking)
struct WindowStackTests {
    static var genWindow: Gen_<StackedWindow> {
        zip(Gen.int32(in: 1...5), Gen.double(in: 0...800), Gen.double(in: 0...800), Gen.double(in: 1...800), Gen.double(in: 1...800), pick([0.0, 0.005, 0.5, 1.0]))
            .map { StackedWindow(pid: $0, bounds: CGRect(x: $1, y: $2, width: $3, height: $4), alpha: $5) }.eraseToAny()
    }

    static var genPoint: Gen_<CGPoint> {
        zip(Gen.double(in: 0...1600), Gen.double(in: 0...1600)).map { CGPoint(x: $0, y: $1) }.eraseToAny()
    }

    @Test func prop_windows_behind_never_change_who_gets_the_click() async {
        await propertyCheck(count: 400, input: Self.genWindow.array(of: 0...8), Self.genWindow.array(of: 0...8), Self.genPoint) { front, behind, point in
            let owner = WindowStack.topOwner(at: point, in: front)
            if owner != nil {
                #expect(WindowStack.topOwner(at: point, in: front + behind) == owner)
            }
        }
    }

    @Test func prop_a_visible_window_in_front_takes_the_click() async {
        await propertyCheck(count: 400, input: Self.genWindow, Self.genWindow.array(of: 0...8), Self.genPoint) { cover, stack, point in
            let result = WindowStack.topOwner(at: point, in: [cover] + stack)
            if cover.alpha > 0.01, cover.bounds.contains(point) {
                #expect(result == cover.pid)
            } else {
                #expect(result == WindowStack.topOwner(at: point, in: stack))
            }
        }
    }

    @Test func a_dialog_from_another_app_over_the_window_blocks_the_click() {
        let shared = StackedWindow(pid: 1, bounds: CGRect(x: 0, y: 0, width: 800, height: 600), alpha: 1)
        let dialog = StackedWindow(pid: 2, bounds: CGRect(x: 300, y: 200, width: 200, height: 100), alpha: 1)
        let overlay = StackedWindow(pid: 3, bounds: CGRect(x: 0, y: 0, width: 2000, height: 2000), alpha: 0)
        #expect(WindowStack.topOwner(at: CGPoint(x: 350, y: 250), in: [overlay, dialog, shared]) == 2)
        #expect(WindowStack.topOwner(at: CGPoint(x: 50, y: 50), in: [overlay, dialog, shared]) == 1)
    }
}

@Suite(.shrinking)
struct ZoomViewportTests {
    static var genSize: Gen_<CGSize> {
        zip(Gen.double(in: 1...4000), Gen.double(in: 1...4000)).map { CGSize(width: $0, height: $1) }.eraseToAny()
    }

    static var genPoint: Gen_<CGPoint> {
        zip(Gen.double(in: -3000...3000), Gen.double(in: -3000...3000)).map { CGPoint(x: $0, y: $1) }.eraseToAny()
    }

    /// Any state a gesture could leave behind, including the odd non-finite value.
    static var genViewport: Gen_<ZoomViewport> {
        let scale = Gen.oneOf(Gen.double(in: 0.01...12).eraseToAny(), pick([0, 1, -1, .infinity, .nan]))
        return zip(scale, genPoint).map { ZoomViewport(scale: $0, offset: $1) }.eraseToAny()
    }

    static func close(_ a: CGFloat, _ b: CGFloat, _ scale: CGFloat) -> Bool {
        abs(a - b) <= 1e-6 * max(1, scale)
    }

    @Test func prop_settled_zoom_is_in_range_and_keeps_the_video_over_the_view() async {
        await propertyCheck(count: 500, input: Self.genViewport, Self.genSize, Self.genSize) { viewport, content, bounds in
            let settled = viewport.settled(content: content, in: bounds)
            #expect(settled.scale >= 1 && settled.scale <= ZoomViewport.maxScale)
            let frame = settled.frame(content: content, in: bounds)
            let tolerance = 1e-6 * max(frame.width, frame.height, 1)
            if frame.width > bounds.width + tolerance {
                #expect(frame.minX <= tolerance && frame.maxX >= bounds.width - tolerance)
            } else {
                #expect(Self.close(frame.midX, bounds.width / 2, frame.width))
            }
            if frame.height > bounds.height + tolerance {
                #expect(frame.minY <= tolerance && frame.maxY >= bounds.height - tolerance)
            } else {
                #expect(Self.close(frame.midY, bounds.height / 2, frame.height))
            }
        }
    }

    @Test func prop_settling_twice_changes_nothing() async {
        await propertyCheck(count: 400, input: Self.genViewport, Self.genSize, Self.genSize) { viewport, content, bounds in
            let once = viewport.settled(content: content, in: bounds)
            let twice = once.settled(content: content, in: bounds)
            #expect(once.scale == twice.scale)
            #expect(Self.close(once.offset.x, twice.offset.x, bounds.width) && Self.close(once.offset.y, twice.offset.y, bounds.height))
        }
    }

    @Test func prop_pinching_keeps_the_spot_under_the_fingers() async {
        let genFinite = zip(Gen.double(in: 0.2...6), Self.genPoint).map { ZoomViewport(scale: $0, offset: $1) }.eraseToAny()
        await propertyCheck(count: 500, input: genFinite, Gen.double(in: 0.2...4), Self.genPoint, Self.genSize, Self.genSize) { viewport, factor, anchor, content, bounds in
            let before = try #require(viewport.spot(at: anchor, content: content, in: bounds))
            let after = try #require(viewport.zoomed(by: factor, around: anchor, content: content, in: bounds).spot(at: anchor, content: content, in: bounds))
            #expect(abs(before.x - after.x) <= 1e-6 * max(1, abs(before.x)) && abs(before.y - after.y) <= 1e-6 * max(1, abs(before.y)))
        }
    }

    @Test func prop_two_finger_drag_moves_the_video_with_the_fingers() async {
        await propertyCheck(count: 400, input: Self.genViewport.filter { $0.scale.isFinite && $0.scale > 0 }.eraseToAny(), Self.genPoint, Self.genPoint, Self.genSize, Self.genSize) { viewport, point, move, content, bounds in
            let before = try #require(viewport.spot(at: point, content: content, in: bounds))
            let moved = CGPoint(x: point.x + move.x, y: point.y + move.y)
            let after = try #require(viewport.panned(by: move).spot(at: moved, content: content, in: bounds))
            #expect(abs(before.x - after.x) < 1e-6 * max(1, abs(before.x)) && abs(before.y - after.y) < 1e-6 * max(1, abs(before.y)))
        }
    }

    @Test func prop_unzoomed_touches_land_exactly_where_the_fitted_video_says() async {
        await propertyCheck(count: 400, input: Self.genPoint, Self.genSize, Self.genSize) { point, content, bounds in
            let zoom = ZoomViewport().normalized(point, content: content, in: bounds)
            let fit = AspectFit.normalized(point, content: content, in: bounds)
            #expect((zoom == nil) == (fit == nil))
            if let zoom, let fit {
                #expect(abs(zoom.x - fit.x) < 1e-9 && abs(zoom.y - fit.y) < 1e-9)
            }
        }
    }

    @Test func prop_overshoot_is_drawn_between_the_limit_and_the_finger() async {
        let genFinite = zip(Gen.double(in: 0.2...8), Self.genPoint).map { ZoomViewport(scale: $0, offset: $1) }.eraseToAny()
        await propertyCheck(count: 400, input: genFinite, Self.genSize, Self.genSize) { raw, content, bounds in
            let rest = raw.settled(content: content, in: bounds)
            let shown = raw.resisted(content: content, in: bounds)
            func between(_ value: CGFloat, _ a: CGFloat, _ b: CGFloat) -> Bool {
                value >= min(a, b) - 1e-9 * max(1, abs(a), abs(b)) && value <= max(a, b) + 1e-9 * max(1, abs(a), abs(b))
            }
            #expect(between(shown.scale, rest.scale, raw.scale))
            #expect(between(shown.offset.x, rest.offset.x, raw.offset.x) && between(shown.offset.y, rest.offset.y, raw.offset.y))
        }
    }

    @Test func prop_a_view_at_rest_does_not_resist() async {
        await propertyCheck(count: 300, input: Self.genViewport, Self.genSize, Self.genSize) { viewport, content, bounds in
            let rest = viewport.settled(content: content, in: bounds)
            let shown = rest.resisted(content: content, in: bounds)
            #expect(shown.scale == rest.scale)
            #expect(Self.close(shown.offset.x, rest.offset.x, bounds.width) && Self.close(shown.offset.y, rest.offset.y, bounds.height))
        }
    }

    @Test func pinching_to_double_at_the_center_then_dragging_past_the_edge() {
        let size = CGSize(width: 1000, height: 500)
        let zoomed = ZoomViewport().zoomed(by: 2, around: CGPoint(x: 500, y: 250), content: size, in: size)
        #expect(zoomed.frame(content: size, in: size) == CGRect(x: -500, y: -250, width: 2000, height: 1000))
        // A spot a quarter of the way in now sits at the left edge of the view.
        #expect(zoomed.normalized(CGPoint(x: 0, y: 250), content: size, in: size) == NormalizedPoint(x: 0.25, y: 0.5))
        let dragged = zoomed.panned(by: CGPoint(x: 900, y: 0)).settled(content: size, in: size)
        #expect(dragged.offset == CGPoint(x: 500, y: 0))
    }

    @Test func pinching_in_past_one_springs_back_to_fit() {
        let size = CGSize(width: 800, height: 600)
        let squeezed = ZoomViewport().zoomed(by: 0.5, around: CGPoint(x: 100, y: 100), content: size, in: size)
        #expect(squeezed.scale == 0.7)
        #expect(squeezed.settled(content: size, in: size) == ZoomViewport())
    }
}
