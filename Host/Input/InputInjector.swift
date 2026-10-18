import AppKit
import ApplicationServices
import CoreGraphics
import os
import PortholeProtocol

/// Turns the device's input into real mouse and keyboard events on the Mac, kept to the shared window:
///
/// - Keys and text are posted to the shared app's process, not to whatever has focus, so they can't
///   reach other apps or system-wide shortcuts. `ShortcutPolicy` drops a few more as a second line.
/// - Clicks and scrolls land inside the window's frame, and only when the shared app is what's on top at
///   that spot (its own menus and sheets count); another app's window covering it gets nothing.
///
/// macOS drops posted events silently unless Porthole Host is allowed under Accessibility.
@MainActor
final class InputInjector {
    struct Target: Equatable {
        var windowID: CGWindowID
        var pid: pid_t
        var bounds: CGRect
    }

    static var isAllowed: Bool { AXIsProcessTrusted() }

    private static let log = Logger(subsystem: "dev.iamngoni.porthole", category: "input")

    /// Shows the system prompt the first time and adds Porthole Host to the Accessibility list.
    static func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private let source = CGEventSource(stateID: .hidSystemState)
    private let systemWide: AXUIElement = {
        let element = AXUIElementCreateSystemWide()
        // A busy app mustn't hold up input for long.
        AXUIElementSetMessagingTimeout(element, 0.3)
        return element
    }()
    private var clicks = ClickTracker()
    private var scrollRemainder = ScrollAccumulator()
    /// Buttons held down, with the click count each went down with (the up event repeats it).
    private var heldButtons: [MouseButton: Int] = [:]
    /// Non-modifier keys held down, as HID usages.
    private var heldKeys: Set<UInt16> = []
    /// Modifier keys held down, as HID usages.
    private var heldModifierKeys: Set<UInt16> = []
    private var location: CGPoint?
    private var repeatTimer: Timer?
    private var repeatingUsage: UInt16?
    /// The process that got the held keys, so their releases go to the same place.
    private var keyboardPID: pid_t?
    /// Set when a scroll gesture began over something other than the shared app; the rest of it is dropped.
    private var scrollBlocked = false

    var isHoldingAnything: Bool { !heldButtons.isEmpty || !heldKeys.isEmpty || !heldModifierKeys.isEmpty }

    // MARK: Mouse

    func move(to point: NormalizedPoint, in target: Target) {
        let location = InputGeometry.globalPoint(point, in: target.bounds)
        self.location = location
        let (type, button): (CGEventType, CGMouseButton) =
            if heldButtons[.left] != nil { (.leftMouseDragged, .left) }
            else if heldButtons[.right] != nil { (.rightMouseDragged, .right) }
            else { (.mouseMoved, .left) }
        post(mouse(type, at: location, button: button, clickCount: heldButtons.values.first ?? 0, modifiers: []))
    }

    func button(_ event: ButtonEvent, in target: Target) {
        let location = InputGeometry.globalPoint(event.point, in: target.bounds)
        self.location = location
        let cgButton: CGMouseButton = event.button == .left ? .left : .right
        if event.isDown {
            guard heldButtons[event.button] == nil else { return }
            guard bringForward(target, until: location) else { return }
            let count = clicks.press(event.button, at: location, time: ProcessInfo.processInfo.systemUptime,
                                     interval: NSEvent.doubleClickInterval)
            heldButtons[event.button] = count
            post(mouse(event.button == .left ? .leftMouseDown : .rightMouseDown, at: location, button: cgButton, clickCount: count, modifiers: []))
        } else {
            guard let count = heldButtons.removeValue(forKey: event.button) else { return }
            post(mouse(event.button == .left ? .leftMouseUp : .rightMouseUp, at: location, button: cgButton, clickCount: count, modifiers: []))
        }
    }

    func scroll(_ event: ScrollEvent, in target: Target) {
        let location = InputGeometry.globalPoint(event.point, in: target.bounds)
        // Scrolls go to the window under the pointer, so put the pointer there first.
        if location != self.location, heldButtons.isEmpty {
            self.location = location
            post(mouse(.mouseMoved, at: location, button: .left, clickCount: 0, modifiers: []))
        }
        if event.phase == .began {
            scrollRemainder.reset()
            scrollBlocked = !bringForward(target, until: location)
        }
        guard !scrollBlocked else { return }
        let points = InputGeometry.scrollPoints(dx: event.dx, dy: event.dy, windowSize: target.bounds.size)
        let step = scrollRemainder.take(dx: points.dx, dy: points.dy)
        // Positive wheel values scroll content down, the way a finger moving down drags it.
        guard let cgEvent = CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 2,
                                    wheel1: step.dy, wheel2: step.dx, wheel3: 0) else { return }
        cgEvent.location = location
        cgEvent.flags = flags([])
        cgEvent.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        cgEvent.setIntegerValueField(.scrollWheelEventScrollPhase, value: Self.scrollPhase(event.phase))
        cgEvent.setIntegerValueField(.scrollWheelEventMomentumPhase, value: Self.momentumPhase(event.momentum))
        post(cgEvent)
    }

    // MARK: Keyboard

    func key(_ event: KeyEvent, in target: Target) {
        guard let keyCode = HIDKeyMap.virtualKey(forUsage: event.usage) else { return }

        if HIDKeyMap.modifier(forUsage: event.usage) != nil {
            if event.isDown { heldModifierKeys.insert(event.usage) } else { heldModifierKeys.remove(event.usage) }
            let cgEvent = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: event.isDown)
            cgEvent?.type = .flagsChanged
            cgEvent?.flags = flags(event.modifiers)
            postKeyboard(cgEvent, to: event.isDown ? target.pid : keyboardPID ?? target.pid)
            if event.isDown { keyboardPID = target.pid }
            return
        }

        if event.isDown {
            guard ShortcutPolicy.allows(usage: event.usage, modifiers: effectiveModifiers(event.modifiers)) else { return }
            focus(target)
            heldKeys.insert(event.usage)
            keyboardPID = target.pid
            postKey(keyCode, down: true, modifiers: event.modifiers, to: target.pid)
            startRepeating(usage: event.usage, keyCode: keyCode, modifiers: event.modifiers, pid: target.pid)
        } else {
            guard heldKeys.remove(event.usage) != nil else { return }
            if repeatingUsage == event.usage { stopRepeating() }
            postKey(keyCode, down: false, modifiers: event.modifiers, to: keyboardPID ?? target.pid)
        }
    }

    func type(_ text: String, in target: Target) {
        focus(target)
        for segment in TextTyping.segments(text) {
            switch segment {
            case .characters(let units):
                for isDown in [true, false] {
                    // The key code is a placeholder; apps read the Unicode string.
                    let cgEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: isDown)
                    cgEvent?.flags = []
                    units.withUnsafeBufferPointer { cgEvent?.keyboardSetUnicodeString(stringLength: $0.count, unicodeString: $0.baseAddress) }
                    postKeyboard(cgEvent, to: target.pid)
                }
            case .key(let usage):
                guard let keyCode = HIDKeyMap.virtualKey(forUsage: usage) else { continue }
                postKey(keyCode, down: true, modifiers: [], to: target.pid)
                postKey(keyCode, down: false, modifiers: [], to: target.pid)
            }
        }
    }

    // MARK: Letting go

    /// Lifts every button and key the device is holding. Called when it asks, when the stream changes
    /// and when it goes quiet, so nothing stays stuck down on the Mac.
    func releaseAll() {
        stopRepeating()
        let at = location ?? CGEvent(source: nil)?.location ?? .zero
        for (button, count) in heldButtons {
            let type: CGEventType = button == .left ? .leftMouseUp : .rightMouseUp
            post(mouse(type, at: at, button: button == .left ? .left : .right, clickCount: count, modifiers: []))
        }
        heldButtons = [:]
        if let pid = keyboardPID {
            for usage in heldKeys {
                if let keyCode = HIDKeyMap.virtualKey(forUsage: usage) { postKey(keyCode, down: false, modifiers: [], to: pid) }
            }
            let modifierKeys = heldModifierKeys
            heldModifierKeys = []
            for usage in modifierKeys {
                guard let keyCode = HIDKeyMap.virtualKey(forUsage: usage) else { continue }
                let cgEvent = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
                cgEvent?.type = .flagsChanged
                cgEvent?.flags = flags([])
                postKeyboard(cgEvent, to: pid)
            }
        }
        heldKeys = []
        heldModifierKeys = []
        keyboardPID = nil
        clicks.reset()
        scrollRemainder.reset()
        scrollBlocked = false
    }

    // MARK: Helpers

    // no-prop-test: no observable oracle; asks the window server, through Accessibility, who is at a point.
    private func isOnTop(_ target: Target, at point: CGPoint) -> Bool {
        let owner = owner(at: point)
        guard owner == target.pid else {
            Self.log.notice("dropped input: another app (pid \(owner.map(String.init) ?? "none", privacy: .public)) is on top of the shared window there")
            return false
        }
        return true
    }

    /// Who would get a click at `point`. The Accessibility hit test follows the window server's own rules,
    /// so it sees past windows that let clicks through: the Dock lays an invisible one over the whole
    /// screen, which a plain window-list check counts as covering everything. If the app there doesn't
    /// answer in time, the window list decides, and it errs toward dropping the click.
    private func owner(at point: CGPoint) -> pid_t? {
        var element: AXUIElement?
        var pid: pid_t = 0
        if AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &element) == .success,
           let element, AXUIElementGetPid(element, &pid) == .success {
            return pid
        }
        return WindowStack.topOwner(at: point, in: WindowCatalog.onScreenStack())
    }

    /// Brings the shared window forward if it isn't already, and says whether it's on top at `point`.
    /// Apps come forward in their own time after being asked, so a window that was just raised gets
    /// half a second to get there; otherwise the first tap after switching windows would be dropped.
    private func bringForward(_ target: Target, until point: CGPoint) -> Bool {
        guard WindowRaiser.focus(windowID: target.windowID, pid: target.pid) else { return isOnTop(target, at: point) }
        let deadline = ProcessInfo.processInfo.systemUptime + 0.5
        repeat {
            Thread.sleep(forTimeInterval: 0.02)
            if owner(at: point) == target.pid { return true }
        } while ProcessInfo.processInfo.systemUptime < deadline
        return isOnTop(target, at: point)
    }

    private func focus(_ target: Target) {
        if WindowRaiser.focus(windowID: target.windowID, pid: target.pid) {
            // Give the window server a moment, or the first event can land on the old front window.
            Thread.sleep(forTimeInterval: 0.03)
        }
    }

    /// The device's own repeat would arrive late and jittery over the network, so the Mac repeats held keys
    /// itself, at the user's key repeat settings.
    private func startRepeating(usage: UInt16, keyCode: CGKeyCode, modifiers: Modifiers, pid: pid_t) {
        stopRepeating()
        repeatingUsage = usage
        let interval = max(NSEvent.keyRepeatInterval, 0.015)
        repeatTimer = Timer.scheduledTimer(withTimeInterval: NSEvent.keyRepeatDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.repeatingUsage == usage else { return }
                self.repeatTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                    MainActor.assumeIsolated {
                        guard let self, self.repeatingUsage == usage, self.heldKeys.contains(usage) else { return }
                        self.postKey(keyCode, down: true, modifiers: modifiers, to: pid, isRepeat: true)
                    }
                }
            }
        }
    }

    private func stopRepeating() {
        repeatTimer?.invalidate()
        repeatTimer = nil
        repeatingUsage = nil
    }

    private func postKey(_ keyCode: CGKeyCode, down: Bool, modifiers: Modifiers, to pid: pid_t, isRepeat: Bool = false) {
        let cgEvent = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: down)
        cgEvent?.flags = flags(modifiers)
        if isRepeat { cgEvent?.setIntegerValueField(.keyboardEventAutorepeat, value: 1) }
        postKeyboard(cgEvent, to: pid)
    }

    /// Straight into the shared app's event queue, past system-wide shortcuts and other apps.
    private func postKeyboard(_ event: CGEvent?, to pid: pid_t) {
        event?.postToPid(pid)
    }

    private func mouse(_ type: CGEventType, at location: CGPoint, button: CGMouseButton, clickCount: Int, modifiers: Modifiers) -> CGEvent? {
        let cgEvent = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: location, mouseButton: button)
        cgEvent?.flags = flags(modifiers)
        if clickCount > 0 { cgEvent?.setIntegerValueField(.mouseEventClickState, value: Int64(clickCount)) }
        return cgEvent
    }

    private func effectiveModifiers(_ modifiers: Modifiers) -> Modifiers {
        heldModifierKeys.reduce(into: modifiers) { result, usage in
            if let modifier = HIDKeyMap.modifier(forUsage: usage) { result.insert(modifier) }
        }
    }

    private func flags(_ modifiers: Modifiers) -> CGEventFlags {
        let all = effectiveModifiers(modifiers)
        var flags: CGEventFlags = []
        if all.contains(.shift) { flags.insert(.maskShift) }
        if all.contains(.control) { flags.insert(.maskControl) }
        if all.contains(.option) { flags.insert(.maskAlternate) }
        if all.contains(.command) { flags.insert(.maskCommand) }
        return flags
    }

    /// Mouse events go through the window server, which hit-tests them; `isOnTop` vets the spot first.
    private func post(_ event: CGEvent?) {
        event?.post(tap: .cghidEventTap)
    }

    private static func scrollPhase(_ phase: ScrollPhase?) -> Int64 {
        switch phase {
        case .began: 1
        case .changed: 2
        case .ended: 4
        case .cancelled: 8
        case nil: 0
        }
    }

    private static func momentumPhase(_ phase: MomentumPhase) -> Int64 {
        switch phase {
        case .none: 0
        case .began: 1
        case .changed: 2
        case .ended: 3
        }
    }
}
