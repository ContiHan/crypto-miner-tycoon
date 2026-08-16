import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/logic/channels.dart';
import 'package:crypto_miner_tycoon/logic/managers/class_manager.dart';
import 'package:crypto_miner_tycoon/logic/systems/proc_system.dart';
import 'test_helper.dart';
import 'fakes.dart';

void main() {
  group('ProcSystem (unit)', () {
    final rng = AlwaysCritRandom(); // nextDouble() == 0 → always passes chance

    test('GOLDEN RULE: synthetic events fire nothing', () {
      final s = ProcSystem();
      final r = s.roll(ProcEvent.onCrit,
          currentClass: BtcClass.soloMiner,
          synthetic: true,
          nowMs: 0,
          rng: rng);
      expect(r, isEmpty);
    });

    test('a class-signature proc fires for its class only', () {
      final s = ProcSystem();
      expect(
          s.roll(ProcEvent.onCrit,
              currentClass: BtcClass.soloMiner,
              synthetic: false,
              nowMs: 0,
              rng: rng),
          isNotEmpty); // Solo Lucky Strike
      final s2 = ProcSystem();
      expect(
          s2.roll(ProcEvent.onCrit,
              currentClass: BtcClass.corporation,
              synthetic: false,
              nowMs: 0,
              rng: rng),
          isEmpty); // Lucky Strike is Solo-only
    });

    test('per-signal ICD gates repeated fires', () {
      final s = ProcSystem();
      List<ProcResult> fire(int now) => s.roll(ProcEvent.onCrit,
          currentClass: BtcClass.soloMiner,
          synthetic: false,
          nowMs: now,
          rng: rng);
      expect(fire(0), isNotEmpty); // fires
      expect(fire(1000), isEmpty); // within the 6s CRIT-tier ICD floor
      expect(fire(7000), isNotEmpty); // ICD elapsed → fires again
    });

    test('a proc BUFF applies a temp multiplier that expires', () {
      final s = ProcSystem();
      // Corp Thermal Runaway: onBlockFound → hash ×1.5 for 8s.
      s.roll(ProcEvent.onBlockFound,
          currentClass: BtcClass.corporation,
          synthetic: false,
          nowMs: 0,
          rng: rng);
      expect(s.tempMult(Channel.hash, 1000), 1.5);
      expect(s.tempMult(Channel.hash, 9000), 1.0); // expired after 8s
    });
  });

  group('Procs (GameLogic integration)', () {
    test('a real crit tap fires Lucky Strike (+UTXO); auto-taps do NOT', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.debugSelectClass(BtcClass.soloMiner);
      game.clickRng = AlwaysCritRandom(); // crit + proc both fire

      final before = game.chips;
      game.clickMine(); // real tap → crit → onCrit → Lucky Strike (+2 UTXO)
      expect(game.chips, before + 2);

      // Auto-tap is synthetic (GOLDEN RULE) → no proc, and never crits.
      final after = game.chips;
      game.clickMine(playSound: false);
      expect(game.chips, after);
    });
  });
}
