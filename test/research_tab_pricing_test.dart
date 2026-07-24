import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:crypto_miner_tycoon/providers/game_logic.dart';
import 'package:crypto_miner_tycoon/screens/research_tab.dart';
import 'test_helper.dart';

void main() {
  group('LAB pricing follows the exchange rate (bug #2)', () {
    // The TECH tree is now a graph; the BUY button lives in the tap sheet. Use a
    // large surface so the (0,0)-anchored root node sits inside the viewport.
    Future<void> pumpTree(WidgetTester tester, GameLogic game) async {
      tester.view.physicalSize = const Size(1400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ChangeNotifierProvider<GameLogic>.value(
          value: game,
          child: const MaterialApp(home: Scaffold(body: ResearchTab())),
        ),
      );
      await tester.pump();
    }

    testWidgets('BTC price adapts to the rate and affordability uses sats cost',
        (tester) async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();

      // After hard forks the exchange rate climbs. Basic Overclocking costs 500
      // credits, so the real charge becomes 500 / 10 = 50 sats.
      game.bitcoinExchangeRate = 10.0;
      game.wallet = 100; // 100 sats: below raw 500, above the true 50.

      await pumpTree(tester, game);

      // The node sublabel shows the rate-adjusted sats price (50), not raw 500.
      expect(find.textContaining('50 Ş'), findsOneWidget);
      expect(find.textContaining('500'), findsNothing);

      // Tap the root node to open its sheet; the BUY button must be enabled
      // (100 sats >= 50 sats). The buggy version compared 100 vs the raw 500.
      await tester.tap(find.text('BASIC OVERCLOCKING'));
      await tester.pumpAndSettle();
      final buttonFinder = find.byType(ElevatedButton);
      expect(buttonFinder, findsOneWidget);
      expect(tester.widget<ElevatedButton>(buttonFinder).onPressed, isNotNull);
    });

    testWidgets('buying at a raised rate deducts only the sats cost',
        (tester) async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.bitcoinExchangeRate = 10.0;
      game.wallet = 100;

      await pumpTree(tester, game);

      await tester.tap(find.text('BASIC OVERCLOCKING')); // open the sheet
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ElevatedButton)); // RESEARCH
      await tester.pump();

      expect(game.isResearched('basic_overclock'), true);
      expect(game.wallet, 50, reason: '100 sats - (500 credits / rate 10)');
    });
  });
}
