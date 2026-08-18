import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:crypto_miner_tycoon/providers/game_logic.dart';
import 'package:crypto_miner_tycoon/screens/research_tab.dart';
import 'test_helper.dart';

void main() {
  group('LAB pricing uses the sats cost', () {
    // TECH V2 is an accordion of branches; THE FOUNDRY (branch A) opens by
    // default and its root node is "Overclocked Cores". The sats price + BUY
    // button live in the tap sheet. A tall surface keeps the node on-screen.
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

      // The branch-A root node is visible (branch opens by default).
      expect(find.text('Overclocked Cores'), findsOneWidget);

      // Tap it: the sheet surfaces the 500-sat price and an enabled RESEARCH
      // button (1000 >= 500).
      await tester.tap(find.text('Overclocked Cores'));
      await tester.pumpAndSettle();
      expect(find.textContaining('500'), findsWidgets);
      final buttonFinder = find.byType(ElevatedButton);
      expect(buttonFinder, findsOneWidget);
      expect(tester.widget<ElevatedButton>(buttonFinder).onPressed, isNotNull);
    });

    testWidgets('buying deducts the sats cost', (tester) async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.wallet = 1000;

      await pumpTree(tester, game);

      await tester.tap(find.text('Overclocked Cores')); // open the sheet
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ElevatedButton)); // RESEARCH
      await tester.pump();

      expect(game.isResearched('basic_overclock'), true);
      expect(game.wallet, 500, reason: '1000 sats - 500 base cost');
    });
  });
}
