import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/ids.dart';
import 'test_helper.dart';

/// Owner asked whether a Soft Fork's blueprint auto-apply re-teches WITHOUT
/// charging BTC. It does charge — this locks that in so a future change can't
/// silently make re-tech free. (It *looks* free because a Soft Fork keeps your
/// whole wallet + blueprints discount the cost, so the dip is tiny.)
void main() {
  test('Soft Fork keeps the wallet; auto-apply re-teches and CHARGES BTC',
      () async {
    final game = createTestGameLogic(loadOnStart: false);
    await game.loadGame();
    game.wallet = 1e12;
    game.buyRig(RigIds.cpuRig); // hashrate > 0, so the tick's auto-apply runs
    game.buyResearch(ResearchIds.basicOverclock); // completes + records a blueprint
    game.saveTechPreset(); // snapshot the build; auto-apply defaults ON
    expect(game.autoApplyPresets, true);

    game.wallet = 1e12; // top back up
    game.lifetimeEarnings = 1e13; // reach a soft-fork threshold

    game.softFork();
    expect(game.wallet, 1e12, reason: 'a Soft Fork resets TECH only — money is kept');
    expect(
        game.researchNodes
            .firstWhere((n) => n.id == ResearchIds.basicOverclock)
            .isCompleted,
        false,
        reason: 'research was reset by the fork');

    final walletAfterFork = game.wallet;
    game.debugTick(); // auto-apply rebuilds the preset

    expect(
        game.researchNodes
            .firstWhere((n) => n.id == ResearchIds.basicOverclock)
            .isCompleted,
        true,
        reason: 'auto-apply re-teched the node');
    expect(game.wallet, lessThan(walletAfterFork),
        reason: 'auto-apply is NOT free — it charged the discounted re-tech cost');
  });
}
