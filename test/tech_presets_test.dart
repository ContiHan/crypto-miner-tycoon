import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/ids.dart';
import 'package:crypto_miner_tycoon/logic/managers/class_manager.dart';
import 'package:crypto_miner_tycoon/providers/game_logic.dart';
import 'package:crypto_miner_tycoon/services/economy_service.dart';
import 'package:crypto_miner_tycoon/services/stash_service.dart';
import 'fakes.dart';

/// TECH PRESETS (Phase 3 QoL): save a build, one-tap re-apply, auto-apply after
/// resets. Presets survive prestige resets; only a full Wipe clears them.
/// TECH V2: nodes are RP-budgeted; a fresh game's budget is 4 RP, and the free
/// core `genesisCore` must be owned before the branch roots unlock.
GameLogic _game(FakeGameRepository repo) => GameLogic(
      gameRepository: repo,
      settingsRepository: FakeSettingsRepository(),
      economyService: EconomyService(),
      stashService: StashService(),
      soundService: FakeSoundService(),
      startTimers: false,
      loadOnStart: false,
    )..clickRng = NoCritRandom();

void main() {
  group('TECH presets', () {
    test('savePreset snapshots completed nodes + auto-names by dominant channel',
        () async {
      final game = _game(FakeGameRepository());
      await game.loadGame();
      // RP now = base + class level; seed a full build so presets have the budget.
      game.debugSelectClass(BtcClass.soloMiner);
      game.debugSetClassLevel(BtcClass.soloMiner, 18);
      game.wallet = 1e15;
      // The Foundry hash spine (all Channel.hash → "Hash Whale").
      game.buyResearch(ResearchIds.genesisCore);
      game.buyResearch(ResearchIds.basicOverclock);
      game.buyResearch(ResearchIds.neuralNet);
      game.buyResearch(ResearchIds.quantumEntanglement);
      game.saveTechPreset();

      expect(game.techPresets.length, 1);
      expect(game.techPresets.first.name, 'Hash Whale'); // dominant = hash
      expect(game.techPresets.first.nodeIds.contains(ResearchIds.neuralNet), true);
      expect(game.activeTechPreset, 0);
    });

    test('preset slots are capped at 3 (oldest dropped)', () async {
      final game = _game(FakeGameRepository());
      await game.loadGame();
      // RP now = base + class level; seed a full build so presets have the budget.
      game.debugSelectClass(BtcClass.soloMiner);
      game.debugSetClassLevel(BtcClass.soloMiner, 18);
      game.wallet = 1e15;
      game.buyResearch(ResearchIds.genesisCore);
      game.buyResearch(ResearchIds.basicOverclock);
      for (var i = 0; i < 4; i++) {
        game.saveTechPreset();
      }
      expect(game.techPresets.length, 3);
    });

    test('applyTechPreset re-buys the saved build after a Hard Fork', () async {
      final game = _game(FakeGameRepository());
      await game.loadGame();
      // RP now = base + class level; seed a full build so presets have the budget.
      game.debugSelectClass(BtcClass.soloMiner);
      game.debugSetClassLevel(BtcClass.soloMiner, 18);
      game.wallet = 1e15;
      game.buyResearch(ResearchIds.genesisCore);
      game.buyResearch(ResearchIds.basicOverclock);
      game.buyResearch(ResearchIds.neuralNet);
      game.buyResearch(ResearchIds.quantumEntanglement);
      game.saveTechPreset();

      // Hard Fork wipes research (needs GovTokens available first).
      game.lifetimeEarnings = 2e9; // enough for a Hard Fork
      game.hardFork();
      expect(game.isResearched(ResearchIds.neuralNet), false, reason: 'wiped');

      game.wallet = 1e15;
      final bought = game.applyTechPreset(0);
      expect(bought, greaterThanOrEqualTo(3));
      expect(game.isResearched(ResearchIds.basicOverclock), true);
      expect(game.isResearched(ResearchIds.neuralNet), true);
      expect(game.isResearched(ResearchIds.quantumEntanglement), true);
    });

    test('overwrite updates ANY slot with the current build (device finding #6)',
        () async {
      final game = _game(FakeGameRepository());
      await game.loadGame();
      // RP now = base + class level; seed a full build so presets have the budget.
      game.debugSelectClass(BtcClass.soloMiner);
      game.debugSetClassLevel(BtcClass.soloMiner, 18);
      game.wallet = 1e15;

      // Slot 0: a hash build. Slot 1: adds a click node.
      game.buyResearch(ResearchIds.genesisCore);
      game.buyResearch(ResearchIds.basicOverclock);
      game.buyResearch(ResearchIds.neuralNet);
      game.saveTechPreset(); // slot 0 = Hash Whale
      game.buyResearch(ResearchIds.ergonomicRig); // Golden Nonce root (click)
      game.saveTechPreset(); // slot 1
      expect(game.techPresets.length, 2);
      final slot0NameBefore = game.techPresets[0].name;

      // Research more, then OVERWRITE slot 0 (the older one).
      game.buyResearch(ResearchIds.quantumEntanglement);
      final ok = game.overwriteTechPreset(0);
      expect(ok, true);
      expect(game.techPresets[0].nodeIds.contains(ResearchIds.quantumEntanglement),
          true,
          reason: 'slot 0 now holds the current build');
      expect(game.techPresets[0].nodeIds.contains(ResearchIds.ergonomicRig), true);
      expect(game.activeTechPreset, 0, reason: 'overwrite makes the slot active');
      expect(game.techPresets.length, 2, reason: 'overwrite does not add a slot');
      expect(game.techPresets[0].name, isNot(equals('')));
      expect(slot0NameBefore, isNotEmpty);
    });

    test('overwrite is a no-op with nothing researched', () async {
      final game = _game(FakeGameRepository());
      await game.loadGame();
      // RP now = base + class level; seed a full build so presets have the budget.
      game.debugSelectClass(BtcClass.soloMiner);
      game.debugSetClassLevel(BtcClass.soloMiner, 18);
      game.wallet = 1e15;
      game.buyResearch(ResearchIds.genesisCore);
      game.buyResearch(ResearchIds.basicOverclock);
      game.saveTechPreset();
      // Clear the completed set → overwriting a slot has nothing to snapshot.
      for (final n in game.researchNodes) {
        n.isCompleted = false;
      }
      expect(game.overwriteTechPreset(0), false);
    });

    test('delete removes a slot and fixes the active pointer', () async {
      final game = _game(FakeGameRepository());
      await game.loadGame();
      // RP now = base + class level; seed a full build so presets have the budget.
      game.debugSelectClass(BtcClass.soloMiner);
      game.debugSetClassLevel(BtcClass.soloMiner, 18);
      game.wallet = 1e15;
      game.buyResearch(ResearchIds.genesisCore);
      game.buyResearch(ResearchIds.basicOverclock);
      game.saveTechPreset(); // 0
      game.buyResearch(ResearchIds.neuralNet);
      game.saveTechPreset(); // 1
      game.buyResearch(ResearchIds.quantumEntanglement);
      game.saveTechPreset(); // 2 (active)
      expect(game.techPresets.length, 3);
      expect(game.activeTechPreset, 2);

      game.deleteTechPreset(0); // delete the first
      expect(game.techPresets.length, 2);
      expect(game.activeTechPreset, 1,
          reason: 'active index shifts down with the hole');

      game.deleteTechPreset(game.activeTechPreset); // delete the active one
      expect(game.activeTechPreset, -1, reason: 'active cleared when deleted');
    });

    test('presets survive a prestige reset and clear on full wipe', () async {
      final repo = FakeGameRepository();
      final g1 = _game(repo);
      await g1.loadGame();
      g1.wallet = 1e15;
      g1.buyResearch(ResearchIds.genesisCore);
      g1.buyResearch(ResearchIds.basicOverclock);
      g1.saveTechPreset();

      final g2 = _game(repo);
      await g2.loadGame();
      expect(g2.techPresets.length, 1, reason: 'preset persisted across reload');
      expect(g2.autoApplyPresets, true);

      await g2.resetGame(); // full Wipe Save
      expect(g2.techPresets.length, 0, reason: 'full wipe clears presets');
    });
  });
}
