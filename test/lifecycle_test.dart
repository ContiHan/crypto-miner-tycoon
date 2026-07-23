import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/providers/game_logic.dart';
import 'package:crypto_miner_tycoon/services/economy_service.dart';
import 'package:crypto_miner_tycoon/services/stash_service.dart';
import 'package:crypto_miner_tycoon/core/ids.dart';
import 'fakes.dart';

GameLogic _gameWith(FakeGameRepository repo) => GameLogic(
  gameRepository: repo,
  settingsRepository: FakeSettingsRepository(),
  economyService: EconomyService(),
  stashService: StashService(),
  soundService: FakeSoundService(),
  startTimers: false,
  loadOnStart: false,
);

FakeGameRepository _repoWithOneRig() {
  final repo = FakeGameRepository();
  repo.data['rigs'] = [
    {'id': RigIds.cpuRig, 'amount': 1},
  ];
  return repo;
}

void main() {
  group('App lifecycle (bug #4)', () {
    test('onAppResumed credits background time and accrues full blocks',
        () async {
      final repo = _repoWithOneRig();
      final game = _gameWith(repo);
      await game.loadGame();
      expect(game.blocksMined, 0);

      // Simulate the app having been backgrounded for 7500 seconds.
      repo.data['last_save_time'] = DateTime.now()
          .subtract(const Duration(seconds: 7500))
          .millisecondsSinceEpoch;

      await game.onAppResumed();

      // 1 second == 1 block, so 7500s must yield exactly 7500 blocks. The old
      // truncating offline loop capped this at 5000 (lost ~33% of progress).
      expect(game.blocksMined, 7500);
      expect(game.wallet, greaterThan(0));
      expect(
        game.offlineEarningsAmount,
        isNotNull,
        reason: 'a long gap should surface the welcome-back dialog',
      );
    });

    test('onAppResumed does NOT credit when timers never stopped (inactive->resumed)',
        () async {
      final repo = _repoWithOneRig();
      final game = _gameWith(repo);
      await game.loadGame();

      // Simulate an inactive->resumed cycle: the live timers were never stopped
      // (onAppPaused never ran), so income kept being credited by the 1s tick.
      game.debugTimersActive = true;
      final walletBefore = game.wallet;
      repo.data['last_save_time'] = DateTime.now()
          .subtract(const Duration(seconds: 300))
          .millisecondsSinceEpoch;

      await game.onAppResumed();

      expect(game.wallet, walletBefore,
          reason: 'must not re-credit a window the live timer already earned');
      expect(game.offlineEarningsAmount, isNull,
          reason: 'no offline reconciliation without a real pause');
    });

    test('a short background gap is reconciled silently', () async {
      final repo = _repoWithOneRig();
      final game = _gameWith(repo);
      await game.loadGame();

      repo.data['last_save_time'] = DateTime.now()
          .subtract(const Duration(seconds: 30))
          .millisecondsSinceEpoch;

      await game.onAppResumed();

      expect(game.wallet, greaterThan(0), reason: 'income is still credited');
      expect(
        game.offlineEarningsAmount,
        isNull,
        reason: 'a sub-threshold gap must not pop the welcome-back dialog',
      );
    });

    test('onAppPaused persists state and refreshes the timestamp', () async {
      final repo = FakeGameRepository();
      final game = _gameWith(repo);
      await game.loadGame();

      game.wallet = 4242;
      repo.data['last_save_time'] = 0;

      await game.onAppPaused();

      expect(repo.data['wallet'], 4242, reason: 'state is saved on pause');
      expect(
        repo.data['last_save_time'] as int,
        greaterThan(0),
        reason: 'timestamp refreshed so resume/cold-start can measure the gap',
      );
    });

    test('a not-yet-loaded game never overwrites the save (bug #1 guard)',
        () async {
      final repo = FakeGameRepository();
      repo.data['wallet'] = 9999.0;

      // loadOnStart:false => loadGame never runs => _isLoaded stays false.
      final game = _gameWith(repo);
      game.wallet = 0;

      await game.onAppPaused();

      expect(
        repo.data['wallet'],
        9999.0,
        reason: 'a blank default state must not clobber the real save on disk',
      );
    });
  });
}
