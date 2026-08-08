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
   income/sec earned while closed. `offlineFraction = clamp(0.70 + sum(offline), 0, 1.0)`.
   Base **0.70** *(owner-chosen: soften the nerf from today's implicit ~100% —
   a gentler transition than 0.50; you climb the last 30% back to parity via
   TECH/TALENT/STASH/OG-class)*, hard cap **1.0 = parity** (offline can never
   out-earn active play → no softcap needed). Source: TECH "Autonomous Daemons",
   universal TALENT "Cron Jobs", STASH `offlineYield` affix, **BTC OG +0.10**.
   Consumed: `_simulateOfflineMining` (a new `yieldFactor` param on `_accrueMining`,
   live tick stays 1.0). Duration cap + block advance unchanged (governs RATE, not
   duration).
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
   < ~18 min, ult never < ~13 h). Source: small sub-linear Mastery nudge,
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
juice offline earnings. Basics: **30 min / 2 h**. ⚑ **Ultimates ~22 h**
*(owner-chosen: deliberately UNDER 24 h so a daily player always finds the ult
ready and it drifts ~2 h earlier each day — daily play is rewarded).* Haste/CDR
can shorten further, floor ~13 h.

**Ability axes:** ⚑ abilities get their **own** multiplier axes (income/hash/
click/cost/luck), independent of chaos (which uses replace-semantics on its own
axis). A buff + a live Bull Run therefore stack multiplicatively — an intended,
brief, cooldown-gated power spike, bounded by duration + the supply clamp.

**Instant grants** snapshot the live per-second rate and route through the
supply-clamped `_accrueMining` lump path → can never breach the 21M/era wall
(disabled once the era is mined out). ⚑ *To keep the roster distinct, the instant
income lump is **Corp-only** (their signature); Pool/OG use different levers.*

**Unlocking (progressive — owner-chosen):** abilities are earned, not handed over
at once. The Abilities Bar appears when you pick a real class; **slot 1** (30-min
basic) is available immediately. **Slot 2** (2-h basic) unlocks at that class's
**Mastery 1**; the **Ultimate** at **Mastery 2** — *or* each can be backed by a
dedicated TECH node ("Ability Console" → slot 2, a deeper node → ult) so they stay
reachable if per-supply Mastery pacing proves slow. Thresholds are **[TUNE]**,
tied to the Mastery-pacing decision in [ENDGAME_REDESIGN.md](ENDGAME_REDESIGN.md)
(1 supply = Mastery 1). Because Mastery is permanent + per class, mastering a class
unlocks its full kit and keeps it forever.

### Solo Miner — clicks / crit / luck
- **OVERCLOCK THE GPU** · 30 min · 45s: every real HACK tap is a guaranteed crit at ×8, click ×2.5 (auto-taps excluded).
- **LUCKY NONCE** · 2 h · instant: open 1 free luck-weighted Supply Crate + luck ×3 for 5 min + spawn 3 anomalies.
- **BLOCK RACE (ult)** · ~22 h · 90s: auto-fire ~12 taps/s, all guaranteed crit, click ×3.

### Corporation — raw hash / income / buy-power
- **SPIN UP THE FARM** · 30 min · 90s: hash ×2.5.
- **CAPITAL INJECTION** · 2 h · instant: bank 30 min of current income (supply-clamped). *(The one signature lump.)*
- **HOSTILE TAKEOVER (ult)** · ~22 h · 10 min income ×4 **and** rig cost ×0.5, plus an instant 2h lump.

### BTC OG — market / prestige / time
- **WHALE ORDER** · 30 min · force a Bull Run (income ×3, 3 min); or cancel an active crash/spike.
- **COLD STORAGE** · 2 h · 6 min: prestige-gain ×1.75 (stacks with class 1.25) on any fork cashed in the window.
- **SATOSHI MODE (ult)** · ~22 h · instant: **resets both basic cooldowns** (WHALE ORDER + COLD STORAGE), then income ×2 & hash ×2 for 8 min. ⚑ *Chosen: TIME/TEMPO, not a third prestige buff — resolves the two-prestige-ability overlap. No lump, no era-sats drip. Lets OG chain a fresh market + prestige window off one ult, bounded by the 22h CD + the concave prestige curves.*

### Pool Member — stability / SWEEP / steady
- **STEADY HANDS** · 30 min · 5 min: income ×2 with total crash-immunity (crash/hack/spike suppressed, active debuff cleared).
- **POOL LUCK** · 2 h · 10 min: SWEEP luck pinned to the 2.5 EV ceiling. ⚑ *Luck-pin ONLY — does NOT reset/raise the SWEEP net cap (that reset was an infinite +EV faucet); the 400/24h bound stays intact.*
- **CONSENSUS RALLY (ult)** · ~22 h · 10 min: income ×3, hash ×1.5, all negative chaos suppressed, cost frozen. ⚑ *No SWEEP cap change.*

### Scaling (bounded, stays relevant)
- **Haste/CDR** shortens CDs (hard cap 0.40, hard floors).
- **Magnitude** (+1%/current-class Mastery level, cap +50%) on buff strength + grant-seconds (NOT durations).
- **Genesis Blocks** add a tiny concave bump (+ up to 25%) to grant-seconds only; GB does NOT cut cooldowns.
- Durations are fixed → no attribute can create infinite uptime.

### ⚑ Balance fixes applied from the review
1. **Pool DEEP LIQUIDITY removed** — its casino net-cap reset was the sole brake on >1-EV sweeps → an infinite money faucet. Replaced by **POOL LUCK** (luck-pin only). CONSENSUS RALLY no longer touches the cap.
2. **Abilities ALLOWED during a Back-in-Time run** (they're core to optimizing your time — disabling them in the endgame loop would make the whole kit pointless), BUT **instant income-lumps (Corp) credit your wallet only and do NOT count toward the run's re-mined 21M** (`speedRunMinedSats`). So a lump can't teleport the progress bar — only real, buff-boosted mining advances the time; the lump still helps indirectly (more wallet → buy rigs → mine faster). Buff abilities count normally.
3. **SATOSHI MODE** is a time/tempo ult (cooldown reset + short income/hash window) — wallet-lump-free, no era-sats drip → the prestige ladder stays honest.
4. **Own-axis** ability multipliers (see above) → chaos never silently clobbers a buff, and the stack is intentional + bounded.
5. **Instant income lump is Corp-only** → the 4 kits read as distinct, not 3× the same lump.
6. **Clock-set-forward** (refreshes CDs + grants offline) is accepted as *self-only* cheating in a single-player offline idle game — consistent with the existing wall-clock offline/casino, no server/leaderboard to protect. Not worth anti-cheat plumbing.

### Implementation sketch (reuses existing systems)
- `channels.dart`: add `offline` to the enum; wire `prestige`/`special` into their consumers.
- `constants.dart`: `offlineBaseFraction=0.50`, `offlineFractionCap=1.0`, ability CDs, haste cap.
- `game_logic.dart`: `yieldFactor` on `_accrueMining` (offline passes `offlineFraction`); crit reads `special`; new `AbilitySystem` (per-class 3 defs + persisted `{abilityId: lastUsedEpochMs}`); during a Back-in-Time run, instant-lump grants skip the `speedRunMinedSats` accumulation (credit wallet/lifetime only); SATOSHI MODE zeroes the two basics' `lastUsedEpochMs`.
- `class_manager.dart`: CX/GT gain hooks also ×`multiplier(prestige)`.
- `chaos_event_system.dart`: reuse temp-multiplier axes for buffs + a chaos-suppression flag (Pool); post ability fires to `showNews`.
- `stash_service.dart` / `AnomalySystem`: Fortune tier-shift.
- `mining_tab.dart`: new `AbilitiesBar` (reuse `pulse_button`, `floating_text`, the progress-arc); gate on class chosen.

---

## Decisions

### Resolved (owner + Claude's pick where delegated)
- ✅ **Offline base = 0.70** (soften the nerf from today's ~100%).
- ✅ **Ultimate CD ~22 h** (sub-24 h so daily play is rewarded — always ready, drifts earlier).
- ✅ **Progressive unlock** via class Mastery (slot 1 → pick, slot 2 → Mastery 1, ult → Mastery 2) and/or TECH nodes.
- ✅ **Solo Basic-2 = LUCKY NONCE** (kept): the only loot/luck active in the roster; JURY-RIG (rigCost) would have overlapped Corp's buy-power. Solo's rigCost identity already lives in its passive channel + TALENTS.
- ✅ **OG = one prestige ability** (COLD STORAGE); SATOSHI MODE re-themed to time/tempo (cooldown reset) → three distinct pillars: market / prestige / time.
- ✅ **Abilities usable in Back-in-Time**; instant lumps credit wallet only, not the timer (so the endgame stays ability-driven without lumps teleporting the best time).

### Still open (minor, [TUNE])
1. **Mastery-gate thresholds** depend on the Mastery-pacing [TUNE] in the endgame doc — if per-supply Mastery is slow, back slot-2/ult with TECH nodes instead.
2. Exact ability numbers (durations/magnitudes) — tune against a build matrix once implemented (see Balance validation below).

---

## Balance validation — the build matrix + "grail build" stance

Once attributes + abilities are implemented with real numbers, validate balance
with two artifacts (owner asked to "look at a heatmap/matrix to judge nothing is
too strong — or maybe it should be"):

1. **Build matrix** — a table of **class × key metric**: income ×, hash ×,
   prestige-gain speed, luck/loot, best Back-in-Time time, ability burst ceiling.
   One row per class (+ notable attribute/ability synergies). Rendered as a
   colour **heatmap** (green = strong on that axis, red = weak) so dominance
   jumps out visually. Buildable as an Artifact/HTML heatmap.
2. **Sim-driven best-times** — extend `test/class_balance_sim_test.dart` to drive
   each class through a Back-in-Time run and print the best time per class; that
   is the objective "is one build strictly faster" check (the sim is the ground
   truth, the heatmap is the readable summary).

**Design stance (owner-aligned):** hard **safety rails are non-negotiable** — the
per-channel softcaps, the inviolable 21M/era cap, the concave prestige curves,
and the bounded casino mean **no build can literally break the game** (no infinite
money, no bypassing 21M, no compliance issue). *Within* those rails, **deliberately
allowing a few standout "grail" builds is good, modern design** — the fun of the
meta is discovering a powerful class+attribute+ability synergy. The bar is not
"every build is equal" but: (a) **no build is strictly dominant** — each class
keeps a niche and a real tradeoff; (b) no build makes the others *pointless* for
the endgame best-time; (c) the rails always hold. So the matrix is used to catch
a *strictly-dominant* or *rail-breaking* build, NOT to flatten everything to
parity. A spread of ~±15–25% between the best and worst class on any single axis
is healthy; a class that wins *every* axis is the red flag.
