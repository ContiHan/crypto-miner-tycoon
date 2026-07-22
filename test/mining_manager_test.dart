import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/logic/managers/mining_manager.dart';

void main() {
  group('MiningManager Halving Tests', () {
    late MiningManager manager;

    setUp(() {
      manager = MiningManager();
    });

    test('Jump in blocks processes multiple halvings (doubling thresholds)', () {
      // Thresholds now DOUBLE each halving: 15000, 30000, 60000, 120000, ...
      // Jumping to 120000 crosses 15k, 30k, 60k, 120k => 4 halvings.
      // Reward: 50 -> 25 -> 12.5 -> 6.25 -> 3.125
      manager.blocksMined = 120000;

      // Mimics a save load / big offline jump processed in one call.
      manager.checkHalving();

      expect(manager.blockReward, closeTo(3.125 * 100000000, 0.1));
      // After crossing 120000, the next threshold has doubled to 240000.
      expect(manager.nextHalvingThreshold, 240000);
    });

    test('single halving at the first threshold', () {
      manager.blocksMined = 15000;
      final halved = manager.checkHalving();
      expect(halved, true);
      expect(manager.blockReward, closeTo(25 * 100000000, 0.1));
      expect(manager.nextHalvingThreshold, 30000);
    });
  });
}
