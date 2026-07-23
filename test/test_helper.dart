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
