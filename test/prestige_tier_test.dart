import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/ids.dart';
import 'test_helper.dart';

// Values below track the concave endgame model:
//   consensusDivisor = 2e9,  consensusBonus      = 0.10*sqrt(CX)
//   govTokenDivisor  = 5e8,  prestigeMultiplier  = 1 + 0.50*sqrt(GT+spent)
//   genesisDivisor   = 65000, genesisGainMult    = 1 + 0.50*sqrt(GB)
//   pendingConsensus = floor((cbrt(eraSats/2e9)+eps) * genesisGainMult)
//   pendingGovTokens = floor(sqrt(lifetime/5e8)     * genesisGainMult)
//   pendingGenesis   = floor(sqrt(chainGovTokens/65000)+eps)
void main() {
  group('Soft Fork (Tier-1 prestige / Consensus)', () {
    test('banks Consensus from era sats (cube-root) and resets LAB', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.wallet = 1e9;
      game.buyResearch(ResearchIds.basicOverclock);
      expect(game.isResearched(ResearchIds.basicOverclock), true);

      game.lifetimeEarnings = 1.6e10; // cbrt(1.6e10 / 2e9) = cbrt(8) = 2
      expect(game.pendingConsensus, 2);

      game.softFork();

      expect(game.consensus, 2);
      expect(game.isResearched(ResearchIds.basicOverclock), false,
          reason: 'Soft Fork resets LAB');
      expect(game.pendingConsensus, 0, reason: 'era resets after soft fork');
    });

    test('Consensus adds a concave income bonus (0.10*sqrt(CX))', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.lifetimeEarnings = 1.28e11; // cbrt(1.28e11 / 2e9) = cbrt(64) = 4
      game.softFork();
      expect(game.consensus, 4);
      // 1 + 0 (no GovTokens) + 0.10*sqrt(4) = 1.20
      expect(game.prestigeMultiplier, closeTo(1.20, 1e-9));
    });

    test('a Hard Fork wipes Consensus (era-scoped currency)', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.lifetimeEarnings = 1.6e10; // cbrt(8) = 2 Consensus
      game.softFork();
      expect(game.consensus, 2);

      game.lifetimeEarnings = 2e9; // sqrt(2e9/5e8)=2 GovTokens available
      game.hardFork();
      expect(game.consensus, 0);
    });

    test('soft fork below the threshold does nothing', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.lifetimeEarnings = 5e6; // below consensusDivisor (2e9)
      expect(game.pendingConsensus, 0);
      game.softFork();
      expect(game.consensus, 0);
    });
  });

  group('New Blockchain (Tier-3 prestige / Genesis Blocks)', () {
    // Mint [tokens] GovTokens through a real Hard Fork so the tier-3
    // "totalGovTokensEver" accumulator is fed exactly as it is in play.
    // Valid only while genesisGainMultiplier == 1 (before any New Blockchain).
    Future<void> mintTokens(dynamic game, int tokens) async {
      // pending = floor(sqrt(lifetime / govTokenDivisor)); govTokenDivisor=5e8.
      game.lifetimeEarnings = tokens * tokens * 5.0e8;
      expect(game.pendingGovTokens, tokens);
      game.hardFork();
    }

    test('pendingGenesis follows sqrt(chainGovTokens / genesisDivisor)',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();

      await mintTokens(game, 30000); // 30000 < 65000 -> 0 Genesis
      expect(game.pendingGenesis, 0);

      // Bump chain total to exactly 65000 -> sqrt(65000/65000) = 1.
      await mintTokens(game, 35000); // 30000 + 35000 = 65000
      expect(game.pendingGenesis, 1);
    });

    test('New Blockchain banks Genesis, keeps Stash, wipes everything else',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();

      // 260000 chain tokens -> sqrt(260000/65000) = sqrt(4) = 2 Genesis Blocks.
      await mintTokens(game, 260000);
      expect(game.pendingGenesis, 2);

      // Seed EVERY resource the deepest reset must wipe, plus a Stash artifact
      // that must survive.
      game.wallet = 1e9;
      game.chips = 40;
      game.buyResearch(ResearchIds.basicOverclock);
      game.buyPerk(PerkIds.clickPower);
      game.rigs.firstWhere((r) => r.id == 'cpu_rig').amount = 5;
      game.stashService.ownedArtifacts['old_hdd'] = 1;
      expect(game.govTokens, greaterThan(0));
      expect(game.isResearched(ResearchIds.basicOverclock), true);
      expect((game.perks[PerkIds.clickPower] ?? 0), greaterThan(0));

      game.newBlockchain();

      expect(game.genesisBlocks, 2, reason: 'Genesis banked');
      expect(game.pendingGenesis, 0, reason: 'chain baseline reset');
      expect(game.wallet, 0);
      expect(game.lifetimeEarnings, 0);
      expect(game.govTokens, 0);
      expect(game.spentGovTokens, 0);
      expect(game.chips, 0, reason: 'chips wiped');
      expect(game.consensus, 0, reason: 'New Blockchain wipes Consensus too');
      expect(game.rigs.every((r) => r.amount == 0), true, reason: 'rigs wiped');
      expect(
        game.isResearched(ResearchIds.basicOverclock),
        false,
        reason: 'research wiped',
      );
      expect(
        (game.perks[PerkIds.clickPower] ?? 0),
        0,
        reason: 'perks wiped',
      );
      expect(
        game.stashService.ownedArtifacts.containsKey('old_hdd'),
        true,
        reason: 'Stash collection is permanent',
      );
    });

    test('Genesis Blocks multiply Consensus and GovToken GAIN', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();

      // 1040000 chain tokens -> sqrt(1040000/65000) = sqrt(16) = 4 Genesis.
      await mintTokens(game, 1040000);
      game.newBlockchain();
      expect(game.genesisBlocks, 4);
      // 1 + 0.5*sqrt(4) = x2.0 gain multiplier.
      expect(game.genesisGainMultiplier, closeTo(2.0, 1e-9));

      // GovToken gain doubled: base floor(sqrt(4.5e9/5e8))=3 -> 6.
      game.lifetimeEarnings = 4.5e9;
      expect(game.pendingGovTokens, 6);

      // Consensus gain doubled: base cbrt(5.4e10/2e9)=cbrt(27)=3 -> 6.
      game.lifetimeEarnings = 5.4e10;
      // era measured from last soft fork (0 after fresh chain).
      expect(game.pendingConsensus, 6);
    });

    test('New Blockchain below the threshold does nothing', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      await mintTokens(game, 5); // 5 chain tokens < 65000
      expect(game.pendingGenesis, 0);
      game.wallet = 500;
      game.newBlockchain();
      expect(game.genesisBlocks, 0);
      expect(game.wallet, 500, reason: 'no-op must not wipe the run');
    });

    test('Genesis Blocks and the chain baseline survive save + reload',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();

      await mintTokens(game, 1040000); // chain 1.04M -> 4 Genesis
      game.newBlockchain(); // banks 4 GB + saves (baseline now 1.04M)
      expect(game.genesisBlocks, 4);

      // Reload from the same repo the newBlockchain save wrote to.
      await game.loadGame();
      expect(game.genesisBlocks, 4, reason: 'Genesis Blocks persisted');
      expect(
        game.pendingGenesis,
        0,
        reason: 'chain baseline persisted -> no free re-trigger after reload',
      );

      // Behavioural check that BOTH totalGovTokensEver (=1.04M) and the baseline
      // (=1.04M) round-tripped. With x2.0 gain (4 GB), base sqrt(1.05625e9)=32500
      // mints 65000, so the fresh chain holds exactly 65000 -> 1 Genesis. A
      // dropped total (chain goes negative) or dropped baseline (chain much
      // larger) both change this count, so it pins both fields.
      game.lifetimeEarnings = 32500.0 * 32500.0 * 5.0e8;
      expect(game.pendingGovTokens, 65000);
      game.hardFork();
      expect(game.pendingGenesis, 1);
    });

    test('a second New Blockchain ADDS to the Genesis total (not replaces)',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();

      await mintTokens(game, 1040000); // chain 1.04M -> 4 Genesis
      game.newBlockchain();
      expect(game.genesisBlocks, 4);
      expect(game.genesisGainMultiplier, closeTo(2.0, 1e-9));

      // Boosted mint (x2.0): base sqrt(1.05625e9)=32500 -> 65000 minted, so the
      // fresh chain reaches 65000 tokens -> floor(sqrt(65000/65000)) = 1 GB.
      game.lifetimeEarnings = 32500.0 * 32500.0 * 5.0e8;
      expect(game.pendingGovTokens, 65000, reason: 'GT gain boosted by Genesis');
      game.hardFork();
      expect(game.pendingGenesis, 1);

      game.newBlockchain();
      expect(game.genesisBlocks, 5, reason: '4 + 1, Genesis accumulates');
    });
  });
}
