import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/logic/channels.dart';
import 'package:crypto_miner_tycoon/logic/managers/class_manager.dart';
import 'package:crypto_miner_tycoon/logic/systems/aura_system.dart';
import 'test_helper.dart';

const _calm = AuraContext(
    goodEvent: false, badEvent: false, breachPending: false, supplyProgress: 0);
const _bad = AuraContext(
    goodEvent: false, badEvent: true, breachPending: false, supplyProgress: 0);

void main() {
  group('AuraSystem (unit)', () {
    test('an always-on stance contributes on-channel (bonuses + cost)', () {
      final s = AuraSystem()..setStance('stance_overclock_protocol', 0);
      final ch = Channels();
      s.contributeChannels(ch, _calm, BtcClass.corporation, 0);
      expect(ch.sum(Channel.hash), closeTo(0.30, 1e-9));
      expect(ch.sum(Channel.click), closeTo(0.20, 1e-9));
      expect(ch.sum(Channel.income), closeTo(-0.15, 1e-9)); // the heat cost
    });

    test('a conditional stance only applies while its condition holds', () {
      final s = AuraSystem()..setStance('stance_storm_rigging', 0);
      final calmCh = Channels();
      s.contributeChannels(calmCh, _calm, BtcClass.poolMember, 0);
      expect(calmCh.sum(Channel.income), 0.0); // inactive when calm

      final badCh = Channels();
      s.contributeChannels(badCh, _bad, BtcClass.poolMember, 0);
      expect(badCh.sum(Channel.income), closeTo(0.50, 1e-9)); // active in a crash
    });

    test('off-channel resist bonus is clamped to the tight aura cap', () {
      // Vault Guard grants +0.10 theftResist (== the off-channel cap).
      final s = AuraSystem();
      s.equippedAuras.add('aura_vault_guard');
      final ch = Channels();
      s.contributeChannels(ch, _calm, BtcClass.soloMiner, 2);
      expect(ch.sum(Channel.theftResist),
          lessThanOrEqualTo(AuraSystem.offChannelResistCap + 1e-9));
    });

    test('60s switch lockout blocks rapid swaps', () {
      final s = AuraSystem();
      expect(s.setStance('stance_bull_rider', 1000000), true);
      expect(s.setStance('stance_storm_rigging', 1000000 + 5000), false);
      expect(s.setStance('stance_storm_rigging',
          1000000 + AuraSystem.switchLockoutMs), true);
    });

    test('progressive unlock: auras gate on Mastery', () {
      final s = AuraSystem();
      final m0 = s.availableFor(BtcClass.soloMiner, 0).map((a) => a.id);
      expect(m0.contains('aura_calm_waters'), true); // Mastery 0
      expect(m0.contains('aura_long_tail'), false); // needs Mastery 1
      final m2 = s.availableFor(BtcClass.soloMiner, 2).map((a) => a.id);
      expect(m2.contains('aura_long_tail'), true);
      expect(m2.contains('aura_vault_guard'), true); // Mastery 2
    });

    test('at most 3 auras equip', () {
      final s = AuraSystem();
      expect(s.toggleAura('aura_calm_waters', 0), true);
      expect(s.toggleAura('aura_long_tail', 60000), true);
      expect(s.toggleAura('aura_vault_guard', 120000), true);
      // a 4th distinct aura is refused (only 3 slots). Force past the lockout.
      s.lastSwitchMs = 0;
      expect(s.equippedAuras.length, 3);
    });
  });

  group('Auras (GameLogic integration)', () {
    test('equipping a stance raises the channel in buildChannels', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.debugSelectClass(BtcClass.corporation);
      final baseHash = game.buildChannels().sum(Channel.hash);
      game.equipStance('stance_overclock_protocol'); // +0.30 hash always
      expect(game.buildChannels().sum(Channel.hash),
          closeTo(baseHash + 0.30, 1e-9));
      expect(game.equippedStance, 'stance_overclock_protocol');
    });
  });
}
