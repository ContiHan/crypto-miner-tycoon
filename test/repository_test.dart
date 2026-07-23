import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto_miner_tycoon/repositories/settings_repository.dart';
import 'package:crypto_miner_tycoon/repositories/game_repository.dart';
import 'package:crypto_miner_tycoon/models/rig.dart';

import 'package:crypto_miner_tycoon/core/ids.dart';
import 'package:crypto_miner_tycoon/core/constants.dart';

Future<void> _save(GameRepository repo, {double wallet = 0}) {
  return repo.saveGameState(
    wallet: wallet,
    lifetimeEarnings: 0,
    govTokens: 0,
    spentGovTokens: 0,
    perks: {},
    perkCosts: {},
    rigs: [],
    researchNodes: [],
    networkDifficulty: 100,
    blockReward: 50,
    blocksMined: 0,
    nextHalvingThreshold: 5000,
    bitcoinExchangeRate: 1.0,
  );
}

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

  group('GameRepository save integrity (bug #1)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('writes a single atomic blob with a schema version', () async {
      final repo = GameRepository();
      await _save(repo, wallet: 1234.5);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('game_save_v2');
      expect(raw, isNotNull, reason: 'state is stored under one atomic key');

      final decoded = jsonDecode(raw!) as Map<String, dynamic>;
      expect(decoded['version'], 2, reason: 'schema version is persisted');
      expect(decoded['wallet'], 1234.5);
    });

    test('a corrupted save blob does not throw and falls back to defaults',
        () async {
      SharedPreferences.setMockInitialValues({
        'game_save_v2': '{ this is not valid json',
      });
      final repo = GameRepository();

      final data = await repo.loadGameState();

      // No FormatException escapes; the game boots on safe defaults instead.
      expect(data['wallet'], 0.0);
      expect(data['blockReward'], 50.0 * 100000000);
      expect(data['nextHalvingThreshold'], GameConstants.halvingFirstThreshold);
    });

    test('numeric fields load as doubles even when stored whole', () async {
      // JSON collapses 1000.0 to 1000; the repo must still hand back a double
      // (a raw int would crash GameLogic's `double wallet = ...` assignment).
      SharedPreferences.setMockInitialValues({
        'game_save_v2': jsonEncode({'version': 2, 'wallet': 1000}),
      });
      final repo = GameRepository();

      final data = await repo.loadGameState();

      expect(data['wallet'], isA<double>());
      expect(data['wallet'], 1000.0);
    });

    test('clearSave wipes game state but preserves user settings', () async {
      SharedPreferences.setMockInitialValues({});
      final settingsRepo = SettingsRepository();
      await settingsRepo.saveSettings(soundEnabled: false, showFiatPrices: true);

      final gameRepo = GameRepository();
      await _save(gameRepo, wallet: 500);

      await gameRepo.clearSave();

      final settings = await settingsRepo.loadSettings();
      expect(settings['sound_enabled'], false, reason: 'settings survive reset');
      expect(settings['show_fiat_prices'], true);

      final data = await gameRepo.loadGameState();
      expect(data['wallet'], 0.0, reason: 'game state is gone');
    });

    test('migrates a legacy per-key save', () async {
      SharedPreferences.setMockInitialValues({
        'wallet': 777.0,
        'blocksMined': 42,
        'perks': jsonEncode({PerkIds.clickPower: 3}),
      });
      final repo = GameRepository();

      final data = await repo.loadGameState();

      expect(data['wallet'], 777.0);
      expect(data['blocksMined'], 42);
      expect(data['perks'][PerkIds.clickPower], 3);
    });

    test('a corrupted legacy key is dropped, not fatal', () async {
      SharedPreferences.setMockInitialValues({
        'wallet': 500.0,
        'perks': '{ broken json',
      });
      final repo = GameRepository();

      final data = await repo.loadGameState();

      expect(data['wallet'], 500.0);
      expect(
        data.containsKey('perks'),
        false,
        reason: 'the unreadable key is skipped rather than crashing the load',
      );
    });

    test('fresh install defaults to the intended first-halving threshold',
        () async {
      SharedPreferences.setMockInitialValues({});
      final data = await GameRepository().loadGameState();
      // Was a stale 5000 (first halving ~1.4h); must be the design value 15000.
      expect(data['nextHalvingThreshold'], GameConstants.halvingFirstThreshold);
    });

    test('a non-finite numeric field never bricks the save (Infinity/NaN)',
        () async {
      final repo = GameRepository();
      // networkDifficulty becomes Infinity at the supply cap; jsonEncode would
      // throw on it. The save must survive and round-trip a finite value.
      await repo.saveGameState(
        wallet: double.nan,
        lifetimeEarnings: 5000,
        govTokens: 0,
        spentGovTokens: 0,
        perks: {},
        perkCosts: {},
        rigs: [],
        researchNodes: [],
        networkDifficulty: double.infinity,
        blockReward: double.infinity,
        blocksMined: 0,
        nextHalvingThreshold: 5000,
        bitcoinExchangeRate: 1.0,
      );

      final data = await repo.loadGameState();
      expect((data['networkDifficulty'] as num).isFinite, true);
      expect((data['wallet'] as num).isFinite, true);
      expect((data['blockReward'] as num).isFinite, true);
      expect(data['lifetimeEarnings'], 5000);
    });

    test('seeds totalGovTokensEver from tokens for saves predating the field',
        () async {
      // A v2 blob written before Tier-3 existed: has tokens but no accumulator.
      SharedPreferences.setMockInitialValues({
        'game_save_v2': jsonEncode({
          'version': 2,
          'govTokens': 50,
          'spentGovTokens': 300,
        }),
      });
      final repo = GameRepository();

      final data = await repo.loadGameState();

      expect(
        data['totalGovTokensEver'],
        350.0,
        reason: 'seeded from govTokens + spentGovTokens when the key is absent',
      );
      expect(data['genesisBlocks'], 0);
      expect(data['govTokensEverAtLastNewChain'], 0.0);
    });

    test('preserves a persisted totalGovTokensEver instead of reseeding',
        () async {
      SharedPreferences.setMockInitialValues({
        'game_save_v2': jsonEncode({
          'version': 2,
          'govTokens': 50,
          'spentGovTokens': 300,
          'totalGovTokensEver': 9999,
          'govTokensEverAtLastNewChain': 4000,
          'genesisBlocks': 3,
        }),
      });
      final repo = GameRepository();

      final data = await repo.loadGameState();

      expect(data['totalGovTokensEver'], 9999.0, reason: 'kept, not reseeded');
      expect(data['govTokensEverAtLastNewChain'], 4000.0);
      expect(data['genesisBlocks'], 3);
    });
  });
}
