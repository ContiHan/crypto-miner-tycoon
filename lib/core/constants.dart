class GameConstants {
  // Economy
  static const double maxSupplySats = 2100000000000000;
  static const double initialBlockReward = 50.0 * 100000000; // 50 BTC in Sats
  static const double miningDivisor = 50000000.0;

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
