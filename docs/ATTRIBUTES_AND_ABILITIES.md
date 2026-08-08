# Attributes + Per-Class Active Abilities — PLAN

Status: **DESIGN / PLANNING ONLY** (owner: "zatím jen plánujeme"). No code.
Produced via a multi-agent design pass (attributes + 3 ability takes → synthesis
→ adversarial review, verdict *ship-with-fixes*; the review's top fixes are
folded in below and marked ⚑).

---

## PART A — ATTRIBUTES

### Current attributes (the "channels" + derived stats)

Channels: additive **within** a channel, multiplicative **across**, each
soft-capped past a threshold so nothing runs away.

| Channel | Does | Sourced by | Consumed by |
|---|---|---|---|
| **hash** | global hash-rate × | TECH, TALENTS, STASH, class (Corp +20%), Mastery | `calculateGlobalHashRate` (softcap 4×) |
| **click** | tap power × | TECH, Solo TALENTS, STASH, class (Solo +15%) | tap income (softcap 3×) |
| **income** | income/sat × | TECH, TALENTS, class (Corp +15%/Pool +8%), Mastery | `calculateMiningIncome` (softcap 3×) |
| **rigCost** | rig-cost discount | TECH, TALENTS, STASH, class (Solo +20%) | `calculateRigCost` (95% floor) |
| **luck** | crit chance, SWEEP winnings, crate/anomaly odds | TALENTS, STASH, class (+8–10%) | crit, casino, anomaly (softcap 1.5×) |
| **volatility** | chaos frequency/severity | class only | chaos reschedule gap |
| **prestige** | *declared, UNUSED* | — | — (revived, see new #3) |
| **special** | *declared, UNUSED* | — | — (revived, see new #2) |

Derived / off-channel: **prestigeMultiplier** (1+0.5√GT+0.1√CX), **prestigeGainMult**
(class scalar), **genesisGainMultiplier** (1+0.5√GB), **Mastery** (+0.5% hash&income
/level), **Notoriety** (+1% income/achievement), **crit** (6%→cap 25%, ×5),
**SWEEP EV** (luck-scaled, cap 2.5, bounded 400 UTXO/24h), **chaos** temp mults,
**offline earnings** (currently ~100% of live rate, no attribute governs it).

### 5 new attributes

1. **OFFLINE YIELD** *(required; new `offline` channel)* — fraction of live
   income/sec earned while closed. `offlineFraction = clamp(0.50 + sum(offline), 0, 1.0)`.
   Base **0.50** (⚑ a deliberate rebalance down from today's implicit ~100%),
   hard cap **1.0 = parity** (offline can never out-earn active play → no softcap
   needed). Source: TECH "Autonomous Daemons", universal TALENT "Cron Jobs", STASH
   `offlineYield` affix, **BTC OG +0.10**. Consumed: `_simulateOfflineMining`
   (a new `yieldFactor` param on `_accrueMining`, live tick stays 1.0). Duration
   cap + block advance unchanged (governs RATE, not duration).
2. **CRIT POWER** *(revives `special`)* — raises crit **payout** (luck governs
   only chance). `critMult = 5 + 5·(special sum, softcapped)`. Source: Solo TALENT,
   repurpose legacy STASH `criticalChance` affix → crit-power, TECH. Self-limiting
   (crits on 6–25% of taps; taps are a minor late source). Fits Solo.
3. **PRESTIGE YIELD** *(revives `prestige`)* — buildable × on CX+GovToken **gain**,
   beside the class scalar. `gainMult ×= multiplier(prestige, softcapped)`. Source:
   endgame OG TALENTS, late TECH, a slice of Genesis Blocks. CX/GT accrual is
   already concave (cbrt/√) so it steepens without trivialising. Fits BTC OG.
4. **FORTUNE / DROP QUALITY** — biases crate + anomaly drops up the rarity ladder
   (no income). Bounded tier-shift chance (max +25% one step, never guarantees
   mythic; Quantum's Epic floor stays). Source: TALENT "Prospector's Eye", STASH
   affix, OG/Pool lean. Consumed: `StashService._rollRarity`, `AnomalySystem`.
5. **HASTE / COOLDOWN REDUCTION** — the bridge to abilities. `effectiveCD =
   baseCD·(1−haste)`, **haste hard-capped 0.40** with hard floors (basics never
   < ~18 min, ult never < ~14.4 h). Source: small sub-linear Mastery nudge,
   endgame TECH, Corp/Pool lean, a TALENT branch. Consumed: the ability timers.

Everything either routes through the existing softcap math or is hard-capped by
construction → the additive-channel backstop is never bypassed. ⚑ *Ability BUFFS
(below) are temp multipliers applied OUTSIDE the softcap, exactly like chaos
events — bounded by duration + the per-era supply clamp, not by the softcap.*

---

## PART B — ACTIVE ABILITIES (LoL-style)

**Where pressed:** an **Abilities Bar** — 3 circular buttons docked just above the
sticky HACK button on MINE. Renders only once a real class is chosen (Prospector:
locked, "Choose a class to unlock abilities"). ⚑ *Ready-forward presentation:
ready abilities glow (reuse `pulse_button`); on-cooldown ones demote to a compact
icon with a centered wall-clock countdown + a radial sweep (reuse the halving /
Back-in-Time arc). Active buff = ONE ticker chip (no extra per-button bar) to
avoid crowding the tap zone.* Firing pops floating text + a NEWS TICKER line.

**Cooldowns:** wall-clock via persisted `lastUsedEpochMs` (like the casino 24h
window), so they tick while closed; **single charge** (a week away = one of each,
no stacking); no pre-load/auto-fire. **Buffs are foreground-only** — they run on a
real-time timer and are NEVER re-applied inside the offline sim, so a buff can't
juice offline earnings.

**Ability axes:** ⚑ abilities get their **own** multiplier axes (income/hash/
click/cost/luck), independent of chaos (which uses replace-semantics on its own
axis). A buff + a live Bull Run therefore stack multiplicatively — an intended,
brief, cooldown-gated power spike, bounded by duration + the supply clamp.

**Instant grants** snapshot the live per-second rate and route through the
supply-clamped `_accrueMining` lump path → can never breach the 21M/era wall
(disabled once the era is mined out). ⚑ *To keep the roster distinct, the instant
income lump is **Corp-only** (their signature); Pool/OG use different levers.*

### Solo Miner — clicks / crit / luck
- **OVERCLOCK THE GPU** · 30 min · 45s: every real HACK tap is a guaranteed crit at ×8, click ×2.5 (auto-taps excluded).
- **LUCKY NONCE** · 2 h · instant: open 1 free luck-weighted Supply Crate + luck ×3 for 5 min + spawn 3 anomalies.
- **BLOCK RACE (ult)** · ~22 h · 90s: auto-fire ~12 taps/s, all guaranteed crit, click ×3.

### Corporation — raw hash / income / buy-power
- **SPIN UP THE FARM** · 30 min · 90s: hash ×2.5.
- **CAPITAL INJECTION** · 2 h · instant: bank 30 min of current income (supply-clamped). *(The one signature lump.)*
- **HOSTILE TAKEOVER (ult)** · ~24 h · 10 min income ×4 **and** rig cost ×0.5, plus an instant 2h lump.

### BTC OG — market / prestige / time
- **WHALE ORDER** · 30 min · force a Bull Run (income ×3, 3 min); or cancel an active crash/spike.
- **COLD STORAGE** · 2 h · 6 min: prestige-gain ×1.75 (stacks with class 1.25) on any fork cashed in the window.
- **SATOSHI MODE (ult)** · ~24 h · 10 min: prestige-gain ×2.5 **and** blocks ×4 (halving progress). ⚑ *Pure prestige/time window — NO raw income lump, NO free era-sats drip; you still pay the full fork reset.*

### Pool Member — stability / SWEEP / steady
- **STEADY HANDS** · 30 min · 5 min: income ×2 with total crash-immunity (crash/hack/spike suppressed, active debuff cleared).
- **POOL LUCK** · 2 h · 10 min: SWEEP luck pinned to the 2.5 EV ceiling. ⚑ *Luck-pin ONLY — does NOT reset/raise the SWEEP net cap (that reset was an infinite +EV faucet); the 400/24h bound stays intact.*
- **CONSENSUS RALLY (ult)** · ~24 h · 10 min: income ×3, hash ×1.5, all negative chaos suppressed, cost frozen. ⚑ *No SWEEP cap change.*

### Scaling (bounded, stays relevant)
- **Haste/CDR** shortens CDs (hard cap 0.40, hard floors).
- **Magnitude** (+1%/current-class Mastery level, cap +50%) on buff strength + grant-seconds (NOT durations).
- **Genesis Blocks** add a tiny concave bump (+ up to 25%) to grant-seconds only; GB does NOT cut cooldowns.
- Durations are fixed → no attribute can create infinite uptime.

### ⚑ Balance fixes applied from the review
1. **Pool DEEP LIQUIDITY removed** — its casino net-cap reset was the sole brake on >1-EV sweeps → an infinite money faucet. Replaced by **POOL LUCK** (luck-pin only). CONSENSUS RALLY no longer touches the cap.
2. **Abilities disabled during a Back-in-Time run** — else a returning player pre-stocks all 3 and dumps ~8.5h of lumps at t=0, trivialising the best time. (Alternatively: exclude ability grants from `speedRunMinedSats`.)
3. **SATOSHI MODE** is wallet-lump-free and doesn't advance era-sats → the prestige ladder stays honest.
4. **Own-axis** ability multipliers (see above) → chaos never silently clobbers a buff, and the stack is intentional + bounded.
5. **Instant income lump is Corp-only** → the 4 kits read as distinct, not 3× the same lump.
6. **Clock-set-forward** (refreshes CDs + grants offline) is accepted as *self-only* cheating in a single-player offline idle game — consistent with the existing wall-clock offline/casino, no server/leaderboard to protect. Not worth anti-cheat plumbing.

### Implementation sketch (reuses existing systems)
- `channels.dart`: add `offline` to the enum; wire `prestige`/`special` into their consumers.
- `constants.dart`: `offlineBaseFraction=0.50`, `offlineFractionCap=1.0`, ability CDs, haste cap.
- `game_logic.dart`: `yieldFactor` on `_accrueMining` (offline passes `offlineFraction`); crit reads `special`; new `AbilitySystem` (per-class 3 defs + persisted `{abilityId: lastUsedEpochMs}`); gate abilities off during a Back-in-Time run.
- `class_manager.dart`: CX/GT gain hooks also ×`multiplier(prestige)`.
- `chaos_event_system.dart`: reuse temp-multiplier axes for buffs + a chaos-suppression flag (Pool); post ability fires to `showNews`.
- `stash_service.dart` / `AnomalySystem`: Fortune tier-shift.
- `mining_tab.dart`: new `AbilitiesBar` (reuse `pulse_button`, `floating_text`, the progress-arc); gate on class chosen.

---

## Open decisions for the owner
1. **Offline base 0.50** — accept the nerf from today's ~100%, or set higher (e.g. 0.70) to soften the transition?
2. **Solo Basic-2** — keep LUCKY NONCE (luck/loot), or a JURY-RIG cheap-build window (leans on Solo's rigCost)?
3. **Ult cooldown** — standardise 24h for all, or stagger (Solo ~22h) so a daily player's ults drift earlier?
4. **Ability gating** — all 3 available the moment a class is chosen, or gate some behind Mastery/TECH?
5. **Prestige tools on OG** — COLD STORAGE + SATOSHI MODE both touch prestige gain (differ by magnitude/CD). Fine, or make one non-prestige?
6. **Abilities during Back-in-Time** — fully disabled (simplest) vs allowed-but-excluded-from-the-timer.
