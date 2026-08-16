import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/constants.dart';
import 'package:crypto_miner_tycoon/providers/game_logic.dart';
import 'package:crypto_miner_tycoon/services/economy_service.dart';
import 'package:crypto_miner_tycoon/services/stash_service.dart';
import 'test_helper.dart';
import 'fakes.dart';

void main() {
  group('THE LAST SATOSHI — win detection', () {
    test('mining a full 21M supply in one era wins exactly once', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      expect(game.hasWonGame, false);
      expect(game.pendingWinCelebration, false);

      // Sit one sat below the per-era cap; the next click fills the supply.
      game.lifetimeEarnings = GameConstants.maxSupplySats - 1;
      game.clickMine(playSound: false);

      expect(game.hasWonGame, true);
      expect(game.pendingWinCelebration, true);
      expect(game.lifetimeEarnings,
          greaterThanOrEqualTo(GameConstants.maxSupplySats));

      // Draining the celebration is one-shot; the win latch stays; income is now
      // clamped to 0 at the cap, so no further click can re-fire the ending.
      game.clearWinCelebration();
      expect(game.pendingWinCelebration, false);
      game.clickMine(playSound: false);
      expect(game.pendingWinCelebration, false, reason: 'never re-fires');
      expect(game.hasWonGame, true);
    });

    test('the Last Satoshi meta achievement unlocks on the win', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.lifetimeEarnings = GameConstants.maxSupplySats - 1;
      game.clickMine(playSound: false);
      expect(game.isAchievementUnlocked('meta_genesis_complete'), true);
    });

    test('supplyProgress is honest linear era progress (0..1)', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.lifetimeEarnings = 0;
      expect(game.supplyProgress, 0.0);
      game.lifetimeEarnings = GameConstants.maxSupplySats / 2;
      expect(game.supplyProgress, closeTo(0.5, 1e-9));
      game.lifetimeEarnings = GameConstants.maxSupplySats;
      expect(game.supplyProgress, 1.0);
      // Never exceeds 1.0 even if a stray value overshoots.
      game.lifetimeEarnings = GameConstants.maxSupplySats * 2;
      expect(game.supplyProgress, 1.0);
    });

    test('a win crossing during offline catch-up is never surfaced before the '
        'offline amount (no ending-under-dialog stacking) — QA regression',
        () async {
      // If the win notifies mid-offline-loop (before offlineEarningsAmount is
      // set), HomeScreen pushes the ending overlay first and the WELCOME BACK
      // dialog stacks on top of it. Assert no notification ever carries a pending
      // win with the offline amount still unset.
      final repo = FakeGameRepository();
      repo.data.addAll({
        'lifetimeEarnings': GameConstants.maxSupplySats - 1e6,
        'rigs': [
          {'id': 'cpu_rig', 'amount': 500000},
        ],
        // No cold-start gap: the win must cross on the WARM-resume path below.
        'last_save_time': DateTime.now().millisecondsSinceEpoch,
      });
      final game = GameLogic(
        gameRepository: repo,
        settingsRepository: FakeSettingsRepository(),
        economyService: EconomyService(),
        stashService: StashService(),
        soundService: FakeSoundService(),
        startTimers: false,
        loadOnStart: false,
      )..clickRng = NoCritRandom();
      await game.loadGame();
      expect(game.hasWonGame, false, reason: 'no win yet (cold-start gap ~0)');

      var sawWinBeforeOfflineAmount = false;
      game.addListener(() {
        if (game.pendingWinCelebration && game.offlineEarningsAmount == null) {
          sawWinBeforeOfflineAmount = true;
        }
      });

      // Warm resume after a long absence: offline mining crosses the cap.
      repo.data['last_save_time'] = DateTime.now()
          .subtract(const Duration(hours: 10))
          .millisecondsSinceEpoch;
      await game.onAppResumed();

      expect(game.hasWonGame, true, reason: 'win crossed during offline catch-up');
      expect(game.offlineEarningsAmount, isNotNull, reason: 'long gap is announced');
      expect(sawWinBeforeOfflineAmount, false,
          reason: 'win never surfaced before the offline amount was set');
    });
  });

  group('The 21M/era cap is inviolable', () {
    test('income stops at the cap — even after the game is won', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.rigs.firstWhere((r) => r.id == 'cpu_rig').amount = 50;
      game.lifetimeEarnings = GameConstants.maxSupplySats; // at the cap

      // Capped: no income, difficulty ∞.
      expect(game.advanceForTest(1), 0);
      expect(game.networkDifficulty.isInfinite, true);

      // Winning does NOT lift the cap — the supply is sacred.
      game.hasWonGame = true;
      expect(game.advanceForTest(1), 0, reason: 'no sandbox: cap always applies');
      expect(game.networkDifficulty.isInfinite, true);
    });

    test('offline mining never accrues past the cap', () async {
      final repo = FakeGameRepository();
      repo.data.addAll({
        'lifetimeEarnings': GameConstants.maxSupplySats - 10,
        'wallet': 0.0,
        'rigs': [
          {'id': 'cpu_rig', 'amount': 1000000}, // huge hashrate
        ],
        'last_save_time':
            DateTime.now().millisecondsSinceEpoch - 10 * 3600 * 1000, // 10h ago
      });
      final game = GameLogic(
        gameRepository: repo,
        settingsRepository: FakeSettingsRepository(),
        economyService: EconomyService(),
        stashService: StashService(),
        soundService: FakeSoundService(),
        startTimers: false,
        loadOnStart: false,
      )..clickRng = NoCritRandom();
      await game.loadGame();

      // The 10h of offline income is clamped to the <=10 sats of remaining room.
      expect(game.lifetimeEarnings,
          lessThanOrEqualTo(GameConstants.maxSupplySats));
      expect((game.offlineEarningsAmount ?? 0), lessThanOrEqualTo(10));
    });
  });

  group('Back in Time (post-win timed re-mine)', () {
    test('a completed run records a time and clears the active flag', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.hasWonGame = true; // unlocks Back in Time
      expect(game.speedRunUnlocked, true);

      game.startSpeedRun();
      expect(game.speedRunActive, true);

      // Mining a full supply while a run is active finishes it.
      game.debugCreditEver(GameConstants.maxSupplySats);
      expect(game.speedRunActive, false, reason: 'run finished at 21M');
      expect(game.speedRunLastMs, greaterThanOrEqualTo(0));
    });
  });

  group('Endgame persistence + wipe', () {
    test('a full Wipe Save clears the win latch + lifetime stat', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.hasWonGame = true;
      game.lifetimeEverSats = 3e17;

      await game.resetGame();
      expect(game.hasWonGame, false);
      expect(game.lifetimeEverSats, 0);
    });

    test('the win latch + lifetime stat survive a save/reload', () async {
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
      g1.wallet = 1e9;
      g1.buyRig('cpu_rig'); // triggers a save

      final g2 = make();
      await g2.loadGame();
      expect(g2.hasWonGame, true);
      expect(g2.lifetimeEverSats, 5e16);
    });

    test('a legacy save already at the 21M cap latches the win on load', () async {
      // Migration: a pre-pivot save sitting at the per-era cap (but with no
      // hasWonGame flag) is silently treated as won, without replaying credits.
      final repo = FakeGameRepository();
      repo.data.addAll({
        'lifetimeEarnings': GameConstants.maxSupplySats,
        // deliberately no 'hasWonGame' key
      });
      final game = GameLogic(
        gameRepository: repo,
        settingsRepository: FakeSettingsRepository(),
        economyService: EconomyService(),
        stashService: StashService(),
        soundService: FakeSoundService(),
        startTimers: false,
        loadOnStart: false,
      )..clickRng = NoCritRandom();
      await game.loadGame();
      expect(game.hasWonGame, true);
      expect(game.pendingWinCelebration, false,
          reason: 'migration latch must not replay the ending');
    });
  });
}
