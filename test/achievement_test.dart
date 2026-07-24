import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/content/achievement_defs.dart';
import 'package:crypto_miner_tycoon/core/constants.dart';
import 'package:crypto_miner_tycoon/logic/managers/achievement_manager.dart';
import 'package:crypto_miner_tycoon/providers/game_logic.dart';
import 'package:crypto_miner_tycoon/services/economy_service.dart';
import 'package:crypto_miner_tycoon/services/stash_service.dart';
import 'fakes.dart';
import 'test_helper.dart';

void main() {
  group('Achievements', () {
    test('unlocking queues a toast but grants NO Notoriety until claimed',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      expect(game.isAchievementUnlocked('earn_1m'), false);

      game.lifetimeEarnings = 2e6; // >= 1e6 threshold
      game.clickMine(playSound: false); // triggers evaluation

      expect(game.isAchievementUnlocked('earn_1m'), true);
      expect(game.isAchievementClaimable('earn_1m'), true);
      expect(game.pendingAchievementToasts.any((a) => a.id == 'earn_1m'), true);
      expect(game.notorietyBonus, 0.0, reason: 'reward gated on claim');
      expect(game.unclaimedAchievements, greaterThan(0));

      // Claiming activates the Notoriety bonus.
      expect(game.claimAchievement('earn_1m'), true);
      expect(game.isAchievementClaimed('earn_1m'), true);
      expect(game.isAchievementClaimable('earn_1m'), false);
      expect(game.notorietyBonus, greaterThan(0));
      // Claiming again is a no-op.
      expect(game.claimAchievement('earn_1m'), false);
    });

    test('claimed Notoriety is applied to income EXACTLY once (+1%)', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.wallet = 1e6;
      final base = game.estimatedClickValue; // notoriety 1.0
      expect(game.notorietyMultiplier, 1.0);

      // rigs_10 unlocks; still no bonus until claimed.
      game.buyRigMax('cpu_rig', 10);
      expect(game.isAchievementClaimable('rigs_10'), true);
      expect(game.notorietyMultiplier, 1.0, reason: 'unclaimed = no bonus');

      game.claimAchievement('rigs_10');
      expect(game.notorietyMultiplier, closeTo(1.01, 1e-9));
      // A double-applied multiplier would read base*1.0201 and fail here.
      expect(game.estimatedClickValue, closeTo(base * 1.01, base * 1e-6),
          reason: 'income multiplier must be applied once, not compounded');
    });

    test('claiming a secret achievement grants NO Notoriety', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.lifetimeEarnings = 2e4; // crosses secret_pizza (1e4), not earn_1m
      game.clickMine(playSound: false);

      expect(game.isAchievementUnlocked('secret_pizza'), true);
      game.claimAchievement('secret_pizza');
      expect(game.isAchievementClaimed('secret_pizza'), true);
      expect(game.notorietyBonus, 0.0, reason: 'secret grants no bonus');
    });

    test('CLAIM ALL claims everything unlocked', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.lifetimeEarnings = 2e6; // earn_1m + secret_pizza
      game.clickMine(playSound: false);
      expect(game.unclaimedAchievements, greaterThanOrEqualTo(2));

      final n = game.claimAllAchievements();
      expect(n, greaterThanOrEqualTo(2));
      expect(game.unclaimedAchievements, 0);
      expect(game.notorietyBonus, greaterThan(0)); // earn_1m (normal) claimed
    });

    test('unlocked + claimed state persists across a reload', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.lifetimeEarnings = 2e6;
      game.clickMine(playSound: false);
      game.claimAchievement('earn_1m');
      expect(game.isAchievementClaimed('earn_1m'), true);

      await game.loadGame(); // same fake repo
      expect(game.isAchievementUnlocked('earn_1m'), true);
      expect(game.isAchievementClaimed('earn_1m'), true, reason: 'claim persists');
      expect(game.notorietyBonus, greaterThan(0));
    });

    test('action counters round-trip across a reload', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.lifetimeEarnings = 2e9;
      game.hardFork();
      game.lifetimeEarnings = 1.6e10;
      game.softFork();
      expect(game.hardForkCount, 1);
      expect(game.softForkCount, 1);
      await game.loadGame();
      expect(game.hardForkCount, 1);
      expect(game.softForkCount, 1);
    });

    test('achievements survive prestige but a full wipe clears them', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.lifetimeEarnings = 2e6;
      game.clickMine(playSound: false);
      game.claimAchievement('earn_1m');

      game.lifetimeEarnings = 2e9;
      game.hardFork();
      expect(game.isAchievementClaimed('earn_1m'), true,
          reason: 'claimed achievements persist across prestige');

      await game.resetGame();
      expect(game.isAchievementUnlocked('earn_1m'), false);
      expect(game.isAchievementClaimed('earn_1m'), false);
      expect(game.hardForkCount, 0);
      expect(game.notorietyBonus, 0.0);
    });

    test('a pre-claim save grandfathers unlocked -> claimed (no income lost)',
        () async {
      // Save with unlocked achievements but no claimedAchievements key.
      final repo = FakeGameRepository();
      repo.data
        ..['achievements'] = ['earn_1m', 'secret_pizza']
        ..remove('claimedAchievements');
      final game = GameLogic(
        gameRepository: repo,
        settingsRepository: FakeSettingsRepository(),
        economyService: EconomyService(),
        stashService: StashService(),
        soundService: FakeSoundService(),
        startTimers: false,
        loadOnStart: false,
      );
      await game.loadGame();

      expect(game.isAchievementClaimed('earn_1m'), true,
          reason: 'migrated to claimed so Notoriety is preserved');
      expect(game.notorietyBonus, greaterThan(0));
      expect(game.unclaimedAchievements, 0);
    });

    test('loading a satisfied state grandfathers achievements SILENTLY (unclaimed)',
        () async {
      final repo = FakeGameRepository();
      repo.data['lifetimeEarnings'] = 2e6;
      final sound = FakeSoundService();
      final game = GameLogic(
        gameRepository: repo,
        settingsRepository: FakeSettingsRepository(),
        economyService: EconomyService(),
        stashService: StashService(),
        soundService: sound,
        startTimers: false,
        loadOnStart: false,
      );
      await game.loadGame();

      expect(game.isAchievementUnlocked('earn_1m'), true);
      expect(game.pendingAchievementToasts, isEmpty);
      expect(sound.unlockCount, 0);
      // Newly discovered on load are claimable (a fresh save had no achievements).
      expect(game.isAchievementClaimable('earn_1m'), true);
    });
  });

  group('AchievementManager', () {
    test('Notoriety counts CLAIMED non-secret only; bounded by catalogue', () {
      final m = AchievementManager();
      m.load(kAchievements.map((a) => a.id)); // unlock everything
      expect(m.notorietyBonus, 0.0, reason: 'unlocked but unclaimed = no bonus');

      m.claimAll();
      final nonSecret = kAchievements.where((a) => !a.secret).length;
      expect(m.notorietyBonus,
          closeTo(nonSecret * GameConstants.perAchievementNotoriety, 1e-9));
    });
  });

  group('Reachability', () {
    // lifetimeEarnings is a PER-ERA counter, hard-clamped to maxSupplySats and
    // reset by every prestige. Any earnings achievement whose threshold exceeds
    // the cap can never unlock (this caught earn_1q at 1e16 > 2.1e15).
    AchStats statsAtCap() => AchStats(
          lifetimeEarnings: GameConstants.maxSupplySats,
          lifetimeEverSats: GameConstants.maxSupplySats,
          totalGovTokensEver: 0,
          govTokens: 0,
          consensus: 0,
          genesisBlocks: 0,
          totalRigs: 0,
          rigTypesOwned: 0,
          rigTypesTotal: 0,
          researchCompleted: 0,
          researchTotal: 0,
          perkLevels: 0,
          stashDiscovered: 0,
          stashTotal: 0,
          chips: 0,
          hardForkCount: 0,
          softForkCount: 0,
          newChainCount: 0,
          cratesOpened: 0,
          casinoSpins: 0,
          casinoJackpots: 0,
          eraHalvings: 0,
          globalHashRate: 0,
          prestigeMultiplier: 1.0,
          achievementsUnlocked: 0,
          ownsArtifact: (_) => false,
          totalMasteryLevel: 0,
          masteredClassCount: 0,
          classMasteryLevel: (_) => 0,
          winCount: 0,
          inSandbox: false,
        );

    test('every earnings achievement is satisfiable at the per-era cap', () {
      final stats = statsAtCap();
      final earnings =
          kAchievements.where((a) => a.category == AchCategory.earnings);
      for (final a in earnings) {
        expect(a.condition(stats), true,
            reason:
                '${a.id} requires more than maxSupplySats and can never unlock');
      }
    });
  });
}
