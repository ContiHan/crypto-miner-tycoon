import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/ids.dart';
import 'package:crypto_miner_tycoon/logic/managers/research_manager.dart';

// TECH V2 "Three Engines": no more doctrines/opposed-pair locks. The tree is
// 3 branches (A/B/C) + a free core spine, bounded by a per-fork Research-Point
// budget; keystones unlock at each branch capstone.
void main() {
  group('TECH V2 — branches + Research-Point budget', () {
    ResearchManager rm() => ResearchManager();
    void complete(ResearchManager m, String id) =>
        m.researchNodes.firstWhere((n) => n.id == id).isCompleted = true;

    test('branch membership: core spine is null, engines are A/B/C', () {
      final m = rm();
      expect(m.branchOf(ResearchIds.genesisCore), isNull);
      expect(m.branchOf(ResearchIds.chipFab), isNull);
      expect(m.branchOf(ResearchIds.basicOverclock), 'A');
      expect(m.branchOf(ResearchIds.ergonomicRig), 'B');
      expect(m.branchOf(ResearchIds.luckyNonce), 'C');
      expect(m.branchOf(ResearchIds.doubleDropManifold), 'C');
    });

    test('each branch resolves to its capstone', () {
      final m = rm();
      expect(m.capstoneIdOf('A'), ResearchIds.centralBank);
      expect(m.capstoneIdOf('B'), ResearchIds.powerCapacitors);
      expect(m.capstoneIdOf('C'), ResearchIds.whalesEye);
    });

    test('branch-consistency: every node prereq is core or the SAME branch', () {
      // This invariant is why RP + branch-depth prereqs can never strand a node.
      final m = rm();
      final byId = {for (final n in m.researchNodes) n.id: n};
      for (final n in m.researchNodes) {
        if (n.branch == null) continue;
        for (final r in n.requirements) {
          final rb = byId[r]?.branch;
          expect(rb == null || rb == n.branch, true,
              reason: '${n.id} (${n.branch}) requires $r ($rb) — cross-branch!');
        }
      }
    });

    test('rpSpent sums completed rpCost; the free core is 0 RP', () {
      final m = rm();
      expect(m.rpSpent, 0);
      complete(m, ResearchIds.genesisCore); // rpCost 0
      complete(m, ResearchIds.chipFab); // rpCost 0
      expect(m.rpSpent, 0);
      complete(m, ResearchIds.basicOverclock); // 1
      complete(m, ResearchIds.centralBank); // 2 (capstone)
      expect(m.rpSpent, 3);
    });

    test('branchesWithCapstoneOwned tracks finished branches', () {
      final m = rm();
      expect(m.branchesWithCapstoneOwned(), isEmpty);
      complete(m, ResearchIds.centralBank);
      expect(m.branchesWithCapstoneOwned(), {'A'});
    });

    test('tryBuy refuses once the RP budget is spent', () {
      final m = rm();
      complete(m, ResearchIds.genesisCore); // free root → engines' roots unlock
      m.refreshUnlocks();
      // Budget 1: one 1-RP node fits.
      expect(m.tryBuy(ResearchIds.basicOverclock, rpBudget: 1), true);
      // A second 1-RP node would exceed the budget of 1.
      expect(m.tryBuy(ResearchIds.ergonomicRig, rpBudget: 1), false);
      // A bigger budget lets it through.
      expect(m.tryBuy(ResearchIds.ergonomicRig, rpBudget: 5), true);
    });

    test('tryBuy enforces prerequisites (branch-depth gate)', () {
      final m = rm();
      // neuralNet needs basicOverclock (unowned) → refused even with a big budget.
      expect(m.tryBuy(ResearchIds.neuralNet, rpBudget: 99), false);
      expect(m.isResearched(ResearchIds.neuralNet), false);
    });
  });
}
