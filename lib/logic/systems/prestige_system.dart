import 'dart:math';
import '../../core/constants.dart';

/// Prestige progression beyond the base GovTokens.
///
/// SKILL S2: the Consensus currency + Soft Fork were removed, and Genesis Blocks
/// became PASSIVE — derived live from the cumulative GovTokens ever minted, with
/// no "New Blockchain" reset to bank them. Genesis Blocks multiply the GAIN of
/// GovTokens (never raw income), so every future run farms prestige faster.
class PrestigeSystem {
  /// Cumulative GovTokens ever minted by Hard Forks — the single source of truth
  /// for the passive Genesis tier (and the perk-unlock progression metric). Only
  /// ever grows in play; a full Wipe Save zeroes it via [reset].
  double totalGovTokensEver = 0;

  /// Genesis Blocks, DERIVED live from [totalGovTokensEver] (no banking, no
  /// reset): floor(sqrt(totalGovTokensEver / genesisDivisor)). Monotonic in play.
  int get genesisBlocks {
    if (totalGovTokensEver < GameConstants.genesisDivisor) return 0;
    // +epsilon so perfect squares don't lose 1 to float error.
    return (sqrt(totalGovTokensEver / GameConstants.genesisDivisor) + 1e-9)
        .floor();
  }

  /// Always-on multiplier applied to the GAIN of GovTokens. CONCAVE in
  /// genesisBlocks (sqrt) — and since genesisBlocks is itself a sqrt of
  /// [totalGovTokensEver], the multiplier grows only like the FOURTH root of
  /// cumulative tokens, so the Genesis<->GovToken feedback loop converges instead
  /// of running away. 1.0 with no Genesis Blocks, so early play is unaffected.
  double get genesisGainMultiplier =>
      1.0 + GameConstants.perGenesisGainBonus * sqrt(genesisBlocks);

  /// Progress (0..1) from the current Genesis Block toward the next, for the
  /// mining-tab progress bar.
  double genesisProgressToNext() {
    final int gb = genesisBlocks;
    final double lo = gb * gb * GameConstants.genesisDivisor;
    final double hi = (gb + 1) * (gb + 1) * GameConstants.genesisDivisor;
    if (hi <= lo) return 0.0;
    final double t = (totalGovTokensEver - lo) / (hi - lo);
    return t.isFinite ? t.clamp(0.0, 1.0) : 0.0;
  }

  /// Record GovTokens minted by a Hard Fork so Genesis progress accumulates.
  void recordGovTokensMinted(int amount) {
    totalGovTokensEver += amount;
  }

  /// Full wipe (Wipe Save): zero the accumulator, which zeroes derived Genesis.
  void reset() {
    totalGovTokensEver = 0;
  }
}
