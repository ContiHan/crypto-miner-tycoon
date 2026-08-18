import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/constants.dart';
import 'package:crypto_miner_tycoon/core/ids.dart';
import 'package:crypto_miner_tycoon/logic/channels.dart';
import 'package:crypto_miner_tycoon/logic/economy/economy_modifiers.dart';
import 'package:crypto_miner_tycoon/logic/systems/keystone_system.dart';
import 'package:crypto_miner_tycoon/providers/game_logic.dart';
import 'package:crypto_miner_tycoon/services/economy_service.dart';
import 'package:crypto_miner_tycoon/services/stash_service.dart';
import 'fakes.dart';

void main() {
  group('DOUBLE-DROP attribute (TECH V2 — Channel.doubleDrop)', () {
    EconomyModifiers modsFor(Channels ch) => EconomyModifiers(
          channels: () => ch,
          keystones: () => KeystoneModifiers.none,
        );

    test('doubleDropChance is 0 with no sources', () {
      expect(modsFor(Channels()).doubleDropChance, 0.0);
    });

    test('doubleDropChance sums the doubleDrop channel', () {
      final ch = Channels()..add(Channel.doubleDrop, 0.15);
      expect(modsFor(ch).doubleDropChance, closeTo(0.15, 1e-9));
    });

    test('doubleDropChance sum-clamps to doubleDropMax (0.25), never past it', () {
      // C6 (+0.15) + C8 (+0.10) + a keystone push must NOT stack past the cap.
      final ch = Channels()
        ..add(Channel.doubleDrop, 0.15)
        ..add(Channel.doubleDrop, 0.10)
        ..add(Channel.doubleDrop, 0.20); // 0.45 raw
      expect(modsFor(ch).doubleDropChance, GameConstants.doubleDropMax);
      expect(modsFor(ch).doubleDropChance, 0.25);
    });

    test('doubleDrop is distinct from fortune (quality) — separate channels', () {
      final ch = Channels()..add(Channel.fortune, 0.20);
      final m = modsFor(ch);
      expect(m.fortuneBonus, closeTo(0.20, 1e-9)); // quality lever moves
      expect(m.doubleDropChance, 0.0); // count lever untouched
    });
  });

  group('DOUBLE-DROP crate banking + drain (contract behind the reveal UI)', () {
    GameLogic makeGame() => GameLogic(
          gameRepository: FakeGameRepository(),
          settingsRepository: FakeSettingsRepository(),
          economyService: EconomyService(),
          stashService: StashService(),
          soundService: FakeSoundService(),
          startTimers: false,
          loadOnStart: false,
          crateRandom: AlwaysCritRandom(), // nextDouble 0.0 → always under the chance
        );

    test('a proc banks exactly one bonus crate that drainBonusCrates returns once',
        () async {
      final game = makeGame();
      await game.loadGame();
      // Double-Drop Manifold grants the doubleDrop chance (+0.15).
      game.researchNodes
          .firstWhere((n) => n.id == ResearchIds.doubleDropManifold)
          .isCompleted = true;
      expect(game.doubleDropChance, greaterThan(0));
      game.chips = 1000;

      final won = game.buyCrate(CrateTier.scrap);
      expect(won, isNotNull, reason: 'the primary crate opened');

      final bonus = game.drainBonusCrates();
      expect(bonus.length, 1, reason: 'the double-drop banked one bonus crate');
      expect(game.drainBonusCrates(), isEmpty,
          reason: 'draining clears the pending queue (no re-reveal)');
    });

    test('no bonus crate is banked when the chance is 0', () async {
      final game = makeGame();
      await game.loadGame();
      expect(game.doubleDropChance, 0.0);
      game.chips = 1000;
      game.buyCrate(CrateTier.scrap);
      expect(game.drainBonusCrates(), isEmpty);
    });
  });
}
