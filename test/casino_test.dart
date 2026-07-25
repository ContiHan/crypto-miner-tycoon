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
  group('CasinoService (player-favoured EV > 1, bounded)', () {
    test('slots return-to-player is above 1 (player edge)', () {
      expect(CasinoService.slotsReturnToPlayer, greaterThan(1.0));
      expect(CasinoService.slotsReturnToPlayer, closeTo(1.65, 0.03));
    });

    test('empirical slots payout favours the player over many spins', () {
      final c = CasinoService();
      final rng = Random(42);
      int staked = 0, returned = 0;
      for (int i = 0; i < 100000; i++) {
        staked += 100;
        returned += c.spinSlots(100, rng).payout;
      }
      final rtp = returned / staked;
      expect(rtp, greaterThan(1.0), reason: 'the player has the edge');
      expect(rtp, closeTo(CasinoService.slotsReturnToPlayer, 0.03));
    });

    test('hash flip win chance is above 50% (player edge)', () {
      final c = CasinoService();
      final rng = Random(7);
      int wins = 0;
      for (int i = 0; i < 100000; i++) {
        if (c.flipWin(rng)) wins++;
      }
      final rate = wins / 100000;
      expect(rate, closeTo(GameConstants.casinoFlipWinChance, 0.02));
      expect(rate, greaterThan(0.5));
    });

    test('a 25x spin reads as a jackpot with correct payout', () {
      const spin = SlotSpin(['🌙', '🌙', '🌙'], 25.0, 10);
      expect(spin.isJackpot, true);
      expect(spin.payout, 250);
      expect(spin.net, 240);
    });

    test('relay return-to-player is above 1 (player edge)', () {
      expect(CasinoService.plinkoReturnToPlayer, greaterThan(1.0));
      expect(CasinoService.plinkoReturnToPlayer, closeTo(1.55, 0.03));
    });

    test('plinko slot probabilities are a valid distribution (sum to 1)', () {
      double sum = 0;
      for (int k = 0; k <= CasinoService.plinkoRows; k++) {
        sum += CasinoService.plinkoSlotProbability(k);
      }
      expect(sum, closeTo(1.0, 1e-9));
    });

    test('plinko multiplier table matches the row count', () {
      expect(CasinoService.plinkoMultipliers.length,
          CasinoService.plinkoRows + 1);
    });

    test('dropPlinko: slot == number of rights, multiplier matches the bucket',
        () {
      final c = CasinoService();
      final rng = Random(123);
      for (int i = 0; i < 5000; i++) {
        final d = c.dropPlinko(10, rng);
        expect(d.path.length, CasinoService.plinkoRows);
        expect(d.slotIndex, d.path.where((r) => r).length);
        expect(d.slotIndex, inInclusiveRange(0, CasinoService.plinkoRows));
        expect(d.multiplier, CasinoService.plinkoMultipliers[d.slotIndex]);
      }
    });

    test('empirical plinko payout has a house edge over many drops', () {
      final c = CasinoService();
      final rng = Random(2024);
      int staked = 0, returned = 0;
      for (int i = 0; i < 200000; i++) {
        staked += 100;
        returned += c.dropPlinko(100, rng).payout;
      }
      final rtp = returned / staked;
      expect(rtp, greaterThan(1.0), reason: 'the player has the edge');
      expect(rtp, closeTo(CasinoService.plinkoReturnToPlayer, 0.03));
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

    test('playPlinko deducts the bet, credits the payout, counts the play',
        () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.chips = 100;
      final drop = game.playPlinko(10);
      expect(drop, isNotNull);
      expect(game.chips, 100 - 10 + drop!.payout);
      expect(game.casinoSpins, 1);
      expect(game.chips, greaterThanOrEqualTo(0));
    });

    test('playPlinko rejects zero/negative and unaffordable bets', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.chips = 3;
      expect(game.playPlinko(0), isNull);
      expect(game.playPlinko(-5), isNull);
      expect(game.playPlinko(10), isNull); // more than balance
      expect(game.chips, 3, reason: 'no chips created or destroyed');
      expect(game.casinoSpins, 0);
    });

    test('a plinko edge (12x) counts as a jackpot', () async {
      // Seed chosen so an edge bucket (all-left or all-right) occurs.
      final repo = FakeGameRepository();
      GameLogic build(int seed) => GameLogic(
            gameRepository: repo,
            settingsRepository: FakeSettingsRepository(),
            economyService: EconomyService(),
            stashService: StashService(),
            soundService: FakeSoundService(),
            startTimers: false,
            loadOnStart: false,
            casinoRandom: Random(seed),
          );
      final game = build(4);
      await game.loadGame();
      game.chips = 100000;
      var guard = 0;
      while (game.casinoJackpots == 0 && guard++ < 100000) {
        game.playPlinko(1);
      }
      expect(game.casinoJackpots, greaterThan(0),
          reason: 'a 12x edge bucket registers as a jackpot');
    });
  });

  group('SWEEP per-window net cap (anti-farm guardrail)', () {
    test('play is blocked once the window net-gain cap is reached', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.chips = 100000;
      // Already netted the cap in an open window.
      game.casinoWindowStartMs = DateTime.now().millisecondsSinceEpoch;
      game.casinoWindowNet = GameConstants.casinoDailyNetCap;
      expect(game.casinoCapped, true);

      final before = game.chips;
      expect(game.playSlots(10), isNull, reason: 'capped: slots blocked');
      expect(game.playPlinko(10), isNull, reason: 'capped: relay blocked');
      expect(game.playDoubleOrNothing(10), isNull, reason: 'capped: flip blocked');
      expect(game.chips, before, reason: 'no DUST risked while capped');
      expect(game.casinoSpins, 0, reason: 'no spin counted while capped');
    });

    test('the cap window resets after the real-time window elapses', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.chips = 100000;
      // A window opened just over the limit ago is expired.
      game.casinoWindowStartMs = DateTime.now()
          .subtract(const Duration(hours: GameConstants.casinoWindowHours + 1))
          .millisecondsSinceEpoch;
      game.casinoWindowNet = GameConstants.casinoDailyNetCap * 2; // was capped
      expect(game.casinoCapped, false, reason: 'an expired window is not capped');

      // A play opens a fresh window (net reset to 0) and succeeds.
      expect(game.playSlots(1), isNotNull);
      expect(game.casinoWindowNet, lessThan(GameConstants.casinoDailyNetCap),
          reason: 'a fresh window started from 0 net, not the old 2x-cap value');
    });

    test('window net + start persist across a reload', () async {
      final repo = FakeGameRepository();
      GameLogic build() => GameLogic(
            gameRepository: repo,
            settingsRepository: FakeSettingsRepository(),
            economyService: EconomyService(),
            stashService: StashService(),
            soundService: FakeSoundService(),
            startTimers: false,
            loadOnStart: false,
            casinoRandom: Random(1),
          );
      final game = build();
      await game.loadGame();
      game.chips = 100000;
      for (int i = 0; i < 50; i++) {
        game.playSlots(10);
      }
      final net = game.casinoWindowNet;
      final start = game.casinoWindowStartMs;
      expect(start, greaterThan(0));

      final game2 = build();
      await game2.loadGame();
      expect(game2.casinoWindowNet, net, reason: 'window net round-trips');
      expect(game2.casinoWindowStartMs, start,
          reason: 'window start round-trips');
    });
  });
}
