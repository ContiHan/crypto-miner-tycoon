class GameConstants {
  // Economy
  static const double maxSupplySats = 2100000000000000; // per-era thematic cap
  static const double initialBlockReward = 50.0 * 100000000; // 50 BTC in Sats
  static const double miningDivisor = 50000000.0; // legacy; no longer in income

  // Income model (Phase 1 redesign): income/sec =
  //   hashRate * satPerHash * blockRewardFactor * prestigeMult * chaosMult
  // where blockRewardFactor = blockReward / initialBlockReward (1.0 -> 0.5 -> ...).
  // No lifetime-difficulty divider (it collapsed income) — difficulty is now a
  // display-only flavour stat.
  static const double satPerHash = 1.0;

  // Halving as gentle PACING: the gap between halvings doubles, so an early era
  // (~hours) sees 0-1 halvings and income grows before the soft-wall.
  static const int halvingFirstThreshold = 15000; // blocks (~4.2 h at 1 block/s)

  // Prestige (Hard Fork): GovTokens = floor(sqrt(lifetimeSats / govTokenDivisor)).
  // Sub-linear in production and slow enough that token counts stay in the
  // hundreds over weeks (no 4.7M-token explosion).
  static const double govTokenDivisor = 5.0e8;
  static const double perTokenIncomeBonus = 0.10; // +10% income per GovToken

  // Soft Fork (Tier-1 prestige): resets LAB only, grants Consensus (CX) =
  // floor(cbrt(eraSats / consensusDivisor)). Frequent, low-stakes, fast loop.
  static const double consensusDivisor = 1.0e7;
  static const double perConsensusBonus = 0.05; // +5% income per Consensus

  // Cosmetic only: the "fiat / astronomical" price toggle multiplies sats by
  // this to show a big USD-style number. Purely visual, no mechanics.
  static const double cosmeticUsdPerSat = 1000.0;

  // Perks
  static const double perkBaseClickPower = 5.0;
  static const double perkClickPowerGrowth = 2.0; // +2 per level
  static const double perkHashBonusGrowth = 0.10; // +10% per level

  // Research
  static const double researchHashBonus = 0.05; // 5% for basic overclock
  static const double chipFabBonus = 0.20; // 20%
  static const double coolingDiscount = 0.10; // 10%
  static const double solarDiscount = 0.15; // 15%
}
