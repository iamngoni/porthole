import Flutter
import Network
import Security
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var system: PortholeSystem?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PortholeSystem") {
      system = PortholeSystem(messenger: registrar.messenger())
    }
  }
}

/// Keep-awake, Local Network access and the first launch of an install, for lib/client/system.dart.
final class PortholeSystem {
  private static let installedKey = "dev.iamngoni.porthole.installed"
  /// Where the Swift app kept its device ID.
  private static let swiftAppDeviceIdKey = "porthole.deviceID"
  /// The Swift app kept each pairing as its own item named by host ID, in the service this app's storage
  /// uses too; this app's own items are named host.<id>, address.<id> and deviceID.
  private static let pairingService = "dev.iamngoni.porthole.paired-hosts"
  private let channel: FlutterMethodChannel
  private var browser: NWBrowser?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "dev.iamngoni.porthole/system", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "keepAwake":
        UIApplication.shared.isIdleTimerDisabled = (call.arguments as? Bool) ?? false
        result(nil)
      case "watchLocalNetwork":
        self?.watchLocalNetwork()
        result(nil)
      case "claimEdges":
        result(nil)
      case "openSettings":
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        result(nil)
      case "install":
        result(PortholeSystem.installState())
      case "finishInstall":
        PortholeSystem.removeSwiftAppPairings()
        UserDefaults.standard.set(true, forKey: PortholeSystem.installedKey)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// What this launch found, for InstallState in lib/client/pairing_store.dart: launched before, an update
  /// over the Swift app (its device ID and pairing records), or a fresh install. User defaults go when the
  /// app is deleted; the Keychain doesn't.
  private static func installState() -> [String: Any] {
    let defaults = UserDefaults.standard
    if defaults.bool(forKey: installedKey) { return ["state": "known"] }
    guard let deviceId = defaults.string(forKey: swiftAppDeviceIdKey), !deviceId.isEmpty else { return ["state": "fresh"] }
    return ["state": "upgrade", "deviceId": deviceId, "pairings": swiftAppAccounts().compactMap(swiftAppRecord)]
  }

  private static func swiftAppAccounts() -> [String] {
    var query = pairingQuery
    query[kSecMatchLimit] = kSecMatchLimitAll
    query[kSecReturnAttributes] = true
    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
          let items = result as? [[CFString: Any]] else { return [] }
    return items.compactMap { $0[kSecAttrAccount] as? String }
      .filter { !$0.hasPrefix("host.") && !$0.hasPrefix("address.") && $0 != "deviceID" }
  }

  private static func swiftAppRecord(_ account: String) -> String? {
    var query = pairingQuery
    query[kSecAttrAccount] = account
    query[kSecMatchLimit] = kSecMatchLimitOne
    query[kSecReturnData] = true
    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }

  private static func removeSwiftAppPairings() {
    for account in swiftAppAccounts() {
      var query = pairingQuery
      query[kSecAttrAccount] = account
      SecItemDelete(query as CFDictionary)
    }
  }

  private static var pairingQuery: [CFString: Any] {
    [kSecClass: kSecClassGenericPassword, kSecAttrService: pairingService, kSecAttrSynchronizable: false]
  }

  /// While Local Network access is off, a Bonjour browse waits with a policy error. The plugin doesn't
  /// pass that on, so a second browse watches for it.
  private func watchLocalNetwork() {
    guard browser == nil else { return }
    let browser = NWBrowser(for: .bonjour(type: "_porthole._tcp", domain: nil), using: .tcp)
    browser.stateUpdateHandler = { [weak self] state in
      guard let self else { return }
      switch state {
      case .ready:
        self.channel.invokeMethod("localNetwork", arguments: "allowed")
      case .waiting(let error), .failed(let error):
        // kDNSServiceErr_PolicyDenied
        if case .dns(let code) = error, code == -65570 {
          self.channel.invokeMethod("localNetwork", arguments: "denied")
        }
        if case .failed = state {
          // A failed browser can't be reused.
          self.browser?.cancel()
          self.browser = nil
          DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.watchLocalNetwork() }
        }
      default:
        break
      }
    }
    browser.start(queue: .main)
    self.browser = browser
  }
}
