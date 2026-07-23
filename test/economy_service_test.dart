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
      // megaIncome base 500, level 2 -> (2/2)*(2*500 + 1*5) = 1005
      // (was under-counted to 25 by the old hardcoded base of 10)
      expect(economy.recalculateSpentTokens({PerkIds.megaIncome: 2}), 1005);
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
  });
}
