import AppKit
import PortholeProtocol

/// The apps installed on this Mac, found in the usual app folders. `InstalledApps.catalog` decides
/// which of them a device may open.
enum AppCatalog {
    /// Most trusted first, since the first copy of a bundle ID wins: the read-only system volume, then
    /// /Applications (which an admin account's processes can add to), then the user's own folder.
    private static var folders: [URL] {
        ["/System/Applications", "/Applications", FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path]
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    /// Finder lives with the system's services rather than with the other apps.
    private static let finder = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")

    /// Every app bundle in the app folders and one level of subfolders (Utilities, or a vendor's folder).
    /// Reads a few hundred Info.plist files, so run it off the main thread.
    static func scan() -> [AppBundle] {
        var urls = [finder]
        for folder in folders {
            guard let walker = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil,
                                                              options: [.skipsPackageDescendants, .skipsHiddenFiles]) else { continue }
            for case let url as URL in walker {
                if url.pathExtension == "app" {
                    urls.append(url)
                } else if walker.level >= 2 {
                    walker.skipDescendants()
                }
            }
        }
        return urls.compactMap(bundle(at:))
    }

    /// The bundle ID on disk right now, read fresh (Bundle caches), to catch a bundle swapped since the scan.
    static func currentBundleID(at url: URL) -> String? {
        (NSDictionary(contentsOf: url.appendingPathComponent("Contents/Info.plist")) as? [String: Any])?["CFBundleIdentifier"] as? String
            ?? Bundle(url: url)?.bundleIdentifier
    }

    /// Whether the Mac's screen is locked or another user is on the console. Nothing is shown,
    /// opened or typed while it is.
    static var isConsoleLocked: Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return true }
        let onConsole = session[kCGSessionOnConsoleKey as String] as? Bool ?? false
        return !onConsole || (session["CGSSessionScreenIsLocked"] as? Bool ?? false)
    }

    private static func bundle(at url: URL) -> AppBundle? {
        let plist = url.appendingPathComponent("Contents/Info.plist")
        // iPhone and iPad apps installed on the Mac keep their Info.plist inside a wrapper; Bundle finds it.
        guard let info = (NSDictionary(contentsOf: plist) as? [String: Any]) ?? Bundle(url: url)?.infoDictionary else { return nil }
        func flag(_ key: String) -> Bool {
            switch info[key] {
            case let value as Bool: value
            case let value as NSNumber: value.boolValue
            case let value as String: ["1", "yes", "true"].contains(value.lowercased())
            default: false
            }
        }
        var name = FileManager.default.displayName(atPath: url.path)
        if name.hasSuffix(".app") { name = String(name.dropLast(4)) }
        return AppBundle(bundleID: info["CFBundleIdentifier"] as? String, name: name, path: url.path,
                         isWindowless: flag("LSUIElement") || flag("LSBackgroundOnly"))
    }

    /// Opens the app, or for one that's already open, brings it forward and asks it to reopen,
    /// which makes most apps show a window. Returns why it failed, or nil.
    static func open(_ url: URL) async -> String? {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.addsToRecentItems = false
        return await withCheckedContinuation { continuation in
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
                continuation.resume(returning: error?.localizedDescription)
            }
        }
    }
}
