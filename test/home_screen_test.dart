import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto_miner_tycoon/screens/home_screen.dart';
import 'package:crypto_miner_tycoon/providers/game_logic.dart';
import 'package:crypto_miner_tycoon/screens/mining_tab.dart';
import 'package:crypto_miner_tycoon/screens/perks_screen.dart';
import 'package:crypto_miner_tycoon/screens/research_tab.dart';
import 'package:crypto_miner_tycoon/screens/stash_screen.dart';

void main() {
  late GameLogic game;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    game = GameLogic(startTimers: false);
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

  testWidgets('HomeScreen: Hard Fork Dialog appears', (
    WidgetTester tester,
  ) async {
    game.govTokens = 0;
    game.lifetimeEarnings = 100000;

    await tester.pumpWidget(createWidgetUnderTest());

    final hardForkButton = find.textContaining('HARD FORK');

    expect(hardForkButton, findsOneWidget);

    await tester.tap(hardForkButton);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('EXECUTE HARD FORK?'), findsOneWidget);
  });
}
