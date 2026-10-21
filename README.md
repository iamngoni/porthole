# Porthole

Stream a single Mac window, not the whole desktop, to an iPad, iPhone or Android device.

- **Porthole Host** (macOS menu bar app) lists your open windows, captures the one you pick with ScreenCaptureKit, and sends it as H.264 video over WebRTC. The stream runs as fast as both screens can show, up to 120 frames a second: a ProMotion iPhone or iPad Pro next to a 120 Hz Mac gets 120, an iPad Air gets 60. A window too big for H.264 at that rate steps down to 100, 90 or 60.
- **Porthole** (`app/`, Flutter, for iPad, iPhone and Android 7 or later) finds your Mac on the local network, shows its windows as live cards, and plays the one you tap edge to edge. The **Apps** tab lists the Mac's installed apps; tap one to open it on the Mac and stream its window. Use the window like an iPad app: tap where you want to click, drag to scroll, pinch to zoom. There's no pointer to push around.

The original Swift iPad and iPhone app is still in `Client/`. Both apps use the bundle ID `dev.iamngoni.porthole`, so installing one replaces the other. Installing the Flutter app over the Swift app keeps its pairings and device ID, so nothing needs pairing again.

## Status

Phase 2 of 5: paired, view and control, on the same Wi-Fi or over Tailscale.

| Phase | What you get |
|---|---|
| 1 ✅ | Find the Mac over Bonjour, pick a window on the iPad, watch it live; the stream follows resizes |
| 2 ✅ | Pairing with a 6-digit code on both screens, encrypted signaling, tap/drag/scroll/type control |
| 3 | Thumbnails and app icons ✅, installed apps (launch on the Mac) ✅, menus and popups via region capture |
| 4 | Over the internet through a small Cloudflare Worker (signaling + TURN), end-to-end encrypted |
| 5 | Real-device polish, Face ID lock, launch at login, notarized build |

## Pairing

1. On the Mac, click the Porthole icon in the menu bar and choose **Pair New Device…**. The Mac accepts a new device for five minutes.
2. On the iPad, tap the Mac in the list. Both screens show the same six-digit code.
3. If the codes match, tap **Codes Match** on the iPad and **Allow** on the Mac.

After that the iPad reconnects on its own. Remove a device from the Porthole menu on the Mac; forget a Mac by touching and holding it in the iPad's list.

How it stays private:

- Pairing compares a code derived from both devices' X25519 keys. The iPad commits to its key before the Mac reveals its own, so someone sitting between them gets different codes on the two screens.
- Each connection starts with both sides proving they hold the pairing secret, then derives fresh ChaCha20-Poly1305 keys for that connection only. Every signaling message after that is sealed, numbered and rejected if replayed, reordered or altered.
- The WebRTC video and control channel are DTLS-encrypted, and their fingerprints travel inside the sealed signaling, so they are tied to the paired device.
- The Mac pairing window closes after one pairing or three failed attempts. If two devices try to pair at the same time, the Mac stops pairing instead of guessing which is yours. Allow needs a click; Return doesn't press it.
- The iPad only pairs with the Mac it was pointed at: a different Mac answering is refused. A Mac that doesn't advertise its ID is refused too, and a saved pairing is only ever found by that ID, never by name.
- In the Flutter app, a paired Mac goes by the name it gave over the encrypted connection, not the one it advertises, so another Mac copying its name or ID can't pass for it.
- Pairing secrets are in the Keychain and never sync to iCloud. The Flutter app clears them the first time it runs after being reinstalled, since the Keychain outlives deleting an app; on Android they are left out of backups and device transfers.

## Reaching your Mac from anywhere

The app finds Macs with Bonjour, which only works on the same network. To reach a paired Mac from anywhere else, put both on [Tailscale](https://tailscale.com), or another VPN that joins them, and tell the app where the Mac is:

1. Pair on the same Wi-Fi first.
2. Away from it, the Mac is listed under **Paired, not nearby**. Tap it and enter its Tailscale name (`studio-mac`, or all of `studio-mac.tail1234.ts.net`) or its Tailscale address (`100.x.y.z`). The app connects and remembers the address.
3. To change or remove the address, use the card's **…** menu. To set it before you leave, touch and hold the Mac while it's nearby and choose **Remote Address…**.

Porthole Host listens on port 47801, so the address doesn't change. If another app already has that port, the Mac takes any free one and its menu says "Nearby only: port 47801 is in use"; it's then only reachable nearby. If you forward another port to it, add `:port` to the address.

It's as private as on Wi-Fi. The app connects with the saved pairing, and the Mac has to prove it holds the pairing secret, so another machine at that address can't pass for your Mac. The video goes straight between the two devices over the VPN, with no relay of Porthole's own.

## Controlling a window

The Mac's cursor isn't in the stream. A touch lands exactly where your finger is, and a small ripple shows where it went.

| On the iPad | On the Mac |
|---|---|
| Tap | Click there (tap twice quickly to double-click) |
| Two-finger tap, or touch and hold | Right-click |
| Touch and hold, then move | Drag (select text, move things) |
| Drag one finger | Scroll, with momentum |
| Pinch, and drag with two fingers | Zoom and look around on the iPad only; the Mac is not affected |
| Trackpad or mouse | Pointer, click, right-click, drag, two-finger scroll |
| Hardware keyboard | Keys and shortcuts, using the Mac's keyboard layout |
| Keyboard button | On-screen keyboard, with Esc, Tab, arrows and sticky ⌘ ⌥ ⌃ ⇧ keys |

A sticky ⌘, ⌥ or ⌃ applies to the next key you type, so ⌘ then C copies. A paste or dictation always goes in as text.

The controls float in a small bar at the top that tucks itself away after a few seconds or as soon as you touch the window; tap the handle to bring it back. From the bar you can go back to all windows, open the keyboard, switch to another window, zoom back to fit, or disconnect.

To open an app that isn't running, or one that's open with no windows, switch the picker (or the in-stream switcher) to **Apps** and tap it. The Mac opens it, or asks it for a new window, and the stream starts on that window as soon as it appears. The list covers /Applications, /System/Applications and ~/Applications (one folder deep) plus Finder, without menu bar agents. The device can only open apps from the list the Mac sent; it never passes a path, a document or arguments. Each time it opens one, the Porthole menu on the Mac says so. If the same app is in more than one place, the copy on the system volume wins, then /Applications, then ~/Applications.

While the Mac is locked, nothing is shown, opened or typed: the stream stops when the screen locks, and the iPad says to unlock the Mac.

Input stays on the shared window:

- Keys and text go straight to the shared app's process, so they can't reach other apps or system-wide shortcuts. Spotlight, the app switcher, Force Quit, Lock Screen, Log Out, Mission Control, Spaces and keyboard navigation are also filtered out, as a second line of defence.
- Clicks and scrolls land inside the window's frame, and only when the window on top at that spot belongs to the shared app (its own menus and sheets count). A dialog from another app over the window is never clicked.
- While a device is connected, the Porthole icon in the Mac's menu bar changes to an iPad. If the iPad goes quiet for three seconds, the Mac lets go of any keys or buttons it was holding. The shared window's menu bar is not part of the stream yet; menu shortcuts work.

## Layout

```
project.example.yml         XcodeGen project: PortholeHost (macOS) and the Swift Porthole app; copy to project.yml
Packages/PortholeKit/
  Sources/PortholeProtocol  Messages, framing, pairing and session crypto, connection state machines,
                            input mapping and key codes, video sizing, SDP edits, window filtering (pure Swift)
  Sources/PortholeSession   WebRTC peer, Bonjour signaling, Keychain pairing store, H.264 codec setup
  Tests/PortholeKitTests    Property tests, plus end-to-end WebRTC and signaling tests over loopback
Host/                       Mac app: capture, window list, pairing prompt, input injection, menu bar UI
Client/                     The original Swift iPad/iPhone app, replaced by app/
Protocol/porthole.proto     The wire format (v3, Protocol Buffers) every app speaks; generate.sh regenerates the code
Protocol/vectors/           Fixed inputs and the exact bytes the protocol must produce, for other implementations
Protocol/dart/              The same protocol in Dart, for the Flutter app: framing, pairing, sealing, messages
app/                        Flutter app (Android, iPad, iPhone)
  lib/client                Session controller, Bonjour browsing, secure pairing store, WebRTC peer, platform calls
  lib/input                 Touch interpretation, momentum, zoom geometry, key codes, soft-keyboard diffing
  lib/screens               Mac list, pairing and connecting screens, window and app pickers
  lib/stream                Stream view: video, input, zoom, touch feedback, key bar, control bar
  lib/design                Shared look: palette, glass cards, buttons, the Porthole mark
  ios/, android/            Platform shells: keep-awake, Android edge gestures, iOS Local Network check, first launch
  tool/app_icons.sh         Draws the home-screen icon from the Porthole mark for iOS and Android
release/                    Test-build scripts: notarized Mac host, TestFlight .ipa, Play app bundle
spike/                      The first Flutter experiment (video and touch on Flutter), kept for reference
```

## Build and run

Requires Xcode 26 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen). First copy the example project and fill in your own Apple team, signing identity and bundle IDs; git ignores `project.yml`:

```bash
cp project.example.yml project.yml
```

```bash
xcodegen generate
```

```bash
xcodebuild -project Porthole.xcodeproj -scheme PortholeHost -destination 'platform=macOS' -derivedDataPath build build
```

```bash
open build/Build/Products/Debug/PortholeHost.app
```

Then install the app on your iPad, iPhone or Android device from `app/` (below).

The original Swift app is the **Porthole** scheme. To check its layout without a Mac, launch a debug build with `-preview` and one of `windows`, `stream`, `opening`, `pairing`, `waiting`, `connecting` or `problem`. It fills the screen with sample windows and never touches the network. Add `-previewIcons <folder>` to use real app icons from PNGs named by bundle ID (`com.apple.Safari.png` and so on).

```bash
xcrun simctl launch booted dev.iamngoni.porthole -preview windows
```

### Flutter app

Requires Flutter 3.44 or later. For iOS, copy `app/ios/Flutter/Signing.example.xcconfig` to `Signing.xcconfig` beside it and put in your Team ID; git ignores it. If your team can't use the bundle ID `dev.iamngoni.porthole`, change it in Xcode to one of your own.

From `app/`, install a release build on a connected device (iOS 15 or later, Android 7 or later):

```bash
flutter run --release
```

Or build an Android APK or an iOS app:

```bash
flutter build apk --release
```

```bash
flutter build ios --release
```

To check a screen's layout without a Mac, pass `--dart-define=PREVIEW=<screen>` with one of `browsing`, `searching`, `connecting`, `pairing`, `waiting`, `problem`, `windows`, `apps`, `opening`, `launching` or `stream`. It uses sample data, keeps pairings in memory and never touches the network. Add `--dart-define=PREVIEW_ICONS=<folder>` for real app icons from PNGs named by bundle ID.

```bash
flutter run --dart-define=PREVIEW=windows
```

### Mac permissions (first run)

Porthole Host needs three permissions, granted in **System Settings → Privacy & Security**:

1. **Screen & System Audio Recording**: to capture windows. Window titles are also hidden from apps without it.
2. **Local Network**: to be found by the iPad. Until it is allowed, the Mac does not appear in the app.
3. **Accessibility**: to click and type in the shared window. Without it, devices can watch but not control.

`project.yml` names a fixed Apple Development identity for the Mac app, so these permissions survive rebuilds.

## Testing with friends

Each friend runs their own Porthole Host on their own Mac and pairs their own devices. Nothing is shared between Macs, and a friend can update their Mac or their app whenever they like: an app and a Mac on different protocol versions say which one to update.

- **Mac:** send them the notarized zip from `./release/host.sh` (below), so they don't need Xcode. To build it themselves instead, they copy `project.example.yml` to `project.yml` with their own team, certificate and bundle IDs.
- **iPad and iPhone:** without TestFlight, an app goes on a device either from your Apple account or theirs.
  - From yours: add their device in your developer account, then install with `flutter run --release` from `app/` while it's connected.
  - From theirs: they put their Team ID in `app/ios/Flutter/Signing.xcconfig` (from `Signing.example.xcconfig`) and change the bundle ID in Xcode to one of their own. A free Apple Account works, but the app stops opening after seven days until it's installed again.
- **Android:** send them an APK from `flutter build apk --release` in `app/`, signed with your upload key (see Android below). They allow installs from unknown sources when asked.

## Test builds

Each script in `release/` stops at a file for you to upload; none of them uploads anything. Build numbers default to the date and hour (`yyMMddHH`), so a second build in the same hour needs `BUILD_NUMBER=<higher number>`.

### Porthole Host, notarized

1. Once, store notarization credentials in the keychain. It asks for an app-specific password from your Apple Account.

   ```bash
   xcrun notarytool store-credentials porthole-notary --apple-id <your Apple Account email> --team-id <your Team ID>
   ```

2. Build, sign with Developer ID, notarize and staple:

   ```bash
   ./release/host.sh
   ```

The zip in `build/release/host/` opens on any Mac without a Gatekeeper warning. `--no-notarize` stops after signing. The notarized build is signed with Developer ID rather than the development identity, so the first time it runs macOS asks again for Screen Recording, Local Network and Accessibility.

Each friend runs their own Porthole Host and updates it whenever they like. A device and a Mac on different protocol versions say which one to update rather than failing.

### iPad and iPhone, TestFlight

1. Once, in App Store Connect, add an app with the bundle ID `dev.iamngoni.porthole`.
2. Build the .ipa, then upload `build/ios/ipa/*.ipa` with Transporter and add testers in TestFlight:

   ```bash
   ./release/ios.sh
   ```

`ITSAppUsesNonExemptEncryption` is `true` in both iOS apps. Porthole uses standard encryption beyond what iOS provides (X25519 and ChaCha20-Poly1305 for pairing and signaling, WebRTC's DTLS-SRTP for video). It is mass-market encryption with no proprietary algorithms; App Store Connect asks about it on the first upload.

### Android, Play internal testing

1. Once, make an upload key and keep it somewhere backed up outside the project. Losing it means asking Google to reset it.

   ```bash
   keytool -genkeypair -v -keystore ~/.android/porthole-upload.jks -alias upload -keyalg RSA -keysize 4096 -validity 10000
   ```

   Then create `app/android/key.properties` (ignored by git):

   ```
   storeFile=/Users/<you>/.android/porthole-upload.jks
   storePassword=<store password>
   keyAlias=upload
   keyPassword=<key password>
   ```

2. Once, in Play Console, create the app with the package name `dev.iamngoni.porthole` and keep Play App Signing on.
3. Build the bundle, then upload `app/build/app/outputs/bundle/release/app-release.aab` to Internal testing:

   ```bash
   ./release/android.sh
   ```

## Tests

```bash
./test.sh
```

It runs `swift test` in `Packages/PortholeKit`, builds the test-only `porthole-interop-host`, runs `dart analyze` and `dart test` in `Protocol/dart`, then `flutter analyze` and `flutter test` in `app/`.

- Property tests ([swift-property-based](https://github.com/x-sheep/swift-property-based)) cover framing, message and wire coding, pairing, the sealed channel, both connection state machines (run against each other, against replays, tampering and random messages), input mapping, pinch-zoom geometry, key codes, shortcut blocking, text typing, video sizing, SDP edits and window filtering. Every run uses fresh random inputs. A failure prints the shrunk input and a `.fixedSeed(...)` line; add it to the test to replay that exact case.
- `SignalingTests` pairs and exchanges sealed messages over a real TCP socket on loopback.
- `PairingStoreTests` checks the Keychain store against a dictionary model. It touches your keychain, so it only runs with `PORTHOLE_KEYCHAIN_TESTS=1 swift test`.
- `PeerSessionTests` connects a host and a client over loopback with real H.264 encode and decode. It checks that 720p, 2560×1600 and 4K frames arrive at full size, that a size change mid-stream arrives, that frames pushed at 120 fps arrive faster than 60 (on a Mac with a hardware H.264 encoder, so not on GitHub's virtual Macs), and that control messages arrive in order in both directions. A stand-in for an Android phone (Constrained Baseline only, level 3.1) checks that the host falls back to Baseline and raises the level so big windows still arrive.
- `ContractVectorsTests` pins the bytes of pairing, the session handshake, sealing and framing from fixed keys and nonces, in `Protocol/vectors/crypto.json`, and one example of every message in `Protocol/vectors/messages.json` (as bytes and as protobuf's standard JSON). The Dart package must reproduce them exactly. If the Swift side changes them, the test fails. Regenerate crypto vectors only for a deliberate protocol change, which breaks every paired device. Regenerate message vectors after adding a field. Both use `PORTHOLE_WRITE_VECTORS=1 swift test`.
- The Dart package checks every vector. It has its own property tests ([glados](https://pub.dev/packages/glados), fixed seed, shrinking) covering:
  - framing under any chunking
  - wire round trips and old-version detection
  - pairing between a Dart device and a Dart stand-in for the Mac
  - the sealed channel against reordering, replay and tampering
  - the device's connection state machine fed forged messages: it never establishes or pairs on its own, and it closes once
- `interop_test.dart` connects a Dart device to `porthole-interop-host`, the real Swift `HostLink` and `SignalingConnection` on loopback with pairing approved automatically. It checks that:
  - pairing shows the same code on both sides
  - a reconnect uses the saved pairing
  - sealed messages flow both ways
  - the Mac refuses replayed and tampered frames, a forged secret and an unknown pairing
  - an app from before v3 is told in JSON to update
- The Flutter app has its own glados property tests (fixed seed, shrinking), each with examples alongside. They cover:
  - touch interpretation, momentum, zoom geometry and key codes
  - soft-keyboard diffing, including emoji and other surrogate pairs, and when sticky modifiers make a shortcut
  - reading image sizes from PNG and JPEG headers, so oversized thumbnails and icons are dropped before decoding
  - the window and app filters
  - merging Bonjour results
  - the pairing codec, which never throws on damaged text
  - reading a typed Mac address, which never throws and reads back what it shows, and a Mac away from this network is only ever reached at its saved address
  - the Keychain store against the memory store, run against random saves and removals, including IDs that look like the store's own keys: pairings and addresses stay apart
  - the session controller, run against random sequences of picks, stream starts and stale updates from a stand-in Mac: only the window the person picked is ever shown
  - saved pairings, which are only ever found by the Mac's ID, and paired Macs keep their saved name
- `client_controller_test.dart` also checks the hello the app sends, every close reason's text, version-skew messages, a bye read before the hang-up that follows it, icon batching, and that input is dropped while the Mac refuses control. For a Mac away from this network, it checks that:
  - the app connects at the saved address and port with the saved pairing
  - another machine at that address fails the handshake before anything is sealed for it
  - an address it can't reach says to check Tailscale
  - forgetting the Mac removes its address
- `address_sheet_test.dart` types names, addresses and typos into the address sheet.
- `app_icon_test.dart` draws the home-screen icon and checks that it is opaque for iOS and that the adaptive Android foreground is see-through around the mark.
- `screens_test.dart` renders every preview screen at iPad landscape, iPad portrait and phone sizes and fails on any layout overflow. Set `SCREENSHOTS=<folder>` to save a PNG of each.
- The app's `interop_test.dart` runs the real session controller against `porthole-interop-host`: it pairs, reconnects with the saved pairing, and checks that the Mac sees the hello and the disconnect.
