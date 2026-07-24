import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:crypto_miner_tycoon/screens/home_screen.dart';
import 'package:crypto_miner_tycoon/providers/game_logic.dart';
import 'package:crypto_miner_tycoon/screens/mining_tab.dart';
import 'package:crypto_miner_tycoon/screens/perks_screen.dart';
import 'package:crypto_miner_tycoon/screens/research_tab.dart';
import 'package:crypto_miner_tycoon/screens/stash_screen.dart';
import 'test_helper.dart';

void main() {
  late GameLogic game;

  setUp(() {
    game = createTestGameLogic(startTimers: false);
  });

  Widget createWidgetUnderTest() {
    return ChangeNotifierProvider<GameLogic>.value(
      value: game,
      child: const MaterialApp(home: HomeScreen()),
    );
  }

  testWidgets('HomeScreen: Navigation works', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    // Default is Mine Tab (Index 3)
    expect(find.byType(MiningTab), findsOneWidget);

    // SKILL/TECH/STASH start locked (progressive disclosure); unlock them so
    // this navigation test can reach every tab.
    game.debugUnlockAllTabs();
    await tester.pump();

    // Tap Perks (Index 0) - Icon: Icons.auto_graph
    await tester.tap(find.byIcon(Icons.auto_graph));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(PerksScreen), findsOneWidget);

    // Tap Lab (Index 1) - Icon: Icons.science
    await tester.tap(find.byIcon(Icons.science));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ResearchTab), findsOneWidget);

    // Tap Stash (Index 2) - Icon: Icons.inventory_2
    await tester.tap(find.byIcon(Icons.inventory_2));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(StashScreen), findsOneWidget);
  });

  testWidgets('HomeScreen: a re-locked tab falls back to MINE', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createWidgetUnderTest());
    game.debugUnlockAllTabs();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.science)); // go to TECH
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ResearchTab), findsOneWidget);

    await game.resetGame(); // wipes → re-locks tabs + notifies
    await tester.pump();
    expect(find.byType(MiningTab), findsOneWidget,
        reason: 'parked on a now-locked tab → fall back to MINE');
  });

  testWidgets('HomeScreen: Hard Fork Dialog appears', (
    WidgetTester tester,
  ) async {
    game.govTokens = 0;
    // Enough lifetime to earn a GovToken under the redesigned accrual
    // (sqrt(2e9 / 5e8) = 2), so the HARD FORK button appears.
    game.lifetimeEarnings = 2e9;

    await tester.pumpWidget(createWidgetUnderTest());

    final hardForkButton = find.textContaining('HARD FORK');

    expect(hardForkButton, findsOneWidget);

    // The MINE tab is scrollable and the endgame progress bar pushes the button
    // lower than the 800x600 test viewport, so bring it on-screen before tapping.
    await tester.ensureVisible(hardForkButton);
    await tester.pump();
    await tester.tap(hardForkButton);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('EXECUTE HARD FORK?'), findsOneWidget);
  });
}
