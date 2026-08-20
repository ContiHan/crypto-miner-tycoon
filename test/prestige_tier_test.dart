import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/ids.dart';
import 'test_helper.dart';

// Values below track the concave endgame model:
//   govTokenDivisor  = 5e8,  prestigeMultiplier  = 1 + 0.50*sqrt(GT+spent)
//   genesisDivisor   = 520000, genesisGainMult   = 1 + 0.50*sqrt(GB)
//   pendingGovTokens = floor(sqrt(lifetime/5e8)     * genesisGainMult)
//   pendingGenesis   = floor(sqrt(chainGovTokens/520000)+eps)
// (Consensus currency + Soft Fork were removed in SKILL S2.)
void main() {
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

      await mintTokens(game, 300000); // 300000 < 520000 -> 0 Genesis
      expect(game.pendingGenesis, 0);

      // Bump chain total to exactly 520000 -> sqrt(520000/520000) = 1.
      await mintTokens(game, 220000); // 300000 + 220000 = 520000
      expect(game.pendingGenesis, 1);
    });

    test('New Blockchain banks Genesis, keeps Stash, wipes everything else',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();

      // 2080000 chain tokens -> sqrt(2080000/520000) = sqrt(4) = 2 Genesis Blocks.
      await mintTokens(game, 2080000);
      expect(game.pendingGenesis, 2);

      // Seed the run resources the deepest reset must wipe, plus permanent
      // things that must survive (Stash artifact + chips/UTXO).
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
      expect(game.chips, 40, reason: 'chips/UTXO are PERMANENT (survive New Blockchain)');
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

    test('Genesis Blocks multiply GovToken GAIN', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();

      // 8320000 chain tokens -> sqrt(8320000/520000) = sqrt(16) = 4 Genesis.
      await mintTokens(game, 8320000);
      game.newBlockchain();
      expect(game.genesisBlocks, 4);
      // 1 + 0.5*sqrt(4) = x2.0 gain multiplier.
      expect(game.genesisGainMultiplier, closeTo(2.0, 1e-9));

      // GovToken gain doubled: base floor(sqrt(4.5e9/5e8))=3 -> 6.
      game.lifetimeEarnings = 4.5e9;
      expect(game.pendingGovTokens, 6);
    });

    test('genesisGainMultiplierAfterNewChain matches the concave applied value',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      await mintTokens(game, 8320000); // chain 8.32M -> pendingGenesis 4
      expect(game.pendingGenesis, 4);
      // Projection must be concave (1 + 0.5*sqrt(0+4) = 2.0), NOT the old linear
      // 1 + 4*0.5 = 3.0 the dialog used to show.
      expect(game.genesisGainMultiplierAfterNewChain, closeTo(2.0, 1e-9));
      game.newBlockchain();
      // ...and it equals what actually got applied.
      expect(game.genesisGainMultiplier, closeTo(2.0, 1e-9));
    });

    test('New Blockchain below the threshold does nothing', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      await mintTokens(game, 5); // 5 chain tokens < 520000
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

      await mintTokens(game, 8320000); // chain 8.32M -> 4 Genesis
      game.newBlockchain(); // banks 4 GB + saves (baseline now 8.32M)
      expect(game.genesisBlocks, 4);

      // Reload from the same repo the newBlockchain save wrote to.
      await game.loadGame();
      expect(game.genesisBlocks, 4, reason: 'Genesis Blocks persisted');
      expect(
        game.pendingGenesis,
        0,
        reason: 'chain baseline persisted -> no free re-trigger after reload',
      );

      // Behavioural check that BOTH totalGovTokensEver (=8.32M) and the baseline
      // (=8.32M) round-tripped. With x2.0 gain (4 GB), base sqrt(6.76e10)=260000
      // mints 520000, so the fresh chain holds exactly 520000 -> 1 Genesis. A
      // dropped total (chain goes negative) or dropped baseline (chain much
      // larger) both change this count, so it pins both fields.
      game.lifetimeEarnings = 260000.0 * 260000.0 * 5.0e8;
      expect(game.pendingGovTokens, 520000);
      game.hardFork();
      expect(game.pendingGenesis, 1);
    });

    test('a second New Blockchain ADDS to the Genesis total (not replaces)',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();

      await mintTokens(game, 8320000); // chain 8.32M -> 4 Genesis
      game.newBlockchain();
      expect(game.genesisBlocks, 4);
      expect(game.genesisGainMultiplier, closeTo(2.0, 1e-9));

      // Boosted mint (x2.0): base sqrt(6.76e10)=260000 -> 520000 minted, so the
      // fresh chain reaches 520000 tokens -> floor(sqrt(520000/520000)) = 1 GB.
      game.lifetimeEarnings = 260000.0 * 260000.0 * 5.0e8;
      expect(game.pendingGovTokens, 520000, reason: 'GT gain boosted by Genesis');
      game.hardFork();
      expect(game.pendingGenesis, 1);

      game.newBlockchain();
      expect(game.genesisBlocks, 5, reason: '4 + 1, Genesis accumulates');
    });
  });
}
