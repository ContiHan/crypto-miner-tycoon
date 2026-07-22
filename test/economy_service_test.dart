import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/services/economy_service.dart';
import 'package:crypto_miner_tycoon/models/rig.dart';

void main() {
  group('EconomyService', () {
    final economy = EconomyService();

    test('calculatePrestigeMultiplier returns 1.0 for 0 tokens', () {
      expect(economy.calculatePrestigeMultiplier(0, 0), 1.0);
    });

    test(
      'calculatePrestigeMultiplier returns correct bonus (10% per token)',
      () {
        // 10 tokens = 100% bonus -> 2.0x multiplier
        expect(economy.calculatePrestigeMultiplier(10, 0), 2.0);
        expect(economy.calculatePrestigeMultiplier(5, 5), 2.0); // Held + Spent
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
