import 'dart:math';
import '../../core/constants.dart';

/// Prestige currencies beyond the base GovTokens.
///
/// (SKILL S2: the Consensus currency + Soft Fork were removed — repeatable income
/// scaling now comes from the GovToken multiplier + Notoriety. Only Genesis Blocks
/// remain here.)
///
/// New Blockchain: grants Genesis Blocks (GB) earned from GovTokens minted since
/// the last New Blockchain. GB do NOT add raw income; they multiply the GAIN of
/// GovTokens, so every future run farms prestige faster.
class PrestigeSystem {
  // Genesis Blocks (New Blockchain).
  int genesisBlocks = 0;

  /// Cumulative GovTokens ever minted by Hard Forks, and the snapshot taken at
  /// the last New Blockchain. Their difference ([chainGovTokens]) is what the
  /// next Genesis Block count is derived from.
  double totalGovTokensEver = 0;
  double govTokensEverAtLastNewChain = 0;

  // ---- Tier 3: New Blockchain / Genesis Blocks ---------------------------

  /// Always-on multiplier applied to the GAIN of GovTokens.
  /// CONCAVE in genesisBlocks (sqrt) so the Genesis<->GovToken feedback loop
  /// converges instead of running away; 1.0 with no Genesis Blocks, so it has no
  /// effect on the base single-run economy until the deepest prestige tier.
  double get genesisGainMultiplier =>
      1.0 + GameConstants.perGenesisGainBonus * sqrt(genesisBlocks);

  /// The gain multiplier the player would have after banking [extraGenesis] more
  /// Genesis Blocks — same concave curve as [genesisGainMultiplier], so UI
  /// projections never diverge from the value actually applied.
  double genesisGainMultiplierWith(int extraGenesis) =>
      1.0 +
      GameConstants.perGenesisGainBonus * sqrt(genesisBlocks + extraGenesis);

  /// GovTokens minted this "chain" (since the last New Blockchain).
  double chainGovTokens() => totalGovTokensEver - govTokensEverAtLastNewChain;

  /// Genesis Blocks the player would gain by starting a New Blockchain now
  /// (square-root curve over this chain's minted GovTokens).
  int pendingGenesis() {
    final chain = chainGovTokens();
    if (chain < GameConstants.genesisDivisor) return 0;
    // +epsilon so perfect squares don't lose 1 to float error.
    return (sqrt(chain / GameConstants.genesisDivisor) + 1e-9).floor();
  }

  /// Record GovTokens minted by a Hard Fork so tier-3 progress accumulates.
  void recordGovTokensMinted(int amount) {
    totalGovTokensEver += amount;
  }

  /// Apply a New Blockchain: bank the Genesis Blocks, snapshot the chain
  /// baseline. Everything else in the run is reset by GameLogic; the Stash
  /// collection is deliberately preserved.
  void applyNewBlockchain() {
    genesisBlocks += pendingGenesis();
    govTokensEverAtLastNewChain = totalGovTokensEver;
  }

  /// Full wipe (Wipe Save): clears every prestige tier including Genesis Blocks.
  void reset() {
    genesisBlocks = 0;
    totalGovTokensEver = 0;
    govTokensEverAtLastNewChain = 0;
  }
}
