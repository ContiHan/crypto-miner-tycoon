// Slice 73b — Rig Firmware loadout: capacity math, socket toggle, the equipped-
// signal projection (graceful over-capacity + CO-PROCESSOR chance scaling),
// persistence, and one live GameLogic firing through the new hooks.
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/constants.dart';
import 'package:crypto_miner_tycoon/core/ids.dart';
import 'package:crypto_miner_tycoon/logic/managers/class_manager.dart';
import 'package:crypto_miner_tycoon/logic/systems/firmware_system.dart';
import 'fakes.dart';
import 'test_helper.dart';

void main() {
  group('FirmwareSystem (unit)', () {
    test('capacity: base 3, +bonus to the cap of 6, or 8 under CO-PROCESSOR', () {
      expect(FirmwareSystem.capacity(bonusSlots: 0, coProcessor: false), 3);
      expect(FirmwareSystem.capacity(bonusSlots: 2, coProcessor: false), 5);
      expect(FirmwareSystem.capacity(bonusSlots: 3, coProcessor: false), 6);
      expect(FirmwareSystem.capacity(bonusSlots: 9, coProcessor: false), 6); // clamp
      expect(FirmwareSystem.capacity(bonusSlots: 0, coProcessor: true), 8);
    });

    test('toggle equips up to cap, then refuses; re-toggle unequips', () {
      final f = FirmwareSystem();
      expect(f.toggle('fw_nonce_cache', 2), true);
      expect(f.toggle('fw_fork_dividend', 2), true);
      expect(f.equipped.length, 2);
      // cap reached → a third is refused.
      expect(f.toggle('fw_cold_boot', 2), false);
      expect(f.equipped.length, 2);
      // unknown affix refused.
      expect(f.toggle('fw_nope', 5), false);
      // re-toggle removes.
      expect(f.toggle('fw_nonce_cache', 2), false);
      expect(f.isEquipped('fw_nonce_cache'), false);
    });

    test('equippedSignals projects only the first [cap] and never loses the rest',
        () {
      final f = FirmwareSystem();
      f.toggle('fw_nonce_cache', 6);
      f.toggle('fw_fork_dividend', 6);
      f.toggle('fw_cold_boot', 6);
      // Capacity dipped to 2 (e.g. doctrines reset) → only 2 active, 3 still saved.
      expect(f.equippedSignals(coProcessor: false, cap: 2).length, 2);
      expect(f.equipped.length, 3); // loadout intact
      // CO-PROCESSOR scales each signal's chance by the −40% factor.
      final scaled = f.equippedSignals(coProcessor: true, cap: 6);
      final baseline = f.equippedSignals(coProcessor: false, cap: 6);
      expect(scaled.first.chance,
          closeTo(baseline.first.chance * GameConstants.firmwareCoProcessorChanceMult, 1e-9));
    });

    test('persistence round-trips and reset clears', () {
      final f = FirmwareSystem();
      f.toggle('fw_nonce_cache', 6);
      f.toggle('fw_cold_boot', 6);
      final f2 = FirmwareSystem()..loadFrom(f.toJson());
      expect(f2.equipped, f.equipped);
      f.reset();
      expect(f.equipped.isEmpty, true);
    });
  });

  group('Rig Firmware (GameLogic integration)', () {
    test('capacity grows with Firmware Bay + current-class Mastery 2', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      expect(game.firmwareCapacity, 3); // base
      game.researchNodes
          .firstWhere((n) => n.id == ResearchIds.firmwareBay)
          .isCompleted = true;
      expect(game.firmwareCapacity, 4); // + Firmware Bay
      game.debugSelectClass(BtcClass.corporation);
      game.debugCreditMastery(BtcClass.corporation, 40000); // Mastery 2
      expect(game.firmwareCapacity, 5); // + Mastery 2
    });

    test('an equipped firmware affix fires through a new hook (onCritStreak)',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      // Corporation has no onCrit UTXO proc, so any UTXO here is the firmware's.
      game.debugSelectClass(BtcClass.corporation);
      game.chips = 0;
      game.toggleFirmware('fw_nonce_cache'); // onCritStreak → +3 UTXO
      expect(game.isFirmwareEquipped('fw_nonce_cache'), true);
      game.clickRng = AlwaysCritRandom();
      // Four consecutive crits trip the streak hook once.
      for (var i = 0; i < GameConstants.critStreakThreshold; i++) {
        game.clickMine(playSound: true);
      }
      expect(game.chips, 3, reason: 'Nonce Cache granted +3 UTXO on the crit streak');
    });

    test('a firing proc pushes a feedback signal for the MINE float (F-D)',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.debugSelectClass(BtcClass.corporation);
      game.toggleFirmware('fw_nonce_cache'); // onCritStreak → grantUtxo
      game.clickRng = AlwaysCritRandom();
      expect(game.procFeedback.value, isNull, reason: 'nothing fired yet');

      for (var i = 0; i < GameConstants.critStreakThreshold; i++) {
        game.clickMine(playSound: true);
      }

      expect(game.procFeedback.value, isNotNull,
          reason: 'the proc fire is surfaced to the UI');
      expect(game.procFeedback.value!.label, isNotEmpty);
    });
  });
}
