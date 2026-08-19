import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:crypto_miner_tycoon/providers/game_logic.dart';
import 'package:crypto_miner_tycoon/screens/research_tab.dart';
import 'test_helper.dart';

void main() {
  group('TECH is Research-Point only (no BTC cost)', () {
    // TECH V2 is an accordion of branches that starts fully collapsed (overview).
    // Expand THE FOUNDRY (branch A) to reach its root node "Overclocked Cores".
    // The node costs only RP — the tap sheet shows the RP price and a RESEARCH
    // button, gated on the RP budget, never on the wallet.
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
      // Everything starts collapsed — open THE FOUNDRY to reveal its nodes.
      await tester.tap(find.text('THE FOUNDRY'));
      await tester.pumpAndSettle();
    }

    testWidgets('the node sheet shows an RP price and an enabled RESEARCH button',
        (tester) async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.wallet = 0; // RP-only: affordability never looks at the wallet

      await pumpTree(tester, game);

      // The branch-A root node is visible (branch opens by default).
      expect(find.text('Overclocked Cores'), findsOneWidget);

      // Tap it: the sheet surfaces the RP price and an enabled RESEARCH button
      // (fresh rpBudget is 4; this 1-RP node fits even at a 0 wallet).
      await tester.tap(find.text('Overclocked Cores'));
      await tester.pumpAndSettle();
      expect(find.textContaining('1 RP'), findsWidgets);
      final buttonFinder = find.byType(ElevatedButton);
      expect(buttonFinder, findsOneWidget);
      expect(tester.widget<ElevatedButton>(buttonFinder).onPressed, isNotNull);
    });

    testWidgets('researching completes the node and spends no BTC',
        (tester) async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.wallet = 0;

      await pumpTree(tester, game);

      await tester.tap(find.text('Overclocked Cores')); // open the sheet
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ElevatedButton)); // RESEARCH
      await tester.pump();

      expect(game.isResearched('basic_overclock'), true);
      expect(game.wallet, 0, reason: 'TECH is RP-only — no BTC deducted');
    });
  });
}
