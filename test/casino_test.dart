import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/constants.dart';
import 'package:crypto_miner_tycoon/services/casino_service.dart';
import 'package:crypto_miner_tycoon/services/economy_service.dart';
import 'package:crypto_miner_tycoon/services/stash_service.dart';
import 'package:crypto_miner_tycoon/providers/game_logic.dart';
import 'fakes.dart';
import 'test_helper.dart';

void main() {
  group('CasinoService (compliance: EV < 1, disclosed odds)', () {
    test('slots return-to-player is below 1 (a chip sink)', () {
      expect(CasinoService.slotsReturnToPlayer, lessThan(1.0));
      expect(CasinoService.slotsReturnToPlayer, closeTo(0.90, 0.01));
    });

    test('empirical slots payout has a house edge over many spins', () {
      final c = CasinoService();
      final rng = Random(42);
      int staked = 0, returned = 0;
      for (int i = 0; i < 100000; i++) {
        staked += 100;
        returned += c.spinSlots(100, rng).payout;
      }
      final rtp = returned / staked;
      expect(rtp, lessThan(1.0), reason: 'house always keeps an edge');
      expect(rtp, closeTo(CasinoService.slotsReturnToPlayer, 0.03));
    });

    test('double-or-nothing win chance is sub-50% (house edge)', () {
      final c = CasinoService();
      final rng = Random(7);
      int wins = 0;
      for (int i = 0; i < 100000; i++) {
        if (c.flipWin(rng)) wins++;
      }
      final rate = wins / 100000;
      expect(rate, closeTo(GameConstants.casinoFlipWinChance, 0.02));
      expect(rate, lessThan(0.5));
    });

    test('a 25x spin reads as a jackpot with correct payout', () {
      const spin = SlotSpin(['🌙', '🌙', '🌙'], 25.0, 10);
      expect(spin.isJackpot, true);
      expect(spin.payout, 250);
      expect(spin.net, 240);
    });
  });

  group('Casino in GameLogic', () {
    test('playSlots deducts the bet, credits the payout, counts the spin',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.chips = 100;
      final spin = game.playSlots(10);
      expect(spin, isNotNull);
      expect(game.chips, 100 - 10 + spin!.payout);
      expect(game.casinoSpins, 1);
    });

    test('playSlots rejects a bet larger than the chip balance', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.chips = 3;
      expect(game.playSlots(10), isNull);
      expect(game.chips, 3, reason: 'no chips are risked when unaffordable');
      expect(game.casinoSpins, 0);
    });

    test('double-or-nothing deducts and never goes negative', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.chips = 50;
      final win = game.playDoubleOrNothing(10);
      expect(win, isNotNull);
      expect(game.chips, win! ? 50 - 10 + 20 : 50 - 10);
      expect(game.chips, greaterThanOrEqualTo(0));
      expect(game.casinoSpins, 1);
    });

    test('rejects zero or negative bets (no chip printing exploit)', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.chips = 100;
      expect(game.playSlots(0), isNull);
      expect(game.playSlots(-5), isNull);
      expect(game.playDoubleOrNothing(0), isNull);
      expect(game.playDoubleOrNothing(-5), isNull);
      expect(game.chips, 100, reason: 'no chips created or destroyed');
      expect(game.casinoSpins, 0);
    });

    test('double-or-nothing rejects a bet larger than the balance', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.chips = 3;
      expect(game.playDoubleOrNothing(10), isNull);
      expect(game.chips, 3);
      expect(game.casinoSpins, 0);
    });

    test('casinoSpins persists across a reload', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.chips = 1000;
      for (int i = 0; i < 5; i++) {
        game.playSlots(10);
      }
      expect(game.casinoSpins, 5);
      await game.loadGame();
      expect(game.casinoSpins, 5, reason: 'casinoSpins round-trips');
    });

    test('a jackpot counts, unlocks the secret achievement, and persists',
        () async {
      final repo = FakeGameRepository();
      GameLogic build() => GameLogic(
            gameRepository: repo,
            settingsRepository: FakeSettingsRepository(),
            economyService: EconomyService(),
            stashService: StashService(),
            soundService: FakeSoundService(),
            startTimers: false,
            loadOnStart: false,
            casinoRandom: Random(999), // deterministic spins
          );

      final game = build();
      await game.loadGame();
      game.chips = 100000;
      var guard = 0;
      while (game.casinoJackpots == 0 && guard++ < 30000) {
        game.playSlots(1);
      }
      expect(game.casinoJackpots, greaterThan(0),
          reason: 'seeded spins hit the jackpot within the cap');
      expect(game.isAchievementUnlocked('secret_jackpot'), true);
      final jackpots = game.casinoJackpots;

      // Reload from the same repo (each spin saved).
      final game2 = build();
      await game2.loadGame();
      expect(game2.casinoJackpots, jackpots, reason: 'casinoJackpots persists');
      expect(game2.isAchievementUnlocked('secret_jackpot'), true);
    });

    test("'Feeling Lucky' achievement unlocks after 25 plays", () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.chips = 100000;
      for (int i = 0; i < 25; i++) {
        game.playSlots(1);
      }
      expect(game.casinoSpins, 25);
      expect(game.isAchievementUnlocked('casino_25'), true);
    });
  });
}
