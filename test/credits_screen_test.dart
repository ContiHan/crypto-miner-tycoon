import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:crypto_miner_tycoon/screens/credits_screen.dart';

void main() {
  setUpAll(() {
    // Match production: never hit the network for fonts in tests (falls back to
    // a bundled/system face synchronously, so no stray fetch exception).
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('CreditsScreen renders its sections without overflow', (t) async {
    await t.pumpWidget(const MaterialApp(home: CreditsScreen()));

    expect(find.text('BTC ONLY TYCOON'), findsOneWidget);
    expect(find.text('CREATED BY'), findsOneWidget);
    expect(find.text('THANKS'), findsOneWidget);
    expect(find.textContaining('vibecoded'), findsOneWidget);
    expect(find.text('CLOSE'), findsOneWidget);

    // A RenderFlex overflow is recorded as an exception in tests; the clean
    // pump above should leave none.
    expect(t.takeException(), isNull);
  });

  testWidgets('CLOSE pops the screen', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => CreditsScreen.open(ctx),
            child: const Text('open'),
          ),
        ),
      ),
    ));

    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('BTC ONLY TYCOON'), findsOneWidget); // credits is up

    // CLOSE sits at the bottom of a scroll view; bring it on-screen to tap it.
    await t.ensureVisible(find.text('CLOSE'));
    await t.pumpAndSettle();
    await t.tap(find.text('CLOSE'));
    await t.pumpAndSettle();
    expect(find.text('BTC ONLY TYCOON'), findsNothing); // popped back
    expect(find.text('open'), findsOneWidget);
  });
}
