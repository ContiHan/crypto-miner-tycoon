import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/constants.dart';
import 'package:crypto_miner_tycoon/logic/managers/class_manager.dart';
import 'package:crypto_miner_tycoon/providers/game_logic.dart';
import 'package:crypto_miner_tycoon/services/economy_service.dart';
import 'package:crypto_miner_tycoon/services/stash_service.dart';
import 'test_helper.dart';
import 'fakes.dart';

void main() {
  group('Endgame win detection', () {
    test('crossing the cumulative-ever target wins exactly once', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      expect(game.hasWonGame, false);
      expect(game.pendingWinCelebration, false);

      // Sit just below the target; one tap of income crosses it.
      game.lifetimeEverSats = GameConstants.endgameTargetSats - 1;
      game.clickMine(playSound: false); // earns >0 click sats

      expect(game.hasWonGame, true);
      expect(game.pendingWinCelebration, true);
      expect(game.lifetimeEverSats,
          greaterThanOrEqualTo(GameConstants.endgameTargetSats));

      // Draining the celebration is one-shot; the win latch stays.
      game.clearWinCelebration();
      expect(game.pendingWinCelebration, false);
      game.clickMine(playSound: false);
      expect(game.pendingWinCelebration, false, reason: 'never re-fires');
      expect(game.hasWonGame, true);
    });

    test('the Genesis Complete meta achievement unlocks on the win', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.lifetimeEverSats = GameConstants.endgameTargetSats - 1;
      game.clickMine(playSound: false);
      expect(game.isAchievementUnlocked('meta_genesis_complete'), true);
    });
  });

  group('Sandbox ("break the chain")', () {
    test('only togglable after a win', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.toggleSandboxNoCap();
      expect(game.sandboxNoCap, false, reason: 'no-op before winning');

      game.hasWonGame = true;
      game.toggleSandboxNoCap();
      expect(game.sandboxNoCap, true);
      // The secret achievement unlocks at the moment of toggling (not only later).
      expect(game.isAchievementUnlocked('secret_sandbox'), true);
    });

    test('lifts the per-era cap so income flows past 21M', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.rigs.firstWhere((r) => r.id == 'cpu_rig').amount = 50;
      game.lifetimeEarnings = GameConstants.maxSupplySats; // at the cap

      // Capped: no income, difficulty ∞.
      expect(game.advanceForTest(1), 0);
      expect(game.networkDifficulty.isInfinite, true);

      // Break the chain: income resumes, difficulty finite.
      game.hasWonGame = true;
      game.toggleSandboxNoCap();
      expect(game.advanceForTest(1), greaterThan(0));
      expect(game.networkDifficulty.isFinite, true);
    });

    test('offline mining accrues the FULL absence in sandbox (past the cap)',
        () async {
      // Regression: the offline loop's early-break at the per-era cap must be
      // skipped in sandbox, or a returning sandbox player gets ~1 chunk instead
      // of the full absence.
      final repo = FakeGameRepository();
      final settings = FakeSettingsRepository();
      repo.data.addAll({
        'sandboxNoCap': true,
        'hasWonGame': true,
        'lifetimeEverSats': 3.0e17,
        'lifetimeEarnings': GameConstants.maxSupplySats + 1e15, // past the cap
        'wallet': 0.0,
        'rigs': [
          {'id': 'cpu_rig', 'amount': 1000000}, // ~1e6 H/s
        ],
        'last_save_time':
            DateTime.now().millisecondsSinceEpoch - 10 * 3600 * 1000, // 10h ago
      });
      final game = GameLogic(
        gameRepository: repo,
        settingsRepository: settings,
        economyService: EconomyService(),
        stashService: StashService(),
        soundService: FakeSoundService(),
        startTimers: false,
        loadOnStart: false,
      )..clickRng = NoCritRandom();
      await game.loadGame();

      // With the bug, offline income would be ~one 7s chunk (~7e6). With the
      // fix, the full 10h accrues (~1e6/s * 36000s ~= 3.6e10).
      expect(game.offlineEarningsAmount, isNotNull);
      expect(game.offlineEarningsAmount!, greaterThan(1e9),
          reason: 'sandbox offline ran the full absence, not one capped chunk');
    });

    test('turning sandbox OFF past the cap starts a fresh NG+ chain', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.hasWonGame = true;
      game.sandboxNoCap = true;
      game.lifetimeEarnings = GameConstants.maxSupplySats + 1e15; // past cap
      final winsBefore = game.winCount;

      game.toggleSandboxNoCap();
      expect(game.sandboxNoCap, false);
      expect(game.winCount, winsBefore + 1, reason: 'NG+ so income isn\'t 0');
      expect(game.lifetimeEarnings, 0, reason: 'landed on a clean chain');
    });
  });

  group('New Genesis (NG+)', () {
    test('requires a win, increments winCount, wipes era, keeps the spine',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();

      game.newGenesisPlus(); // no-op before winning
      expect(game.winCount, 0);

      game.hasWonGame = true;
      game.lifetimeEverSats = 3e17;
      game.lifetimeEarnings = 1e10;
      game.wallet = 500;

      game.newGenesisPlus(chosenClass: BtcClass.soloMiner);
      expect(game.winCount, 1);
      expect(game.currentClass, BtcClass.soloMiner);
      expect(game.lifetimeEarnings, 0, reason: 'era wiped');
      expect(game.wallet, 0);
      expect(game.hasWonGame, true, reason: 'endgame spine preserved');
      expect(game.lifetimeEverSats, 3e17, reason: 'cumulative-ever preserved');
    });

    test('trophy multiplier scales prestige gain with winCount', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      expect(game.trophyGainMultiplier, 1.0);
      game.winCount = 2;
      expect(game.trophyGainMultiplier,
          closeTo(1.0 + GameConstants.perWinTrophyBonus * 2, 1e-9));

      // Higher winCount => strictly more pending prestige for the same lifetime.
      game.lifetimeEarnings = 1e13;
      final gt2 = game.pendingGovTokens;
      game.winCount = 0;
      final gt0 = game.pendingGovTokens;
      expect(gt2, greaterThan(gt0));
    });
  });

  group('Endgame persistence + wipe', () {
    test('a full Wipe Save clears the endgame spine', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.hasWonGame = true;
      game.lifetimeEverSats = 3e17;
      game.winCount = 2;
      game.sandboxNoCap = true;

      await game.resetGame();
      expect(game.hasWonGame, false);
      expect(game.lifetimeEverSats, 0);
      expect(game.winCount, 0);
      expect(game.sandboxNoCap, false);
    });

    test('endgame state survives a save/reload', () async {
      final repo = FakeGameRepository();
      final settings = FakeSettingsRepository();
      GameLogic make() => GameLogic(
            gameRepository: repo,
            settingsRepository: settings,
            economyService: EconomyService(),
            stashService: StashService(),
            soundService: FakeSoundService(),
            startTimers: false,
            loadOnStart: false,
          )..clickRng = NoCritRandom();

      final g1 = make();
      await g1.loadGame();
      g1.hasWonGame = true;
      g1.lifetimeEverSats = 5e16;
      g1.winCount = 3;
      g1.sandboxNoCap = true;
      g1.wallet = 1e9;
      g1.buyRig('cpu_rig'); // triggers a save

      final g2 = make();
      await g2.loadGame();
      expect(g2.hasWonGame, true);
      expect(g2.winCount, 3);
      expect(g2.sandboxNoCap, true);
      expect(g2.lifetimeEverSats, 5e16);
    });
  });
}
