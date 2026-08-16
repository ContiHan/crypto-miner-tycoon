class GameConstants {
  // Economy
  static const double maxSupplySats = 2100000000000000; // 21M BTC in sats

  // THE LAST SATOSHI (endgame). The win is thematically honest to Bitcoin:
  // mine one full 21,000,000-coin supply within a SINGLE era. The per-era income
  // cap (maxSupplySats) is inviolable, so the win latches the instant a run's
  // lifetimeEarnings reaches it — no "own a multiple of all Bitcoin" counter.
  // After the credits, the post-game loop is Back in Time (a timed re-mine).
  static const double initialBlockReward = 50.0 * 100000000; // 50 BTC in Sats

  // OFFLINE YIELD (attribute). Fraction of the live per-second rate earned while
  // the app is closed. Base 0.70 (owner-chosen — softer than the old implicit
  // ~100%); the `offline` channel adds to it, hard-capped at 1.0 (offline can
  // never out-earn active play, so no softcap needed). offlineFraction =
  // clamp(offlineBaseFraction + Σ(offline), 0, offlineFractionCap).
  static const double offlineBaseFraction = 0.70;
  static const double offlineFractionCap = 1.0;
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
  // Raised with the 10-rig rescale: the new top-tier hashrate (~10,000x the old
  // ladder) lets a whale saturate the per-era supply cap every fork, so each
  // fork mints the MAX GovTokens and tier-3 (New Blockchain) was reachable in
  // ~16-20h of optimal play (vs the intended multi-day milestone). Raising this
  // gate keeps the deepest prestige a genuine investment under the new economy.
  static const double genesisDivisor = 520000.0; // chain-GovTokens -> 1 GB
  static const double perGenesisGainBonus = 0.5; // gain x = 1 + 0.5*sqrt(GB)

  // Achievements: each NORMAL (non-secret) achievement grants this much permanent
  // "Notoriety" income bonus. Its own lane (off the perk/lab budget) and bounded
  // by the fixed achievement count, so it can't run away.
  static const double perAchievementNotoriety = 0.01; // +1% income each

  // SWEEP minigame (simulated, in-game UTXO only — no real money or value).
  // Deliberately PLAYER-FAVOURED: every game returns >1 per stake on average, so
  // sweeping the chain pays out. It is NOT an infinite faucet: net UTXO gained is
  // bounded per real-time window by [casinoDailyNetCap] (thematically, the
  // network gets congested), which is the anti-farm guardrail. Each game's
  // paytable/EV lives in casino_service.dart (Hash Flip is the high-variance one:
  // mostly busts, rare 30× jackpot, EV ~1.5 matched to the others).

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

  // Luck scales SWEEP winnings up, but the realized average return per stake is
  // clamped to this ceiling so even maxed Luck can't make it absurd. Set above
  // the base EVs (~1.36–1.65) so Luck still meaningfully boosts winnings. The
  // economy is bounded by [casinoDailyNetCap], not by the return.
  static const double casinoEvCeiling = 2.5;

  // Anti-farm guardrail: the net-UTXO BLOCK THRESHOLD for SWEEP within one
  // real-time window ([casinoWindowHours]). Once net gain reaches this, sweeps
  // are blocked until the window resets ("the mempool is congested"). The sweep
  // that CROSSES the threshold is still paid in full (a fair final win), so the
  // realized per-window net can exceed this by up to one winning stake — the
  // point is to bound farming, not to clamp an honest jackpot. [TUNE].
  static const double casinoDailyNetCap = 400;
  static const int casinoWindowHours = 24;

  // RPG classes + Mastery (Phase 3). A class is picked at each New Blockchain
  // and reshapes the run via small additive channel weightings (softcapped like
  // every other bonus) plus a prestige-gain multiplier. Mastery is permanent
  // (survives everything but a full wipe) and is the "play them all" driver.
  //
  // Mastery XP is earned by MINING, credited live to the class you're playing:
  // masteryXp += masteryXpPerFullSupply * (income / maxSupplySats). Since a full
  // era mines at most one 21M supply, ONE full supply mined == exactly one XP
  // unit == masteryXpPerFullSupply, so with masteryXpDivisor equal, mining one
  // full supply = Mastery level 1, four = level 2, nine = level 3 (concave,
  // un-farmable by rapid resetting — only real mining grants it).
  static const double masteryXpDivisor = 10000.0; // level = floor(sqrt(xp/this))
  static const double masteryXpPerFullSupply = 10000.0; // 1 full 21M supply = 1 unit
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
