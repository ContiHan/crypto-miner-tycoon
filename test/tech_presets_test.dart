import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/ids.dart';
import 'package:crypto_miner_tycoon/providers/game_logic.dart';
import 'package:crypto_miner_tycoon/services/economy_service.dart';
import 'package:crypto_miner_tycoon/services/stash_service.dart';
import 'fakes.dart';

/// TECH PRESETS (Phase 3 QoL): save a build, one-tap re-apply, auto-apply after
/// resets. Presets survive prestige resets; only a full Wipe clears them.
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
      game.wallet = 1e15;
      // Buy the hash spine: basicOverclock (root) then advanced/neuralNet (hash).
      game.buyResearch(ResearchIds.basicOverclock);
      game.buyResearch(ResearchIds.advancedOverclock);
      game.buyResearch(ResearchIds.neuralNet);
      game.saveTechPreset();

      expect(game.techPresets.length, 1);
      expect(game.techPresets.first.name, 'Hash Whale'); // dominant = hash
      expect(game.techPresets.first.nodeIds.contains(ResearchIds.neuralNet), true);
      expect(game.activeTechPreset, 0);
    });

    test('preset slots are capped at 3 (oldest dropped)', () async {
      final game = _game(FakeGameRepository());
      await game.loadGame();
      game.wallet = 1e15;
      game.buyResearch(ResearchIds.basicOverclock);
      for (var i = 0; i < 4; i++) {
        game.saveTechPreset();
      }
      expect(game.techPresets.length, 3);
    });

    test('applyTechPreset re-buys the saved build after a Hard Fork', () async {
      final game = _game(FakeGameRepository());
      await game.loadGame();
      game.wallet = 1e15;
      game.buyResearch(ResearchIds.basicOverclock);
      game.buyResearch(ResearchIds.advancedOverclock);
      game.buyResearch(ResearchIds.neuralNet);
      game.saveTechPreset();

      // Hard Fork wipes research (needs GovTokens available first).
      game.lifetimeEarnings = 2e9; // enough for a Hard Fork
      game.hardFork();
      expect(game.isResearched(ResearchIds.neuralNet), false, reason: 'wiped');

      game.wallet = 1e15;
      final bought = game.applyTechPreset(0);
      expect(bought, greaterThanOrEqualTo(3));
      expect(game.isResearched(ResearchIds.basicOverclock), true);
      expect(game.isResearched(ResearchIds.advancedOverclock), true);
      expect(game.isResearched(ResearchIds.neuralNet), true);
    });

    test('presets survive a prestige reset and clear on full wipe', () async {
      final repo = FakeGameRepository();
      final g1 = _game(repo);
      await g1.loadGame();
      g1.wallet = 1e15;
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
