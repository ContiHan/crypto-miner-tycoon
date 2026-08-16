import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/ids.dart';
import 'package:crypto_miner_tycoon/logic/managers/research_manager.dart';

void main() {
  group('TECH doctrines — exclusivity + budget', () {
    ResearchManager rm() => ResearchManager();
    void complete(ResearchManager m, String id) =>
        m.researchNodes.firstWhere((n) => n.id == id).isCompleted = true;

    test('membership: trunk / meta / doctrine tags', () {
      final m = rm();
      expect(m.doctrineOf(ResearchIds.basicOverclock), Doctrine.trunk);
      expect(m.doctrineOf(ResearchIds.aiManager), Doctrine.meta);
      expect(m.doctrineOf(ResearchIds.advancedOverclock), Doctrine.megaHash);
      expect(m.doctrineOf(ResearchIds.geothermalCooling), Doctrine.leanRig);
      expect(m.doctrineOf(ResearchIds.autonomousDaemons), Doctrine.hodler);
      expect(m.doctrineOf(ResearchIds.diamondHands), Doctrine.coldStorage);
    });

    test('SELF-CONSISTENCY: every node\'s prereqs are trunk/meta or same doctrine',
        () {
      // This is the invariant that lets exclusivity work WITHOUT re-wiring the
      // requirement graph: committing a doctrine can never strand a reachable
      // node, because a doctrine node only depends on shared hubs or its own kind.
      final m = rm();
      for (final n in m.researchNodes) {
        final d = m.doctrineOf(n.id);
        if (d == Doctrine.trunk || d == Doctrine.meta) continue;
        for (final r in n.requirements) {
          final rd = m.doctrineOf(r);
          expect(
              rd == Doctrine.trunk || rd == Doctrine.meta || rd == d, true,
              reason: '${n.id} ($d) requires $r ($rd) — cross-doctrine prereq!');
        }
      }
    });

    test('committing a doctrine LOCKS its sibling, not itself', () {
      final m = rm();
      expect(m.isDoctrineLocked(ResearchIds.geothermalCooling), false);
      complete(m, ResearchIds.advancedOverclock); // commit MEGA-HASH
      expect(m.committedDoctrines().contains(Doctrine.megaHash), true);
      // sibling LEAN-RIG is now locked; MEGA-HASH stays open.
      expect(m.isDoctrineLocked(ResearchIds.geothermalCooling), true);
      expect(m.isDoctrineLocked(ResearchIds.neuralNet), false);
      // trunk/meta never lock.
      expect(m.isDoctrineLocked(ResearchIds.betterCooling), false);
      expect(m.isDoctrineLocked(ResearchIds.aiManager), false);
    });

    test('commitment budget = 2 pairs; the 3rd pair is locked', () {
      final m = rm();
      complete(m, ResearchIds.advancedOverclock); // pair 1 (MEGA-HASH)
      complete(m, ResearchIds.autonomousDaemons); // pair 2 (HODLER)
      expect(m.committedPairCount(), 2);
      // The 3rd pair (DEGEN-LUCK ⟂ COLD-STORAGE) is entirely locked now.
      expect(m.isDoctrineLocked(ResearchIds.noncePrediction), true);
      expect(m.isDoctrineLocked(ResearchIds.diamondHands), true);
    });

    test('tryBuy refuses a doctrine-locked node', () {
      final m = rm();
      complete(m, ResearchIds.advancedOverclock); // commit MEGA-HASH → LEAN-RIG locked
      m.researchNodes
          .firstWhere((n) => n.id == ResearchIds.geothermalCooling)
          .isUnlocked = true; // requirement-unlocked but doctrine-locked
      final cost = m.tryBuy(ResearchIds.geothermalCooling, 1e18, 1.0);
      expect(cost, 0);
      expect(m.isResearched(ResearchIds.geothermalCooling), false);
    });
  });
}
