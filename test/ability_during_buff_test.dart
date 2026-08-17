// ignore_for_file: avoid_print
// Slice 72a — the DURING-BUFF state effects of abilities (the fields existed on
// AbilityDef since Slice 5; this is the consumption wiring): LUCKY NONCE luck ×3
// + anomaly burst, POOL LUCK sweep-luck pin, BLOCK RACE auto-taps, and crash-
// immunity (suppressNegatives) folded into the chaos roll.
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/logic/managers/class_manager.dart';
import 'package:crypto_miner_tycoon/logic/systems/anomaly_system.dart';
import 'package:crypto_miner_tycoon/logic/systems/chaos_event_system.dart';
import 'package:crypto_miner_tycoon/models/news_event.dart';
import 'test_helper.dart';

void main() {
  group('AnomalySystem.forceSpawn (unit)', () {
    test('a forced burst is delivered one at a time and drains on collect', () {
      var collected = 0;
      final a = AnomalySystem(onChanged: () {}, onCollect: () => collected++);
      a.forceSpawn(3);
      // One is shown immediately, the other two queue behind it.
      expect(a.active, true);
      expect(a.forcedQueueLength, 2);
      a.collect();
      expect(collected, 1);
      expect(a.active, true); // the next of the burst spawned immediately
      expect(a.forcedQueueLength, 1);
      a.collect();
      expect(a.active, true);
      expect(a.forcedQueueLength, 0);
      a.collect();
      expect(a.active, false); // burst spent
      expect(collected, 3);
    });

    test('stop() clears a pending forced burst', () {
      final a = AnomalySystem(onChanged: () {}, onCollect: () {});
      a.forceSpawn(3);
      a.stop();
      expect(a.active, false);
      expect(a.forcedQueueLength, 0);
    });
  });

  group('ChaosEventSystem crash-immunity + bull-bias (unit)', () {
    ChaosEventSystem make({required bool suppress, double bullBias = 0.0}) =>
        ChaosEventSystem(
          onChanged: () {},
          onBreach: () {},
          onAirdropGain: () => 0.0,
          onEventSound: (_) {},
          chaosSteering: () => (suppressNegatives: suppress, bullBias: bullBias),
        );

    test('suppressNegatives: no crash/spike ever lands over many rolls', () {
      final s = make(suppress: true);
      for (var i = 0; i < 400; i++) {
        s.triggerRandom();
        // marketCrash would push income < 1; costSpike would push cost > 1.
        expect(s.incomeMultiplier, greaterThanOrEqualTo(1.0));
        expect(s.costMultiplier, lessThanOrEqualTo(1.0));
        expect(s.currentNews?.type == EventType.marketCrash, isNot(true));
        expect(s.currentNews?.type == EventType.costSpike, isNot(true));
      }
      s.stop();
    });

    test('clearActiveNegative resets a crash but leaves a bull run alone', () {
      final s = make(suppress: false);
      s.incomeMultiplier = 0.5; // an in-progress market crash
      s.clearActiveNegative();
      expect(s.incomeMultiplier, 1.0);
      s.incomeMultiplier = 2.0; // a bull run — a POSITIVE, must survive
      s.clearActiveNegative();
      expect(s.incomeMultiplier, 2.0);
      s.stop();
    });

    test('bullBias never zeroes negatives (they can still roll)', () {
      // With a strong bull bias, negatives are rarer but NOT impossible: over many
      // rolls at least one negative should still slip through.
      final s = make(suppress: false, bullBias: 3.0);
      var sawNegative = false;
      for (var i = 0; i < 2000 && !sawNegative; i++) {
        s.incomeMultiplier = 1.0;
        s.costMultiplier = 1.0;
        s.triggerRandom();
        if (s.incomeMultiplier < 1.0 || s.costMultiplier > 1.0) sawNegative = true;
      }
      expect(sawNegative, true, reason: 'bull bias must not make negatives impossible');
      s.stop();
    });
  });

  group('Abilities during-buff (GameLogic integration)', () {
    test('LUCKY NONCE folds luck ×3 and fires an anomaly burst', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.debugSelectClass(BtcClass.soloMiner);
      game.debugCreditMastery(BtcClass.soloMiner, 40000); // Mastery 2
      final beforeCrit = game.critLuckMultiplier;
      expect(game.abilityLuckBuff, 1.0);
      expect(game.castAbility('solo_lucky_nonce'), true);
      expect(game.abilityLuckBuff, 3.0);
      // Crit-chance luck scales ~×3 (a free crate may add a tiny stash bump).
      expect(game.critLuckMultiplier, greaterThan(beforeCrit * 2.8));
      expect(game.critLuckMultiplier, lessThan(beforeCrit * 3.5));
      // A guaranteed anomaly burst is now on screen.
      expect(game.isAnomalyActive, true);
    });

    test('POOL LUCK pins SWEEP luck to the EV ceiling while active', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.debugSelectClass(BtcClass.poolMember);
      game.debugCreditMastery(BtcClass.poolMember, 40000);
      expect(game.sweepLuckMultiplier, lessThan(100)); // normal combined luck
      expect(game.castAbility('pool_pool_luck'), true);
      expect(game.sweepLuckMultiplier, greaterThan(1e6)); // pinned (casino clamps)
    });

    test('STEADY HANDS turns on crash-immunity', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.debugSelectClass(BtcClass.poolMember);
      expect(game.abilityCrashImmune, false);
      expect(game.castAbility('pool_steady_hands'), true); // basic1
      expect(game.abilityCrashImmune, true);
    });

    test('BLOCK RACE auto-taps credit income on the tick (no rigs, isolated)',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.debugSelectClass(BtcClass.soloMiner);
      game.debugCreditMastery(BtcClass.soloMiner, 60000); // Mastery 2 -> ult open
      // No rigs => globalHashRate 0 => the passive accrual half of the tick is a
      // no-op, so any wallet growth is purely the auto-taps.
      final before = game.wallet;
      game.debugTick();
      expect(game.wallet, before, reason: 'no auto-taps before BLOCK RACE');
      expect(game.castAbility('solo_block_race'), true);
      game.debugTick();
      expect(game.wallet, greaterThan(before),
          reason: 'BLOCK RACE fires guaranteed-crit auto-taps each tick');
    });
  });
}
