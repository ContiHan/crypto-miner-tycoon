import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:crypto_miner_tycoon/providers/game_logic.dart';
import 'package:crypto_miner_tycoon/screens/research_tab.dart';
import 'test_helper.dart';

void main() {
  group('LAB pricing follows the exchange rate (bug #2)', () {
    testWidgets('BTC price adapts to the rate and affordability uses sats cost',
        (tester) async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();

      // After hard forks the exchange rate climbs. Basic Overclocking costs 500
      // credits, so the real charge becomes 500 / 10 = 50 sats.
      game.bitcoinExchangeRate = 10.0;
      game.wallet = 100; // 100 sats: below the raw 500, above the true 50.

      await tester.pumpWidget(
        ChangeNotifierProvider<GameLogic>.value(
          value: game,
          child: const MaterialApp(home: Scaffold(body: ResearchTab())),
        ),
      );
      await tester.pump();

      // Only Basic Overclocking is unlocked at the start => one buy button.
      final buttonFinder = find.byType(ElevatedButton);
      expect(buttonFinder, findsOneWidget);

      // The rate-adjusted sats price (50) is shown, not the raw 500.
      expect(find.textContaining('50 Ş'), findsOneWidget);
      expect(find.textContaining('500'), findsNothing);

      // 100 sats >= 50 sats => affordable, so the button must be enabled. The
      // buggy version compared 100 against the raw 500 and stayed disabled.
      final button = tester.widget<ElevatedButton>(buttonFinder);
      expect(button.onPressed, isNotNull);
    });

    testWidgets('buying at a raised rate deducts only the sats cost',
        (tester) async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.bitcoinExchangeRate = 10.0;
      game.wallet = 100;

      await tester.pumpWidget(
        ChangeNotifierProvider<GameLogic>.value(
          value: game,
          child: const MaterialApp(home: Scaffold(body: ResearchTab())),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(game.isResearched('basic_overclock'), true);
      expect(game.wallet, 50, reason: '100 sats - (500 credits / rate 10)');
    });
  });
}
