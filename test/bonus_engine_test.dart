import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/ids.dart';
import 'package:crypto_miner_tycoon/logic/channels.dart';
import 'package:crypto_miner_tycoon/logic/managers/class_manager.dart';
import 'test_helper.dart';

void main() {
  group('BonusEngine (buildChannels aggregates research + skills + stash)', () {
    test('hash channel sums research, class-skill and stash bonuses additively',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.wallet = 1e9;
      // Solo Miner has NO hash racial, so the hash channel is exactly the sum of
      // the research + skill-node + stash contributions.
      game.debugSelectClass(BtcClass.soloMiner);

      game.buyResearch(ResearchIds.basicOverclock); // hash +0.05
      game.perks['solo_fusion'] = 2; // hash +0.06 (2 * 0.03)
      game.stashService.loadStash({
        'artifacts': {'old_hdd': 1}, // hash +0.02
      });

      expect(game.buildChannels().sum(Channel.hash),
          closeTo(0.05 + 0.06 + 0.02, 1e-9));
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

    test('rig-cost channel sums research + class-skill discounts', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.wallet = 1e9;
      // Corporation has NO rigCost racial.
      game.debugSelectClass(BtcClass.corporation);

      game.buyResearch(ResearchIds.betterCooling); // rigCost +0.10
      game.perks['corp_acquisition'] = 2; // rigCost +0.06 (2 * 0.03)

      expect(game.buildChannels().sum(Channel.rigCost),
          closeTo(0.10 + 0.06, 1e-9));
    });

    test('a skill rig-cost discount is capped at its max level', () {
      // corp_acquisition maxes at level 15 (45%); asking beyond clamps.
      final game = createTestGameLogic(loadOnStart: false);
      game.debugSelectClass(BtcClass.corporation);
      game.perks['corp_acquisition'] = 999; // absurd
      expect(game.buildChannels().sum(Channel.rigCost), closeTo(0.45, 1e-9));
    });
  });
}
