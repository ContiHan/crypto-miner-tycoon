import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/ids.dart';
import 'package:crypto_miner_tycoon/providers/game_logic.dart';
import 'package:crypto_miner_tycoon/services/economy_service.dart';
import 'package:crypto_miner_tycoon/services/stash_service.dart';
import 'fakes.dart';
import 'test_helper.dart';

/// Device finding #2: the Fusion Rig used to gate on riding a *Bull Run* — a rare
/// market event nobody can force, which stalled the ordered rig reveal (fatal in
/// a Speed Run). It now gates on witnessing ANY market event, counted globally
/// (any tab), so it is actually reachable.
void main() {
  group('Fusion rig gates on any market event (#2)', () {
    test('hint reads "Witness any market event"', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      expect(game.rigUnlockHint(RigIds.fusionRig), 'Witness any market event');
    });

    test('one event reveals the fusion rig', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.wallet = 1e18;
      game.buyRig(RigIds.quantumRig); // fusion's predecessor is now owned/visible

      expect(game.visibleRigs.any((r) => r.id == RigIds.fusionRig), false,
          reason: 'fusion stays gated until an event is witnessed');

      game.eventsSeen += 1; // witness a single market event (good or bad)
      game.debugEvaluateAchievements(); // refreshes rig reveals

      expect(game.visibleRigs.any((r) => r.id == RigIds.fusionRig), true,
          reason: 'any one market event reveals fusion');
    });

    test('eventsSeen persists across save + reload', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.eventsSeen = 7;
      await game.debugSave();
      await game.loadGame();
      expect(game.eventsSeen, 7);
    });

    test('a pre-rename save (bullRunsSeen) carries its count forward', () async {
      final repo = FakeGameRepository();
      repo.data
        ..remove('eventsSeen')
        ..['bullRunsSeen'] = 4;
      final game = GameLogic(
        gameRepository: repo,
        settingsRepository: FakeSettingsRepository(),
        economyService: EconomyService(),
        stashService: StashService(),
        soundService: FakeSoundService(),
        startTimers: false,
        loadOnStart: false,
      );
      await game.loadGame();
      expect(game.eventsSeen, 4,
          reason: 'old bullRunsSeen key still seeds the event baseline');
    });
  });
}
