import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto_miner_tycoon/services/persistence_service.dart';
import 'package:crypto_miner_tycoon/models/rig.dart';
import 'package:crypto_miner_tycoon/models/research_node.dart';

void main() {
  group('PersistenceService', () {
    late PersistenceService persistence;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      persistence = PersistenceService();
    });

    test('Save and Load basic values', () async {
      // Create test data
      final rigs = [
        Rig(id: 'cpu', name: 'CPU', baseCost: 10, baseHashRate: 1, amount: 5),
      ];
      final research = [
        ResearchNode(
          id: 'res1',
          name: 'R1',
          description: 'D1',
          cost: 100,
          icon: Icons.error,
          isCompleted: true,
          isUnlocked: true,
        ),
      ];
      final perks = {'click_power': 2};
      final perkCosts = {'click_power': 15};
      final stash = {
        'artifacts': {'hdd': 1},
        'crates': 0,
      };

      await persistence.saveGame(
        wallet: 123.45,
        lifetimeEarnings: 500.0,
        govTokens: 10,
        spentGovTokens: 5,
        perks: perks,
        perkCosts: perkCosts,
        rigs: rigs,
        researchNodes: research,
        soundEnabled: false,
        networkDifficulty: 150.0,
        blockReward: 25.0,
        blocksMined: 100,
        nextHalvingThreshold: 2000,
        bitcoinExchangeRate: 1.5,
        chips: 7,
        stash: stash,
      );

      final data = await persistence.loadGame();

      expect(data['wallet'], 123.45);
      expect(data['lifetimeEarnings'], 500.0);
      expect(data['govTokens'], 10);
      expect(data['spentGovTokens'], 5);
      expect(data['sound_enabled'], false);
      expect(data['networkDifficulty'], 150.0);
      expect(data['blockReward'], 25.0);
      expect(data['blocksMined'], 100);
      expect(data['nextHalvingThreshold'], 2000);
      expect(data['bitcoinExchangeRate'], 1.5);
      expect(data['chips'], 7);

      // Complex objects
      expect(data['perks'], perks);
      expect(data['perkCosts'], perkCosts);

      final loadedRigs = data['rigs'] as List;
      expect(loadedRigs.length, 1);
      expect(loadedRigs[0]['id'], 'cpu');
      expect(loadedRigs[0]['amount'], 5);

      final loadedResearch = data['research'] as List;
      expect(loadedResearch.length, 1);
      expect(loadedResearch[0]['id'], 'res1');
      expect(loadedResearch[0]['isCompleted'], true);

      final loadedStash = data['stash'] as Map;
      expect(loadedStash['artifacts'], {'hdd': 1});
    });

    test('Reset Game wipes data', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('wallet', 1000);

      await persistence.resetGame();

      expect(prefs.containsKey('wallet'), false);
    });

    test('Load Game defaults when keys missing', () async {
      // Empty mock values
      SharedPreferences.setMockInitialValues({});

      final data = await persistence.loadGame();

      expect(data['wallet'], 0.0);
      expect(data['govTokens'], 0);
      expect(data['sound_enabled'], true); // Default true
      expect(data['networkDifficulty'], 100.0); // Default base
    });
  });
}
