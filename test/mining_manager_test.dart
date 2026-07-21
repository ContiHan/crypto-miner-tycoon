import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/logic/managers/mining_manager.dart';

void main() {
  group('MiningManager Halving Tests', () {
    late MiningManager manager;

    setUp(() {
      manager = MiningManager();
    });

    test('Jump in blocks should process multiple halvings immediately', () {
      // Thresholds: 5000, 15000, 25000, 35000, 45000
      // If we jump to 40000, we passed 5k, 15k, 25k, 35k. (4 halvings)
      // Initial Reward: 50
      // 1: 25
      // 2: 12.5
      // 3: 6.25
      // 4: 3.125

      manager.blocksMined = 40000;

      // This mimics what happens if we load a save or do a huge offline jump without looping checkHalving
      manager.checkHalving();

      // If bug exists, it only halving once (50 -> 25)
      // If fixed, it should be 3.125

      // Assert the FIXED state (so test FAILS now)
      expect(manager.blockReward, closeTo(3.125 * 100000000, 0.1));
      expect(manager.nextHalvingThreshold, 45000);
    });
  });
}
