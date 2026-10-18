import Foundation

/// One entry from the Mac's window list, before filtering.
public struct WindowRecord: Hashable, Sendable {
    public var id: UInt32
    public var title: String
    public var appName: String
    public var bundleID: String?
    public var pid: Int32
    public var layer: Int
    public var alpha: Double
    public var size: PointSize
    public var isOnScreen: Bool
    /// True when the owning app shows in the Dock (not an agent or background helper).
    public var isRegularApp: Bool

    public init(id: UInt32, title: String, appName: String, bundleID: String?, pid: Int32, layer: Int, alpha: Double, size: PointSize, isOnScreen: Bool, isRegularApp: Bool) {
        self.id = id
        self.title = title
        self.appName = appName
        self.bundleID = bundleID
        self.pid = pid
        self.layer = layer
        self.alpha = alpha
        self.size = size
        self.isOnScreen = isOnScreen
        self.isRegularApp = isRegularApp
    }
}

/// Picks the windows worth offering to the client: normal app windows, not panels, helpers or slivers.
public enum WindowFilter {
    public static let minimumSide: Double = 100

    public static func isCandidate(_ record: WindowRecord, excludingPID ownPID: Int32) -> Bool {
        record.layer == 0
            && record.alpha > 0
            && record.size.width >= minimumSide
            && record.size.height >= minimumSide
            && record.pid != ownPID
            && record.isRegularApp
    }

    /// Candidate windows, de-duplicated by id. Untitled windows are kept only when they are their app's only candidate.
    /// Sorted by app name, then title, then id.
    public static func streamable(_ records: [WindowRecord], excludingPID ownPID: Int32) -> [WindowInfo] {
        var seen = Set<UInt32>()
        let candidates = records.filter { isCandidate($0, excludingPID: ownPID) && seen.insert($0.id).inserted }
        let countByPID = Dictionary(grouping: candidates, by: \.pid).mapValues(\.count)
        return candidates
            .filter { !$0.title.isEmpty || countByPID[$0.pid] == 1 }
            .sorted { lhs, rhs in
                let byApp = lhs.appName.localizedCaseInsensitiveCompare(rhs.appName)
                if byApp != .orderedSame { return byApp == .orderedAscending }
                let byTitle = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
                if byTitle != .orderedSame { return byTitle == .orderedAscending }
                return lhs.id < rhs.id
            }
            .map { WindowInfo(id: $0.id, title: $0.title, appName: $0.appName, bundleID: $0.bundleID, pid: $0.pid, size: $0.size, isOnScreen: $0.isOnScreen) }
    }
}

/// One on-screen window, front to back, as the window server lists them.
public struct StackedWindow: Equatable, Sendable {
    public var pid: Int32
    public var bounds: CGRect
    public var alpha: Double

    public init(pid: Int32, bounds: CGRect, alpha: Double) {
        self.pid = pid
        self.bounds = bounds
        self.alpha = alpha
    }
}

public enum WindowStack {
    /// The process whose window a click at `point` would land on: the frontmost visible window there.
    /// Input is only sent when this is the shared app, so nothing covering the window can be clicked.
    public static func topOwner(at point: CGPoint, in frontToBack: [StackedWindow]) -> Int32? {
        frontToBack.first { $0.alpha > 0.01 && $0.bounds.contains(point) }?.pid
    }
}

/// An app bundle found on the Mac's disk, before it is offered to the device.
public struct AppBundle: Hashable, Sendable {
    public var bundleID: String?
    public var name: String
    public var path: String
    /// Menu bar agents and background-only apps (LSUIElement, LSBackgroundOnly) have no window to show.
    public var isWindowless: Bool

    public init(bundleID: String?, name: String, path: String, isWindowless: Bool) {
        self.bundleID = bundleID
        self.name = name
        self.path = path
        self.isWindowless = isWindowless
    }
}

/// Which installed apps the device may open.
public enum InstalledApps {
    public static let defaultLimit = 600

    /// One entry per bundle ID, the first found winning, so callers list the most trusted folders first
    /// and a copy planted elsewhere can't stand in for a system app. Leaves out windowless agents,
    /// `excluded` and malformed bundle IDs; keeps the first `limit` (so a flood of junk later in the list
    /// can't push real apps out); cleans names for display; sorts by name.
    public static func catalog(_ bundles: [AppBundle], excluding excluded: Set<String>, limit: Int = defaultLimit) -> [AppBundle] {
        var seen: Set<String> = []
        let offered = bundles.filter { bundle in
            guard let id = bundle.bundleID, isWellFormed(id), !bundle.isWindowless, !excluded.contains(id) else { return false }
            return seen.insert(id).inserted
        }
        .prefix(max(0, limit))
        .map { bundle in
            var bundle = bundle
            bundle.name = DisplayName.clean(bundle.name, fallback: bundle.bundleID!)
            return bundle
        }
        return offered.sorted { a, b in
            let (left, right) = (a.name.lowercased(), b.name.lowercased())
            return left != right ? left < right : a.bundleID! < b.bundleID!
        }
    }

    /// Bundle IDs as Apple defines them: letters, digits, dots and hyphens (underscores tolerated), at most 255.
    static func isWellFormed(_ id: String) -> Bool {
        (1...255).contains(id.utf8.count) && id.utf8.allSatisfy { byte in
            (UInt8(ascii: "a")...UInt8(ascii: "z")).contains(byte) || (UInt8(ascii: "A")...UInt8(ascii: "Z")).contains(byte)
                || (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte) || [UInt8(ascii: "."), UInt8(ascii: "-"), UInt8(ascii: "_")].contains(byte)
        }
    }
}
