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

  // IDLE CAPACITY attribute — how long an absence keeps accruing offline income.
  // Base 8h, extended by the `idle` channel (sources add HOURS) up to a hard 24h
  // FINAL cap (#16). A returning player banks at most this many hours of offline
  // mining regardless of how long they were away.
  static const double offlineWindowBaseHours = 8.0;
  static const double offlineWindowMaxHours = 24.0;

  // Resistances (Phase 2). Pattern: effect = penalty × (1 − R). Per-lever caps,
  // plus an AUTHORITATIVE combined cap (#8): the total mitigation of any single
  // event type — across magnitude + duration (+ future aura/keystone levers) —
  // is clamped to combinedResistCap, so a crash/cost-spike/halving always lands
  // at >= 30% of its base impact (never full immunity, never a payout).
  static const double combinedResistCap = 0.70;
  static const double resistCapMagnitude = 0.70; // Diamond Hands, Fee Hedge, Cold Storage
  static const double resistCapDuration = 0.60; // Steel Nerves
  static const double resistCapHalving = 0.60; // Stock-to-Flow (never cancels a halving)

  // (BLUEPRINTS retired: TECH is RP-only now, so there is no BTC re-tech cost to
  // discount. Re-teching after a fork is free — you just re-spend your RP budget.)

  // ABILITIES (Phase 4). Wall-clock cooldowns; buffs are foreground-only (never
  // re-applied in the offline sim). Base cooldowns: basics 30min / 2h, ults ~22h
  // (owner: deliberately UNDER 24h so a daily player always finds the ult ready).
  static const int abilityCdBasic1Ms = 30 * 60 * 1000; // 30 min
  static const int abilityCdBasic2Ms = 2 * 60 * 60 * 1000; // 2 h
  static const int abilityCdUltimateMs = 22 * 60 * 60 * 1000; // ~22 h
  // RIG COOLING (Haste/CDR): shortens cooldowns, hard-capped, with absolute floors.
  static const double hasteCap = 0.40; // max 40% CDR (aggregate)
  static const int abilityCdFloorBasicMs = 18 * 60 * 1000; // basics never < ~18 min
  static const int abilityCdFloorUltMs = 13 * 60 * 60 * 1000; // ult never < ~13 h
  // OVERCHARGE: ability buff MAGNITUDE + grant-seconds scaling (NOT durations).
  static const double overchargeCap = 0.50; // +50% max
  // BULL BIAS: how strongly chaos selection tilts toward positive events. The
  // pick weights positives by (1 + bullBias); negatives keep weight 1 (never
  // zeroed). Capped so positives can be favoured at most ~3:1.
  static const double bullBiasCap = 2.0;
  // AGGREGATE temp-multiplier ceiling per channel (#10) — the PRODUCT of the
  // outside-softcap temp lane (ability buffs × chaos market lane) is clamped so a
  // stacked buff window stays auditable. [TUNE].
  static const double incomeTempMax = 6.0;
  static const double hashTempMax = 5.0;
  static const double clickTempMax = 4.0;
  // BLOCK RACE (Solo ultimate): auto-fires this many guaranteed-crit taps per
  // 1-second tick while active (synthetic → fires no procs; supply-clamped).
  static const int blockRaceTapsPerTick = 12;
  // Progressive unlock: basic-1 on class pick, basic-2 at Mastery 1, ult at Mastery 2.
  static const int abilityMasteryForBasic2 = 1;
  static const int abilityMasteryForUltimate = 2;
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

  // (Soft Fork / Consensus currency removed in SKILL S2 — repeatable income
  // scaling now comes from the GovToken multiplier + Notoriety.)

  // New Blockchain (Tier-3 prestige): resets almost everything (keeps only the
  // permanent Stash collection + banked Genesis Blocks), grants Genesis Blocks
  // (GB) = floor(sqrt(chainGovTokens / genesisDivisor)) where chainGovTokens is
  // the GovTokens minted since the last New Blockchain. GB do NOT add raw income;
  // they multiply the GAIN of GovTokens, so each New Blockchain makes every
  // future run farm prestige faster instead of stacking yet another raw income
  // multiplier. The multiplier is CONCAVE in GB (1 + perGenesisGainBonus*sqrt(GB))
  // so the Genesis<->GovToken feedback loop converges instead of running away.
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
  static const double clickCritMultiplier = 5.0; // base crit payout (5x)
  // Luck scales the crit chance up to this hard cap (keeps it a thrill, not the
  // main income source).
  static const double clickCritChanceCap = 0.25;
  // GOLDEN NONCE PROTOCOL (B6): a bounded pity timer — every Nth real tap is a
  // guaranteed golden nonce (crit) on top of the luck roll.
  static const int goldenNonceEvery = 12;
  // REINVESTMENT ENGINE (A7): reinvest this fraction of the raw hash-channel sum
  // into the income channel — the branch-A hash<->income synergy — capped so a
  // deep hash stack can never diverge the income multiplier.
  static const double reinvestFraction = 0.20;
  static const double reinvestIncomeCap = 0.75;
  // AI CO-PILOT (B5): the auto-clicker fires every Nth tick; owning the node
  // tightens the interval from the base cadence to the faster one.
  static const int autoClickEveryBase = 5;
  static const int autoClickEveryFast = 3;

  // BLOCK REWARD attribute — crit PAYOUT scales with the `special` channel:
  //   critMult = clickCritMultiplier + clickCritPayoutSpecialScale ·
  //              softcap(Σspecial, 1.0, 0.5)
  // clamped at [critPayoutMax]. The cap is on the FINAL aggregate crit multiplier
  // (BALANCE_AND_BOUNDS #11); ~x55 leaves headroom for future guaranteed-crit
  // abilities × LASER EYES without letting stacked crit-power reach absurd payouts.
  static const double clickCritPayoutSpecialScale = 5.0;
  static const double critPayoutMax = 55.0;

  // PRESTIGE WEIGHT attribute — a buildable multiplier on GovToken GAIN via the
  // `prestige` channel: gainMult ×= multiplier(prestige, 1.0, 0.5) (softcap params
  // pinned per BALANCE_AND_BOUNDS X7). The TOTAL prestige-gain multiplier (class
  // scalar × Prestige Weight × future keystones/abilities) is clamped at
  // [prestigeGainMax] (#17) so the Genesis↔GovToken feedback loop can never
  // diverge; the concave GT accrual + softcap keep it well under this in practice
  // (the paper worst-case full stack is ~x58).
  static const double prestigeGainMax = 60.0;

  // PROSPECTOR'S EYE attribute (Fortune / drop quality). Each crate roll has a
  // fortuneBonus chance to bump its rolled rarity UP one step (never the top by
  // guarantee — only +1, and only on a successful roll). Hard-capped so it can
  // never dominate loot (#22). Additive `fortune`-channel sources feed it.
  static const double fortuneMaxTierShiftChance = 0.25;

  // DOUBLE-DROP attribute (TECH "Double-Drop Manifold"). Distinct from Fortune:
  // Fortune bumps a rolled crate's QUALITY (+1 rarity); doubleDrop is the chance a
  // crate open yields a SECOND full crate (COUNT). Additive `doubleDrop`-channel
  // sources feed it, hard-capped here so loot can't runaway.
  static const double doubleDropMax = 0.25;

  // Luck scales SWEEP winnings up, but the realized average return per stake is
  // clamped to this ceiling so even maxed Luck can't make it absurd. Set above
  // the base EVs (~1.50–1.65) so Luck still meaningfully boosts winnings. The
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
  // masteryXp += masteryXpPerFullSupply * masteryXpSpeed * (income / maxSupplySats).
  // "supply" = the whole 21M-BTC total (maxSupplySats). Mastery IS the "class level"
  // that drives the RP budget (SKILL S1). The level curve is deliberately LINEAR
  // (not a steepening curve) — stretched only by the TOTAL amount needed, per owner:
  //   level = floor(xp / masteryXpDivisor), CAPPED at classLevelMax (18).
  // With the values below, one full 21M supply mined = 2 class levels — so your
  // first mined-out is NOT an instant level 18; maxing a class (18) takes ~9 full
  // supplies mined cumulatively (slow, endgame). [TUNE the rate via these two]
  static const double masteryXpDivisor = 10000.0; // xp per level (linear)
  static const double masteryXpPerFullSupply = 20000.0; // 1 full supply = 2 levels
  // Runtime GAME SPEED for testing (Settings → Danger Zone) scales the whole mining
  // tick, so income/blocks/halvings/mastery/RP all speed up together. Default 1.0.
  static const double gameSpeedDefault = 1.0;
  static const List<double> gameSpeedOptions = [1, 10, 100, 1000];
  // Class level is capped at 18. RP = rpTechBaseBonus + class level → max 20, which
  // is exactly 2 full branches (each 7 nodes×1 + a 3-RP capstone = 10). The base is
  // a small taste so early TECH (unlocked before the class pick) isn't a dead tab.
  static const int classLevelMax = 18;
  static const int rpTechBaseBonus = 2;
  // Each TOTAL mastery level (summed across all classes) grants this much
  // permanent hash AND income bonus, for every class including Prospector. Tiny
  // and softcapped; CLAMPED to masteryNudgeCap so the faster curve can't balloon it.
  static const double masteryBonusPerLevel = 0.005; // +0.5% hash & income / level
  static const double masteryNudgeCap = 0.10; // max +10% hash & income from the nudge

  // THE POWER BILL — upkeep (Phase 5). A skim off GROSS income that hits only the
  // spendable WALLET: lifetime / the 21M drawdown / Mastery XP are ALL credited in
  // full (grossMined), and only netToWallet = gross×(1−upkeepRate) reaches the
  // wallet — so upkeep slows how fast you BUY, never the win/supply/Mastery (#15).
  // Owner chose the GENTLER end: cap 10% (not 15%). Never a bill/bankruptcy.
  //   load       = Σ ownedCount × tierWeight (multipliers aren't taxed; carpeting
  //                the 500th rig is)
  //   rawUpkeep  = upkeepCap · (1 − 1/(1 + load/upkeepK))   ~0% first rigs → cap
  //   reduced by min(upkeepReductionCap, FeeHedge); × class mod; then clamped.
  static const double upkeepCap = 0.10; // gentler than the 0.15 design ceiling
  // [TUNE] load at which upkeep is ~half-cap (5%). Lowered 1500→800 (device
  // feedback: a 500-rig fleet only shaved ~4%). At K=800: ~500 rigs (load≈1000)
  // ≈5% raw, first rigs (load≈100) ≈1.1% (onboarding stays gentle), and big
  // brute fleets press the 10% cap far sooner. Cap unchanged → net stays ≥0.90g.
  static const double upkeepK = 800.0;
  static const double upkeepReductionCap = 0.75; // Fee Hedge / Energy Efficiency
  static const double upkeepClassCorp = 1.10; // Corp pays a bit more
  static const double upkeepClassLean = 0.90; // Pool/Solo pay a bit less
  static const double cheapEnergyUpkeepFactor = 0.5; // CHEAP ENERGY halves upkeep
  static const double costSpikeUpkeepFactor = 1.5; // COST SPIKE raises it (clamped)

  // THE BREACH — theft (Phase 5). Replaces the old instant −15% "hack": a
  // TELEGRAPHED steal of the HOT wallet only — NEVER lifetime/supply/GovTokens/
  // Genesis/Mastery/Stash/best-times/chips (#27). A THREAT DETECTED
  // banner gives a countdown to tap SECURE (fully vault, 0 loss); ignored, it
  // steals breachBaseLoss × (1 − COLD STORAGE resistance ≤0.70), so it always
  // lands ≥30% of base. Owner chose the GENTLER end: base loss 10% (not 15%).
  // The FIRST breach of a save is a 0-loss DRILL (the tutorial). AIRDROP (+15%)
  // stays as its positive twin.
  static const double breachBaseLoss = 0.10; // gentler than the 0.15 ceiling
  static const int breachTelegraphSeconds = 10; // base countdown to SECURE
  // Cold Storage lengthens the SECURE window: +up to this many seconds at full
  // theftResistance (0.70), so investing in defense buys reaction time.
  static const int breachTelegraphBonusMaxSec = 8;
  // Frequency floor: a breach can't START within this window of the previous one
  // (docs §E ~10–15 min), so the telegraph can't spam.
  static const int breachMinGapMs = 12 * 60 * 1000;
  // Tiers: DUST ATTACK (frequent, tiny) / BREACH (normal) / 51% ATTACK (rare, big
  // + a brief market dip). Loss = breachBaseLoss × tierMult. Weights sum to 100.
  static const double breachTierDustMult = 0.3; // ~3% of hot wallet
  static const double breachTierNormalMult = 1.0; // ~10%
  static const double breachTier51Mult = 2.5; // ~25%
  static const int breachTierDustWeight = 60;
  static const int breachTierNormalWeight = 33;
  static const int breachTier51Weight = 7;
  // 51% ATTACK aftermath: a brief bounded income dip (never stacks with a real crash).
  static const double breach51DipMult = 0.8;
  static const int breach51DipSeconds = 60;

  // --- Procs / Rig Firmware (Slice 7 / 7b) ---
  // Per-window UTXO cap (#25): total chips granted by procs + forced anomalies
  // within a rolling real-time window, so firmware can't farm UTXO.
  static const int procUtxoWindowMs = 60 * 1000; // 1-minute window
  static const int procUtxoWindowCap = 25; // max granted chips per window
  static const int critStreakThreshold = 4; // consecutive crits → onCritStreak
  static const double procCdRefundMax = 0.50; // a CD-refund proc shaves ≤50%
  // RIG FIRMWARE loadout: base sockets, hard cap, and the CO-PROCESSOR override.
  static const int firmwareBaseSlots = 3;
  static const int firmwareMaxSlots = 6; // via Firmware Bay / Mastery / doctrine
  static const int firmwareCoProcessorSlots = 8; // CO-PROCESSOR keystone
  static const double firmwareCoProcessorChanceMult = 0.60; // −40% proc chance

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
