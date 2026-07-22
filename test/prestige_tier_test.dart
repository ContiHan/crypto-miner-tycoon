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

  group('New Blockchain (Tier-3 prestige / Genesis Blocks)', () {
    // Mint [tokens] GovTokens through a real Hard Fork so the tier-3
    // "totalGovTokensEver" accumulator is fed exactly as it is in play.
    Future<void> mintTokens(dynamic game, int tokens) async {
      // pending = floor(sqrt(lifetime / govTokenDivisor)); govTokenDivisor=5e8.
      game.lifetimeEarnings = tokens * tokens * 5.0e8;
      expect(game.pendingGovTokens, tokens);
      game.hardFork();
    }

    test('pendingGenesis follows sqrt(chainGovTokens / 100)', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();

      await mintTokens(game, 9); // 9 < 100 -> still 0 Genesis
      expect(game.pendingGenesis, 0);

      await mintTokens(game, 10); // total 19 chain tokens, still < 100
      expect(game.pendingGenesis, 0);

      // Bump chain total to exactly 100 -> sqrt(100/100) = 1.
      await mintTokens(game, 81); // 19 + 81 = 100
      expect(game.pendingGenesis, 1);
    });

    test('New Blockchain banks Genesis, keeps Stash, wipes everything else',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();

      // Reach 400 chain tokens -> sqrt(400/100) = 2 Genesis Blocks.
      await mintTokens(game, 400);
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

      await mintTokens(game, 400); // 400 chain tokens -> 2 Genesis
      game.newBlockchain();
      expect(game.genesisBlocks, 2);
      // 1 + 2 * perGenesisGainBonus(1.0) = x3 gain multiplier.
      expect(game.genesisGainMultiplier, closeTo(3.0, 1e-9));

      // GovToken gain is tripled: base floor(sqrt(4.5e9/5e8))=3 -> 9.
      game.lifetimeEarnings = 4.5e9;
      expect(game.pendingGovTokens, 9);

      // Consensus gain is tripled: base cbrt(2.7e8/1e7)=cbrt(27)=3 -> 9.
      game.lifetimeEarnings = 2.7e8;
      // era measured from last soft fork (0 after fresh chain).
      expect(game.pendingConsensus, 9);
    });

    test('New Blockchain below the threshold does nothing', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      await mintTokens(game, 5); // 5 chain tokens < 100
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

      await mintTokens(game, 400); // chain 400 -> 2 Genesis
      game.newBlockchain(); // banks 2 GB + saves (baseline now 400)
      expect(game.genesisBlocks, 2);

      // Reload from the same repo the newBlockchain save wrote to.
      await game.loadGame();
      expect(game.genesisBlocks, 2, reason: 'Genesis Blocks persisted');
      expect(
        game.pendingGenesis,
        0,
        reason: 'chain baseline persisted -> no free re-trigger after reload',
      );

      // Behavioural check that BOTH totalGovTokensEver (=400) and the baseline
      // (=400) round-tripped: mint 300 more tokens (x3 gain from 2 GB) so the
      // fresh chain holds exactly 300 -> floor(sqrt(300/100)) = 1. A dropped
      // total (chain would go negative) or dropped baseline (chain would be 700
      // -> 2) both yield a different count, so this pins both fields.
      game.lifetimeEarnings = 5e12;
      expect(game.pendingGovTokens, 300);
      game.hardFork();
      expect(game.pendingGenesis, 1);
    });

    test('a second New Blockchain ADDS to the Genesis total (not replaces)',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();

      await mintTokens(game, 400); // chain 400 -> 2 Genesis
      game.newBlockchain();
      expect(game.genesisBlocks, 2);
      expect(game.genesisGainMultiplier, closeTo(3.0, 1e-9));

      // Now minting is boosted x3: base floor(sqrt(5e12/5e8))=100 -> 300 minted,
      // so the fresh chain reaches 300 tokens -> floor(sqrt(300/100)) = 1 GB.
      game.lifetimeEarnings = 5e12;
      expect(game.pendingGovTokens, 300, reason: 'GT gain boosted by Genesis');
      game.hardFork();
      expect(game.pendingGenesis, 1);

      game.newBlockchain();
      expect(game.genesisBlocks, 3, reason: '2 + 1, Genesis accumulates');
    });
  });
}
