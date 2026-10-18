import Foundation
import PropertyBased
import Testing
@testable import PortholeProtocol
@testable import PortholeSession

@Suite(.shrinking)
struct PairingStoreTests {
    enum Operation: Sendable {
        case save(key: String, item: PairedHost)
        case remove(key: String)
    }

    static var genOperation: Gen_<Operation> {
        let genKey = pick(["a", "b", "c", "d"])
        let genItem = zip(genText, Gen.uint8(in: 0...255).array(of: 32)).map {
            PairedHost(hostID: "host", hostName: $0, pairID: "pair", secret: Data($1))
        }
        return Gen.oneOf(
            zip(genKey, genItem).map { Operation.save(key: $0, item: $1) }.eraseToAny(),
            genKey.map { Operation.remove(key: $0) }.eraseToAny()
        ).eraseToAny()
    }

    /// Touches the real keychain, so it only runs when asked: `PORTHOLE_KEYCHAIN_TESTS=1 swift test`.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["PORTHOLE_KEYCHAIN_TESTS"] != nil))
    func prop_keychain_store_behaves_like_a_dictionary() async throws {
        await propertyCheck(count: 25, input: Self.genOperation.array(of: 1...12)) { operations in
            let store = KeychainPairingStore<PairedHost>(service: "dev.iamngoni.porthole.tests.\(UUID().uuidString)")
            defer { for key in ["a", "b", "c", "d"] { try? store.remove(key) } }
            var model: [String: PairedHost] = [:]
            for operation in operations {
                switch operation {
                case .save(let key, let item):
                    try store.save(item, for: key)
                    model[key] = item
                case .remove(let key):
                    try store.remove(key)
                    model[key] = nil
                }
            }
            for key in ["a", "b", "c", "d"] { #expect(store.item(for: key) == model[key]) }
            #expect(Set(store.all()) == Set(model.values))
        }
    }

    /// The shrunk counterexample from the first run: listing came back empty on the Mac's keychain.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["PORTHOLE_KEYCHAIN_TESTS"] != nil))
    func one_saved_pairing_is_listed() throws {
        let store = KeychainPairingStore<PairedHost>(service: "dev.iamngoni.porthole.tests.\(UUID().uuidString)")
        defer { try? store.remove("d") }
        let item = PairedHost(hostID: "host", hostName: "", pairID: "pair", secret: Data(repeating: 7, count: 32))
        try store.save(item, for: "d")
        #expect(store.all() == [item])
    }

    @Test func installation_id_is_made_once_and_kept() throws {
        let suite = "dev.iamngoni.porthole.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = InstallationID.current(defaults: defaults)
        #expect(!first.isEmpty)
        #expect(InstallationID.current(defaults: defaults) == first)
    }
}
