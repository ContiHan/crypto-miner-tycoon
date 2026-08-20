import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/constants.dart';
import 'test_helper.dart';

// Passive endgame model (SKILL S2):
//   govTokenDivisor = 5e8,   prestigeMultiplier = 1 + 0.50*sqrt(GT+spent)
//   genesisDivisor  = 25000, genesisGainMult    = 1 + 0.50*sqrt(GB)
//   pendingGovTokens = floor(sqrt(lifetime/5e8) * genesisGainMult)
//   genesisBlocks    = floor(sqrt(totalGovTokensEver / genesisDivisor))  [DERIVED]
// (Consensus + Soft Fork + the New Blockchain banking flow were all removed in
//  SKILL S2; Genesis Blocks now accrue PASSIVELY from cumulative GovTokens.)
void main() {
  group('Genesis Blocks (passive, derived from totalGovTokensEver)', () {
    // Mint exactly [tokens] GovTokens through a single Hard Fork from a FRESH
    // game — while genesisBlocks == 0 the gain multiplier is 1.0, so this seeds
    // totalGovTokensEver == tokens deterministically.
    Future<void> mintFresh(dynamic game, int tokens) async {
      game.lifetimeEarnings = tokens * tokens * 5.0e8;
      expect(game.pendingGovTokens, tokens);
      game.hardFork();
      expect(game.totalGovTokensEver, closeTo(tokens.toDouble(), 1e-6));
    }

    test('threshold is the S2 value (guards the migration math)', () {
      expect(GameConstants.genesisDivisor, 25000.0);
    });

    test('below the threshold yields 0 Genesis (multiplier neutral)', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      await mintFresh(game, 100); // 100 << 25000 -> 0 Genesis
      expect(game.genesisBlocks, 0);
      expect(game.genesisGainMultiplier, closeTo(1.0, 1e-9));
    });

    test('genesisBlocks = floor(sqrt(totalGovTokensEver / genesisDivisor))',
        () async {
      // 1 Genesis at exactly the threshold.
      final g1 = createTestGameLogic(loadOnStart: false);
      await g1.loadGame();
      await mintFresh(g1, 25000); // 25000 / 25000 = 1
      expect(g1.genesisBlocks, 1);

      // 4 Genesis at 16x the threshold.
      final g4 = createTestGameLogic(loadOnStart: false);
      await g4.loadGame();
      await mintFresh(g4, 400000); // 400000 / 25000 = 16 -> sqrt = 4
      expect(g4.genesisBlocks, 4);
      // 1 + 0.5*sqrt(4) = x2.0 gain multiplier.
      expect(g4.genesisGainMultiplier, closeTo(2.0, 1e-9));
    });

    test('Genesis Blocks multiply GovToken GAIN', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      await mintFresh(game, 400000); // -> 4 Genesis, x2.0 gain
      expect(game.genesisBlocks, 4);

      // GovToken gain doubled: base floor(sqrt(4.5e9/5e8)) = 3 -> 6.
      game.lifetimeEarnings = 4.5e9;
      expect(game.pendingGovTokens, 6);
    });

    test('a Hard Fork never LOWERS Genesis (monotonic, no banking/reset)',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      await mintFresh(game, 400000); // 4 Genesis
      expect(game.genesisBlocks, 4);

      // Another Hard Fork only ADDS to totalGovTokensEver → Genesis can only grow.
      game.lifetimeEarnings = 4.5e9; // some more tokens
      game.hardFork();
      expect(game.genesisBlocks, greaterThanOrEqualTo(4));
    });

    test('derived Genesis survives save + reload (only totalEver persists)',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      await mintFresh(game, 400000); // 4 Genesis; hardFork() already saved
      expect(game.genesisBlocks, 4);

      await game.loadGame(); // same fake repo
      expect(game.genesisBlocks, 4, reason: 'derived from persisted totalEver');
      expect(game.totalGovTokensEver, closeTo(400000.0, 1e-6));
    });
  });
}
