import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/services/stash_service.dart';

void main() {
  group('StashService', () {
    late StashService stash;

    setUp(() {
      stash = StashService();
    });

    test('Initial State is empty', () {
      expect(stash.ownedArtifacts, isEmpty);
      expect(stash.getClickPowerMultiplier(), 1.0);
      expect(stash.getTotalHashBonus(), 1.0);
      // Only 5.0% cap minimum is tested in economy, but stash returns discount sum.
      expect(stash.getMainCostDiscount(), 0.0);
    });

    test('Load Stash populates artifacts', () {
      // Use any string ID for generic load test, but calculations need valid IDs
      stash.loadStash({
        'artifacts': {'satoshi_whitepaper': 2, 'old_hdd': 1},
      });

      expect(stash.ownedArtifacts['satoshi_whitepaper'], 2);
      expect(stash.ownedArtifacts['old_hdd'], 1);
    });

    test('Click Power Multiplier Calculation', () {
      // 'satoshi_whitepaper' gives +100% click power (x2.0)
      stash.loadStash({
        'artifacts': {'satoshi_whitepaper': 1},
      });
      // 1.0 + (1 * 1.0) = 2.0
      expect(stash.getClickPowerMultiplier(), 2.0);

      // Stack: 2 papers -> x3.0
      stash.loadStash({
        'artifacts': {'satoshi_whitepaper': 2},
      });
      expect(stash.getClickPowerMultiplier(), 3.0);
    });

    test('Hash Rate Bonus Calculation', () {
      // 'old_hdd' gives +2% hash rate
      stash.loadStash({
        'artifacts': {'old_hdd': 1},
      });
      expect(stash.getTotalHashBonus(), 1.02);

      // Stack: 10 hdd -> 1.20 (20%)
      stash.loadStash({
        'artifacts': {'old_hdd': 10},
      });
      expect(stash.getTotalHashBonus(), closeTo(1.20, 0.001));
    });

    test('Cost Discount Calculation', () {
      // 'usb_fan' gives 1% discount
      stash.loadStash({
        'artifacts': {'usb_fan': 1},
      });
      expect(stash.getMainCostDiscount(), 0.01);

      // Stack: 5 fans -> 5%
      stash.loadStash({
        'artifacts': {'usb_fan': 5},
      });
      expect(stash.getMainCostDiscount(), 0.05);
    });

    test('Open Crate adds artifacts', () {
      // Can't easily deterministic test random drops without mocking Random or high volumes.
      // We check that inventory grows.

      stash.openCrate(isPremium: false);

      // Should have at least one artifact now
      int totalItems = stash.ownedArtifacts.values.fold(0, (a, b) => a + b);
      expect(totalItems, greaterThan(0));
    });

    test('Premium Crate gives better/more loot', () {
      // Premium gives 3 rolls.
      stash.openCrate(isPremium: true);
      int totalItems = stash.ownedArtifacts.values.fold(0, (a, b) => a + b);
      expect(totalItems, greaterThanOrEqualTo(1));
    });

    test('Save Stash returns correct map', () {
      stash.loadStash({
        'artifacts': {'satoshi_whitepaper': 1},
      });
      final map = stash.saveStash();
      expect(map['artifacts']['satoshi_whitepaper'], 1);
    });
  });
}
