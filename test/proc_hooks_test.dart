// Slice 73a — broader proc plumbing: the per-window UTXO cap (#25) and the
// ability CD-refund grant. (Firmware affixes that react to the new fork/genesis/
// breach/crit-streak hooks are exercised in 73b once the affix pool exists.)
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/constants.dart';
import 'package:crypto_miner_tycoon/logic/systems/ability_system.dart';
import 'test_helper.dart';

void main() {
  group('Per-window UTXO cap (#25)', () {
    test('grants are clamped to the window budget, then refill next window',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.chips = 0;
      // Ask for far more than the cap in one window.
      var granted = 0;
      for (var i = 0; i < 100; i++) {
        granted += game.debugGrantUtxo(1);
      }
      expect(granted, GameConstants.procUtxoWindowCap);
      expect(game.chips, GameConstants.procUtxoWindowCap);
      // A single big request is also clamped to the remaining room (0 here).
      expect(game.debugGrantUtxo(999), 0);
    });

    test('a request larger than the window is clamped to the cap', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.chips = 0;
      expect(game.debugGrantUtxo(999), GameConstants.procUtxoWindowCap);
    });
  });

  group('Ability CD-refund (AbilitySystem.refundCooldowns)', () {
    AbilityDef def(String id) => kAbilities.firstWhere((a) => a.id == id);

    test('shaves the given fraction off remaining cooldown; ready abilities safe',
        () {
      final s = AbilitySystem();
      final spin = def('corp_spin_up'); // 30-min basic cooldown
      const t0 = 1000000;
      s.activate(spin, t0);
      final full = s.cooldownRemainingMs(spin, t0, 0.0);
      expect(full, GameConstants.abilityCdBasic1Ms);
      // Refund 50% of the remaining cooldown.
      s.refundCooldowns(0.5, t0, 0.0);
      final after = s.cooldownRemainingMs(spin, t0, 0.0);
      expect(after, closeTo(full * 0.5, 2));
      // A ready ability (never cast) is untouched by a refund.
      final whale = def('og_whale_order');
      s.refundCooldowns(0.5, t0, 0.0);
      expect(s.isReady(whale, t0, 0.0), true);
    });

    test('a zero/negative fraction is a no-op', () {
      final s = AbilitySystem();
      final spin = def('corp_spin_up');
      const t0 = 2000000;
      s.activate(spin, t0);
      final before = s.cooldownRemainingMs(spin, t0, 0.0);
      s.refundCooldowns(0.0, t0, 0.0);
      expect(s.cooldownRemainingMs(spin, t0, 0.0), before);
    });
  });
}
