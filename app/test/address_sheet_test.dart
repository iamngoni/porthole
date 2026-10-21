import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porthole/client/remote_address.dart';
import 'package:porthole/screens/address_sheet.dart';

// no-prop-test: the sheet only hands typed text to RemoteAddress.parse, whose properties are in
// remote_address_test.dart; these pin what the person sees and gets back.

void main() {
  /// Opens the sheet; the function it returns waits for the sheet to close and gives what it returned.
  Future<Future<RemoteAddress?> Function()> open(WidgetTester tester, {RemoteAddress? current}) async {
    RemoteAddress? result;
    var closed = false;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () async {
              result = await showAddressSheet(context, macName: 'Studio Mac', current: current, saveLabel: 'Connect');
              closed = true;
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return () async {
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      return result;
    };
  }

  testWidgets('a Tailscale name comes back as an address on the usual port', (tester) async {
    final closed = await open(tester);
    expect(find.text('Connect from anywhere'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '  Studio-Mac  ');
    await tester.pump();
    await tester.tap(find.text('Connect'));
    expect(await closed(), const RemoteAddress('studio-mac'));
  });

  testWidgets('a typo says so and keeps the sheet open until it’s fixed', (tester) async {
    final closed = await open(tester);
    await tester.enterText(find.byType(TextField), 'http://studio-mac');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.textContaining('That isn’t a name or address.'), findsOneWidget);
    expect(find.text('Connect from anywhere'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '100.101.102.103:47900');
    await tester.pump();
    expect(find.textContaining('That isn’t a name or address.'), findsNothing);
    await tester.tap(find.text('Connect'));
    expect(await closed(), const RemoteAddress('100.101.102.103', 47900));
  });

  testWidgets('it starts from the saved address, and cancelling changes nothing', (tester) async {
    final closed = await open(tester, current: const RemoteAddress('office-imac', 47900));
    expect(find.widgetWithText(TextField, 'office-imac:47900'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    expect(await closed(), isNull);
  });
}
