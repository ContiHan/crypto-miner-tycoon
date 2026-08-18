import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/core/ids.dart';
import 'test_helper.dart';

/// TECH is RP-only, so re-teching a saved build after a Soft Fork is FREE — it
/// re-spends the Research-Point budget, never BTC. Locking that in so a future
/// change can't silently re-introduce a BTC charge for research: the re-tech must
/// apply even at a ZERO wallet (a BTC-costed re-tech could not).
void main() {
  test('Soft Fork resets TECH; re-applying the preset re-teches for free',
      () async {
    final game = createTestGameLogic(loadOnStart: false);
    await game.loadGame();
    game.wallet = 1e12;
    game.buyResearch(ResearchIds.basicOverclock); // complete a node
    game.saveTechPreset(); // snapshot the build

    game.wallet = 1e12;
    game.lifetimeEarnings = 1e13; // reach a soft-fork threshold
    game.softFork();
    expect(game.wallet, 1e12,
        reason: 'a Soft Fork resets TECH only — money is kept');
    expect(
        game.researchNodes
            .firstWhere((n) => n.id == ResearchIds.basicOverclock)
            .isCompleted,
        false,
        reason: 'research was reset by the fork');

    // Broke on purpose: a BTC-costed re-tech could not run. RP-only can.
    game.wallet = 0;
    final bought = game.applyTechPreset(0);
    expect(bought, greaterThan(0),
        reason: 'RP-only re-tech applies even at a 0 wallet');
    expect(
        game.researchNodes
            .firstWhere((n) => n.id == ResearchIds.basicOverclock)
            .isCompleted,
        true,
        reason: 'the preset re-teched the node');
    expect(game.wallet, 0, reason: 'RP-only: re-teching charged no BTC');
  });
}
