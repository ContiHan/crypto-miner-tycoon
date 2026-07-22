import 'dart:math';
import '../../core/constants.dart';

/// Multi-tier prestige currencies beyond the base GovTokens.
///
/// Tier 1 — Soft Fork: resets LAB only, grants Consensus (CX). CX is an "era"
/// currency earned from sats mined since the last Soft Fork; each CX gives a
/// small always-on income bonus.
///
/// Tier 3 — New Blockchain: resets almost everything (keeps only the permanent
/// Stash collection), grants Genesis Blocks (GB) earned from GovTokens minted
/// since the last New Blockchain. GB do NOT add raw income; they multiply the
/// GAIN of the two lower prestige currencies (Consensus + GovTokens), so every
/// future run farms prestige faster. (GovTokens/Hard Fork themselves stay in
/// GameLogic for now.)
class PrestigeSystem {
  // Tier 1 — Consensus (Soft Fork).
  int consensus = 0;
  double lifetimeAtLastSoftFork = 0;

  // Tier 3 — Genesis Blocks (New Blockchain).
  int genesisBlocks = 0;

  /// Cumulative GovTokens ever minted by Hard Forks, and the snapshot taken at
  /// the last New Blockchain. Their difference ([chainGovTokens]) is what the
  /// next Genesis Block count is derived from.
  double totalGovTokensEver = 0;
  double govTokensEverAtLastNewChain = 0;

  // ---- Tier 3: New Blockchain / Genesis Blocks ---------------------------

  /// Always-on multiplier applied to the GAIN of both Consensus and GovTokens.
  /// 1.0 with no Genesis Blocks, so it has no effect on the base single-run
  /// economy until the player reaches the deepest prestige tier.
  double get genesisGainMultiplier =>
      1.0 + genesisBlocks * GameConstants.perGenesisGainBonus;

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
  /// baseline, and wipe the (era-scoped) Consensus. Everything else in the run
  /// is reset by GameLogic; the Stash collection is deliberately preserved.
  void applyNewBlockchain() {
    genesisBlocks += pendingGenesis();
    govTokensEverAtLastNewChain = totalGovTokensEver;
    consensus = 0;
    lifetimeAtLastSoftFork = 0;
  }

  // ---- Tier 1: Consensus (Soft Fork) -------------------------------------

  /// Sats earned this Soft-Fork era.
  double eraSats(double lifetimeEarnings) =>
      lifetimeEarnings - lifetimeAtLastSoftFork;

  /// Consensus the player would gain by soft-forking now (cube-root curve,
  /// scaled by the Genesis gain multiplier).
  int pendingConsensus(double lifetimeEarnings) {
    final era = eraSats(lifetimeEarnings);
    if (era < GameConstants.consensusDivisor) return 0;
    // +epsilon BEFORE scaling so perfect cubes don't lose 1 to float error
    // (cbrt(27)=2.9999…); adding it after the gain multiplier would let the
    // amplified error round 9 down to 8.
    final base = pow(era / GameConstants.consensusDivisor, 1 / 3).toDouble();
    return ((base + 1e-9) * genesisGainMultiplier).floor();
  }

  /// Always-on income bonus from held Consensus (added into the prestige channel).
  double get consensusBonus => consensus * GameConstants.perConsensusBonus;

  /// Apply a Soft Fork: bank the CX and start a new era.
  void applySoftFork(double lifetimeEarnings) {
    consensus += pendingConsensus(lifetimeEarnings);
    lifetimeAtLastSoftFork = lifetimeEarnings;
  }

  /// A Hard Fork wipes the Consensus era (CX is era-scoped).
  void onHardFork() {
    consensus = 0;
    lifetimeAtLastSoftFork = 0;
  }

  /// Full wipe (Wipe Save): clears every prestige tier including Genesis Blocks.
  void reset() {
    consensus = 0;
    lifetimeAtLastSoftFork = 0;
    genesisBlocks = 0;
    totalGovTokensEver = 0;
    govTokensEverAtLastNewChain = 0;
  }
}
