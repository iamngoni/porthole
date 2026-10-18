import AppKit
import ApplicationServices

/// Maps an Accessibility window element to its window number. Private, but stable for years and used
/// by every window manager on the Mac; there is no public way to match AX windows to CGWindowIDs.
@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: UnsafeMutablePointer<CGWindowID>) -> AXError

/// Brings the streamed window to the front so clicks and keys land on it, not on whatever covers it.
enum WindowRaiser {
    /// Returns true if it had to change focus (the caller may want to give the switch a moment).
    @discardableResult
    static func focus(windowID: CGWindowID, pid: pid_t) -> Bool {
        let app = AXUIElementCreateApplication(pid)
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == pid, focusedWindowID(of: app) == windowID {
            return false
        }
        if let window = window(withID: windowID, in: app) {
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        }
        // Setting frontmost through Accessibility works even though Porthole Host is in the background,
        // where NSRunningApplication.activate() may be ignored.
        AXUIElementSetAttributeValue(app, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        return true
    }

    private static func focusedWindowID(of app: AXUIElement) -> CGWindowID? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return windowID(of: value as! AXUIElement)
    }

    private static func window(withID id: CGWindowID, in app: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return nil }
        return windows.first { windowID(of: $0) == id }
    }

    private static func windowID(of element: AXUIElement) -> CGWindowID? {
        var id: CGWindowID = 0
        return _AXUIElementGetWindow(element, &id) == .success ? id : nil
    }
}
