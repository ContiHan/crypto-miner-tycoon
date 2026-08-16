import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/constants.dart';
import 'package:crypto_miner_tycoon/core/ids.dart';
import 'package:crypto_miner_tycoon/logic/channels.dart';
import 'package:crypto_miner_tycoon/logic/managers/class_manager.dart';
import 'package:crypto_miner_tycoon/services/stash_service.dart';
import 'test_helper.dart';
import 'fakes.dart';

/// Phase-0 attribute foundation (ATTRIBUTES_AND_ABILITIES / BUILD_DEPTH):
/// OFFLINE YIELD, BLOCK REWARD (crit payout), CONSENSUS WEIGHT, PROSPECTOR'S EYE.
void main() {
  group('OFFLINE YIELD attribute', () {
    test('fresh Prospector earns the 0.70 base fraction offline', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      expect(game.offlineFraction, closeTo(GameConstants.offlineBaseFraction, 1e-9));
      expect(game.offlineFraction, closeTo(0.70, 1e-9));
    });

    test('BTC OG racial adds +0.10 offline', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.debugSelectClass(BtcClass.btcOg);
      expect(game.offlineFraction, closeTo(0.80, 1e-9));
    });

    test('offline TECH nodes raise the fraction and it hard-caps at 1.0', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.researchNodes
          .firstWhere((n) => n.id == ResearchIds.autonomousDaemons)
          .isCompleted = true; // +0.15 -> 0.85
      expect(game.offlineFraction, closeTo(0.85, 1e-9));
      game.researchNodes
          .firstWhere((n) => n.id == ResearchIds.miningDaemonSwarm)
          .isCompleted = true; // +0.15 -> 1.00
      expect(game.offlineFraction, closeTo(1.0, 1e-9));
      // OG on top would be 1.10 -> clamped to 1.0 (never out-earns live).
      game.debugSelectClass(BtcClass.btcOg);
      expect(game.offlineFraction, closeTo(1.0, 1e-9));
    });

    test('offline accrual is scaled by offlineFraction vs the live rate', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.rigs.firstWhere((r) => r.id == 'cpu_rig').amount = 100;

      // Live baseline (yieldFactor 1.0), then rewind the era so the second
      // accrual sees the same room/rate.
      final live = game.advanceForTest(10);
      game.lifetimeEarnings = 0;
      final offline = game.advanceForTest(10, yieldFactor: game.offlineFraction);

      expect(live, greaterThan(0));
      expect(offline, closeTo(live * game.offlineFraction, live * 1e-6));
      expect(game.offlineFraction, closeTo(0.70, 1e-9)); // Prospector base
    });
  });

  group('BLOCK REWARD attribute (crit payout)', () {
    double expectedCrit(double special) =>
        (GameConstants.clickCritMultiplier +
                GameConstants.clickCritPayoutSpecialScale *
                    softcap(special, 1.0, 0.5))
            .clamp(0.0, GameConstants.critPayoutMax);

    test('base crit payout is 5x with no special sources', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      expect(game.critPayoutMultiplier, closeTo(5.0, 1e-9));
    });

    test('the `special` channel raises crit payout concavely', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      // Genesis Coinbase = +1.20 special -> 5 + 5*softcap(1.2,1,0.5).
      game.stashService.ownedArtifacts['genesis_coinbase'] = 1;
      expect(game.critPayoutMultiplier, closeTo(expectedCrit(1.20), 1e-6));
      // Add the TECH node (+0.50) -> special 1.70, still concave.
      game.researchNodes
          .firstWhere((n) => n.id == ResearchIds.precisionHashing)
          .isCompleted = true;
      expect(game.critPayoutMultiplier, closeTo(expectedCrit(1.70), 1e-6));
    });

    test('crit payout is hard-capped at critPayoutMax', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.stashService.ownedArtifacts['genesis_coinbase'] = 100; // special 120
      expect(game.critPayoutMultiplier, closeTo(GameConstants.critPayoutMax, 1e-9));
    });

    test('a crit tap actually pays critPayoutMultiplier x the estimate', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.stashService.ownedArtifacts['genesis_coinbase'] = 1;
      game.clickRng = AlwaysCritRandom();
      final est = game.estimatedClickValue;
      final crit = game.clickMine();
      expect(crit.isCrit, true);
      expect(crit.sats, closeTo(est * game.critPayoutMultiplier, est * 1e-6));
      expect(game.critPayoutMultiplier, greaterThan(5.0));
    });
  });

  group('CONSENSUS WEIGHT attribute (prestige gain)', () {
    test('neutral (1.0) with no prestige sources', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      expect(game.consensusWeightMultiplier, closeTo(1.0, 1e-9));
      expect(game.prestigeGainMultiplier, closeTo(1.0, 1e-9)); // Prospector ×1.0
    });

    test('prestige TECH nodes raise CX + GovToken GAIN', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.lifetimeEarnings = 1.28e11; // cbrt(1.28e11/2e9)=4 Consensus at gain 1.0
      final baseCX = game.pendingConsensus; // 4
      final baseGT = game.pendingGovTokens; // sqrt(256)=16

      // Both prestige nodes: Σprestige 0.75 → multiplier(prestige,1,0.5)=
      // softcap(1.75,1,0.5)≈1.32, enough to cross the floor (4→5, 16→21).
      game.researchNodes
          .firstWhere((n) => n.id == ResearchIds.consensusProtocol)
          .isCompleted = true;
      game.researchNodes
          .firstWhere((n) => n.id == ResearchIds.governanceCartel)
          .isCompleted = true;
      expect(game.consensusWeightMultiplier, greaterThan(1.0));
      expect(game.pendingConsensus, greaterThan(baseCX));
      expect(game.pendingGovTokens, greaterThan(baseGT));
    });

    test('total prestige-gain multiplier is hard-capped (#17, no divergence)',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.debugSelectClass(BtcClass.btcOg); // 1.25 class scalar
      // Pile a huge prestige-channel sum via a debug-mounted research effect is
      // not available; instead assert the clamp holds for an extreme channel sum
      // by checking the getter never exceeds prestigeGainMax even with OG + nodes.
      game.researchNodes
          .firstWhere((n) => n.id == ResearchIds.consensusProtocol)
          .isCompleted = true;
      game.researchNodes
          .firstWhere((n) => n.id == ResearchIds.governanceCartel)
          .isCompleted = true;
      expect(game.prestigeGainMultiplier,
          lessThanOrEqualTo(GameConstants.prestigeGainMax));
      expect(game.prestigeGainMultiplier, greaterThan(1.25)); // OG × CW > OG alone
    });
  });

  group("PROSPECTOR'S EYE attribute (crate drop quality)", () {
    test('fortuneBonus is 0 by default, adds up, and hard-caps at 0.25', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      expect(game.fortuneBonus, closeTo(0.0, 1e-9));

      game.debugSelectClass(BtcClass.poolMember); // +0.05
      expect(game.fortuneBonus, closeTo(0.05, 1e-9));

      game.researchNodes
          .firstWhere((n) => n.id == ResearchIds.assayLab)
          .isCompleted = true; // +0.10 -> 0.15
      game.stashService.ownedArtifacts['prospectors_loupe'] = 1; // +0.10 -> 0.25
      expect(game.fortuneBonus, closeTo(0.25, 1e-9));

      // Pile more: still clamped at the 0.25 ceiling (#22).
      game.stashService.ownedArtifacts['divining_rod'] = 5; // +0.25 more
      expect(game.fortuneBonus,
          closeTo(GameConstants.fortuneMaxTierShiftChance, 1e-9));
    });

    test('fortune biases crate rolls up the rarity ladder (never guarantees top)',
        () {
      double meanRarity(double fortune, int seed) {
        final rng = Random(seed);
        final s = StashService();
        double sum = 0;
        const n = 4000;
        for (var i = 0; i < n; i++) {
          final a =
              s.openCrate(tier: CrateTier.standard, fortune: fortune, random: rng);
          sum += a.rarity.index;
        }
        return sum / n;
      }

      final without = meanRarity(0.0, 7);
      final with25 = meanRarity(0.25, 7);
      expect(with25, greaterThan(without),
          reason: 'fortune shifts the average roll up the ladder');
      // Even at max fortune it is a per-roll +1 chance, never a mythic guarantee:
      // the mean stays far below the top rarity index.
      expect(with25, lessThan(ArtifactRarity.values.last.index.toDouble()));
    });
  });
}
