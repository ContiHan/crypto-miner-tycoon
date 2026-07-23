import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/providers/game_logic.dart';
import 'package:crypto_miner_tycoon/models/rig.dart';

import 'package:crypto_miner_tycoon/services/economy_service.dart';
import 'package:crypto_miner_tycoon/services/stash_service.dart';
import 'package:crypto_miner_tycoon/core/ids.dart';
import 'fakes.dart';

void main() {
  group('GameLogic Tests', () {
    late GameLogic game;

    setUp(() {
      game = GameLogic(
        gameRepository: FakeGameRepository(),
        settingsRepository: FakeSettingsRepository(),
        economyService: EconomyService(),
        stashService: StashService(),
        soundService: FakeSoundService(),
      );
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
      game.wallet = 1000;
      final cpuRigId = 'cpu_rig';
      final initialCost = game.getRigCost(
        game.rigs.firstWhere((r) => r.id == cpuRigId),
      );

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
      game.wallet = 10000;
      game.buyRig('cpu_rig');

      double hashBefore = game.globalHashRate;

      game.buyResearch('basic_overclock');

      double hashAfter = game.globalHashRate;

      expect(hashAfter, greaterThan(hashBefore));
      expect(hashAfter, closeTo(1.05, 0.001));
    });

    test('Research Cost scales with Exchange Rate', () {
      // Base Cost: 500 (Basic Overclock)
      // Rate: 1.0 -> Cost 500 Sats
      game.bitcoinExchangeRate = 1.0;
      double cost1 = game.getResearchCost('basic_overclock');
      expect(cost1, 500.0);

      // Rate: 2.0 -> Cost 250 Sats
      game.bitcoinExchangeRate = 2.0;
      double cost2 = game.getResearchCost('basic_overclock');
      expect(cost2, 250.0);
    });

    test('Offline Earnings should calculate correctly', () async {
      final fakeGameRepo = FakeGameRepository();
      fakeGameRepo.data['last_save_time'] = DateTime.now()
          .subtract(const Duration(seconds: 100))
          .millisecondsSinceEpoch;
      fakeGameRepo.data['rigs'] = [
        {'id': RigIds.cpuRig, 'amount': 1},
      ];

      final newGame = GameLogic(
        gameRepository: fakeGameRepo,
        settingsRepository: FakeSettingsRepository(),
        economyService: EconomyService(),
        stashService: StashService(),
        soundService: FakeSoundService(),
        loadOnStart: false,
      );
      await newGame.loadGame();

      expect(newGame.offlineEarningsAmount, closeTo(100, 5));
      expect(newGame.wallet, closeTo(100, 5));
    });

    test('Prestige Multiplier calculation', () {
      // Concave: 1 + 0.5*sqrt(4) = 2.0x.
      game.govTokens = 4;
      expect(game.prestigeMultiplier, 2.0);
    });

    test('Sound Toggle persistence', () async {
      final fakeSettingsRepo = FakeSettingsRepository();
      game = GameLogic(
        gameRepository: FakeGameRepository(),
        settingsRepository: fakeSettingsRepo,
        economyService: EconomyService(),
        stashService: StashService(),
        soundService: FakeSoundService(),
      );

      await Future.delayed(const Duration(milliseconds: 50));

      expect(game.soundEnabled, true);

      await game.toggleSound();
      expect(game.soundEnabled, false);

      final settings = await fakeSettingsRepo.loadSettings();
      expect(settings['sound_enabled'], false);
    });

    test('Hard Fork resets Research', () async {
      game.wallet = 100000;
      game.buyResearch('basic_overclock');
      expect(game.isResearched('basic_overclock'), true);

      game.lifetimeEarnings = 2e9; // sqrt(2e9 / 5e8) = 2 GovTokens

      game.hardFork();

      expect(
        game.isResearched('basic_overclock'),
        false,
        reason: 'Research should be reset',
      );
      expect(game.govTokens, greaterThan(0), reason: 'Should claim tokens');
    });

    test('Full Reset clears all state', () async {
      game.wallet = 999;
      game.chips = 5;
      game.stashService.loadStash({
        'artifacts': {'old_hdd': 1},
      });

      await game.resetGame();

      expect(game.wallet, 0);
      expect(game.chips, 0);
      expect(game.stashService.ownedArtifacts, isEmpty);
    });

    test('Chaos Multipliers affect Income and Cost', () {
      game.wallet = 10000;
      game.perks['click_power'] = 0;

      double walletStart = game.wallet;
      game.clickMine();
      double baseClickValue = game.wallet - walletStart;
      expect(baseClickValue, greaterThan(0));

      // 1. Test Bull Run (+100% Income)
      game.chaosIncomeMultiplier = 2.0;

      double walletBefore = game.wallet;
      game.clickMine();
      expect(game.wallet - walletBefore, closeTo(baseClickValue * 2, 0.1));

      // 2. Test Market Crash (-50% Income)
      game.chaosIncomeMultiplier = 0.5;
      walletBefore = game.wallet;
      game.clickMine();
      expect(game.wallet - walletBefore, closeTo(baseClickValue * 0.5, 0.1));

      // 3. Test Cheap Energy (Cost Discount)
      game.chaosCostMultiplier = 0.7; // 30% off
      Rig cpu = game.rigs.firstWhere((r) => r.id == 'cpu_rig');
      expect(game.getRigCost(cpu), 70.0);
    });
  });
}
