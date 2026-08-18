import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:crypto_miner_tycoon/providers/game_logic.dart';
import 'package:crypto_miner_tycoon/screens/research_tab.dart';
import 'test_helper.dart';

void main() {
  group('LAB pricing uses the sats cost', () {
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

    testWidgets('node shows its sats cost; affordability uses that cost',
        (tester) async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.wallet = 1000; // >= the 500 base cost

      await pumpTree(tester, game);

      // The node sublabel shows the sats price (500).
      expect(find.textContaining('500'), findsWidgets);

      // Tap the root node; BUY is enabled since 1000 >= 500.
      await tester.tap(find.text('BASIC OVERCLOCKING'));
      await tester.pumpAndSettle();
      final buttonFinder = find.byType(ElevatedButton);
      expect(buttonFinder, findsOneWidget);
      expect(tester.widget<ElevatedButton>(buttonFinder).onPressed, isNotNull);
    });

    testWidgets('buying deducts the sats cost', (tester) async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.wallet = 1000;

      await pumpTree(tester, game);

      await tester.tap(find.text('BASIC OVERCLOCKING')); // open the sheet
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ElevatedButton)); // RESEARCH
      await tester.pump();

      expect(game.isResearched('basic_overclock'), true);
      expect(game.wallet, 500, reason: '1000 sats - 500 base cost');
    });
  });
}
