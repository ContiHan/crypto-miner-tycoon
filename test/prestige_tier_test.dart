import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/ids.dart';
import 'test_helper.dart';

void main() {
  group('Soft Fork (Tier-1 prestige / Consensus)', () {
    test('banks Consensus from era sats (cube-root) and resets LAB', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.wallet = 1e9;
      game.buyResearch(ResearchIds.basicOverclock);
      expect(game.isResearched(ResearchIds.basicOverclock), true);

      game.lifetimeEarnings = 8e7; // eraSats 8e7 -> cbrt(8e7/1e7)=cbrt(8)=2
      expect(game.pendingConsensus, 2);

      game.softFork();

      expect(game.consensus, 2);
      expect(game.isResearched(ResearchIds.basicOverclock), false,
          reason: 'Soft Fork resets LAB');
      expect(game.pendingConsensus, 0, reason: 'era resets after soft fork');
    });

    test('Consensus adds +5% income each to the prestige multiplier', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.lifetimeEarnings = 2.7e8; // cbrt(27) = 3 Consensus
      game.softFork();
      expect(game.consensus, 3);
      // 1 + 0 (no GovTokens) + 3 * 0.05 = 1.15
      expect(game.prestigeMultiplier, closeTo(1.15, 1e-9));
    });

    test('a Hard Fork wipes Consensus (era-scoped currency)', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.lifetimeEarnings = 8e7;
      game.softFork();
      expect(game.consensus, 2);

      game.lifetimeEarnings = 2e9; // enough for GovTokens
      game.hardFork();
      expect(game.consensus, 0);
    });

    test('soft fork below the threshold does nothing', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.lifetimeEarnings = 5e6; // below consensusDivisor (1e7)
      expect(game.pendingConsensus, 0);
      game.softFork();
      expect(game.consensus, 0);
    });
  });
}
