import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/constants.dart';
import 'package:crypto_miner_tycoon/core/ids.dart';
import 'package:crypto_miner_tycoon/logic/channels.dart';
import 'package:crypto_miner_tycoon/logic/managers/perk_manager.dart';
import 'package:crypto_miner_tycoon/logic/managers/research_manager.dart';
import 'package:crypto_miner_tycoon/logic/managers/class_manager.dart';
import 'package:crypto_miner_tycoon/services/stash_service.dart';
import 'test_helper.dart';

void main() {
  group('Content volume', () {
    test('expected catalogue sizes', () {
      expect(PerkManager.defs.length, 33,
          reason: 'skill nodes: 1 universal + 4 class trees of 8');
      expect(ResearchManager().researchNodes.length, 43,
          reason: 'lab nodes (Phase 0: +6; Phase 1: +3 luck facets +2 idle)');
      expect(StashService.allArtifacts.length, 84,
          reason: 'stash artifacts (+4 BLOCK REWARD, +2 PROSPECTOR\'S EYE)');
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

    test('every artifact description % matches its actual baseBonus (drop text '
        'is truthful)', () {
      final re = RegExp(r'([0-9]+(?:\.[0-9]+)?)%');
      for (final a in StashService.allArtifacts) {
        final m = re.firstMatch(a.description);
        expect(m, isNotNull,
            reason: '${a.id}: description "${a.description}" has no % value');
        final pct = double.parse(m!.group(1)!);
        expect(pct / 100.0, closeTo(a.baseBonus, 1e-9),
            reason: '${a.id}: "${a.description}" says $pct% but baseBonus is '
                '${a.baseBonus} (${a.baseBonus * 100}%)');
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
      // Click now includes stash click power (folded into the channel, #19), so
      // the raw sum tracks the whole click catalogue. It's bounded near that
      // total (catches a stray typo) AND — the real rail — the softcapped
      // multiplier the economy actually applies stays tame (3.0/0.6 softcap).
      expect(ch.sum(Channel.click), lessThan(30));
      expect(
        ch.multiplier(Channel.click,
            softStart: GameConstants.clickSoftStart,
            power: GameConstants.channelSoftPower),
        lessThan(15),
      );
      expect(ch.sum(Channel.rigCost), lessThan(6));
    });
  });

  group('Class skill-tree gating', () {
    test('a fresh Prospector sees only the universal node', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      final unlocked = game.perkDefs.keys.where(game.isPerkUnlocked).length;
      expect(unlocked, 1,
          reason: 'only the universal click node before a class is chosen');
    });

    test('a class reveals its root; buying it unlocks the children', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.debugSelectClass(BtcClass.soloMiner);
      game.govTokens = 1000;

      int available() =>
          game.perkDefs.keys.where(game.isPerkUnlocked).length;

      // Universal click node + the Solo root are available; children are locked.
      expect(available(), 2, reason: 'click_power + solo_scrounger root');

      // Buying the root unlocks its two direct children.
      game.buyPerk('solo_scrounger');
      expect(available(), 4,
          reason: 'root bought → solo_caffeine + solo_multimeter unlock');
    });

    test('a node from another class is never buyable', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.debugSelectClass(BtcClass.soloMiner);
      game.govTokens = 1000;
      game.buyPerk('corp_serverfarm'); // wrong class
      expect(game.perks['corp_serverfarm'], 0, reason: 'cross-class buy blocked');
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

    test('stash click power flows into earnings via the click channel '
        '(additive within the channel, no double-count)', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      final base = game.estimatedClickValue;

      // Stash click power now folds into Channel.click (#19). Whitepaper = +100%
      // → click channel 1 + 1.0 = x2.0 (below the 3.0 softStart, untouched).
      game.stashService.ownedArtifacts['satoshi_whitepaper'] = 1;
      expect(game.estimatedClickValue, closeTo(base * 2.0, base * 1e-4),
          reason: 'stash click must reach earnings through the click channel');

      // Add a click-CHANNEL source (+25%): they SUM within the channel
      // (1 + 1.0 + 0.25 = x2.25), not multiply — additive-within-channel, no
      // double-count.
      game.researchNodes
          .firstWhere((n) => n.id == ResearchIds.ergonomicRig)
          .isCompleted = true;
      expect(game.estimatedClickValue, closeTo(base * 2.25, base * 1e-4),
          reason: 'stash click and click channel are additive within the channel');
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
        BonusType.critPayout, // consumed via Channel.special (BLOCK REWARD)
        BonusType.fortune, // consumed via Channel.fortune (crate drop quality)
      };
      for (final a in StashService.allArtifacts) {
        expect(consumed.contains(a.bonusType), true,
            reason: '${a.id} uses unconsumed bonus type ${a.bonusType}');
      }
    });

    test('perk & lab channel effects only use consumed channels', () {
      // hash/rigCost/income/click/luck/offline/special/prestige are consumed by
      // the economy (luck via luckMultiplier → crit + SWEEP + anomaly/crate odds;
      // offline via offlineFraction; special via critPayoutMultiplier; prestige
      // via consensusWeightMultiplier → CX/GT gain). volatility is scaled by class
      // sources not nodes. A null channel is an explicitly-handled special (flat
      // click perk, Chip Fab, AI).
      const consumed = {
        Channel.hash,
        Channel.rigCost,
        Channel.income,
        Channel.click,
        Channel.luck,
        Channel.offline,
        Channel.special,
        Channel.prestige,
        Channel.fortune,
        Channel.nonce, // crit-chance luck facet (consumed via critLuckMultiplier)
        Channel.sweepLuck, // SWEEP luck facet (consumed via sweepLuckMultiplier)
        Channel.magnetism, // anomaly luck facet (consumed via anomalyLuckMultiplier)
        Channel.idle, // offline window (consumed via idleCapacitySeconds)
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
