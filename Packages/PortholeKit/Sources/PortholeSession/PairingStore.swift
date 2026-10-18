import Foundation
import os
import PortholeProtocol
import Security

private let log = Logger(subsystem: "dev.iamngoni.porthole", category: "pairing")

/// Saved pairings, keyed by a string (the pair ID on the Mac, the host ID on the device).
public protocol PairingStore<Item>: AnyObject {
    associatedtype Item: Codable
    func all() -> [Item]
    func item(for key: String) -> Item?
    func save(_ item: Item, for key: String) throws
    func remove(_ key: String) throws
}

public struct KeychainError: Error, Equatable, CustomStringConvertible {
    public let status: OSStatus

    public var description: String {
        let message = SecCopyErrorMessageString(status, nil) as String? ?? "unknown error"
        return "Keychain error \(status): \(message)"
    }
}

/// Keeps each pairing as one generic password item. Items never sync to iCloud, and on iOS they
/// stay on this device and are readable once it has been unlocked after a restart.
public final class KeychainPairingStore<Item: Codable>: PairingStore {
    private let service: String

    public init(service: String) {
        self.service = service
    }

    public func all() -> [Item] {
        // The Mac's login keychain won't return data for more than one item at a time,
        // so list the accounts first and read each one.
        var query = baseQuery()
        query[kSecMatchLimit] = kSecMatchLimitAll
        query[kSecReturnAttributes] = true
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let found = result as? [[CFString: Any]] else {
            if status != errSecItemNotFound { log.error("listing pairings failed: \(KeychainError(status: status).description, privacy: .public)") }
            return []
        }
        return found.compactMap { $0[kSecAttrAccount] as? String }.sorted().compactMap(item(for:))
    }

    public func item(for key: String) -> Item? {
        var query = baseQuery()
        query[kSecAttrAccount] = key
        query[kSecMatchLimit] = kSecMatchLimitOne
        query[kSecReturnData] = true
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            if status != errSecItemNotFound { log.error("reading a pairing failed: \(KeychainError(status: status).description, privacy: .public)") }
            return nil
        }
        return try? JSONDecoder().decode(Item.self, from: data)
    }

    public func save(_ item: Item, for key: String) throws {
        let data = try JSONEncoder().encode(item)
        var query = baseQuery()
        query[kSecAttrAccount] = key
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)
        if status == errSecItemNotFound {
            query[kSecValueData] = data
            #if os(iOS)
            query[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            #endif
            let added = SecItemAdd(query as CFDictionary, nil)
            guard added == errSecSuccess else { throw KeychainError(status: added) }
        } else if status != errSecSuccess {
            throw KeychainError(status: status)
        }
    }

    public func remove(_ key: String) throws {
        var query = baseQuery()
        query[kSecAttrAccount] = key
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
    }

    private func baseQuery() -> [CFString: Any] {
        [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrSynchronizable: false]
    }
}

/// For tests and previews.
public final class MemoryPairingStore<Item: Codable>: PairingStore {
    private var items: [String: Item] = [:]

    public init() {}

    public func all() -> [Item] { items.keys.sorted().compactMap { items[$0] } }
    public func item(for key: String) -> Item? { items[key] }
    public func save(_ item: Item, for key: String) throws { items[key] = item }
    public func remove(_ key: String) throws { items[key] = nil }
}

public enum PairingStores {
    /// On the Mac: every device paired with it, keyed by pair ID.
    public static func pairedDevices() -> KeychainPairingStore<PairedDevice> {
        KeychainPairingStore(service: "dev.iamngoni.porthole.paired-devices")
    }

    /// On the iPad or iPhone: every Mac it is paired with, keyed by host ID.
    public static func pairedHosts() -> KeychainPairingStore<PairedHost> {
        KeychainPairingStore(service: "dev.iamngoni.porthole.paired-hosts")
    }
}

/// A random ID made on first launch and kept from then on. It names this install to the other side;
/// it is not a secret and proves nothing (the pairing secret does that).
public enum InstallationID {
    public static func current(defaults: UserDefaults = .standard, key: String = "porthole.installationID") -> String {
        if let existing = defaults.string(forKey: key), !existing.isEmpty { return existing }
        let id = UUID().uuidString
        defaults.set(id, forKey: key)
        return id
    }
}
