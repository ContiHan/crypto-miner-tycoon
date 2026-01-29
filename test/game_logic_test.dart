import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto_miner_tycoon/providers/game_logic.dart';

void main() {
  group('GameLogic Tests', () {
    late GameLogic game;

    setUp(() {
      // Mock SharedPreferences
      SharedPreferences.setMockInitialValues({});
      game = GameLogic();
    });

    test('Initial State should be empty', () {
      expect(game.wallet, 0);
      expect(game.lifetimeEarnings, 0);
      expect(game.rigs.every((r) => r.amount == 0), true);
    });

    test('Click Mine should add money', () {
      game.clickMine();
      expect(game.wallet, greaterThan(0));
      expect(game.lifetimeEarnings, greaterThan(0));
    });

    test('Buying a Rig should deduct money and increase amount', () async {
      // Give initial money
      game.wallet = 1000;
      final cpuRigId = 'cpu_rig';
      final initialCost = game.getRigCost(game.rigs.firstWhere((r) => r.id == cpuRigId));

      game.buyRig(cpuRigId);

      expect(game.wallet, 1000 - initialCost);
      expect(game.rigs.firstWhere((r) => r.id == cpuRigId).amount, 1);
    });

    test('Buying Rig without money should fail', () {
      game.wallet = 0;
      final cpuRigId = 'cpu_rig';

      game.buyRig(cpuRigId);

      expect(game.wallet, 0);
      expect(game.rigs.firstWhere((r) => r.id == cpuRigId).amount, 0);
    });

    test('Research Bonus should apply to HashRate', () {
      // Unlock Basic Overclock (+5%)
      // We need to bypass the buyResearch cost check or give money
      game.wallet = 10000;
      
      // Initial hash rate checks would be complex without rigs. 
      // Let's buy a rig first.
      game.buyRig('cpu_rig'); // Base 1 H/s
      
      double hashBefore = game.globalHashRate;
      
      // Buy research
      game.buyResearch('basic_overclock');
      
      double hashAfter = game.globalHashRate; // Should be base * 1.05
      
      expect(hashAfter, greaterThan(hashBefore));
      // 1.0 * 1.05 = 1.05
      expect(hashAfter, closeTo(1.05, 0.001));
    });

    test('Offline Earnings should calculate correctly', () async {
      SharedPreferences.setMockInitialValues({
        'last_save_time': DateTime.now().subtract(const Duration(seconds: 100)).millisecondsSinceEpoch,
        'rigs': '[{"id": "cpu_rig", "amount": 1}]', // 1 CPU rig = 1 H/s
      });

      // reload game to trigger loadGame logic
      final newGame = GameLogic();
      await newGame.loadGame();

      // 1 H/s * 100 seconds = 100 earnings
      // Tolerance for execution time
      expect(newGame.offlineEarningsAmount, closeTo(100, 5));
      expect(newGame.wallet, closeTo(100, 5));
    });

    test('Prestige Multiplier calculation', () {
      game.govTokens = 10;
      // 1.0 + (10 * 0.1) = 2.0
      expect(game.prestigeMultiplier, 2.0);
    });
  });
}
