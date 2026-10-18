import AppKit
import CoreGraphics
import PortholeProtocol

/// Reads the Mac's window list. Titles are only visible once Screen Recording is allowed.
enum WindowCatalog {
    static func streamableWindows() -> [WindowInfo] {
        WindowFilter.streamable(records(), excludingPID: ProcessInfo.processInfo.processIdentifier)
    }

    /// Current frame of a window in global points (top-left origin), or nil once it is gone.
    static func bounds(of windowID: CGWindowID) -> CGRect? {
        guard let info = (CGWindowListCopyWindowInfo(.optionIncludingWindow, windowID) as? [[String: Any]])?.first,
              let dictionary = info[kCGWindowBounds as String] as? NSDictionary
        else { return nil }
        return CGRect(dictionaryRepresentation: dictionary as CFDictionary)
    }

    /// Where input for a window should go: its frame and the process that owns it, or nil once it is gone.
    static func target(of windowID: CGWindowID) -> InputInjector.Target? {
        guard let info = (CGWindowListCopyWindowInfo(.optionIncludingWindow, windowID) as? [[String: Any]])?.first,
              let dictionary = info[kCGWindowBounds as String] as? NSDictionary,
              let bounds = CGRect(dictionaryRepresentation: dictionary as CFDictionary),
              let pid = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value
        else { return nil }
        return InputInjector.Target(windowID: windowID, pid: pid, bounds: bounds)
    }

    /// On-screen window numbers, front to back.
    static func frontToBack() -> [CGWindowID] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        return list.compactMap { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value }
    }

    /// Every window on screen, front to back, for checking what a click would land on.
    static func onScreenStack() -> [StackedWindow] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        return list.compactMap { info in
            guard let pid = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                  let dictionary = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: dictionary as CFDictionary)
            else { return nil }
            return StackedWindow(pid: pid, bounds: bounds, alpha: (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1)
        }
    }

    private static func records() -> [WindowRecord] {
        guard let list = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        var apps: [pid_t: NSRunningApplication?] = [:]
        return list.compactMap { info in
            guard let number = info[kCGWindowNumber as String] as? NSNumber,
                  let pid = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                  let boundsDictionary = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary)
            else { return nil }
            let app = apps[pid] ?? {
                let found = NSRunningApplication(processIdentifier: pid)
                apps[pid] = found
                return found
            }()
            return WindowRecord(
                id: number.uint32Value,
                title: info[kCGWindowName as String] as? String ?? "",
                appName: app?.localizedName ?? info[kCGWindowOwnerName as String] as? String ?? "",
                bundleID: app?.bundleIdentifier,
                pid: pid,
                layer: (info[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0,
                alpha: (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1,
                size: PointSize(width: bounds.width, height: bounds.height),
                isOnScreen: (info[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue ?? false,
                isRegularApp: app?.activationPolicy == .regular
            )
        }
    }
}
