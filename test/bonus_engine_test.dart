import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/ids.dart';
import 'package:crypto_miner_tycoon/logic/channels.dart';
import 'test_helper.dart';

void main() {
  group('BonusEngine (buildChannels aggregates research + perks + stash)', () {
    test('hash channel sums research, perk and stash bonuses additively',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.wallet = 1e9;

      game.buyResearch(ResearchIds.basicOverclock); // hash +0.05
      game.perks[PerkIds.hashBonus] = 2; // hash +0.20 (2 * 0.10)
      game.stashService.loadStash({
        'artifacts': {'old_hdd': 1}, // hash +0.02
      });

      final ch = game.buildChannels();
      expect(ch.sum(Channel.hash), closeTo(0.05 + 0.20 + 0.02, 1e-9));
    });

    test('a NEW data-driven research node contributes with no extra code',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.wallet = 1e12;

      game.buyResearch(ResearchIds.basicOverclock); // +0.05
      game.buyResearch(ResearchIds.advancedOverclock); // +0.15 (new node)

      expect(game.buildChannels().sum(Channel.hash), closeTo(0.20, 1e-9));
    });

    test('rig-cost channel sums research + perk discounts', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.wallet = 1e9;

      game.buyResearch(ResearchIds.basicOverclock);
      game.buyResearch(ResearchIds.betterCooling); // rigCost +0.10
      game.perks[PerkIds.rigCost] = 2; // rigCost +0.10

      expect(game.buildChannels().sum(Channel.rigCost), closeTo(0.20, 1e-9));
    });

    test('perk rig-cost discount is capped at its max level', () {
      // The rigCost perk maxes at level 18 (90%); asking beyond clamps.
      final game = createTestGameLogic(loadOnStart: false);
      game.perks[PerkIds.rigCost] = 999; // absurd
      expect(game.buildChannels().sum(Channel.rigCost), closeTo(0.90, 1e-9));
    });
  });
}
