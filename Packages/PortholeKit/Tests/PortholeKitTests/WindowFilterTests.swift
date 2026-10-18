import Foundation
import PropertyBased
import Testing
@testable import PortholeProtocol

@Suite(.shrinking)
struct WindowFilterTests {
    static let ownPID: Int32 = 3

    static func record(_ id: UInt32, _ title: String, pid: Int32 = 10, app: String = "Mail", layer: Int = 0, width: Double = 800, regular: Bool = true) -> WindowRecord {
        WindowRecord(id: id, title: title, appName: app, bundleID: nil, pid: pid, layer: layer, alpha: 1, size: PointSize(width: width, height: 600), isOnScreen: true, isRegularApp: regular)
    }

    // MARK: Properties

    @Test
    func prop_every_result_is_a_real_candidate_window() async {
        await propertyCheck(count: 300, input: genWindowRecord.array(of: 0...25)) { records in
            for window in WindowFilter.streamable(records, excludingPID: Self.ownPID) {
                let sources = records.filter { $0.id == window.id && $0.pid == window.pid && $0.title == window.title }
                #expect(sources.contains { WindowFilter.isCandidate($0, excludingPID: Self.ownPID) })
                #expect(window.pid != Self.ownPID)
            }
        }
    }

    @Test
    func prop_results_have_unique_ids() async {
        await propertyCheck(count: 300, input: genWindowRecord.array(of: 0...25)) { records in
            let ids = WindowFilter.streamable(records, excludingPID: Self.ownPID).map(\.id)
            #expect(Set(ids).count == ids.count)
        }
    }

    @Test
    func prop_untitled_windows_only_when_alone_in_their_app() async {
        await propertyCheck(count: 300, input: genWindowRecord.array(of: 0...25)) { records in
            let result = WindowFilter.streamable(records, excludingPID: Self.ownPID)
            for window in result where window.title.isEmpty {
                #expect(result.filter { $0.pid == window.pid }.count == 1)
            }
        }
    }

    @Test
    func prop_result_does_not_depend_on_input_order() async {
        await propertyCheck(count: 300, input: genWindowRecord.array(of: 0...25)) { generated in
            // The real window list never repeats an id, so give each record its own.
            let records = generated.enumerated().map { index, record in
                var copy = record
                copy.id = UInt32(index + 1)
                return copy
            }
            #expect(WindowFilter.streamable(records, excludingPID: Self.ownPID) == WindowFilter.streamable(records.reversed(), excludingPID: Self.ownPID))
        }
    }

    @Test
    func prop_filtering_the_kept_windows_again_keeps_them_all() async {
        await propertyCheck(count: 300, input: genWindowRecord.array(of: 0...25)) { records in
            let first = WindowFilter.streamable(records, excludingPID: Self.ownPID)
            let keptIDs = Set(first.map(\.id))
            var seen = Set<UInt32>()
            let survivors = records.filter {
                keptIDs.contains($0.id) && WindowFilter.isCandidate($0, excludingPID: Self.ownPID) && seen.insert($0.id).inserted
            }
            #expect(WindowFilter.streamable(survivors, excludingPID: Self.ownPID) == first)
        }
    }

    // MARK: Examples

    @Test func untitled_helper_is_hidden_next_to_a_titled_window() {
        let result = WindowFilter.streamable([Self.record(1, "Inbox"), Self.record(2, "")], excludingPID: Self.ownPID)
        #expect(result.map(\.id) == [1])
    }

    @Test func an_apps_only_window_is_kept_even_without_a_title() {
        let result = WindowFilter.streamable([Self.record(1, "", pid: 20, app: "Calculator")], excludingPID: Self.ownPID)
        #expect(result.map(\.id) == [1])
    }

    @Test func excludes_own_windows_menus_slivers_and_agents() {
        let records = [
            Self.record(1, "Porthole", pid: Self.ownPID),
            Self.record(2, "Menu", layer: 25),
            Self.record(3, "Sliver", width: 40),
            Self.record(4, "Agent", pid: 30, regular: false),
            Self.record(5, "Keep me"),
        ]
        #expect(WindowFilter.streamable(records, excludingPID: Self.ownPID).map(\.id) == [5])
    }

    /// Found by prop_every_result_is_a_real_candidate_window: with a repeated id, the usable copy wins.
    @Test func repeated_id_keeps_the_candidate_copy() {
        let records = [Self.record(3, "", pid: 1, layer: 3), Self.record(3, "Untitled", pid: 1)]
        let result = WindowFilter.streamable(records, excludingPID: Self.ownPID)
        #expect(result.map(\.title) == ["Untitled"])
    }

    @Test func sorted_by_app_then_title() {
        let records = [
            Self.record(1, "b", pid: 10, app: "Safari"),
            Self.record(2, "z", pid: 11, app: "mail"),
            Self.record(3, "a", pid: 10, app: "Safari"),
        ]
        #expect(WindowFilter.streamable(records, excludingPID: Self.ownPID).map(\.id) == [2, 3, 1])
    }
}

@Suite(.shrinking)
struct InstalledAppsTests {
    /// Bundles from a small pool, so duplicate IDs, missing IDs, agents and same-name apps all occur.
    static var genBundle: Gen_<AppBundle> {
        zip(
            pick([nil, "", "com.apple.Safari", "com.apple.Notes", "com.example.mail", "dev.iamngoni.porthole.host", "com.example.agent",
                  "com.example.bad id", "com.example.\u{202E}evil", String(repeating: "a", count: 300)]),
            pick(["Safari", "Notes", "notes", "Mail", "Porthole Host", "Agent", "é", "", "\u{202E}gnp.exe", String(repeating: "Long ", count: 20)]),
            pick(["/Applications", "/System/Applications", "/Users/me/Applications", "/Applications/Utilities"]),
            Gen.bool(0.2)
        ).map { id, name, folder, windowless in
            AppBundle(bundleID: id, name: name, path: "\(folder)/\(name).app", isWindowless: windowless)
        }.eraseToAny()
    }

    static let excluded: Set<String> = ["dev.iamngoni.porthole.host"]

    @Test func prop_offered_apps_are_unique_windowed_allowed_and_sorted() async {
        await propertyCheck(count: 400, input: Self.genBundle.array(of: 0...14)) { bundles in
            let catalog = InstalledApps.catalog(bundles, excluding: Self.excluded)
            let ids = catalog.compactMap(\.bundleID)
            #expect(ids.count == catalog.count && Set(ids).count == ids.count)
            #expect(catalog.allSatisfy { !$0.isWindowless && !($0.bundleID ?? "").isEmpty && !Self.excluded.contains($0.bundleID!) })
            #expect(zip(catalog, catalog.dropFirst()).allSatisfy { a, b in
                (a.name.lowercased(), a.bundleID!) <= (b.name.lowercased(), b.bundleID!)
            })
        }
    }

    @Test func prop_every_eligible_app_is_offered() async {
        await propertyCheck(count: 300, input: Self.genBundle.array(of: 0...14)) { bundles in
            let offered = Set(InstalledApps.catalog(bundles, excluding: Self.excluded).compactMap(\.bundleID))
            let eligible = Set(bundles.filter { !$0.isWindowless }.compactMap(\.bundleID).filter(InstalledApps.isWellFormed)).subtracting(Self.excluded)
            #expect(offered == eligible)
        }
    }

    @Test func prop_ids_are_well_formed_and_names_safe_to_show() async {
        await propertyCheck(count: 300, input: Self.genBundle.array(of: 0...14)) { bundles in
            for app in InstalledApps.catalog(bundles, excluding: Self.excluded) {
                let id = try #require(app.bundleID)
                #expect(id.utf8.count <= 255 && !id.isEmpty && id.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || ".-_".contains($0)) })
                #expect(DisplayName.clean(app.name, fallback: id) == app.name)
                #expect(!app.name.isEmpty && app.name.count <= DisplayName.maxLength)
            }
        }
    }

    @Test func prop_a_bigger_limit_only_adds_apps() async {
        await propertyCheck(count: 300, input: Self.genBundle.array(of: 0...14), Gen.int(in: 0...8)) { bundles, limit in
            let fewer = Set(InstalledApps.catalog(bundles, excluding: Self.excluded, limit: limit).compactMap(\.bundleID))
            let more = Set(InstalledApps.catalog(bundles, excluding: Self.excluded, limit: limit + 1).compactMap(\.bundleID))
            #expect(fewer.count <= limit && fewer.isSubset(of: more))
        }
    }

    @Test func prop_apps_found_later_never_replace_one_already_offered() async {
        await propertyCheck(count: 300, input: Self.genBundle.array(of: 0...10), Self.genBundle.array(of: 0...10)) { first, later in
            let before = InstalledApps.catalog(first, excluding: Self.excluded)
            let after = InstalledApps.catalog(first + later, excluding: Self.excluded)
            for app in before {
                #expect(after.first { $0.bundleID == app.bundleID }?.path == app.path)
            }
        }
    }

    @Test func prop_cataloguing_twice_changes_nothing() async {
        await propertyCheck(count: 300, input: Self.genBundle.array(of: 0...14)) { bundles in
            let once = InstalledApps.catalog(bundles, excluding: Self.excluded)
            #expect(InstalledApps.catalog(once, excluding: Self.excluded) == once)
        }
    }

    @Test func junk_after_the_limit_never_pushes_out_apps_found_first() {
        let real = AppBundle(bundleID: "com.apple.Terminal", name: "Terminal", path: "/System/Applications/Utilities/Terminal.app", isWindowless: false)
        let junk = (0..<5).map { AppBundle(bundleID: "com.junk.\($0)", name: "!\($0)", path: "/Users/me/Applications/\($0).app", isWindowless: false) }
        #expect(InstalledApps.catalog([real] + junk, excluding: [], limit: 3).map(\.bundleID) == ["com.junk.0", "com.junk.1", "com.apple.Terminal"])
    }

    @Test func a_system_copy_listed_first_beats_a_lookalike_planted_in_applications() {
        let system = AppBundle(bundleID: "com.apple.Terminal", name: "Terminal", path: "/System/Applications/Utilities/Terminal.app", isWindowless: false)
        let planted = AppBundle(bundleID: "com.apple.Terminal", name: "Terminal", path: "/Applications/Terminal.app", isWindowless: false)
        #expect(InstalledApps.catalog([system, planted], excluding: []).map(\.path) == [system.path])
    }

    @Test func the_applications_folder_copy_wins_and_agents_and_porthole_are_left_out() {
        let bundles = [
            AppBundle(bundleID: "com.apple.Safari", name: "Safari", path: "/Applications/Safari.app", isWindowless: false),
            AppBundle(bundleID: "com.example.agent", name: "Menu Agent", path: "/Applications/Menu Agent.app", isWindowless: true),
            AppBundle(bundleID: "dev.iamngoni.porthole.host", name: "Porthole Host", path: "/Applications/Porthole Host.app", isWindowless: false),
            AppBundle(bundleID: "com.apple.Notes", name: "Notes", path: "/System/Applications/Notes.app", isWindowless: false),
            AppBundle(bundleID: "com.apple.Safari", name: "Safari", path: "/Users/me/Downloads/Safari.app", isWindowless: false),
        ]
        let catalog = InstalledApps.catalog(bundles, excluding: ["dev.iamngoni.porthole.host"])
        #expect(catalog.map(\.path) == ["/System/Applications/Notes.app", "/Applications/Safari.app"])
    }
}
