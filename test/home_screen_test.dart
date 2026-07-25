import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:crypto_miner_tycoon/screens/home_screen.dart';
import 'package:crypto_miner_tycoon/providers/game_logic.dart';
import 'package:crypto_miner_tycoon/screens/mining_tab.dart';
import 'package:crypto_miner_tycoon/screens/perks_screen.dart';
import 'package:crypto_miner_tycoon/screens/research_tab.dart';
import 'package:crypto_miner_tycoon/screens/stash_screen.dart';
import 'package:crypto_miner_tycoon/services/economy_service.dart';
import 'package:crypto_miner_tycoon/services/stash_service.dart';
import 'package:crypto_miner_tycoon/core/ids.dart';
import 'test_helper.dart';
import 'fakes.dart';

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

  testWidgets(
      'warm resume credits offline earnings — a return-path `hidden` must not '
      'clobber last_save_time (QA HIGH regression)', (tester) async {
    // Flutter traverses paused->hidden->inactive->resumed when returning to the
    // foreground, so `hidden` fires on the RE-ENTRY path. If the widget routes
    // `hidden` to onAppPaused it re-saves last_save_time=now right before
    // onAppResumed reads it, zeroing the elapsed gap and silently dropping the
    // WELCOME BACK offline payout. Guard the correct routing end-to-end.
    final repo = FakeGameRepository()
      ..data['rigs'] = [
        {'id': RigIds.cpuRig, 'amount': 1},
      ];
    final lifecycleGame = GameLogic(
      gameRepository: repo,
      settingsRepository: FakeSettingsRepository(),
      economyService: EconomyService(),
      stashService: StashService(),
      soundService: FakeSoundService(),
      startTimers: false,
      loadOnStart: false,
    )..clickRng = NoCritRandom();
    await lifecycleGame.loadGame();

    await tester.pumpWidget(
      ChangeNotifierProvider<GameLogic>.value(
        value: lifecycleGame,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    // Background: inactive -> hidden -> paused (onAppPaused saves + stops timers).
    for (final s in const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await tester.pump();

    // Pretend two hours elapsed while backgrounded.
    final twoHoursAgo =
        DateTime.now().subtract(const Duration(hours: 2)).millisecondsSinceEpoch;
    repo.data['last_save_time'] = twoHoursAgo;

    // Return path so far: paused -> hidden -> inactive. The `hidden` step must
    // NOT be treated as a pause (that would overwrite the timestamp we just set).
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(repo.data['last_save_time'], twoHoursAgo,
        reason: 'a return-path `hidden` must not overwrite the save timestamp');

    // ...resumed: the full 2h gap is now reconciled into the wallet.
    final walletBefore = lifecycleGame.wallet;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(lifecycleGame.wallet, greaterThan(walletBefore),
        reason: 'warm resume credited the background absence (welcome-back payout)');

    // Let the welcome-back dialog's finite transition finish (HomeScreen's news
    // ticker animates forever, so a full pumpAndSettle would never converge).
    await tester.pump(const Duration(milliseconds: 400));
  });
}
