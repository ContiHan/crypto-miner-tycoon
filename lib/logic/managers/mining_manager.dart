import 'dart:math';
import '../../core/constants.dart';

class MiningManager {
  // State
  double blockReward = GameConstants.initialBlockReward;
  int blocksMined = 0;
  int nextHalvingThreshold = 5000;
  double bitcoinExchangeRate = 1.0;

  // Dependencies on GameLogic state (passed in or callbacks) could be tricky.
  // Instead, we return results of mining ticks.

  MiningManager();

  void reset() {
    blockReward = GameConstants.initialBlockReward;
    blocksMined = 0;
    nextHalvingThreshold = 5000;
    bitcoinExchangeRate = 1.0;
  }

  void hardForkReset() {
    blocksMined = 0;
    blockReward = GameConstants.initialBlockReward;
    nextHalvingThreshold = 5000;
    // bitcoinExchangeRate is NOT reset on hard fork completely, it's boosted, but logic in GameLogic did:
    // bitcoinExchangeRate *= (1.0 + tokensToClaim);
    // AND then calls _saveGame.
    // Wait, GameLogic.hardFork() says:
    // bitcoinExchangeRate *= (1.0 + tokensToClaim);
    // ...
    // blocksMined = 0;
    // blockReward = ...;
    // So Rate is persistent/boosted.
  }

  // Calculate Network Difficulty
  double calculateNetworkDifficulty(double totalMined) {
    if (totalMined >= GameConstants.maxSupplySats) return double.infinity;

    // 1. Asymptote
    double asymptote = 0.0;
    if (totalMined > 0) {
      asymptote =
          100.0 / pow(1.0 - (totalMined / GameConstants.maxSupplySats), 2) -
          100.0;
    }

    // 2. Linear Growth
    double linearGrowth = totalMined / 1000.0;

    return 100.0 + linearGrowth + asymptote;
  }

  // Returns the amount earned in this tick (or click)
  double calculateMiningIncome({
    required double hashRate,
    required double difficulty,
    required double prestigeMultiplier,
    required double chaosMultiplier,
    required double lifetimeEarnings,
  }) {
    if (difficulty.isInfinite) return 0;
    if (hashRate <= 0) return 0;

    double baseReward = hashRate / difficulty;
    double adjustedReward = blockReward / GameConstants.miningDivisor;
    double incomeSats =
        baseReward * adjustedReward * prestigeMultiplier * chaosMultiplier;

    // Cap at Max Supply
    if (lifetimeEarnings + incomeSats > GameConstants.maxSupplySats) {
      incomeSats = GameConstants.maxSupplySats - lifetimeEarnings;
    }

    return incomeSats;
  }

  // Returns true if halving occurred
  bool checkHalving() {
    if (blocksMined >= nextHalvingThreshold) {
      blockReward /= 2;
      nextHalvingThreshold += 10000;
      return true;
    }
    return false;
  }

  void incrementBlocksMined() {
    blocksMined++;
  }
}
