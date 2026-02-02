import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto_miner_tycoon/repositories/settings_repository.dart';
import 'package:crypto_miner_tycoon/repositories/game_repository.dart';
import 'package:crypto_miner_tycoon/models/rig.dart';

import 'package:crypto_miner_tycoon/core/ids.dart';

void main() {
  group('SettingsRepository', () {
    late SettingsRepository settingsRepo;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      settingsRepo = SettingsRepository();
    });

    test('should save and load settings', () async {
      await settingsRepo.saveSettings(
        soundEnabled: false,
        showFiatPrices: true,
      );

      final settings = await settingsRepo.loadSettings();
      expect(settings['sound_enabled'], false);
      expect(settings['show_fiat_prices'], true);
    });
  });

  group('GameRepository', () {
    late GameRepository gameRepo;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      gameRepo = GameRepository();
    });

    test('should save and load simple game state', () async {
      await gameRepo.saveGameState(
        wallet: 1000.0,
        lifetimeEarnings: 5000.0,
        govTokens: 10,
        spentGovTokens: 5,
        perks: {PerkIds.clickPower: 1},
        perkCosts: {PerkIds.clickPower: 10},
        rigs: [],
        researchNodes: [],
        networkDifficulty: 100,
        blockReward: 50,
        blocksMined: 10,
        nextHalvingThreshold: 20,
        bitcoinExchangeRate: 1.0,
        chips: 5,
      );

      final data = await gameRepo.loadGameState();
      expect(data['wallet'], 1000.0);
      expect(data['govTokens'], 10);
      expect(data['chips'], 5);
      expect(data['perks'][PerkIds.clickPower], 1);
    });

    test('should save and load Rigs', () async {
      final rig = Rig(
        id: RigIds.cpuRig,
        amount: 5,
        // static fields are ignored in JSON but required by constructor in test creation
        // but loadGameState returns raw JSON maps for Rigs
        name: 'CPU',
        baseCost: 100,
        baseHashRate: 1,
      );

      await gameRepo.saveGameState(
        wallet: 0,
        lifetimeEarnings: 0,
        govTokens: 0,
        spentGovTokens: 0,
        perks: {},
        perkCosts: {},
        rigs: [rig],
        researchNodes: [],
        networkDifficulty: 0,
        blockReward: 0,
        blocksMined: 0,
        nextHalvingThreshold: 0,
        bitcoinExchangeRate: 0,
      );

      final data = await gameRepo.loadGameState();
      final stats = data['rigs'] as List;
      expect(stats.length, 1);
      expect(stats[0]['id'], RigIds.cpuRig);
      expect(stats[0]['amount'], 5);
      // Ensure static fields were NOT saved (optimization check)
      expect(stats[0].containsKey('name'), false);
    });
  });
}
