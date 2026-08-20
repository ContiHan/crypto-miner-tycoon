import 'package:crypto_miner_tycoon/providers/game_logic.dart';
import 'package:crypto_miner_tycoon/services/economy_service.dart';
import 'package:crypto_miner_tycoon/services/stash_service.dart';
import 'fakes.dart';

GameLogic createTestGameLogic({
  bool startTimers = false,
  bool loadOnStart = true,
}) {
  final game = GameLogic(
    gameRepository: FakeGameRepository(),

    settingsRepository: FakeSettingsRepository(),
    economyService: EconomyService(),
    stashService: StashService(),
    soundService: FakeSoundService(),
    startTimers: startTimers,

    loadOnStart: loadOnStart,
  );
  // Deterministic mining taps by default (no random crits); tests that exercise
  // crits override this with AlwaysCritRandom.
  game.clickRng = NoCritRandom();
  return game;
}

/// Builds a GameLogic over a FakeGameRepository whose save is preseeded with
/// [save] (merged onto the fake's defaults), for testing load/migration paths.
/// [loadOnStart] is false — call `await game.loadGame()` yourself.
GameLogic createTestGameLogicSeeded(Map<String, dynamic> save) {
  final repo = FakeGameRepository();
  repo.data.addAll(save);
  final game = GameLogic(
    gameRepository: repo,
    settingsRepository: FakeSettingsRepository(),
    economyService: EconomyService(),
    stashService: StashService(),
    soundService: FakeSoundService(),
    startTimers: false,
    loadOnStart: false,
  );
  game.clickRng = NoCritRandom();
  return game;
}
