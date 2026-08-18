import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/ids.dart';
import 'test_helper.dart';

/// F-C: one free respec per era. Clears the TECH tree (uncommitting doctrines)
/// once per era so a mis-committed build can be re-picked without waiting for a
/// fork. Blueprints (the permanent re-tech discount) survive. Every fork refreshes
/// the respec (forks reset research anyway).
void main() {
  group('Free respec (one per era)', () {
    test('unavailable on a fresh era (nothing researched to clear)', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      expect(game.respecAvailable, false,
          reason: 'nothing completed yet — nothing to respec');
      expect(game.respecSpent, false);
    });

    test('becomes available after researching, then clears the tree + is spent',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.wallet = 1e12;
      game.buyResearch(ResearchIds.basicOverclock);
      expect(game.researchNodes.any((n) => n.isCompleted), true);
      expect(game.respecAvailable, true);

      game.respecTech();

      // Every RP-spent pick is cleared; the always-owned free genesis core stays.
      expect(game.researchNodes.any((n) => n.isCompleted && n.rpCost > 0), false,
          reason: 'respec clears every researched (RP-spent) node');
      expect(game.rpSpent, 0);
      expect(game.respecSpent, true);
      expect(game.respecAvailable, false, reason: 'only one per era');
    });

    test('clears owned nodes (frees Research Points + branch capstones)',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      // Own a branch node and its capstone.
      game.researchNodes
          .firstWhere((n) => n.id == ResearchIds.basicOverclock)
          .isCompleted = true;
      game.researchNodes
          .firstWhere((n) => n.id == ResearchIds.centralBank)
          .isCompleted = true;
      expect(game.ownedCapstones(), contains('A'));
      expect(game.rpSpent, greaterThan(0));

      game.respecTech();

      expect(game.ownedCapstones(), isEmpty);
      expect(game.rpSpent, 0, reason: 'respec frees the whole RP budget');
    });

    test('a second respec in the same era is a no-op', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.wallet = 1e12;
      game.buyResearch(ResearchIds.basicOverclock);
      game.respecTech();
      expect(game.respecSpent, true);

      // Re-research something, then try again — still blocked this era.
      game.buyResearch(ResearchIds.basicOverclock);
      expect(game.respecAvailable, false);
      game.respecTech();
      expect(game.researchNodes.any((n) => n.isCompleted), true,
          reason: 'the second respec did nothing — the re-teched node survives');
    });

    test('a fork refreshes the respec', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.wallet = 1e12;
      game.buyResearch(ResearchIds.basicOverclock);
      game.respecTech();
      expect(game.respecSpent, true);

      // A Hard Fork resets research (and the respec).
      game.lifetimeEarnings = 2e9;
      game.hardFork();
      expect(game.respecSpent, false, reason: 'fork refreshes the free respec');
    });

    test('spent-state round-trips across save + reload', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.wallet = 1e12;
      game.buyResearch(ResearchIds.basicOverclock);
      game.respecTech();
      expect(game.respecSpent, true);

      await game.loadGame(); // same fake repo
      expect(game.respecSpent, true, reason: 'respec-spent flag persisted');
    });

    test('a full wipe refreshes the respec', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.wallet = 1e12;
      game.buyResearch(ResearchIds.basicOverclock);
      game.respecTech();
      expect(game.respecSpent, true);

      await game.resetGame();
      expect(game.respecSpent, false, reason: 'full wipe refreshes the respec');
    });
  });
}
