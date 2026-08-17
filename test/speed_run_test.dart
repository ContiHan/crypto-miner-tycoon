import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/constants.dart';
import 'package:crypto_miner_tycoon/core/ids.dart';
import 'package:crypto_miner_tycoon/logic/managers/class_manager.dart';
import 'test_helper.dart';

int _now() => DateTime.now().millisecondsSinceEpoch;

void main() {
  group('Speed Run (Genesis Sprint)', () {
    test('locked until the win, then unlocked (post-credits replay)', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      expect(game.speedRunUnlocked, false, reason: 'fresh game: not won yet');
      game.hardForkCount = 1; // a prestige alone no longer unlocks Back in Time
      expect(game.speedRunUnlocked, false, reason: 'a Hard Fork does NOT unlock it');

      game.hasWonGame = true; // the win (mined a full 21M supply) unlocks it
      expect(game.speedRunUnlocked, true);
    });

    test('start wipes the run but keeps the permanent spine and starts the clock',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.hasWonGame = true; // unlock
      game.wallet = 1e9;
      game.govTokens = 500;
      game.buyRig(RigIds.cpuRig);
      game.lifetimeEverSats = 5e15; // permanent cumulative-ever (must survive)

      game.startSpeedRun();

      expect(game.speedRunActive, true);
      expect(game.speedRunMinedSats, 0);
      expect(game.speedRunStartMs, greaterThan(0));
      expect(game.wallet, 0, reason: 'run wallet wiped');
      expect(game.govTokens, 0, reason: 'GovTokens wiped');
      expect(game.rigs.firstWhere((r) => r.id == RigIds.cpuRig).amount, 0,
          reason: 'rigs wiped');
      expect(game.lifetimeEverSats, 5e15,
          reason: 'permanent cumulative-ever survives the sprint reset');
    });

    test('does nothing while locked', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.wallet = 1e9;
      game.startSpeedRun(); // locked -> no-op
      expect(game.speedRunActive, false);
      expect(game.wallet, 1e9, reason: 'no reset while locked');
    });

    test('progress tracks mined sats toward one full supply', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.hasWonGame = true;
      game.startSpeedRun();

      game.debugCreditEver(GameConstants.maxSupplySats / 2);
      expect(game.speedRunProgress, closeTo(0.5, 1e-6));
      expect(game.speedRunActive, true, reason: 'not finished at 50%');
    });

    test('finishing one full supply records the time, best and celebration',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.hasWonGame = true;
      game.startSpeedRun();
      game.speedRunStartMs = _now() - 5000; // pretend the run started 5s ago

      game.debugCreditEver(GameConstants.maxSupplySats); // reach one supply

      expect(game.speedRunActive, false, reason: 'run ends at one full supply');
      expect(game.speedRunLastMs, greaterThanOrEqualTo(4900));
      expect(game.speedRunLastMs, lessThan(8000));
      expect(game.speedRunBestMs, game.speedRunLastMs, reason: 'first run = best');
      expect(game.speedRunWasRecord, true);
      expect(game.pendingSpeedRunCelebration, true);
    });

    test('best only improves on a faster time', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.hasWonGame = true;

      // Run 1: ~3s.
      game.startSpeedRun();
      game.speedRunStartMs = _now() - 3000;
      game.debugCreditEver(GameConstants.maxSupplySats);
      final firstBest = game.speedRunBestMs;
      expect(firstBest, greaterThanOrEqualTo(2900));

      // Run 2: slower (~8s) -> best unchanged, not a record.
      game.startSpeedRun();
      game.speedRunStartMs = _now() - 8000;
      game.debugCreditEver(GameConstants.maxSupplySats);
      expect(game.speedRunBestMs, firstBest, reason: 'slower run does not beat PB');
      expect(game.speedRunWasRecord, false);

      // Run 3: faster (~1s) -> new record.
      game.startSpeedRun();
      game.speedRunStartMs = _now() - 1000;
      game.debugCreditEver(GameConstants.maxSupplySats);
      expect(game.speedRunBestMs, lessThan(firstBest));
      expect(game.speedRunWasRecord, true);
    });

    test('abort ends the run without recording', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.hasWonGame = true;
      game.startSpeedRun();
      game.debugCreditEver(GameConstants.maxSupplySats / 3);

      game.abortSpeedRun();
      expect(game.speedRunActive, false);
      expect(game.speedRunBestMs, 0, reason: 'aborting records no time');
      expect(game.pendingSpeedRunCelebration, false);
    });

    test('best time and an active run survive save + reload', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.hasWonGame = true;

      // Complete one run to bank a best time.
      game.startSpeedRun();
      game.speedRunStartMs = _now() - 4000;
      game.debugCreditEver(GameConstants.maxSupplySats);
      final banked = game.speedRunBestMs;
      expect(banked, greaterThan(0));

      // Start another run (persists active + start), then reload.
      game.startSpeedRun();
      final startMs = game.speedRunStartMs;
      await game.loadGame();

      expect(game.speedRunBestMs, banked, reason: 'best time persisted');
      expect(game.speedRunActive, true, reason: 'active run persisted');
      expect(game.speedRunStartMs, startMs, reason: 'wall-clock start persisted');
    });
  });

  group('Back in Time long-tail — per-class times + medals + TIMECHAIN (F-B)', () {
    test('completing a run records a per-class best + unlocks the time medals',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.debugSelectClass(BtcClass.corporation);
      game.hasWonGame = true;

      game.startSpeedRun();
      game.speedRunStartMs = _now() - 1000; // a ~1s (sub-30m) completion
      game.debugCreditEver(GameConstants.maxSupplySats);

      expect(game.speedRunBestForClass('corporation'), greaterThan(0));
      expect(game.speedRunClassCount, 1);
      // A sub-30m run trips the whole ladder.
      expect(game.isAchievementUnlocked('ng_plus'), true);
      expect(game.isAchievementUnlocked('speedrun_silver'), true);
      expect(game.isAchievementUnlocked('speedrun_satoshi'), true);
    });

    test('speedRunClassCount counts only real classes (not Prospector)', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.speedRunBestByClass = {'prospector': 100, 'corporation': 200};
      expect(game.speedRunClassCount, 1);
    });

    test('THE TIMECHAIN unlocks once all four classes have a recorded time',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.speedRunBestByClass = {
        'soloMiner': 1,
        'corporation': 2,
        'btcOg': 3,
        'poolMember': 4,
      };
      expect(game.speedRunClassCount, 4);
      game.debugEvaluateAchievements();
      expect(game.isAchievementUnlocked('the_timechain'), true);
    });

    test('per-class best map survives save + reload', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.speedRunBestByClass = {'btcOg': 4200};
      await game.debugSave();
      await game.loadGame();
      expect(game.speedRunBestForClass('btcOg'), 4200);
    });
  });
}
