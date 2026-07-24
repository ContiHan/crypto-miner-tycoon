class GameConstants {
  // Economy
  static const double maxSupplySats = 2100000000000000; // per-era thematic cap

  // Endgame (RPG Phase 5): the true "own all the Bitcoin" win is a MONOTONIC
  // cumulative-ever counter (lifetimeEverSats) that survives every prestige
  // reset — distinct from the per-era maxSupplySats soft-wall above. A whale
  // mines a per-era 21M-worth (2.1e15) in ~19h, so the win target is a separate,
  // larger number: 2.1e17 sats (~100x the entire supply — "more BTC than will
  // ever exist"). The whale crosses it at ~14 sim-days; the real ~1-year pace is
  // a Phase-6 [TUNE]. INVARIANT: must stay > maxSupplySats so a legacy save
  // (seeded from lifetimeEarnings <= 2.1e15) can never falsely win and at least
  // one prestige is always required to finish.
  static const double endgameTargetSats = 2.1e17;

  // Each ending reached grants a permanent New Genesis (NG+) prestige-gain
  // bonus: trophyGainMultiplier = 1 + perWinTrophyBonus * winCount. [TUNE]
  static const double perWinTrophyBonus = 0.10;
  static const double initialBlockReward = 50.0 * 100000000; // 50 BTC in Sats
  static const double miningDivisor = 50000000.0; // legacy; no longer in income

  // Income model (Phase 1 redesign): income/sec =
  //   hashRate * satPerHash * blockRewardFactor * prestigeMult * chaosMult
  // where blockRewardFactor = blockReward / initialBlockReward (1.0 -> 0.5 -> ...).
  // No lifetime-difficulty divider (it collapsed income) — difficulty is now a
  // display-only flavour stat.
  static const double satPerHash = 1.0;

  // Channel softcaps (RPG Phase 2c retune). Additive channel bonuses stack
  // cheaply (many small ~2-6% perk levels), so past a GENEROUS threshold each
  // channel decelerates (diminishing returns) instead of running the economy
  // away. Below *SoftStart the channel multiplier is untouched; above it,
  // applied = start * (mult / start)^channelSoftPower. This is a runaway
  // BACKSTOP — the small per-level perk %s do the primary pacing, the softcap
  // only catches a whale who stacks a channel into the hundreds of percent.
  static const double hashSoftStart = 4.0; // hash decelerates past 4x
  static const double incomeSoftStart = 3.0; // income decelerates past 3x
  static const double clickSoftStart = 3.0; // click decelerates past 3x
  static const double channelSoftPower = 0.6; // <1 = diminishing returns

  // Halving as gentle PACING: the gap between halvings doubles, so an early era
  // (~hours) sees 0-1 halvings and income grows before the soft-wall.
  static const int halvingFirstThreshold = 15000; // blocks (~4.2 h at 1 block/s)

  // Prestige (Hard Fork): GovTokens = floor(sqrt(lifetimeSats / govTokenDivisor)).
  // Sub-linear in production and slow enough that token counts stay in the
  // hundreds over weeks (no 4.7M-token explosion).
  static const double govTokenDivisor = 5.0e8;
  static const double perTokenIncomeBonus = 0.50; // income bonus = 0.50*sqrt(GT)

  // Soft Fork (Tier-1 prestige): resets LAB only, grants Consensus (CX) =
  // floor(cbrt(eraSats / consensusDivisor)). Frequent, low-stakes, fast loop.
  // Income bonus is CONCAVE in CX (perConsensusBonus * sqrt(consensus)) so a
  // fast/cheap soft-fork loop can't pump the multiplier without bound.
  static const double consensusDivisor = 2.0e9;
  static const double perConsensusBonus = 0.10; // income bonus = 0.10*sqrt(CX)

  // New Blockchain (Tier-3 prestige): resets almost everything (keeps only the
  // permanent Stash collection + banked Genesis Blocks), grants Genesis Blocks
  // (GB) = floor(sqrt(chainGovTokens / genesisDivisor)) where chainGovTokens is
  // the GovTokens minted since the last New Blockchain. GB do NOT add raw income;
  // they multiply the GAIN of the two lower prestige currencies (Consensus +
  // GovTokens), so each New Blockchain makes every future run farm prestige
  // faster instead of stacking yet another raw income multiplier. The multiplier
  // is CONCAVE in GB (1 + perGenesisGainBonus*sqrt(GB)) so the Genesis<->GovToken
  // feedback loop converges instead of running away.
  static const double genesisDivisor = 65000.0; // 65k chain-GovTokens -> 1 GB
  static const double perGenesisGainBonus = 0.5; // gain x = 1 + 0.5*sqrt(GB)

  // Achievements: each NORMAL (non-secret) achievement grants this much permanent
  // "Notoriety" income bonus. Its own lane (off the perk/lab budget) and bounded
  // by the fixed achievement count, so it can't run away.
  static const double perAchievementNotoriety = 0.01; // +1% income each

  // Casino (SIMULATED gambling — in-game Micro-Chips only, no real value).
  // Double-or-Nothing win chance < 50% gives the house edge (EV = 0.48*2 = 0.96).
  // Slots have their own weighted paytable in CasinoService (EV ~0.90). Both
  // odds are disclosed in-app for compliance.
  static const double casinoFlipWinChance = 0.48;

  // Cosmetic only: the "fiat / astronomical" price toggle multiplies sats by
  // this to show a big USD-style number. Purely visual, no mechanics.
  static const double cosmeticUsdPerSat = 1000.0;

  // Mining tap "critical hit" (pure game feel): a small chance for a tap to pay
  // out a multiple, with a gold float + heavy haptic + screen shake. Cosmetic
  // thrill only — the estimated-click readout stays the non-crit value.
  static const double clickCritChance = 0.06; // ~6% of taps crit (base)
  static const double clickCritMultiplier = 5.0; // crit taps pay 5x
  // Luck scales the crit chance up to this hard cap (keeps it a thrill, not the
  // main income source).
  static const double clickCritChanceCap = 0.25;

  // Luck may nudge casino winnings up, but the realized return-to-player is
  // clamped to this so every game stays a negative-EV chip sink (< 1) — the
  // simulated casino must never become +EV (Google Play compliance).
  static const double casinoRtpCap = 0.97;

  // RPG classes + Mastery (Phase 3). A class is picked at each New Blockchain
  // and reshapes the run via small additive channel weightings (softcapped like
  // every other bonus) plus a prestige-gain multiplier. Mastery is permanent
  // (survives everything but a full wipe) and is the "play them all" driver.
  //
  // Mastery XP earned when a chain ends (New Blockchain) = the GovTokens minted
  // during that chain, credited to the class you played it as. Mastery level is
  // CONCAVE (sqrt) so it keeps growing but never runs away.
  static const double masteryXpDivisor = 10000.0; // level = floor(sqrt(xp/this))
  // Each TOTAL mastery level (summed across all classes) grants this much
  // permanent hash AND income bonus, for every class including Prospector. Tiny
  // and softcapped, so mastering all four is a gentle nudge, not a power spike.
  static const double masteryBonusPerLevel = 0.005; // +0.5% hash & income / level

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
