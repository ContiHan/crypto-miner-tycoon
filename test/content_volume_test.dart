import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/ids.dart';
import 'package:crypto_miner_tycoon/logic/channels.dart';
import 'package:crypto_miner_tycoon/logic/managers/perk_manager.dart';
import 'package:crypto_miner_tycoon/logic/managers/research_manager.dart';
import 'package:crypto_miner_tycoon/services/stash_service.dart';
import 'test_helper.dart';

void main() {
  group('Content volume', () {
    test('expected catalogue sizes', () {
      expect(PerkManager.defs.length, 20, reason: 'perks');
      expect(ResearchManager().researchNodes.length, 32, reason: 'lab nodes');
      expect(StashService.allArtifacts.length, 78, reason: 'stash artifacts');
    });

    test('every stash artifact id is unique', () {
      final ids = StashService.allArtifacts.map((a) => a.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'duplicate artifact id');
    });

    test('every lab node id is unique', () {
      final ids = ResearchManager().researchNodes.map((n) => n.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'duplicate node id');
    });

    test('no artifact exceeds its rarity ceiling (catches value collisions)', () {
      // Per-rarity UPPER bounds from the content plan. rig-cost discounts
      // legitimately sit lower than the headline hash/click bands, so only the
      // ceiling is asserted — its job is to catch a stray +2000% on a low rarity.
      const ceiling = {
        ArtifactRarity.common: 0.03,
        ArtifactRarity.uncommon: 0.08,
        ArtifactRarity.rare: 0.20,
        ArtifactRarity.epic: 0.50,
        ArtifactRarity.legendary: 1.5,
        ArtifactRarity.mythic: 5.0,
      };
      for (final a in StashService.allArtifacts) {
        expect(a.baseBonus, greaterThan(0), reason: '${a.id} has no bonus');
        expect(a.baseBonus, lessThanOrEqualTo(ceiling[a.rarity]!),
            reason: '${a.id} exceeds its ${a.rarity} ceiling');
      }
    });
  });

  group('No math collision (channel sums bounded when everything is owned)', () {
    test('all research + all stash keep every channel bounded', () {
      final ch = Channels();

      final rm = ResearchManager();
      for (final n in rm.researchNodes) {
        n.isCompleted = true;
      }
      rm.contributeChannels(ch);

      final stash = StashService();
      for (final a in StashService.allArtifacts) {
        stash.ownedArtifacts[a.id] = 1; // one of each
      }
      stash.contributeChannels(ch);

      // Wired channels actually receive content...
      expect(ch.sum(Channel.hash), greaterThan(0));
      expect(ch.sum(Channel.income), greaterThan(0));
      expect(ch.sum(Channel.click), greaterThan(0));
      expect(ch.sum(Channel.rigCost), greaterThan(0));

      // ...and stay in a sane additive range (a stray +2000% typo would blow
      // one of these past the bound). The economy applies these as 1+sum, and
      // rig cost is additionally hard-clamped to 95% in EconomyService. Bounds
      // scale with the (fixed) catalogue size — they catch collisions/typos, not
      // enforce a game cap.
      expect(ch.sum(Channel.hash), lessThan(40));
      expect(ch.sum(Channel.income), lessThan(6));
      expect(ch.sum(Channel.click), lessThan(4));
      expect(ch.sum(Channel.rigCost), lessThan(6));
    });
  });

  group('Progressive perk discovery', () {
    test('only tier-0 perks are visible at the start', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      final unlocked =
          game.perkDefs.keys.where(game.isPerkUnlocked).length;
      expect(unlocked, 3);
    });

    test('perks reveal as totalGovTokensEver grows', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();

      // Mint 25 GovTokens via a real hard fork (feeds totalGovTokensEver).
      game.lifetimeEarnings = 25.0 * 25.0 * 5.0e8; // sqrt(625) = 25
      expect(game.pendingGovTokens, 25);
      game.hardFork();
      expect(game.totalGovTokensEver, 25);

      // Perks with unlockAtTokensEver <= 25 are now revealed (3 tier-0 + 4).
      final unlocked =
          game.perkDefs.keys.where(game.isPerkUnlocked).length;
      expect(unlocked, 7);
    });
  });

  group('New channels are wired into the economy', () {
    test('an income node raises the income multiplier AND actual earnings',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      expect(game.buildChannels().multiplier(Channel.income), 1.0);
      final base = game.estimatedClickValue;
      expect(base, greaterThan(0));

      game.researchNodes
          .firstWhere((n) => n.id == ResearchIds.marketAnalytics)
          .isCompleted = true;

      expect(game.buildChannels().multiplier(Channel.income),
          closeTo(1.10, 1e-9));
      // The +10% income channel must actually reach earnings (this fails if the
      // incomeMultiplier is dropped from the accrual/click paths).
      expect(game.estimatedClickValue, closeTo(base * 1.10, base * 1e-4));
    });

    test('completing a click node raises the click multiplier', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      final base = game.estimatedClickValue;

      game.researchNodes
          .firstWhere((n) => n.id == ResearchIds.ergonomicRig)
          .isCompleted = true;

      expect(game.buildChannels().multiplier(Channel.click),
          closeTo(1.25, 1e-9));
      expect(game.estimatedClickValue, greaterThan(base));
    });

    test('stash click power flows into earnings and stacks with the click '
        'channel (no double-count)', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      final base = game.estimatedClickValue;

      // Stash click power is applied separately from the click CHANNEL, via
      // StashService.getClickPowerMultiplier. Whitepaper = +100% (x2.0).
      game.stashService.ownedArtifacts['satoshi_whitepaper'] = 1;
      expect(game.estimatedClickValue, closeTo(base * 2.0, base * 1e-4),
          reason: 'stash click multiplier must reach earnings');

      // Add a click-CHANNEL source (+25%): the two mechanisms multiply
      // (x2.0 * x1.25 = x2.5), not double-count.
      game.researchNodes
          .firstWhere((n) => n.id == ResearchIds.ergonomicRig)
          .isCompleted = true;
      expect(game.estimatedClickValue, closeTo(base * 2.5, base * 1e-4),
          reason: 'stash click and click channel stack multiplicatively');
    });
  });

  group('Save compatibility — new nodes unlock on load', () {
    test('refreshUnlocks reveals nodes whose prereqs are already completed', () {
      final rm = ResearchManager();
      // Simulate an old save: a prerequisite is completed, but a node added by a
      // later content update is still locked (its unlock never ran).
      rm.researchNodes
          .firstWhere((n) => n.id == ResearchIds.basicOverclock)
          .isCompleted = true;
      final added = rm.researchNodes
          .firstWhere((n) => n.id == ResearchIds.advancedOverclock);
      expect(added.isUnlocked, false, reason: 'added-later node starts locked');

      rm.refreshUnlocks();

      expect(added.isUnlocked, true,
          reason: 'prereq is complete -> node must unlock on load, not soft-lock');
    });
  });

  group('No dead content — every effect uses a consumed channel/type', () {
    test('stash artifacts only use consumed bonus types', () {
      const consumed = {
        BonusType.hashRate,
        BonusType.rigCost,
        BonusType.clickPower,
        BonusType.luck, // consumed via Channel.luck (crit + casino RTP)
      };
      for (final a in StashService.allArtifacts) {
        expect(consumed.contains(a.bonusType), true,
            reason: '${a.id} uses unconsumed bonus type ${a.bonusType}');
      }
    });

    test('perk & lab channel effects only use consumed channels', () {
      // hash/rigCost/income/click are consumed by the economy; prestige/special
      // are NOT. A null channel is an explicitly-handled special (flat click
      // perk, Chip Fab, AI Manager).
      const consumed = {
        Channel.hash,
        Channel.rigCost,
        Channel.income,
        Channel.click,
      };
      PerkManager.defs.forEach((id, def) {
        if (def.channel != null) {
          expect(consumed.contains(def.channel), true,
              reason: 'perk $id uses unconsumed channel ${def.channel}');
        }
      });
      for (final n in ResearchManager().researchNodes) {
        if (n.effectChannel != null) {
          expect(consumed.contains(n.effectChannel), true,
              reason: 'node ${n.id} uses unconsumed channel ${n.effectChannel}');
        }
      }
    });
  });
}
