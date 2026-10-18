import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test, setUp, tearDown;
import 'package:porthole/client/client_controller.dart';
import 'package:porthole/client/host_browser.dart';
import 'package:porthole/client/pairing_store.dart';
import 'package:porthole/client/peer_session.dart';
import 'package:porthole_protocol/porthole_protocol.dart';

import 'support/fakes.dart';
import 'support/images.dart';

// The controller against a fake Mac that speaks the real sealed protocol, and a fake video connection.

sealed class Op {
  const Op();
}

final class PickWindow extends Op {
  const PickWindow(this.id);
  final int id;
  @override
  String toString() => 'PickWindow($id)';
}

final class PickApp extends Op {
  const PickApp();
  @override
  String toString() => 'PickApp';
}

final class StopStream extends Op {
  const StopStream();
  @override
  String toString() => 'StopStream';
}

final class MacSends extends Op {
  const MacSends(this.message, this.label);
  final HostMessage message;
  final String label;
  @override
  String toString() => 'MacSends($label)';
}

extension ControllerAnys on Any {
  Generator<int> get windowId => intInRange(1, 5);
  Generator<int> get gen => intInRange(1, 4);

  Generator<Op> get op => oneOf([
        windowId.map<Op>(PickWindow.new),
        always<Op>(const PickApp()),
        always<Op>(const StopStream()),
        listWithLengthInRange(0, 4, windowId).map((ids) => ids.toSet()).map<Op>((ids) => MacSends(
            HostMessage(windows: WindowList(windows: [for (final id in ids.toList()..sort()) window(id)])), 'windows $ids')),
        combine2(gen, windowId, (int g, int w) => MacSends(HostMessage(streamStarted: streamInfo(g, w)), 'started $g/$w')),
        combine2(gen, windowId, (int g, int w) => MacSends(HostMessage(geometry: streamInfo(g, w)), 'geometry $g/$w')),
        gen.map<Op>((g) => MacSends(
            HostMessage(streamState: StreamStateUpdate(gen: g, state: StreamState(closed: Nothing()))), 'closed $g')),
        windowId.map<Op>((w) => MacSends(HostMessage(thumbnail: Thumbnail(windowId: w, jpeg: jpegHeader(16, 10))), 'thumb $w')),
      ]);

  Generator<T> always<T>(T value) => choose([value]);

  Generator<String> get hostIdOrNone => choose(const ['host-1', 'host-2', 'host-3', '']);
  Generator<String> get macName => choose(const ['Studio Mac', 'MacBook Pro', 'Studio Mac\u200B']);

  /// Saved pairings, one per host ID, with names that may match other Macs'.
  Generator<List<PairedHost>> get pairings => listWithLengthInRange(0, 3, combine2(hostIdOrNone, macName, (String id, String name) => (id, name)))
      .map((pairs) => {for (final (id, name) in pairs) if (id.isNotEmpty) id: name})
      .map((byId) => [
            for (final MapEntry(key: id, value: name) in byId.entries)
              PairedHost(hostId: id, hostName: name, pairId: 'pair-$id', secret: testPairing.secret),
          ]);
}

void main() {
  // The image cache, which the controller clears of old thumbnails.
  TestWidgetsFlutterBinding.ensureInitialized();

  Glados(any.listWithLengthInRange(0, 30, any.op), ExploreConfig(numRuns: 150))
      .test('prop_only_windows_the_person_picked_are_shown_and_stale_updates_change_nothing', (ops) async {
    final h = Harness();
    await h.connect();
    final c = h.controller;
    var askedSinceStop = false;
    for (final op in ops) {
      final before = c.stream;
      final sentBefore = h.peer.sent.length;
      final wasWaiting = c.isShowingStream;
      switch (op) {
        case PickWindow(:final id):
          c.select(window(id));
          askedSinceStop = true;
        case PickApp():
          c.launch(AppInfo(bundleId: 'com.apple.Maps', name: 'Maps'));
          askedSinceStop = true;
        case StopStream():
          c.stopStream();
          askedSinceStop = false;
          expect(c.isShowingStream, isFalse);
        case MacSends(:final message):
          h.peer.receive(message);
          if (message.hasGeometry() && message.geometry.gen != before?.gen) expect(c.stream, same(before));
          if (message.hasStreamState() && message.streamState.gen != before?.gen) expect(c.stream, same(before));
          if (message.hasStreamStarted() && !wasWaiting) {
            // Nobody asked: it isn't shown, and the Mac is told to stop.
            expect(c.stream, isNull);
            expect(h.peer.sent.skip(sentBefore).single.hasStopStream(), isTrue);
          }
      }
      if (c.stream != null) expect(askedSinceStop, isTrue);
      final alive = {for (final w in c.windows) w.id};
      expect(c.thumbnails.keys.every(alive.contains), isTrue);
    }
    c.dispose();
  });

  Glados2(any.choose([...CloseReason.values, null]), any.bool).test('prop_every_ending_says_something_about_that_mac',
      (reason, saidByMac) {
    final problem = ClientController.problemFor(reason, saidByMac: saidByMac, hostName: 'Studio Mac', host: testHost);
    expect(problem.text, contains('Studio Mac'));
    if (problem.action != null) expect(problem.host, testHost);
  });

  Glados3(any.pairings, any.hostIdOrNone, any.macName)
      .test('prop_a_saved_pairing_is_only_ever_found_by_the_macs_id', (pairings, id, name) {
    // Synchronous, so glados can replay and shrink a failure: the preview loader sets the pairings at once.
    final controller = ClientController(deviceId: 'device-1', deviceName: 'Test iPad', store: MemoryPairingStore(pairings))
      ..loadPreview('browsing', windows: const [], apps: const [], paired: pairings);
    final host = DiscoveredHost(name: name, hostId: id.isEmpty ? null : id, addresses: const ['192.168.1.20'], port: 47801);
    final found = controller.savedPairing(host);
    final paired = pairings.where((p) => p.hostId == host.hostId).firstOrNull;
    expect(found?.hostId, paired?.hostId);
    if (host.hostId == null) expect(found, isNull);
    // A paired Mac goes by its saved name, whatever its Bonjour record says.
    if (paired != null) expect(controller.hostName(host), paired.hostName);
    controller.dispose();
  });

  group('connecting', () {
    test('a Mac with no ID in its Bonjour record is refused before anything is sent', () async {
      final h = Harness();
      await Harness.settle();
      h.controller.connect(const DiscoveredHost(name: 'Studio Mac', addresses: ['192.168.1.20'], port: 47801));
      expect(h.connects, 0);
      expect(h.controller.phase, const Browsing());
      expect(h.controller.problem!.text, 'Couldn’t read Studio Mac’s details. Check that Porthole Host is up to date, then try again.');
      expect(h.controller.problem!.action, ProblemAction.tryAgain);
    });

    test('a Mac using a paired Mac’s name, without its ID, gets no pairing', () async {
      final h = Harness();
      await Harness.settle();
      const port = 47801;
      expect(h.controller.savedPairing(const DiscoveredHost(name: 'Studio Mac', addresses: [], port: port)), isNull);
      expect(h.controller.savedPairing(const DiscoveredHost(name: 'Studio Mac', hostId: 'host-2', addresses: [], port: port)), isNull);
      expect(h.controller.savedPairing(testHost)?.pairId, testPairing.pairId);
    });

    test('a paired Mac goes by the name it paired with, and its sealed welcome renames it', () async {
      final h = Harness();
      await Harness.settle();
      h.controller.connect(const DiscoveredHost(name: 'Not Studio Mac', hostId: 'host-1', addresses: ['192.168.1.20'], port: 47801));
      expect(h.controller.phase, const Connecting('Studio Mac'));
      await Harness.until(() => h.mac.signals.any((s) => s.hasHello()));
      h.mac.sendSignal(Signal(welcome: HostWelcome(protocolVersion: portholeProtocolVersion, hostName: 'Studio Mac Pro\u202E')));
      await Harness.until(() => h.controller.pairedHosts.single.hostName == 'Studio Mac Pro');
      final saved = (await h.store.all()).single;
      expect((saved.hostId, saved.hostName, saved.pairId), ('host-1', 'Studio Mac Pro', 'pair-1'));
      expect(saved.secret, testPairing.secret);
      h.mac.sendSignal(Signal(offer: 'offer-sdp'));
      await Harness.until(() => h.mac.signals.any((s) => s.hasAnswer()));
      h.peer.onStateChange?.call(PeerState.connected);
      expect(h.controller.phase, const Connected('Studio Mac Pro'));
    });

    test('the hello describes this screen, and an open control channel asks for windows', () async {
      final h = Harness();
      await h.connect();
      final hello = h.mac.signals.firstWhere((s) => s.hasHello()).hello;
      expect((hello.protocolVersion, hello.deviceName), (portholeProtocolVersion, 'Test iPad'));
      expect((hello.viewport.width.toInt(), hello.viewport.height.toInt(), hello.maxFramesPerSecond.toInt()), (2752, 2064, 120));
      expect(h.mac.signals.firstWhere((s) => s.hasAnswer()).answer, 'answer to offer-sdp');
      expect(h.controller.phase, const Connected('Studio Mac'));
      expect(h.awake, isTrue);
      expect(h.peer.sent.first.hasListWindows(), isTrue);
    });

    test('a goodbye from the Mac is read before the hang-up that follows it', () async {
      final h = Harness();
      await h.connect();
      h.mac.bye(CloseReason.replaced);
      await Harness.until(() => h.controller.problem != null);
      expect(h.controller.problem!.text, 'Another device connected to Studio Mac.');
      expect(h.controller.phase, const Browsing());
      expect(h.peer.isClosed, isTrue);
    });

    test('a hang-up without a word is a lost connection', () async {
      final h = Harness();
      await h.connect();
      h.mac.hangUp();
      await Harness.until(() => h.controller.problem != null);
      expect(h.controller.problem!.text, 'Lost the connection to Studio Mac.');
      expect(h.controller.problem!.action, ProblemAction.tryAgain);
    });

    test('a Mac that forgot this device offers to pair again', () async {
      final h = Harness();
      await Harness.settle();
      h.controller.connect(testHost);
      await Harness.until(() => h.mac.isClosed || h.controller.phase is Connecting);
      await Harness.settle();
      h.mac.bye(CloseReason.unknownPairing);
      await Harness.until(() => h.controller.problem != null);
      expect(h.controller.problem!.action, ProblemAction.pairAgain);
    });

    test('a Mac that can’t be reached says so', () async {
      final h = Harness();
      final c = ClientController(
        deviceId: 'd',
        deviceName: 'n',
        store: h.store,
        connect: (host) async => throw const SocketLikeError(),
        makePeer: FakePeer.new,
        keepAwake: (_) async {},
      );
      c.connect(testHost);
      await Harness.until(() => c.problem != null);
      expect(c.problem!.text, startsWith('Couldn’t reach Studio Mac.'));
      expect(c.problem!.action, ProblemAction.tryAgain);
    });

    test('disconnecting says goodbye', () async {
      final h = Harness();
      await h.connect();
      h.controller.disconnect();
      expect(h.mac.closedWith, CloseReason.disconnected);
      expect(h.controller.phase, const Browsing());
      expect(h.awake, isFalse);
    });

    test('a failed video connection ends the session', () async {
      final h = Harness();
      await h.connect();
      h.peer.onStateChange?.call(PeerState.failed);
      expect(h.controller.problem!.text, 'The connection to Studio Mac failed.');
    });
  });

  group('versions', () {
    test('an older Mac is asked to update, a newer one asks this app to', () {
      expect(ClientController.incompatibleText('Studio', 2), 'Studio runs an older Porthole Host. Update it on the Mac, then try again.');
      expect(ClientController.incompatibleText('Studio', 4), 'Studio runs a newer Porthole Host. Update this app, then try again.');
    });
  });

  group('windows', () {
    test('a window that started after the person backed out is stopped on the Mac', () async {
      final h = Harness();
      await h.connect();
      h.controller.select(window(1));
      h.controller.stopStream();
      h.peer.sent.clear();
      h.peer.receive(HostMessage(streamStarted: streamInfo(1, 1)));
      expect(h.controller.stream, isNull);
      expect(h.peer.sent.single.hasStopStream(), isTrue);
    });

    test('an older start while another window is coming is ignored, not stopped', () async {
      final h = Harness();
      await h.connect();
      h.controller.select(window(2));
      h.controller.select(window(1));
      h.peer.sent.clear();
      h.peer.receive(HostMessage(streamStarted: streamInfo(1, 2)));
      expect(h.controller.stream, isNull);
      expect(h.peer.sent, isEmpty);
      h.peer.receive(HostMessage(streamStarted: streamInfo(2, 1)));
      expect(h.controller.stream!.windowId, 1);
    });

    test('thumbnails go when their window does', () async {
      final h = Harness();
      await h.connect();
      h.peer.receive(HostMessage(windows: WindowList(windows: [window(1), window(2)])));
      h.peer.receive(HostMessage(thumbnail: Thumbnail(windowId: 2, jpeg: jpegHeader(720, 450))));
      h.peer.receive(HostMessage(thumbnail: Thumbnail(windowId: 9, jpeg: jpegHeader(720, 450))));
      expect(h.controller.thumbnails.keys, [2]);
      h.peer.receive(HostMessage(windows: WindowList(windows: [window(1)])));
      expect(h.controller.thumbnails, isEmpty);
    });

    test('a thumbnail too big to decode safely, or not a JPEG, is dropped', () async {
      final h = Harness();
      await h.connect();
      h.peer.receive(HostMessage(windows: WindowList(windows: [window(1)])));
      for (final bytes in [jpegHeader(8000, 8000), jpegHeader(1025, 10), pngHeader(720, 450), <int>[1, 2, 3]]) {
        h.peer.receive(HostMessage(thumbnail: Thumbnail(windowId: 1, jpeg: bytes)));
      }
      expect(h.controller.thumbnails, isEmpty);
      h.peer.receive(HostMessage(thumbnail: Thumbnail(windowId: 1, jpeg: jpegHeader(800, 500))));
      expect(h.controller.thumbnails.keys, [1]);
    });

    test('an icon counts only if it was asked for, is a PNG and is icon-sized', () async {
      final h = Harness();
      await h.connect();
      h.peer.receive(HostMessage(windows: WindowList(windows: [window(1, app: 'Notes', bundleId: 'com.apple.Notes')])));
      h.peer.receive(HostMessage(appIcon: AppIcon(bundleId: 'com.example.unasked', png: pngHeader(128, 128))));
      h.peer.receive(HostMessage(appIcon: AppIcon(bundleId: 'com.apple.Notes', png: pngHeader(4096, 4096))));
      h.peer.receive(HostMessage(appIcon: AppIcon(bundleId: 'com.apple.Notes', png: jpegHeader(128, 128))));
      expect(h.controller.appIcons, isEmpty);
      h.peer.receive(HostMessage(appIcon: AppIcon(bundleId: 'com.apple.Notes', png: pngHeader(128, 128))));
      expect(h.controller.appIcons.keys, ['com.apple.Notes']);
    });

    test('window and app lists stop at a size no Mac reaches', () async {
      final h = Harness();
      await h.connect();
      h.peer.receive(HostMessage(windows: WindowList(windows: [for (var i = 1; i <= 600; i++) window(i)])));
      h.peer.receive(HostMessage(apps: AppList(apps: [for (var i = 0; i < 2500; i++) AppInfo(bundleId: 'app.$i', name: 'App $i')])));
      expect((h.controller.windows.length, h.controller.apps.length), (ClientController.maxWindows, ClientController.maxApps));
    });

    test('the first window list asks for previews and each app icon once', () async {
      final h = Harness();
      await h.connect();
      h.peer.sent.clear();
      h.peer.receive(HostMessage(windows: WindowList(windows: [window(1), window(2), window(3, app: 'Notes', bundleId: 'com.apple.Notes')])));
      expect(h.peer.sent.map((m) => m.whichMsg()), [ClientMessage_Msg.thumbnails, ClientMessage_Msg.appIcons]);
      expect(h.peer.sent.last.appIcons.bundleIds, ['com.apple.Notes', 'com.apple.Safari']);
      h.peer.sent.clear();
      h.controller.refreshWindows();
      expect(h.peer.sent.map((m) => m.whichMsg()), [ClientMessage_Msg.listWindows, ClientMessage_Msg.thumbnails]);
    });

    test('icons wanted together go out together, at most 40 to a request', () async {
      final h = Harness();
      await h.connect();
      h.peer.sent.clear();
      for (var i = 0; i < 95; i++) {
        h.controller.wantIcon('app.$i');
        h.controller.wantIcon('app.$i');
      }
      await Harness.settle();
      final requests = h.peer.sent.where((m) => m.hasAppIcons()).map((m) => m.appIcons.bundleIds.length);
      expect(requests, [40, 40, 15]);
      h.controller.wantIcon('app.3');
      await Harness.settle();
      expect(h.peer.sent.where((m) => m.hasAppIcons()).length, 3);
    });

    test('input is dropped while the Mac refuses control', () async {
      final h = Harness();
      await h.connect();
      h.peer.receive(HostMessage(control: ControlStatus(allowed: false, reason: 'Accessibility is off')));
      h.peer.sent.clear();
      h.controller.sendInput(ClientMessage(text: TextEvent(gen: 1, text: 'hi')));
      expect(h.peer.sent, isEmpty);
    });
  });
}

final class SocketLikeError implements Exception {
  const SocketLikeError();
}
