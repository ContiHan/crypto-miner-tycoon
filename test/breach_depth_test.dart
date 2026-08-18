// F-A: THE BREACH depth — tiers (DUST/BREACH/51%), Cold-Storage-scaled telegraph,
// and the frequency floor.
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/constants.dart';
import 'package:crypto_miner_tycoon/core/ids.dart';
import 'package:crypto_miner_tycoon/logic/systems/breach_system.dart';
import 'test_helper.dart';

void main() {
  group('BreachSystem frequency floor (unit)', () {
    test('a too-soon second breach is blocked until the gap elapses', () {
      var clock = 1000000;
      final b = BreachSystem(
        onChanged: () {},
        onSave: () {},
        playThreatCue: () {},
        blocked: () => false,
        applyLoss: () => 5,
        nowMs: () => clock,
        extraTelegraphSeconds: () => 0,
      );
      b.startThreat();
      expect(b.pending, true);
      b.resolve(secured: true);
      // Immediately after → floored.
      b.startThreat();
      expect(b.pending, false, reason: 'frequency floor blocks a too-soon breach');
      // After the gap → fires again.
      clock += GameConstants.breachMinGapMs + 1;
      b.startThreat();
      expect(b.pending, true);
      b.stop();
    });
  });

  group('THE BREACH depth (GameLogic integration)', () {
    test('tier scales the loss: DUST < BREACH < 51%', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.wallet = 1000;
      game.debugStartBreach(); // spend the 0-loss drill
      game.resolveBreach(secured: false);

      game.wallet = 1000;
      game.debugStartBreach(tier: BreachTier.dust);
      game.resolveBreach(secured: false);
      expect(game.wallet,
          closeTo(1000 * (1 - GameConstants.breachBaseLoss * 0.3), 1e-6));

      game.wallet = 1000;
      game.debugStartBreach(tier: BreachTier.fiftyOne);
      game.resolveBreach(secured: false);
      expect(game.wallet,
          closeTo(1000 * (1 - GameConstants.breachBaseLoss * 2.5), 1e-6));
      // The 51% aftermath leaves a brief market dip.
      expect(game.chaosIncomeMultiplier, lessThan(1.0),
          reason: '51% attack triggers a bounded income dip');
    });

    test('Cold Storage lengthens the SECURE telegraph window', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.debugStartBreach();
      final baseWindow = game.breachSecondsRemaining;
      game.secureBreach();
      expect(baseWindow, greaterThanOrEqualTo(GameConstants.breachTelegraphSeconds - 1));

      game.researchNodes
          .firstWhere((n) => n.id == ResearchIds.hardenedVault)
          .isCompleted = true; // +0.25 theftResist (among others)
      game.debugStartBreach();
      expect(game.breachSecondsRemaining, greaterThan(baseWindow),
          reason: 'Cold Storage buys extra reaction time');
      game.secureBreach();
    });
  });
}
