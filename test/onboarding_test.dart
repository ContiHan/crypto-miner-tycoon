import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:crypto_miner_tycoon/providers/game_logic.dart';
import 'package:crypto_miner_tycoon/screens/mining_tab.dart';
import 'package:crypto_miner_tycoon/services/economy_service.dart';
import 'package:crypto_miner_tycoon/services/stash_service.dart';
import 'fakes.dart';

GameLogic _freshRunGame(FakeSettingsRepository repo) {
  repo.data['onboarding_complete'] = false; // simulate a first run
  return GameLogic(
    gameRepository: FakeGameRepository(),
    settingsRepository: repo,
    economyService: EconomyService(),
    stashService: StashService(),
    soundService: FakeSoundService(),
    startTimers: false,
    loadOnStart: false,
  );
}

void main() {
  test('completeOnboarding persists across a reload', () async {
    final repo = FakeSettingsRepository();
    final game = _freshRunGame(repo);
    await game.loadGame();
    expect(game.onboardingComplete, false);

    await game.completeOnboarding();
    expect(game.onboardingComplete, true);
    expect(repo.data['onboarding_complete'], true);

    await game.loadGame(); // same fake repo
    expect(game.onboardingComplete, true, reason: 'stays done after reload');
  });

  testWidgets('first-run coach steps through and completes', (tester) async {
    final game = _freshRunGame(FakeSettingsRepository());
    await game.loadGame();

    await tester.pumpWidget(
      ChangeNotifierProvider<GameLogic>.value(
        value: game,
        child: MaterialApp(
          home: Scaffold(
            body: MiningTab(onHardFork: () {}, onBuyRig: (_) {}),
          ),
        ),
      ),
    );
    await tester.pump(); // post-frame: spotlight rects resolve

    // Beat 1 of 3 is showing.
    expect(find.text('1/3'), findsOneWidget);
    expect(find.text('NEXT'), findsOneWidget);

    await tester.tap(find.text('NEXT'));
    await tester.pump();
    expect(find.text('2/3'), findsOneWidget);

    await tester.tap(find.text('NEXT'));
    await tester.pump();
    expect(find.text('3/3'), findsOneWidget);
    expect(find.text('START MINING'), findsOneWidget);

    await tester.tap(find.text('START MINING'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // let async persist + notify

    expect(game.onboardingComplete, true);
    expect(find.text('NEXT'), findsNothing);
    expect(find.text('1/3'), findsNothing);
  });

  testWidgets('SKIP completes the coach immediately', (tester) async {
    final game = _freshRunGame(FakeSettingsRepository());
    await game.loadGame();

    await tester.pumpWidget(
      ChangeNotifierProvider<GameLogic>.value(
        value: game,
        child: MaterialApp(
          home: Scaffold(
            body: MiningTab(onHardFork: () {}, onBuyRig: (_) {}),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('SKIP'), findsOneWidget);
    await tester.tap(find.text('SKIP'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(game.onboardingComplete, true);
    expect(find.text('SKIP'), findsNothing);
  });
}
