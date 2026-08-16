import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/constants.dart';
import 'package:crypto_miner_tycoon/logic/channels.dart';
import 'package:crypto_miner_tycoon/logic/managers/class_manager.dart';
import 'package:crypto_miner_tycoon/logic/systems/ability_system.dart';
import 'test_helper.dart';

void main() {
  group('AbilitySystem (unit)', () {
    AbilityDef def(String id) => kAbilities.firstWhere((a) => a.id == id);

    test('progressive unlock: basic1 on pick, basic2 @M1, ult @M2', () {
      final s = AbilitySystem();
      // Solo, Mastery 0.
      expect(s.isUnlocked(def('solo_overclock'), BtcClass.soloMiner, 0), true);
      expect(s.isUnlocked(def('solo_lucky_nonce'), BtcClass.soloMiner, 0), false);
      expect(s.isUnlocked(def('solo_block_race'), BtcClass.soloMiner, 0), false);
      // Mastery 1 unlocks basic2; Mastery 2 unlocks the ult.
      expect(s.isUnlocked(def('solo_lucky_nonce'), BtcClass.soloMiner, 1), true);
      expect(s.isUnlocked(def('solo_block_race'), BtcClass.soloMiner, 1), false);
      expect(s.isUnlocked(def('solo_block_race'), BtcClass.soloMiner, 2), true);
      // Never unlocked for another class.
      expect(s.isUnlocked(def('solo_overclock'), BtcClass.corporation, 5), false);
    });

    test('haste shortens cooldowns, capped + floored', () {
      final s = AbilitySystem();
      final b1 = def('corp_spin_up'); // basic, 30 min
      expect(s.effectiveCooldownMs(b1, 0.0), GameConstants.abilityCdBasic1Ms);
      // 20% haste -> 24 min.
      expect(s.effectiveCooldownMs(b1, 0.2),
          (GameConstants.abilityCdBasic1Ms * 0.8).round());
      // Over-cap haste clamps to 0.40 -> 30min×0.6 = 18 min = the basic floor.
      expect(s.effectiveCooldownMs(b1, 0.9),
          GameConstants.abilityCdFloorBasicMs);
      // Ultimate at max haste: 22h×0.6 = 13.2h, which stays ABOVE the 13h floor
      // (so the reduced value applies; the floor is a safety for shorter CDs).
      final ult = def('corp_hostile_takeover');
      expect(s.effectiveCooldownMs(ult, 0.9),
          (GameConstants.abilityCdUltimateMs * 0.6).round());
      expect(s.effectiveCooldownMs(ult, 0.9),
          greaterThan(GameConstants.abilityCdFloorUltMs));
    });

    test('activate sets cooldown + a temp buff that expires', () {
      final s = AbilitySystem();
      final spin = def('corp_spin_up'); // hash ×2.5 for 90s
      const t0 = 1000000;
      expect(s.isReady(spin, t0, 0), true);
      s.activate(spin, t0);
      expect(s.isReady(spin, t0, 0), false);
      expect(s.tempMult(Channel.hash, t0 + 1000), 2.5);
      // After the 90s window it's gone; still on cooldown though.
      expect(s.tempMult(Channel.hash, t0 + 91 * 1000), 1.0);
      // Ready again after the full 30-min cooldown.
      expect(s.isReady(spin, t0 + GameConstants.abilityCdBasic1Ms, 0), true);
    });

    test('SATOSHI MODE resets the two basic cooldowns', () {
      final s = AbilitySystem();
      const t0 = 5000000;
      s.activate(def('og_whale_order'), t0); // basic1
      s.activate(def('og_deep_freeze'), t0); // basic2
      expect(s.isReady(def('og_whale_order'), t0 + 1000, 0), false);
      s.activate(def('og_satoshi_mode'), t0 + 2000); // ult resets basics
      expect(s.isReady(def('og_whale_order'), t0 + 3000, 0), true);
      expect(s.isReady(def('og_deep_freeze'), t0 + 3000, 0), true);
      // ...but the ult itself is now on cooldown.
      expect(s.isReady(def('og_satoshi_mode'), t0 + 3000, 0), false);
    });

    test('lastUsed round-trips (cooldowns persist)', () {
      final s = AbilitySystem();
      s.activate(def('corp_spin_up'), 12345);
      final json = s.lastUsedJson();
      final s2 = AbilitySystem()..loadLastUsed(json);
      expect(s2.lastUsedMs['corp_spin_up'], 12345);
    });
  });

  group('Abilities (GameLogic integration)', () {
    test('cast is gated by class + unlock + cooldown', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      // Prospector: nothing casts.
      expect(game.castAbility('corp_spin_up'), false);

      game.debugSelectClass(BtcClass.corporation);
      expect(game.castAbility('corp_spin_up'), true); // basic1 available on pick
      expect(game.isAbilityReady(
          kAbilities.firstWhere((a) => a.id == 'corp_spin_up')), false);
      // basic2 locked until Mastery 1.
      expect(game.castAbility('corp_capital_injection'), false);
    });

    test('SPIN UP THE FARM multiplies hash by 2.5 while active', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.rigs.firstWhere((r) => r.id == 'cpu_rig').amount = 10;
      game.debugSelectClass(BtcClass.corporation);
      final baseHash = game.globalHashRate;
      expect(game.castAbility('corp_spin_up'), true);
      expect(game.globalHashRate, closeTo(baseHash * 2.5, baseHash * 1e-6));
    });

    test('CAPITAL INJECTION banks an instant income lump', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.rigs.firstWhere((r) => r.id == 'cpu_rig').amount = 50;
      game.debugSelectClass(BtcClass.corporation);
      game.debugCreditMastery(BtcClass.corporation, 40000); // Mastery 2 -> basic2 open
      final before = game.wallet;
      expect(game.castAbility('corp_capital_injection'), true);
      expect(game.wallet, greaterThan(before),
          reason: '30 min of income banked instantly');
    });

    test('OG WHALE ORDER forces a Bull Run (income multiplier jumps)', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.debugSelectClass(BtcClass.btcOg);
      expect(game.chaosIncomeMultiplier, closeTo(1.0, 1e-9));
      expect(game.castAbility('og_whale_order'), true);
      expect(game.chaosIncomeMultiplier, greaterThan(1.5),
          reason: 'Whale Order pumps income ×3');
    });

    test('Solo LUCKY NONCE opens a free crate', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.debugSelectClass(BtcClass.soloMiner);
      game.debugCreditMastery(BtcClass.soloMiner, 40000); // Mastery 2 -> basic2 open
      final crates = game.cratesOpened;
      expect(game.castAbility('solo_lucky_nonce'), true);
      expect(game.cratesOpened, crates + 1);
    });
  });
}
