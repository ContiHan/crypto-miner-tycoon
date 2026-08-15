# Build Depth — ~25 attributes, resistances, exclusive TECH branches, presets & blueprints

Status: **PLANNING ONLY.** No code. Multi-agent design pass + adversarial review
(verdict *ship-with-fixes*); the review's cuts/fixes are folded in below (⚑).
Companion to [ATTRIBUTES_AND_ABILITIES.md](ATTRIBUTES_AND_ABILITIES.md) (the 5
core attributes + the ability kit) and [ENDGAME_REDESIGN.md](ENDGAME_REDESIGN.md).

**Goal:** turn ~10 attributes into a proper RPG-style sheet so classes + TECH +
TALENTS + STASH can build genuinely distinct builds. **Stance:** the safety rails
(per-channel softcaps, the inviolable 21M/era cap, concave prestige, bounded
casino) mean no build can *break* the game; within them a few strong "grail"
builds are desirable. Target **distinctness, not a round number** — ⚑ the review
cut the padding, landing **~25 load-bearing attributes**, not a forced 30.

⚑ **The single best idea: de-monolith LUCK.** Today one `luck` stat silently does
four jobs (crit chance, SWEEP payout, anomaly rate, crate odds). Split it into
four dedicated facets → one lever becomes four build levers with **zero** new
ceiling. Highest value-per-line in the whole plan.

---

## Part 1 — Attribute catalog (~25, grouped)

`[P0]` = one of the 5 already-agreed. `[NEW]` = new hook/system. `[CUT]` = dropped
by the review (listed so we remember why).

**I. Production / Offense** — raw output; leaning here alone hits softcaps fast.
1. **HASH POWER** — hash × — `hash` channel — softcap 4.0×/0.6.
2. **INCOME YIELD** — sats/sec — `income` channel — softcap 3.0×/0.6.
3. **CLICK POWER** — tap power — `click` channel — softcap 3.0×/0.6.

**II. Precision / Crit** (Solo's signature; a minor income share on purpose)
4. **NONCE PRECISION** — crit CHANCE — decouple crit-chance onto its own stat — hard cap 25% (base 6%).
5. **BLOCK REWARD** — crit PAYOUT — revives dead `special`; `critMult = 5 + 5·softcap(Σspecial, start 1.0, power 0.5)` — self-limiting. `[P0]`
6. ~~STALE-BLOCK ECHO~~ `[CUT]` — a 4th tap-modifier on a click that softcaps at 3× = proc-noise.

**III. Efficiency / Economy** — spend less / keep more; makes a cheap build rival a brute.
7. **RIG THRIFT** — cheaper rigs — `rigCost` channel — hard floor −95%.
8. **R&D OPTIMIZATION** — cheaper TECH — `[NEW]` cost lane in research_manager (pairs with blueprints) — cap −80%.
9. **OFFLINE YIELD** — fraction of live rate earned while closed — `[NEW]` `offline` channel — base 0.70, hard cap 1.0 = parity. `[P0]`
10. ~~DUST HARVEST~~ `[CUT]` — redundant tap-lump.
- **ENERGY EFFICIENCY** — cuts an electricity-upkeep skim — `[NEW]` upkeep sink — **optional/late** (heaviest new system; gives Fee Hedge something to bite). Upkeep bounded 0–15% of gross, attr reduces toward 0.

**IV. Prestige / Progression** (BTC OG's home; all concave)
11. **CONSENSUS WEIGHT** — buildable × on CX+GT gain — revives dead `prestige`; `multiplier(prestige, start 1.0, power 0.5)` ⚑ *(pin these params — was only "softcapped")* — CX/GT accrual already concave. `[P0]`
12. **MASTERY DRIVE** — +% Mastery XP per GovToken — `[NEW]` hook on Mastery-XP accrual — cap +50%.
- ⚑ *Genesis Attunement merged into Consensus Weight (both were "another concave prestige-gain ×").*

**V. Fortune / Luck** — the de-monolithed facets; a sideways UTXO/STASH economy.
13. **PROSPECTOR'S EYE** — crate/anomaly rarity bias — `StashService._rollRarity` — +25% max one-step, never guarantees mythic. `[P0]`
14. **WHALE'S FAVOR** — SWEEP payout toward EV — casino path — hard cap 2.5 EV AND the 400-UTXO/24h net cap (the real brake).
15. **UTXO MAGNETISM** — anomaly spawn rate — `AnomalySystem` — base 5%/tick, hard cap 30%.
- ⚑ *Generalist "Serendipity" catch-all CUT — keeping it would re-monolith the stat we just split. The `luck` channel still exists as the shared base; these three are the specialization facets.*

**VI. Market / Volatility** — turn the ticker into a build lever (OG steers the chain).
16. **MARKET EXPOSURE** — chaos event FREQUENCY — `volatility` channel — softcap 1.5×/0.5.
17. **BULL BIAS** — reweights the event roll toward positive — `[NEW]` chaos RNG weighting — bounded, can never zero-out negatives.
- ⚑ *Momentum Trader CUT (3 market stats for ~6 events was thin); its "longer good events" folds into BULL BIAS if wanted.*

**VII. Resistances / Defense** — see Part 2.
18. **DIAMOND HANDS** (crash magnitude), 19. **FEE HEDGE** (cost-spike + upkeep), 20. **STOCK-TO-FLOW** (halving), 21. **STEEL NERVES** (negative-event duration), 22. **COLD STORAGE** (hack/theft).

**VIII. Ability / Meta** — scales the ability kit (lands WITH the AbilitySystem, see scope).
23. **RIG COOLING** (Haste/CDR) — cuts ability cooldowns — hard cap 0.40 + floors. `[P0]`
24. **OVERCHARGE** — ability buff MAGNITUDE + grant-seconds (NOT durations) — cap +50%.

**IX. Utility / Tempo**
25. **IDLE CAPACITY** — extends the offline-accrual WINDOW — reuse existing offline duration cap — base ~8h → cap ~24h.
- **SEED CAPITAL** — `[NEW]` post-reset starting bank (skips dead minutes) — scales concave with prestige, can never start a run already-won — optional, pairs with presets/blueprints.

⚑ *Renaming note: "Haste/CDR" and "Ability Power" are the most un-BTC labels — give them chain-native names ("Rig Cooling", "Overcharge" above are a start).*

---

## Part 2 — Resistances (owner priority) + the stacking fix

One safe pattern: **reduce a penalty, never add income, hard-capped BELOW full
immunity.** `effect = penalty × (1 − R)`, `R ∈ [0, cap]`. Only cooldown-gated
actives (Pool's STEADY HANDS / CONSENSUS RALLY) grant true immunity.

| # | Name (BTC) | Resists | Formula | Cap |
|---|---|---|---|---|
| 18 | **DIAMOND HANDS** | Market Crash magnitude | `crashMult = 1 − 0.50·(1−R)` | R 0.75 |
| 19 | **FEE HEDGE** | Cost Spike surcharge + Energy upkeep | `surcharge = 0.5·(1−R)` | R 0.75 |
| 20 | **STOCK-TO-FLOW** | the halving's income cut | `f' = f + R·(1−f)` | R 0.60 (never cancels) |
| 21 | **STEEL NERVES** | ⚑ DURATION of Crash/Cost-Spike only | `dur = base·(1−R)` | R 0.60 |
| 22 | **COLD STORAGE** | Hack loss (+ optional theft roll) | `loss = 0.15·(1−R)` | R 0.75 |

⚑ **Review fixes (must-do):**
- **Combined-mitigation cap** — Diamond Hands (magnitude) × Steel Nerves (duration)
  on ONE crash multiply to ~90% passive mitigation = de-facto immunity, which
  collapses the market axis. **Cap the integrated per-event mitigation at ≤0.70
  total** across all resistance levers, so any event always lands ≥30%.
- **STEEL NERVES scoped honestly** — Hack is an instant one-shot (no duration to
  shorten); Steel Nerves resists **only the two duration events** (Crash, Cost
  Spike). Drop the Hack claim.
- **COLD STORAGE** standalone only blunts one rare −15% Hack → thin. Its real
  value is the **theft roll**, which is a `[NEW]` system → **defer to Phase 5**
  (or merge into a broader chaos-defense stat). Lowest-priority resist.
- **DROP "Mempool Agility"** (a proposed dodge) — a third stacking layer on an
  already-near-immune axis.

**Why caps sit below 1.0:** full passive immunity would let a build ignore the
whole market/chaos axis (and remove the reason Corp's "louder chaos" is a real
tradeoff). Total immunity stays reserved for brief, cooldown-gated ability windows.

---

## Part 3 — Exclusive TECH branches + presets + blueprints

**Shape:** 1 shared **TRUNK** + 1 always-open **META spur** + **3 opposed DOCTRINE
PAIRS** (6 branches). Reuses the existing top-down spider graph verbatim; the
horizontal layout just gains "lanes".

- **TRUNK** (shared, ~4 nodes, no lock): the current cheap on-ramp. The Prospector
  phase lives here; the tree forks only after it.
- **META spur** (shared, never lockable): AI Manager + Auto-Research Daemon
  (unlocks preset auto-apply) + Haste/Ability nodes + Blueprint Archive.
- **6 doctrines in 3 pairs** (each ~6–8 tiers, hangs off the trunk via one GATE):
  1. **MEGA-HASH ⟂ LEAN-RIG** (hash / Production vs rigCost+click / Efficiency)
  2. **HODLER ⟂ DEGEN-YIELD** (Prestige+Offline vs income+market harvest)
  3. **DEGEN-LUCK ⟂ COLD-STORAGE** (luck/fortune/crit vs the resistance suite)

Almost all existing nodes re-home with **zero effect changes** (hash chain →
MEGA-HASH; cooling/solar/click → LEAN-RIG; analytics/HFT/DeFi → DEGEN-YIELD).
HODLER / DEGEN-LUCK / COLD-STORAGE populate as the Part-1/2 attributes land.
A build = a triple → 2³ = 8 archetype silhouettes before class + depth factor in.

**Exclusivity (pair-level, v1):** each doctrine starts with a GATE. Buying a gate
commits the pair → the sibling gate + subtree flip to a `locked` state for the run
(greyed, lock-chain icon, "LOCKED — chose MEGA-HASH", not purchasable). At most
one doctrine per pair → up to 3 active, always giving up 3 siblings. FOCUS (all-in
1) vs GENERALIST (3 shallow) is itself a choice. Trunk + META never lockable.
Exclusivity only *removes* access — never grants power or a cheaper path → no
softcap or the 21M wall is touched.

**Respec = the frequent reset.** TECH already fully wipes on every Soft Fork
(frequent), Hard Fork, and New Genesis; `reset()` clears node state AND committed
groups, so you re-choose at every fork. A mid-run paid REROUTE is deferred.

**PRESETS** — one-tap re-tech. `preset = {name, nodeIds}` (the completed set; the
ids imply the gates). Save = snapshot + name. Apply (one tap) = dependency-ordered
auto-buy toward the set as affordable (commits the gates first, auto-locking the
opposing siblings). Every buy at normal (blueprint-discounted) cost → **auto-buy is
economically identical to manual buying**, no new power. If a preset's gates
conflict with a doctrine already entered this run: "Locked this run — apply at your
next Soft Fork."

**AUTO-APPLY** (gated behind the META Auto-Research Daemon): after each Soft Fork
the active preset auto-rebuilds as income allows — **build-aware** (rebuilds YOUR
doctrines, not "everything affordable"). This supersedes the plain REBUILD/AUTO in
[TECH_REACQUISITION_QOL.md](TECH_REACQUISITION_QOL.md).

**BLUEPRINTS** — bounded permanent re-tech discount (no power). Each node keeps a
permanent `researchCount` (survives every reset, like Mastery/Stash).
`discount(count) = 0.40·(1 − 1/(1 + count/6))` → ~2–3% early, ~24% by 12, asymptote
40%. Applied once in `getCostInSats`. Turns the repetition into a mild, capped
"specialization dividend" — your main build spins back up faster each fork.

⚑ **Pick a lane (review):** auto-apply + the blueprint dividend both push toward
build **lock-in**, which sits in tension with "exclusivity = a live choice every
fork". **Resolution: embrace it.** Exclusivity is a **build SETUP** choice you
*can* revisit any fork, but by default your preset re-applies for convenience —
experimenting is opt-in (save a new preset / manually pick a different doctrine).
Idle players settle into a build; the depth is in *finding* it, not re-picking it
every 20 minutes.

---

## Part 4 — Build archetypes (diversity proof)

Eight builds, distinct on **win-condition × primary channel × class**. Endgame
axes: THE LAST SATOSHI (first era to fill 21M → credits), BACK IN TIME best time
(overall + per-class medals), THE TIMECHAIN (all 4 classes mastered).

1. **GARAGE OVERCLOCKER** — Solo, crit-tap (Click+Nonce+Block Reward+Cooling+Thrift; LEAN-RIG/DEGEN-LUCK). Wins fastest *early* Back-in-Time. Weak: foreground-only, click softcaps, fades deep-late.
2. **DATA-CENTER BROADSIDE** — Corp, hash-rush (Hash+Income; MEGA-HASH). Wins raw-throughput (saturates 21M fastest). Weak: worse prestige, louder chaos = variance, no resists.
3. **SATOSHI-ERA WHALE** — OG, prestige-loop (Consensus Weight; HODLER). Wins deep prestige / first LAST SATOSHI. Weak: slow start, concave gain, weak burst.
4. **CONSENSUS COLLECTIVE** — Pool, crash-proof steady (full resist suite; COLD-STORAGE). Wins most *consistent* Back-in-Time + THE TIMECHAIN. Weak: no spikes, SWEEP-capped, no loot.
5. **PROSPECTOR'S EYE** — OG/Solo, loot-hunter (Prospector's Eye; DEGEN-LUCK). Wins STASH collection (a non-time win). Weak: Fortune = no direct income, fragile.
6. **COLD-WALLET HODLER** — OG, AFK once-a-day (Offline Yield + Idle Capacity; HODLER). Wins progress-per-check-in. Weak: offline capped at parity → can never beat an active build's time.
7. **LIGHTNING TEMPO** — Corp, Haste/ability-burst (Cooling+Overcharge; MEGA-HASH+META). Wins burst-ceiling. Weak: Haste capped, durations fixed, foreground-only.
8. **REGULATED WHALE** — Corp, economy-fortress (Hash+income+Fee Hedge+Diamond Hands; DEGEN-YIELD locks HODLER). Wins sustained mid-game. Weak: forgoes prestige, beaten on peak by #2/#7.

**Verdict:** win-conditions cover every rewarded axis; primary channels differ;
all 4 classes represented; hard branch locks (not mere emphasis) separate the
close pairs (#1 vs #2/#7, #3 vs #8, #4 vs #5). None strictly dominant — each wins
one axis and is measurably weak elsewhere; the softcaps + 21M wall + concave
prestige + SWEEP cap keep even a "grail" synergy inside the rails.

---

## Part 5 — New systems (honest scope) + phasing

⚑ **Scope honesty (review):** "only 4 new systems" was optimistic. Reality:
- **AbilitySystem is a PREREQUISITE EPIC, not a free rider** — Rig Cooling /
  Overcharge depend on it, so they **cannot be Phase 0**; they land whenever the
  ability kit is built.
- Genuinely new, each needing design + save-field + sim-guard + UI (not "one
  line"): **Upkeep/Energy**, **theft roll** (Cold Storage), **R&D discount lane**,
  **Bull Bias RNG reweight**, **Seed Capital grant**. Honest count of nontrivial
  new surfaces ≈ 8–10.
- Cheapest + highest-value: the **luck decouple** and the **resistance hooks**
  (owner priority) — mostly `penalty×(1−R)` at sites that already compute the
  penalty.

**Phasing (each slice independently shippable + sim-guarded):**
- **Phase 0** — the 5 agreed: Offline Yield, Block Reward (`special`), Consensus
  Weight (`prestige`), Prospector's Eye. *(Rig Cooling moves to the AbilitySystem
  phase — fixes the Phase-0 contradiction.)*
- **Phase 1** — luck decouple (Nonce Precision / Whale's Favor / UTXO Magnetism) +
  Mastery Drive + Idle Capacity. All reuse existing systems. Highest variety/line.
- **Phase 2** — the resistance suite (Diamond Hands / Fee Hedge / Stock-to-Flow /
  Steel Nerves) with the combined-mitigation cap. Gives Pool its identity.
- **Phase 3** — exclusive TECH forks + presets (branch-tag existing nodes, gate
  exclusivity, save/apply/auto-apply). Supersedes the plain REBUILD QoL.
- **Phase 4** — market steering (Bull Bias) + ability meta (Overcharge, Rig
  Cooling) landing with the AbilitySystem.
- **Phase 5** — blueprints + the heavy/optional new systems (Upkeep+Fee-Hedge
  bite, R&D discount, Seed Capital, Cold-Storage theft roll). Any subset droppable.

---

## Open decisions for the owner
1. **Attribute count** — target **distinctness (~25 load-bearing), not exactly 30**? (Review's strong recommendation; I agree.)
2. **Commitment budget** — enter all 3 doctrine pairs (generalist) or cap at 2 (sharper specialization)? Recommend ship 3, A/B via the sim.
3. **Upkeep/Energy economy** (the heaviest new system) — build it (gives Fee Hedge real bite + a sustain axis) or cut it (game is diverse without it)?
4. **Cold Storage / theft roll** — build the theft system (Phase 5) or merge Cold Storage into a broader chaos-defense stat?
5. **Auto-apply default** — off (opt-in via Auto-Research Daemon) or on once owned?
6. **Blueprint curve** (cap 40%, T=6) + preset cap (~5) — accept or tune to playtest re-tech times.
