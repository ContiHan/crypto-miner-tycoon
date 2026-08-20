import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/constants.dart';
import 'package:crypto_miner_tycoon/core/ids.dart';
import 'package:crypto_miner_tycoon/logic/channels.dart';
import 'package:crypto_miner_tycoon/logic/managers/class_manager.dart';
import 'package:crypto_miner_tycoon/logic/managers/mining_manager.dart';
import 'package:crypto_miner_tycoon/models/news_event.dart';
import 'package:crypto_miner_tycoon/providers/game_logic.dart';
import 'package:crypto_miner_tycoon/services/economy_service.dart';
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

    test('offline TECH node raises the fraction; a parity keystone hard-caps at 1.0',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.researchNodes
          .firstWhere((n) => n.id == ResearchIds.coldStorageLogistics)
          .isCompleted = true; // offline +0.15 -> 0.85
      expect(game.offlineFraction, closeTo(0.85, 1e-9));
      // Own the Foundry capstone → equip Low Time Preference (forces offline
      // parity), which clamps the fraction to its 1.0 cap.
      game.researchNodes
          .firstWhere((n) => n.id == ResearchIds.centralBank)
          .isCompleted = true;
      game.toggleKeystone('ks_low_time_preference');
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

  group('PRESTIGE WEIGHT attribute (prestige gain)', () {
    test('neutral (1.0) with no prestige sources', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      expect(game.consensusWeightMultiplier, closeTo(1.0, 1e-9));
      expect(game.prestigeGainMultiplier, closeTo(1.0, 1e-9)); // Prospector ×1.0
    });

    test('prestige TECH nodes raise GovToken GAIN', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.lifetimeEarnings = 2e13; // sqrt(4e4)=200 GT at gain 1.0
      final baseGT = game.pendingGovTokens; // 200

      // The Central Bank capstone grants prestige +0.25 → consensusWeightMultiplier
      // = softcap(1.25,1,0.5) = sqrt(1.25) ≈ 1.118; a large base guarantees the
      // 11.8% bump crosses the integer floor (200→223).
      game.researchNodes
          .firstWhere((n) => n.id == ResearchIds.centralBank)
          .isCompleted = true;
      expect(game.consensusWeightMultiplier, greaterThan(1.0));
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
          .firstWhere((n) => n.id == ResearchIds.centralBank)
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

  group('Luck decouple (NONCE PRECISION / WHALE\'S FAVOR / UTXO MAGNETISM)', () {
    test('facets are independent; shared luck lifts all three', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      final baseCrit = game.critLuckMultiplier;
      final baseSweep = game.sweepLuckMultiplier;
      final baseAnom = game.anomalyLuckMultiplier;
      expect(baseCrit, closeTo(baseSweep, 1e-9));
      expect(baseCrit, closeTo(baseAnom, 1e-9)); // all equal with no sources

      // A crit-luck (nonce) source lifts ONLY crit luck.
      game.researchNodes
          .firstWhere((n) => n.id == ResearchIds.noncePrediction)
          .isCompleted = true;
      expect(game.critLuckMultiplier, greaterThan(baseCrit));
      expect(game.sweepLuckMultiplier, closeTo(baseSweep, 1e-9));
      expect(game.anomalyLuckMultiplier, closeTo(baseAnom, 1e-9));

      // Pool's shared luck + SWEEP lean lifts SWEEP most, but shared luck also
      // lifts the others above their bare base.
      game.debugSelectClass(BtcClass.poolMember); // luck +0.10 shared, sweep +0.10
      expect(game.sweepLuckMultiplier, greaterThan(game.anomalyLuckMultiplier));
      expect(game.anomalyLuckMultiplier, greaterThan(baseAnom)); // shared luck
    });
  });

  group('IDLE CAPACITY attribute (offline window)', () {
    test('base 8h, extends with idle sources, hard-caps at 24h', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      expect(game.idleCapacitySeconds, closeTo(8 * 3600, 1e-6));
      game.researchNodes
          .firstWhere((n) => n.id == ResearchIds.coldStorageLogistics)
          .isCompleted = true; // idle +8h -> 16h
      expect(game.idleCapacitySeconds, closeTo(16 * 3600, 1e-6));
      // Own the Golden Nonce capstone → Cold Wallet Discipline (idle ×2): 32h,
      // clamped to the 24h cap.
      game.researchNodes
          .firstWhere((n) => n.id == ResearchIds.powerCapacitors)
          .isCompleted = true;
      game.toggleKeystone('ks_cold_wallet_discipline');
      expect(game.idleCapacitySeconds, closeTo(24 * 3600, 1e-6));
    });

    test('an absence longer than the window banks only the window', () async {
      Future<double> offlineForGap(Duration gap) async {
        final repo = FakeGameRepository();
        repo.data.addAll({
          'rigs': [
            {'id': 'cpu_rig', 'amount': 10},
          ],
          'last_save_time':
              DateTime.now().subtract(gap).millisecondsSinceEpoch,
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
        return game.offlineEarningsAmount ?? 0;
      }

      final off4h = await offlineForGap(const Duration(hours: 4));
      final off8h = await offlineForGap(const Duration(hours: 8));
      final off48h = await offlineForGap(const Duration(hours: 48));

      expect(off4h, greaterThan(0));
      // 4h is under the 8h base window → not capped, so it earns less than 8h.
      expect(off4h, lessThan(off8h));
      // 48h is clamped to the same 8h window → identical to the 8h absence.
      expect(off48h, closeTo(off8h, off8h * 1e-6));
    });
  });

  group('Resistance suite (Phase 2)', () {
    test('resistance getters clamp to their per-lever caps', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      expect(game.crashResistance, 0.0);
      // Hardened Vault node (crashResist +0.25) + Pool racial (+0.10) = 0.35.
      game.debugSelectClass(BtcClass.poolMember);
      game.researchNodes
          .firstWhere((n) => n.id == ResearchIds.hardenedVault)
          .isCompleted = true;
      expect(game.crashResistance, closeTo(0.35, 1e-9));
      expect(game.durationResistance, closeTo(0.10, 1e-9)); // Pool racial only
    });

    test('Diamond Hands softens a crash; Steel Nerves shortens it', () {
      // Unresisted crash: income x0.5 for 100s.
      var r = GameLogic.applyEventResistances(
          EventType.marketCrash, 0.5, 1.0, 100,
          crashR: 0.0, costR: 0.0, durR: 0.0);
      expect(r.$1, closeTo(0.5, 1e-9));
      expect(r.$3, 100);
      // Diamond 0.70: drop 0.5 -> 0.5*0.3 = 0.15 -> income x0.85 (crash softened).
      r = GameLogic.applyEventResistances(EventType.marketCrash, 0.5, 1.0, 100,
          crashR: 0.70, costR: 0.0, durR: 0.0);
      expect(r.$1, closeTo(0.85, 1e-9));
      // Steel Nerves 0.60 alone: duration 100 -> 40.
      r = GameLogic.applyEventResistances(EventType.marketCrash, 0.5, 1.0, 100,
          crashR: 0.0, costR: 0.0, durR: 0.60);
      expect(r.$3, 40);
    });

    test('combined crash mitigation never exceeds 0.70 (always lands >=30%)', () {
      // Max both levers: magnitude 0.70 + duration 0.60. Naively that would be
      // 1-(0.30*0.40)=0.88 mitigation; the cap must pull it back to <=0.70.
      final r = GameLogic.applyEventResistances(
          EventType.marketCrash, 0.5, 1.0, 100,
          crashR: 0.70, costR: 0.0, durR: 0.60);
      final incomeMult = r.$1; // 1 - 0.5*remainMag ; remainMag = 0.30
      final durationRemain = r.$3 / 100.0;
      // total impact remaining = magnitudeRemaining * durationRemaining
      final magnitudeRemaining = (1 - incomeMult) / 0.5; // = remainMag
      final totalImpactRemaining = magnitudeRemaining * durationRemain;
      expect(totalImpactRemaining, greaterThanOrEqualTo(0.30 - 1e-9),
          reason: 'a crash must always cost >= 30% of its base impact');
    });

    test('Steel Nerves does NOTHING to a hack (value-only event)', () {
      final r = GameLogic.applyEventResistances(EventType.hack, 1.0, 1.0, 45,
          crashR: 0.70, costR: 0.70, durR: 0.60);
      expect(r.$1, 1.0);
      expect(r.$2, 1.0);
      expect(r.$3, 45); // untouched
    });

    test('Fee Hedge softens a cost spike surcharge', () {
      final r = GameLogic.applyEventResistances(EventType.costSpike, 1.0, 1.5, 120,
          crashR: 0.0, costR: 0.60, durR: 0.0);
      // surcharge 0.5 * (1-0.60) = 0.20 -> cost x1.20.
      expect(r.$2, closeTo(1.20, 1e-9));
    });

    test('THE POWER BILL skims the wallet only, never lifetime/supply (#15)',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.rigs.firstWhere((r) => r.id == 'cpu_rig').amount = 5000; // real load
      expect(game.upkeepRate, greaterThan(0.03));
      expect(game.upkeepRate, lessThanOrEqualTo(GameConstants.upkeepCap));

      final lifeBefore = game.lifetimeEarnings;
      final walletBefore = game.wallet;
      final net = game.advanceForTest(1); // returns the spendable (net) gain
      final gross = game.lifetimeEarnings - lifeBefore;
      final walletGain = game.wallet - walletBefore;

      expect(walletGain, closeTo(net, net * 1e-6));
      // Wallet got LESS than the gross (upkeep skim); lifetime got the FULL gross.
      expect(gross, greaterThan(walletGain));
      expect(walletGain, closeTo(gross * game.netIncomeFraction, gross * 1e-6));
    });

    test('upkeep is 0 with no fleet, rises with load, capped, class-nudged',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      expect(game.upkeepRate, 0.0); // no rigs owned
      game.rigs.firstWhere((r) => r.id == 'singularity_rig').amount = 100000;
      expect(game.upkeepRate, lessThanOrEqualTo(GameConstants.upkeepCap));
      game.debugSelectClass(BtcClass.corporation);
      final corp = game.upkeepRate;
      game.debugSelectClass(BtcClass.soloMiner);
      final solo = game.upkeepRate;
      expect(corp, greaterThan(solo), reason: 'Corp pays more upkeep than Solo');
    });

    test('THE BREACH: first is a 0-loss drill, then steals HOT wallet only', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      final chipsBefore = game.chips;
      final lifeBefore = game.lifetimeEarnings;

      // First breach of the save = a 0-loss DRILL.
      game.wallet = 1000;
      game.debugStartBreach();
      expect(game.breachPending, true);
      game.resolveBreach(secured: false);
      expect(game.wallet, 1000, reason: 'first breach is a drill');
      expect(game.breachPending, false);

      // Second breach: 10% of the hot wallet (no Cold Storage yet).
      game.wallet = 1000;
      game.debugStartBreach();
      game.resolveBreach(secured: false);
      expect(game.wallet, closeTo(1000 * (1 - GameConstants.breachBaseLoss), 1e-6));
      // NEVER touches permanent progress.
      expect(game.chips, chipsBefore);
      expect(game.lifetimeEarnings, lifeBefore);
    });

    test('THE BREACH: SECURE fully vaults; Cold Storage cuts the loss', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      // Spend the drill.
      game.wallet = 1000;
      game.debugStartBreach();
      game.resolveBreach(secured: false);

      // Tapping SECURE = 0 loss.
      game.wallet = 1000;
      game.debugStartBreach();
      game.secureBreach();
      expect(game.wallet, 1000);

      // Hardened Vault (+0.25 theftResist) → loss uses the 0.75 remaining factor.
      game.researchNodes
          .firstWhere((n) => n.id == ResearchIds.hardenedVault)
          .isCompleted = true;
      expect(game.theftResistance, closeTo(0.25, 1e-9));
      game.wallet = 1000;
      game.debugStartBreach();
      game.resolveBreach(secured: false);
      expect(game.wallet,
          closeTo(1000 - 1000 * GameConstants.breachBaseLoss * 0.75, 1e-6));
    });

    test('Stock-to-Flow lifts a halved reward but never cancels the halving', () {
      final mm = MiningManager();
      mm.blockReward = GameConstants.initialBlockReward / 2; // one halving (f=0.5)
      final baseline = mm.calculateMiningIncome(
          hashRate: 1000, difficulty: 100, prestigeMultiplier: 1, chaosMultiplier: 1,
          lifetimeEarnings: 0);
      final resisted = mm.calculateMiningIncome(
          hashRate: 1000, difficulty: 100, prestigeMultiplier: 1, chaosMultiplier: 1,
          lifetimeEarnings: 0, halvingResist: 0.60);
      final full = mm.calculateMiningIncome(
          hashRate: 1000, difficulty: 100, prestigeMultiplier: 1, chaosMultiplier: 1,
          lifetimeEarnings: 0)
          * 2; // what an un-halved reward (f=1.0) would give
      expect(resisted, greaterThan(baseline)); // softens the cut
      expect(resisted, lessThan(full)); // but never fully cancels it
    });
  });
}
