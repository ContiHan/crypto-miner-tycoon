import 'dart:math';
import '../../core/constants.dart';

/// Multi-tier prestige currencies beyond the base GovTokens.
///
/// Tier 1 — Soft Fork: resets LAB only, grants Consensus (CX). CX is an "era"
/// currency earned from sats mined since the last Soft Fork; each CX gives a
/// small always-on income bonus. (GovTokens/Hard Fork stay in GameLogic for now;
/// New Blockchain / Genesis Blocks will be added here next.)
class PrestigeSystem {
  int consensus = 0;
  double lifetimeAtLastSoftFork = 0;

  /// Sats earned this Soft-Fork era.
  double eraSats(double lifetimeEarnings) =>
      lifetimeEarnings - lifetimeAtLastSoftFork;

  /// Consensus the player would gain by soft-forking now (cube-root curve).
  int pendingConsensus(double lifetimeEarnings) {
    final era = eraSats(lifetimeEarnings);
    if (era < GameConstants.consensusDivisor) return 0;
    // +epsilon so perfect cubes don't lose 1 to float error (cbrt(8)=1.9999…).
    return (pow(era / GameConstants.consensusDivisor, 1 / 3) + 1e-9).floor();
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

  void reset() {
    consensus = 0;
    lifetimeAtLastSoftFork = 0;
  }
}
