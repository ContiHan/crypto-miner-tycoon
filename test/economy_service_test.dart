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

    test('calculateRigCost applies correct discount', () {
      final rig = Rig(
        id: 'test',
        name: 'Test',
        baseCost: 100,
        baseHashRate: 10,
      );
      final perks = {'rig_cost': 2}; // 10% discount

      // Cost: 100 * 0.9 = 90
      expect(economy.calculateRigCost(rig, perks, false, 1.0), 90.0);
    });

    test('calculateRigCost respects max perk discount (90%)', () {
      final rig = Rig(
        id: 'test',
        name: 'Test',
        baseCost: 100,
        baseHashRate: 10,
      );
      final perks = {'rig_cost': 50}; // 250% discount (theoretical)

      // Should cap at 90% discount (0.1 multiplier) -> Cost 10
      expect(economy.calculateRigCost(rig, perks, false, 1.0), 10.0);
    });

    test('calculateRigCost applies research discount', () {
      final rig = Rig(
        id: 'test',
        name: 'Test',
        baseCost: 100,
        baseHashRate: 10,
      );

      // 10% Research Discount -> Cost 90
      expect(economy.calculateRigCost(rig, {}, true, 1.0), 90.0);
    });

    test('calculateRigCost applies solar power discount', () {
      final rig = Rig(
        id: 'test',
        name: 'Test',
        baseCost: 100,
        baseHashRate: 10,
      );

      // 15% Solar Discount -> Cost 85
      expect(
        economy.calculateRigCost(
          rig,
          {},
          false,
          1.0,
          isSolarPowerResearched: true,
        ),
        85.0,
      );
    });

    test('calculateRigCost enforces minimum 5% cost cap (Anti-Free Bug)', () {
      final rig = Rig(
        id: 'test',
        name: 'Test',
        baseCost: 100,
        baseHashRate: 10,
      );
      final perks = {'rig_cost': 18}; // 18 * 5 = 90% discount

      // 90% Perk + 10% Research = 100% Discount (0.0 multiplier)
      // Should hit hard cap of 0.05

      // Expected: 100 * 0.05 = 5.0
      expect(economy.calculateRigCost(rig, perks, true, 1.0), 5.0);
    });

    test('calculateRigCost applies chaos multiplier', () {
      final rig = Rig(
        id: 'test',
        name: 'Test',
        baseCost: 100,
        baseHashRate: 10,
      );

      // 50% Chaos Discount
      expect(economy.calculateRigCost(rig, {}, false, 0.5), 50.0);
    });
  });
}
