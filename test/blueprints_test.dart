import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/constants.dart';
import 'package:crypto_miner_tycoon/core/ids.dart';
import 'package:crypto_miner_tycoon/logic/managers/research_manager.dart';
import 'package:crypto_miner_tycoon/providers/game_logic.dart';
import 'package:crypto_miner_tycoon/services/economy_service.dart';
import 'package:crypto_miner_tycoon/services/stash_service.dart';
import 'fakes.dart';

/// BLUEPRINTS (Phase 3): a permanent, bounded re-tech discount that survives
/// every prestige reset (only a full Wipe clears it) + the combined TECH-cost
/// floor (#3).
void main() {
  group('Blueprints — re-tech discount curve', () {
    test('discount is 0 at count 0, concave, and asymptotes to the 40% cap', () {
      final rm = ResearchManager();
      expect(rm.blueprintDiscount('x'), 0.0);
      rm.researchCount['x'] = 6; // 0.40*(1-1/2) = 0.20
      expect(rm.blueprintDiscount('x'), closeTo(0.20, 1e-9));
      rm.researchCount['x'] = 12; // 0.40*(1-1/3) ≈ 0.267
      expect(rm.blueprintDiscount('x'), closeTo(0.2667, 1e-3));
      rm.researchCount['x'] = 100000; // → cap
      expect(rm.blueprintDiscount('x'),
          closeTo(GameConstants.blueprintMaxDiscount, 1e-3));
      expect(rm.blueprintDiscount('x'),
          lessThanOrEqualTo(GameConstants.blueprintMaxDiscount));
    });

    test('cost applies the discount and never drops below the floor (#3)', () {
      final rm = ResearchManager();
      final node = rm.researchNodes
          .firstWhere((n) => n.id == ResearchIds.basicOverclock);
      final base = rm.getCostInSats(node, 1.0);
      expect(base, node.cost);

      rm.researchCount[node.id] = 12; // ~26.7% off
      final discounted = rm.getCostInSats(node, 1.0);
      expect(discounted, lessThan(base));
      expect(discounted, closeTo(base * (1 - rm.blueprintDiscount(node.id)), 1e-6));

      // Even at an extreme count the discount caps at 40%, so cost stays at
      // 60% of base — always well above the 5% techCostFloor.
      rm.researchCount[node.id] = 1000000;
      final capped = rm.getCostInSats(node, 1.0);
      expect(capped, greaterThanOrEqualTo(base * GameConstants.techCostFloor));
      expect(capped, closeTo(base * (1 - GameConstants.blueprintMaxDiscount), base * 1e-3));
    });

    test('buying a node records a permanent blueprint count', () {
      final rm = ResearchManager();
      final node = rm.researchNodes
          .firstWhere((n) => n.id == ResearchIds.basicOverclock);
      final cost = rm.getCostInSats(node, 1.0);
      rm.tryBuy(ResearchIds.basicOverclock, cost, 1.0);
      expect(rm.researchCount[ResearchIds.basicOverclock], 1);
    });

    test('blueprint counts survive a prestige reset; node completion does not', () {
      final rm = ResearchManager();
      final node = rm.researchNodes
          .firstWhere((n) => n.id == ResearchIds.basicOverclock);
      rm.tryBuy(ResearchIds.basicOverclock, rm.getCostInSats(node, 1.0), 1.0);
      expect(node.isCompleted, true);
      expect(rm.researchCount[ResearchIds.basicOverclock], 1);

      rm.reset(); // prestige reset
      expect(node.isCompleted, false, reason: 'node completion resets');
      expect(rm.researchCount[ResearchIds.basicOverclock], 1,
          reason: 'blueprint count is permanent across resets');

      rm.wipeBlueprints(); // full Wipe Save only
      expect(rm.researchCount[ResearchIds.basicOverclock], null);
    });
  });

  group('Blueprints — persistence + full wipe (GameLogic)', () {
    test('blueprint counts round-trip a save/reload and clear on full wipe',
        () async {
      final repo = FakeGameRepository();
      final settings = FakeSettingsRepository();
      GameLogic make() => GameLogic(
            gameRepository: repo,
            settingsRepository: settings,
            economyService: EconomyService(),
            stashService: StashService(),
            soundService: FakeSoundService(),
            startTimers: false,
            loadOnStart: false,
          )..clickRng = NoCritRandom();

      final g1 = make();
      await g1.loadGame();
      g1.wallet = 1e12;
      g1.buyResearch(ResearchIds.basicOverclock); // records a blueprint + saves

      final g2 = make();
      await g2.loadGame();
      expect(g2.blueprintCount(ResearchIds.basicOverclock), 1,
          reason: 'blueprint persisted across reload');

      await g2.resetGame(); // full Wipe Save
      expect(g2.blueprintCount(ResearchIds.basicOverclock), 0,
          reason: 'full wipe clears blueprints');
    });
  });
}
