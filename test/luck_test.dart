import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/constants.dart';
import 'package:crypto_miner_tycoon/logic/channels.dart';
import 'package:crypto_miner_tycoon/logic/systems/anomaly_system.dart';
import 'package:crypto_miner_tycoon/services/casino_service.dart';
import 'test_helper.dart';

/// Random stub returning a fixed nextDouble (to sit between base and boosted
/// crit chance).
class _FixedRandom implements Random {
  final double d;
  _FixedRandom(this.d);
  @override
  double nextDouble() => d;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}

void main() {
  group('Casino RTP stays < 1 even with huge Luck (compliance)', () {
    final bases = <String, double>{
      'slots': CasinoService.slotsReturnToPlayer,
      'flip': CasinoService.flipReturnToPlayer,
      'plinko': CasinoService.plinkoReturnToPlayer,
    };
    bases.forEach((name, base) {
      test('$name realized RTP is capped below 1', () {
        final lf = CasinoService.effectiveLuck(1000.0, base);
        expect(lf, greaterThanOrEqualTo(1.0),
            reason: 'luck must never reduce winnings');
        expect(base * lf, lessThanOrEqualTo(GameConstants.casinoRtpCap + 1e-9),
            reason: '$name RTP must stay <= cap (<1) with any luck');
        expect(GameConstants.casinoRtpCap, lessThan(1.0));
      });
    });

    test('luck <= 1 leaves the factor at exactly 1 (no change)', () {
      expect(
          CasinoService.effectiveLuck(1.0, CasinoService.slotsReturnToPlayer),
          1.0);
      expect(
          CasinoService.effectiveLuck(0.5, CasinoService.slotsReturnToPlayer),
          1.0);
    });
  });

  group('Luck attribute', () {
    test('lucky_coin feeds the Luck channel', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      expect(game.buildChannels().sum(Channel.luck), 0.0);
      expect(game.luckMultiplier, 1.0);

      game.stashService.addArtifact('lucky_coin');
      expect(game.buildChannels().sum(Channel.luck), greaterThan(0));
      expect(game.luckMultiplier, greaterThan(1.0));
    });

    test('Luck raises crit chance (a roll that misses at base now crits)',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.wallet = 1e6;
      game.clickRng = _FixedRandom(0.11); // between base (0.06) and boosted

      expect(game.clickMine().isCrit, false, reason: '0.11 >= base 0.06');

      for (int i = 0; i < 100; i++) {
        game.stashService.addArtifact('lucky_coin');
      }
      expect(game.clickMine().isCrit, true,
          reason: 'luck pushed the crit chance above the 0.11 roll');
    });
  });

  group('Luck raises anomaly spawn rate (capped)', () {
    test('spawnChance scales with luck and is capped', () {
      double luck = 1.0;
      final sys = AnomalySystem(
        onChanged: () {},
        onCollect: () {},
        luckFactor: () => luck,
      );
      expect(sys.spawnChance, closeTo(0.05, 1e-9));
      luck = 2.0;
      expect(sys.spawnChance, closeTo(0.10, 1e-9));
      luck = 100.0;
      expect(sys.spawnChance, 0.30, reason: 'hard-capped, never guaranteed');
    });
  });
}
