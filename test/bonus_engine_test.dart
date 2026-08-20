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

      // Complete the node directly (RP now = class level, and we keep Solo at
      // level 0 so the all-class Mastery nudge stays 0 — this test asserts the
      // EXACT hash sum with no racial/nudge interference).
      game.researchNodes
          .firstWhere((n) => n.id == ResearchIds.basicOverclock)
          .isCompleted = true; // hash +0.15
      game.perks['solo_fusion'] = 2; // hash +0.06 (2 * 0.03)
      game.stashService.loadStash({
        'artifacts': {'old_hdd': 1}, // hash +0.02
      });

      expect(game.buildChannels().sum(Channel.hash),
          closeTo(0.15 + 0.06 + 0.02, 1e-9));
    });

    test('a NEW data-driven research node contributes with no extra code',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.wallet = 1e12;

      game.buyResearch(ResearchIds.genesisCore); // free root
      game.buyResearch(ResearchIds.basicOverclock); // +0.15
      game.buyResearch(ResearchIds.neuralNet); // +0.30 (data-driven, no extra code)

      expect(game.buildChannels().sum(Channel.hash), closeTo(0.45, 1e-9));
    });

    test('rig-cost channel sums research + class-skill discounts', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.wallet = 1e9;
      // Corporation has NO rigCost racial.
      game.debugSelectClass(BtcClass.corporation);

      // Cold Storage Logistics grants rigCost +0.20 (among others); complete it
      // directly (its buy needs the deep A-lane chain, irrelevant to this sum).
      game.researchNodes
          .firstWhere((n) => n.id == ResearchIds.coldStorageLogistics)
          .isCompleted = true;
      game.perks['corp_acquisition'] = 2; // rigCost +0.06 (2 * 0.03)

      expect(game.buildChannels().sum(Channel.rigCost),
          closeTo(0.20 + 0.06, 1e-9));
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
