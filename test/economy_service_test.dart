import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/services/economy_service.dart';
import 'package:crypto_miner_tycoon/models/rig.dart';
import 'package:crypto_miner_tycoon/core/ids.dart';

void main() {
  group('EconomyService', () {
    final economy = EconomyService();

    test('recalculateSpentTokens uses each perk\'s real base cost', () {
      // clickPower base 5, level 3 -> (3/2)*(2*5 + 2*5) = 30
      expect(economy.recalculateSpentTokens({PerkIds.clickPower: 3}), 30);
      // corp_hyperscale base 200, level 2 -> (2/2)*(2*200 + 1*5) = 405
      expect(economy.recalculateSpentTokens({'corp_hyperscale': 2}), 405);
    });

    test('calculatePrestigeMultiplier returns 1.0 for 0 tokens', () {
      expect(economy.calculatePrestigeMultiplier(0, 0), 1.0);
    });

    test(
      'calculatePrestigeMultiplier is concave in token count (0.5*sqrt)',
      () {
        // Concave (0.5*sqrt) so the endgame can't run away: 4 tokens ->
        // 1 + 0.5*sqrt(4) = 2.0x.
        expect(economy.calculatePrestigeMultiplier(4, 0), 2.0);
        expect(economy.calculatePrestigeMultiplier(2, 2), 2.0); // held + spent
        // 100 tokens -> 1 + 0.5*sqrt(100) = 6.0x (grows sub-linearly).
        expect(economy.calculatePrestigeMultiplier(100, 0), 6.0);
      },
    );

    Rig testRig() =>
        Rig(id: 'test', name: 'Test', baseCost: 100, baseHashRate: 10);

    test('calculateRigCost applies an additive discount fraction', () {
      // 10% discount -> 100 * 0.9 = 90
      expect(economy.calculateRigCost(testRig(), 0.10, 1.0), 90.0);
      // 15% discount -> 85
      expect(economy.calculateRigCost(testRig(), 0.15, 1.0), 85.0);
    });

    test('calculateRigCost enforces the 95% max discount (Anti-Free Bug)', () {
      // Any discount >= 95% clamps to a 5% cost floor.
      expect(economy.calculateRigCost(testRig(), 0.90, 1.0), closeTo(10.0, 1e-9));
      expect(economy.calculateRigCost(testRig(), 1.0, 1.0), 5.0);
      expect(economy.calculateRigCost(testRig(), 2.5, 1.0), 5.0);
    });

    test('calculateRigCost applies the chaos cost multiplier', () {
      expect(economy.calculateRigCost(testRig(), 0.0, 0.5), 50.0);
    });

    test('calculateRigCost floors the FINAL product at 5% of base (#6)', () {
      // The channel discount alone is capped at 95% off (factor 0.05), but
      // stacking that with CHEAP ENERGY (x0.7) and a future ability (x0.5) would
      // reach ~1.75% of base. The product of ALL cost multipliers is clamped to
      // 0.05 so a rig can never cost less than 5% of its sticker price.
      // 95% channel discount x CHEAP ENERGY 0.7 -> would be 0.035, floored to 0.05.
      expect(economy.calculateRigCost(testRig(), 1.0, 0.7), 5.0);
      // 95% discount x CHEAP ENERGY 0.7 x ability 0.5 -> would be 0.0175, floored.
      expect(
        economy.calculateRigCost(testRig(), 1.0, 0.7, abilityCostMultiplier: 0.5),
        5.0,
      );
      // A mild stack that stays above the floor is untouched:
      // 20% discount (0.8) x CHEAP ENERGY 0.7 = 0.56 -> 56.0.
      expect(economy.calculateRigCost(testRig(), 0.20, 0.7), closeTo(56.0, 1e-9));
      // COST SPIKE never triggers the floor (it raises price).
      expect(economy.calculateRigCost(testRig(), 0.0, 1.5), 150.0);
    });
  });
}
