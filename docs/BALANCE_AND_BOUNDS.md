# Master Feasibility, Consistency & Bounds Audit

Status: **PLANNING — authoritative bounds/consistency reference.** Multi-agent
audit (consistency + worst-case bounds + multiplicative-stacking stress) →
synthesis → adversarial review. **Verdict: FEASIBLE-WITH-CAPS** — the design is
buildable and rail-safe *once the cap/floor checklist below is enforced in code*.
This doc is the single source of truth for caps; the feature docs own the designs.

## Executive summary

The architecture is sound: **additive-within / multiplicative-across channels +
per-channel softcaps + the 21M-sats/era HARD income clamp + concave prestige**
together mean **no stack can create infinite or negative MONEY** — every
"runaway" degrades into "the era fills faster" (a *pacing* problem, not a break),
and per-fork GovToken mint is itself bounded by the 21M wall so prestige can't
diverge either. The 21M clamp is load-bearing → the **#1 code change is deleting
the entire `sandboxNoCap`/`ignoreCap` path** so 21M is truly inviolable.

The genuinely **nonsensical** values that ARE reachable (not just fast) and MUST
be hard-capped: negative/free TECH cost (R&D −80% + Blueprint −40% = −120%),
negative income/hash/click/volatility multipliers (`channels.dart` passes a
negative `1+Σ` straight through the softcap), resistances ≥100% turning penalties
into payouts, ~90% de-facto crash immunity via multiplicative resist stacking, and
rig cost slipping below the intended 95%-discount floor. All finite on paper once
the list holds — but the runtime sim is the final arbiter for the aggregate temp
ceiling, critPayoutMax, integrated mitigation, and two prestige feedback loops.

---

## THE AUTHORITATIVE CAP / FLOOR CHECKLIST

`[PRESENT]` already in code · `[DOC]` specified, unimplemented · `[MISSING]` newly
found, in neither.

### Tier 0 — inviolable (everything leans on these)
1. `[PRESENT]` **21M/era income clamp** (`maxSupplySats=2.1e15`), applied every accrual AND on click *after* the crit multiply. Never bypass.
2. `[DO]` **Delete all `sandboxNoCap`/`ignoreCap`/`noCap` paths** (game_logic, mining_manager, game_repository). Highest-priority change — makes #1 truly inviolable; every overshoot becomes pacing, not a money break.

### Tier 1 — literal nonsensical values reachable (clamp or it goes negative/immune/free)
3. `[MISSING]` **Combined TECH-cost floor**: `cost = base × max(≈0.05..0.20, 1 − totalTechDiscount)`. R&D −80% + Blueprint −40% = −120% → negative cost. The most dangerous unguarded lane.
4. `[MISSING]` **Per-channel multiplier floor**: clamp `(1+Σ)` to ≥ ε (~0.01) BEFORE softcap on hash/income/click/volatility. `channels.dart:54` returns a negative `1+Σ` unchanged → negative income/hash + an un-latching win.
5. `[MISSING]` **Volatility multiplier floor > 0** (special case of #4; 0/negative → chaos-reschedule div-by-zero).
6. `[PRESENT, extend]` **Rig-cost FINAL floor**: clamp the PRODUCT of all cost multipliers (channel factor × chaos × ability) to ≥ 0.05 — today only the channel factor is floored, then ×chaosCostMult × ability ×0.5 can reach ~1.25% of base.
7. `[DOC]` **Each resistance R < 1.0** after summing its sources, so `(1−R)` can never ≤ 0 (a crash/breach must never PAY the player).
8. `[DOC]` **Combined per-event mitigation ≤ 0.70**: `R_total = min(0.70, 1 − ∏(1−R_i))` over ALL levers (magnitude + duration + aura + FORT KNOX), PER event type (crash, cost-spike, halving, breach). Supersedes the per-lever 0.75 sub-caps.
9. `[DOC]` **Stock-to-Flow R ≤ 0.60** (`f' = f + R(1−f) < 1` — never cancels a halving).

### Tier 2 — pacing / auditability (wall holds without them, but the timed endgame or UI breaks)
10. `[MISSING]` **Aggregate temp-mult ceiling per channel**, on the OUTSIDE-softcap TEMP LANE only (NOT total): `total = base_softcapped × min(tempProduct, ceiling)`. **incomeTempMax ≈ x6, hashTempMax ≈ x5, clickTempMax ≈ x4** [TUNE via the Back-in-Time pacing sim]. ⚑ re-derive as SUSTAINED values (see #34 min-event-gap), not rare peaks.
11. `[MISSING]` **`critPayoutMax`** on the FINAL aggregate crit multiplier (Block Reward × LASER EYES × ability × procs), not per-factor. ⚑ Review: **~x50–60, NOT x30** — x30 neuters GARAGE OVERCLOCKER / NONCE CASCADE (guaranteed-crit ability ×8 × LASER EYES ×2 = ×16 already), OR make Block Reward + crit-ability share ONE declared budget.
12. `[DOC]` **ONE merged temp-buff axis per channel** (proc + ability share it; two exempt lanes must not multiply).
13. `[DOC]` **Haste aggregate cap 0.40** + absolute CD floors (basic ≥ ~18min, ult ≥ ~13h). Cap the AGGREGATE. GB adds grant-seconds only, never CDR.
14. `[DOC]` **Offline** `= clamp(0.70+Σ, 0, 1.0)` THEN keystone-mult, result in [0,1.0]; foreground-only; NO procs/buffs/chaos offline.
15. `[DOC]` **Upkeep** `rawUpkeep∈[0,0.15]`, final `clamp(...,0,0.15)` applied LAST (after class ×1.10 and costSpike ×1.5); reduction `min(0.75, EnergyEff+FeeHedge)`; net ∈ [0.85g, g]; wallet-only; skim BURNED.
16. `[DOC]` **Idle Capacity offline window ≤ ~24h** FINAL (COLD-WALLET DISCIPLINE ×2 must respect, not bypass).
17. `[MISSING]` **Combined prestige-GAIN cap** OR sim-proven convergence (Consensus Weight ×2.2 × OG 1.25 × PAPER HANDS ×2 × LOW-TIME-PREF ×1.5 × COLD-STORAGE ability ×1.75 × genesis ≈ x58 gain).
18. `[MISSING]` **Seed Capital**: hard cap << 21M (<< first milestone), concave with prestige. ⚑ Review: **WALLET-ONLY** — must be excluded from `lifetimeEarnings`, `speedRunMinedSats`, AND Mastery XP (else it fakes best-time + re-opens the rapid-reset Mastery farm).
19. `[MISSING]` **Stash click multiplier** (`getClickPowerMultiplier`) — route through `Channel.click` or softcap it (currently a raw `1+Σ` outside the softcap).

### Tier 3 — structural / faucet / anti-loop
20. `[PRESENT]` crit CHANCE ∈ [0, 0.25]; `onCrit` must NEVER raise crit chance.
21. `[PRESENT]` casino EV ≤ 2.5 + net ≤ 400 UTXO/24h; `casinoDailyNetCap` IMMUTABLE — no lever (POOL LUCK / DEGENERATE GAMBLER) may reset/raise it (pin luck to the EV ceiling only).
22. `[DOC]` UTXO Magnetism ≤ 30%/tick; Prospector's Eye +25% one-step, never mythic. ⚑ DEGENERATE GAMBLER "rarity/anomaly maxed" = *set to these caps*, never bypass them.
23. `[DOC]` Blueprint discount asymptote 0.40 (`0.40·(1−1/(1+n/6))`).
24. `[DOC]` **Proc brakes**: GOLDEN RULE (synthetic/auto-tap events fire NO triggers), ICD floors (HOT 8–10s / CRIT 5–6s / WARM 20–30s), token-bucket ~8/10s, per-tick ≤3, firmware slot cap 6 (8 w/ CO-PROCESSOR), offline = NO procs; onAbilityCast must NOT refund the triggering ability; crate-open UTXO refund < crate cost.
25. `[MISSING]` **Per-window UTXO cap** on proc/anomaly UTXO grants (the supply clamp binds SATS, not UTXO) — or sim-verify limiter×ICD keeps proc-UTXO/hr below crate cost.
26. `[DOC]` Counter-hack bounty EV strictly < breach-loss EV (else a farmable +EV faucet) — or CUT the bounty.
27. `[DOC]` Breach: loss ≤ 15% of HOT wallet ×(1−R≤0.70); hot-only; never permanent progress; offline = one batched capped breach; first breach = 0-loss drill.
28. `[DOC]` Aura ceilings routed into EXISTING shared softcaps, NO private lane (passive ≤+0.20, stance ≤+0.75, off-ch resist ≤+0.10, prestige-gain ≤+0.15).
29. `[DOC]` Keystone equip ≤ 2 + pair-exclusivity; flat-% keystone bonuses declared on-channel-additive OR counted vs the temp ceiling — never a 3rd uncapped lane.
30. `[DO]` Delete `winCount`/`trophyGainMultiplier` (linear, uncapped) with NG+ retirement.
31. `[DOC]` `special` scoped to crit-payout ONLY (still called "catch-all" in channels.dart).
32. `[DOC]` Every GRANT/instant-lump routes through the supply clamp; Back-in-Time lumps credit wallet/lifetime ONLY, excluded from `speedRunMinedSats`; lumps snapshot BASE rate, not buffed rate.
33. `[PRESENT]` Re-validate `prestigeMult < 1e5` against the FULL stacked gain (#17); keep `isFinite`/`1e300` wallet & lifetime clamps; event-duration hard-max (BULL RIDER "negatives last longer" must not be uncapped).
34. `[MISSING]` ⚑ **Min inter-chaos-event gap** (or enforced max 1 concurrent positive event via replace-semantics) — Market Exposure has no lower bound on event spacing, so a maxed-volatility build turns "brief buffs" into SUSTAINED uptime. Also make chaos **replace-semantics a MUST-CODE invariant** (only in prose today).

---

## Worst-case multiplicative peaks (paper trace, [TUNE] placeholders)

| Output | Base (softcapped) | Temp lane (uncapped) | Uncapped peak | Bound |
|---|---|---|---|---|
| Income/sec | ~x8–12 | Bull ×3 (×4.5 MARKET MAKER) × abilities ×3–4 × Overcharge × proc ≈ **x27** | ~x214 over baseline (then 21M-clamped) | #10 aggregate temp ceiling |
| Hash/sec | ~x10–17 | SPIN UP ×2.5 × SATOSHI ×2 × CONSENSUS ×1.5 × proc ≈ **x11** | ~x115 | #10 |
| Click/tap | ~x7 | OVERCLOCK ×2.5 × BLOCK RACE ×3 ≈ **x7.5** | ~x52 | #10 |
| **Crit payout/tap** | 5 + 5·√Σspecial → **~x20–55** | × LASER EYES ×2 × guaranteed-crit ×8 | **~x880/crit** | #11 critPayoutMax (~x50–60) |
| Rig cost | 0.05 floor | × CHEAP 0.5 × HOSTILE 0.5 = **0.0125** | 1.25% of base (positive, but < 95% floor) | #6 final-product floor |
| Net-of-upkeep | — | — | [0.85g, g], never <0/>g | #15 |
| Resistance | — | Diamond 0.75 × Steel 0.60 → **0.90** | de-facto crash immunity | #8 integrated ≤0.70 |
| Offline / Haste | — | — | ≤1.0 parity / CD floors | #14 / #13 |

Every peak is FINITE (21M clamp + concavity + no surviving loop); the caps convert
the "fast" ones from a timed-endgame pacing break into a bounded spike.

---

## Cross-doc contradictions to fix (before coding)

> **Reconciliation status (doc pass done):** ✅ X3 (offline 0.70), ✅ X4 (resist
> caps 0.70 + integrated ≤0.70 authoritative), ✅ X5 (TECH QoL marked superseded),
> ✅ X6 (Prestige Yield = canonical CONSENSUS WEIGHT; OG ability Cold Storage →
> **DEEP FREEZE** so "Cold Storage" = only the theft vault/attribute), ✅ X7
> (formula), ✅ X8 (Steel Nerves "NOT hack" noted), ✅ X9 (aura on-channel), and
> ✅ MASTERY DRIVE cut. **Remaining = CODE-phase:** X1 (constants.dart still has
> the old win/sandbox — implement the redesign + migration) and X2's accrual-basis
> switch (Mastery → per-mined-supply). Plus all `[MISSING]` caps in the checklist.

- **X1 (biggest):** `constants.dart` still encodes the OLD win (endgameTargetSats 2.1e20, perWinTrophyBonus, winCount, Sandbox) that ENDGAME_REDESIGN retires → implement the redesign + save migration (enables Tier-0 #2).
- **X2 / Mastery:** move Mastery from per-GovToken to per-mined-supply; make "1 full supply = Mastery 1" explicit. ⚑ **MASTERY DRIVE (BUILD_DEPTH #12) contradicts this** — its per-GovToken hook no longer exists, and +50% breaks the "1 supply = 1 unit, un-farmable" identity + de-syncs ability-unlock gates → **delete it, or re-scope to a separate soft bonus excluded from the `floor(√supplies)` gate count.**
- **X3:** offline base is **0.70** (decided) — fix stale `0.50` references.
- **X4:** resistance per-lever caps 0.75 vs the ≤0.70 rail → make the integrated ≤0.70 clamp (#8) authoritative; lower per-lever caps to ≤0.70 or mark them cosmetic.
- **X5:** `TECH_REACQUISITION_QOL.md` (cumulative tree, plain REBUILD) is SUPERSEDED by BUILD_DEPTH's exclusive doctrines + build-aware auto-apply → mark it superseded so no one builds the wrong auto-buy.
- **X6 naming:** "Consensus Weight" (BUILD_DEPTH #11) == "Prestige Yield" (ATTRIBUTES #3) — ONE attribute, one impl. "Cold Storage" names THREE things (an OG ability, resistance #22, the wallet-vault/doctrine) — rename to three distinct ids.
- **X7:** doc `prestigeMultiplier` drops `spent`; code has `√(GT+spent)` — fix the doc.
- **X8/X9:** Steel Nerves does NOT touch Hack (add an inline guard-note); aura "+0.75 / doubles under Bull Run" is ADDITIVE-contribution-then-softcap (on-channel), not a flat output ×.

---

## Runtime-sim plan (final arbiter)

The three existing sims buy no perks/keystones, run `chaosMultiplier=1.0`, and fire
no abilities/procs/auras → they MISS every new lane. Extend them to assert, per
tick: (1) `base_softcapped × tempProduct ≤ aggregate ceiling`; (2) final crit ≤
`critPayoutMax`; (3) integrated mitigation ≤ 0.70 per event; (4) `net ∈ [0.85g,g]`,
gross credited in full, skim/steal never re-enter a balance; (5) offline ≤ live;
(6) CD ≥ floors under max haste; (7) `prestigeMult < 1e5` AND per-fork mint stays
polynomial across 200+ forks under the full gain stack; (8) rig price ≥ floor > 0;
(9) casino net cap never exceeded; (10) no single tick mines the whole era;
(11) Back-in-Time best-time buffed-vs-base delta is modest, never order-of-magnitude;
(12) no negative income/hash/click/volatility mult, no free/negative TECH cost.

**Stress builds** (full multi-week run + a hand-built max-everything peak tick):
CHAOS SURFER (→1,10), NONCE CASCADE (→2), STORM COUNTERPUNCH (→3, breach ≥30%),
MAX-DISCOUNT RIG (→8), COLD-WALLET WHALE (→4,5,6), DEEP-PRESTIGE OG 200+ forks
(→7), TECH-cost stress R&D+Blueprint on one node (→12).

---

## Open tuning (sim is the arbiter)
Aggregate ceilings incomeTempMax~x6 / hashTempMax~x5 / clickTempMax~x4 (temp lane);
critPayoutMax ~x50–60; combined TECH-cost floor (0.05–0.20); rig-price final floor;
combined prestige-gain cap (or accept sim convergence); per-window proc-UTXO cap;
channel `1+Σ` floor ε; min inter-chaos-event gap; upkeep K; proc token-bucket +
ICD floors; breach cadence + loss + bounty EV; aura ceilings; masteryXpPerFullSupply;
Seed Capital cap. **Decided already:** commitment budget 2, preset slots 3, ~25
attributes, auto-apply ON, offline 0.70, ults ~22h, keystone/procs/auras/upkeep/theft IN.
