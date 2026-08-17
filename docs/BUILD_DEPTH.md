# Build Depth — ~25 attributes, resistances, exclusive TECH branches, presets & blueprints

Status: **IMPLEMENTED** (Slices 0–10, 2026-08). The attribute suite, resistances,
exclusive TECH doctrines (commitment budget 2), presets + auto-apply, and
blueprints all shipped — see channels.dart / constants.dart / research_manager.dart
/ game_logic.dart. Was: PLANNING ONLY. Multi-agent design pass + adversarial review
(verdict *ship-with-fixes*); the review's cuts/fixes are folded in below (⚑).
NOTE: a few literal numbers below are stale vs the shipped (gentler) values —
upkeep cap 15%→**10%** and breach base loss 15%→**10%** (owner-chosen); Mastery XP
source changed to **per mined 21M supply** (not per GovToken). lib/core/constants.dart
is the source of truth for all caps.
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
- **ENERGY EFFICIENCY** — cuts an electricity-upkeep skim — `[NEW]` upkeep sink — **optional/late** (heaviest new system; gives Fee Hedge something to bite). Upkeep bounded 0–10% of gross (as-built; was 15% — `upkeepCap=0.10`), attr reduces toward 0.

**IV. Prestige / Progression** (BTC OG's home; all concave)
11. **CONSENSUS WEIGHT** — buildable × on CX+GT gain — revives dead `prestige`; `multiplier(prestige, start 1.0, power 0.5)` ⚑ *(pin these params — was only "softcapped")* — CX/GT accrual already concave. `[P0]`
12. ~~MASTERY DRIVE~~ `[CUT]` — ⚑ its "+% Mastery XP per GovToken" hook no longer exists once Mastery moves to **per-mined-supply** (ENDGAME_REDESIGN), and +50% would break the "1 full supply = exactly 1 Mastery unit, un-farmable" identity + de-sync the ability-unlock gates (slot 2 @ Mastery 1, ult @ Mastery 2). Removed.
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
| 18 | **DIAMOND HANDS** | Market Crash magnitude | `crashMult = 1 − 0.50·(1−R)` | R 0.70 |
| 19 | **FEE HEDGE** | Cost Spike surcharge + Energy upkeep | `surcharge = 0.5·(1−R)` | R 0.70 |
| 20 | **STOCK-TO-FLOW** | the halving's income cut | `f' = f + R·(1−f)` | R 0.60 (never cancels) |
| 21 | **STEEL NERVES** | ⚑ DURATION of Crash/Cost-Spike only — **NOT hack/breach** | `dur = base·(1−R)` | R 0.60 |
| 22 | **COLD STORAGE** | Hack loss (+ optional theft roll) | `loss = 0.10·(1−R)` (as-built; was 0.15 — `breachBaseLoss=0.10`) | R 0.70 |

⚑ Per-lever caps lowered 0.75→0.70 and the **integrated combined mitigation
`min(0.70, 1 − ∏(1−Rᵢ))` per event type is AUTHORITATIVE** (see
[BALANCE_AND_BOUNDS.md](BALANCE_AND_BOUNDS.md) #8) — an event always lands ≥30%.

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
  3. **DEGEN-LUCK ⟂ COLD-STORAGE** (luck/fortune/crit vs the resistance suite — ⚑ as-built, one suite member, **Fee Hedge** (`Channel.costResist`), sits on the TRUNK, not the COLD-STORAGE gate, so it is reachable by any build; the gated members are Diamond Hands / Stock-to-Flow / Steel Nerves / Cold Storage Vault)

Almost all existing nodes re-home with **zero effect changes** (hash chain →
MEGA-HASH; cooling/solar/click → LEAN-RIG; analytics/HFT/DeFi → DEGEN-YIELD).
HODLER / DEGEN-LUCK / COLD-STORAGE populate as the Part-1/2 attributes land.
A build = a triple → 2³ = 8 archetype silhouettes before class + depth factor in.

**Exclusivity (pair-level, v1):** each doctrine starts with a GATE. Buying a gate
commits the pair → the sibling gate + subtree flip to a `locked` state for the run
(greyed, lock-chain icon, "LOCKED — chose MEGA-HASH", not purchasable). At most
one doctrine per pair, and a **commitment budget of 2 pairs** (as-built; was 3 —
`commitmentBudget=2`) → up to 2 active, giving up their siblings, and the third
pair stays unentered once the budget is spent. FOCUS (all-in 1) vs GENERALIST (2
shallow) is itself a choice. Trunk + META never lockable.
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

**AUTO-APPLY (owner-chosen: default ON, opt-out).** After every reset the active
preset auto-rebuilds as income allows — **build-aware** (rebuilds YOUR doctrines,
not "everything affordable"). A first-time GUIDE explains it ("Your build re-applies
automatically after each reset — you can turn this off, or rebuild once per run").
Supersedes the plain REBUILD/AUTO in
[TECH_REACQUISITION_QOL.md](TECH_REACQUISITION_QOL.md).

**ONE FREE RESPEC PER RUN (owner-chosen) — SHIPPED.** After the preset auto-applies
you may, **once per era**, clear the whole tree and manually build something
different — re-choosing your doctrines (this is the in-run REROUTE the earlier plan
deferred) — then **save it as a new preset**. After that single respec the doctrines
lock again until the next fork. So: auto-apply keeps it frictionless, but
experimenting + saving a new build is always one tap away, without waiting for a
fork. *As built:* a `FREE RESPEC` button in the TECH header (only shown once
something is researched); a confirm dialog; `respecTech()` calls the same
`ResearchManager.reset()` the forks use, so it **keeps blueprints** (re-tech stays
discounted) and only clears node/doctrine state. The `respecUsed` flag persists in
the save, and every fork (Soft/Hard/New Genesis) + full wipe refreshes it.

**PRESET SLOTS: cap 3 (owner-chosen).** Small on purpose. Each is **auto-named by
its dominant axis** so the player never types a name: pick the doctrine/channel
with the most invested nodes and label it — e.g. mostly MEGA-HASH → "Hash Whale",
HODLER/prestige → "Prestige Farmer", DEGEN-LUCK → "Fortune Hunter", COLD-STORAGE →
"Fortress", LEAN-RIG+crit → "Crit Tapper". (Player can still rename.)

**BLUEPRINTS** — bounded permanent re-tech discount (no power). Each node keeps a
permanent `researchCount` (survives every reset, like Mastery/Stash).
`discount(count) = 0.40·(1 − 1/(1 + count/6))` → ~2–3% early, ~24% by 12, asymptote
40%. Applied once in `getCostInSats`. Turns the repetition into a mild, capped
"specialization dividend" — your main build spins back up faster each fork.

⚑ **Lane resolved (owner):** auto-apply + the blueprint dividend push toward build
**lock-in**, which is *intended*. Exclusivity is a **build SETUP** choice: your
preset re-applies automatically after each reset (frictionless), and the **one
free respec per run** is the opt-in path to try + save a different build. Idle
players settle into a build; the depth is in *finding* the grail, not re-picking
it every 20 minutes.

---

## Part 3b — Keystones (the MOBA / PoE build-definer layer)

Beyond the ~25 numeric attributes, add a small set of **KEYSTONES** — the
MMORPG/MOBA "talent" / PoE "keystone" idea: **a big, build-defining effect with a
real downside; you pick ONE.** These are what make a "grail build" feel like a
*build*, not just stacked %s. They live at **doctrine capstones** (the deepest
node of a TECH branch), so committing a doctrine + its keystone is the identity of
the run. Optional later phase; ~1 per doctrine to start.

| Keystone (BTC) | Doctrine | Upside | Downside |
|---|---|---|---|
| **ASIC MONOCULTURE** | MEGA-HASH | +100% hash | −60% luck, no crits (all-in raw output) |
| **LASER EYES** | DEGEN-LUCK | crit chance to cap + crit payout ×2 | non-crit taps do nothing (crit-or-bust) |
| **PAPER HANDS** | DEGEN-YIELD | GovToken gain ×2 | Consensus can't be held — you must fork fast |
| **LOW TIME PREFERENCE** | HODLER | prestige gain ×1.5 + full offline parity | −30% active income (the loop, not the grind) |
| **COLD MINER** | COLD-STORAGE | immune to ALL negative events | positive events (Bull Run etc.) also never fire |

They stay rail-safe: each is one bounded multiplier/flag with a symmetric cost,
gated behind a deep exclusive doctrine, so no keystone stacks into a runaway —
the tradeoff *is* the balance. This is the layer that most directly answers "draw
on RPG/MMO/MOBA history," and it pairs perfectly with the exclusive-branch TECH.

## Part 4 — Build archetypes (diversity proof)

*(Reminder: there are still **4 classes** — Solo Miner, Corporation, BTC OG, Pool
Member. The 8 below are **archetypes / builds** = class × attributes × TECH
doctrine (× keystone), not new classes.)*

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
  Idle Capacity. All reuse existing systems. Highest variety/line.
- **Phase 2** — the resistance suite (Diamond Hands / Fee Hedge / Stock-to-Flow /
  Steel Nerves) with the combined-mitigation cap. Gives Pool its identity.
- **Phase 3** — exclusive TECH forks + presets (branch-tag existing nodes, gate
  exclusivity, save/apply/auto-apply). Supersedes the plain REBUILD QoL.
- **Phase 4** — market steering (Bull Bias) + ability meta (Overcharge, Rig
  Cooling) landing with the AbilitySystem.
- **Phase 5** — blueprints + the heavy/optional new systems (Upkeep+Fee-Hedge
  bite, R&D discount, Seed Capital, Cold-Storage theft roll). Any subset droppable.

---

## Decisions

### Resolved (owner)
- ✅ **~25 load-bearing attributes** (distinctness over a round 30).
- ✅ **Keystone layer added** (Part 3b) — the MOBA/PoE build-definers; ~1 per doctrine, optional later phase.
- ✅ **Auto-apply preset = default ON, opt-out**, with a first-time guide.
- ⚑ **One free respec per run** to rebuild + save a new preset — *resolved-but-NOT-yet-built in v1: no clear-tree/respec code shipped (`reset()` on a fork is still the only re-choice path; there is no in-run REROUTE).*
- ✅ **Preset cap = 3**, auto-named by dominant axis.
- ✅ **Commitment budget = 2 doctrine pairs** (sharper specialization; → equip ≤2 keystones).
- ✅ **Upkeep/Energy economy = IN** (owner reversed the earlier defer) — designed as "THE POWER BILL" in [CHAOS_DEPTH_LAYER.md](CHAOS_DEPTH_LAYER.md).
- ✅ **Theft = BUILT** ("THE BREACH", hot/cold wallet) — gives Cold Storage real bite; see CHAOS_DEPTH_LAYER.md.
- ✅ **MORE MOBA/MMO breadth = YES, go big** — procs + auras + on-crit + expanded (12) keystones, all in CHAOS_DEPTH_LAYER.md.

### Still open
1. **Blueprint curve** (cap 40%, T=6) — accept or tune to playtest re-tech times.
2. Tuning constants for the whole depth stack — see the open decisions in [CHAOS_DEPTH_LAYER.md](CHAOS_DEPTH_LAYER.md) (aggregate temp ceiling, crit-payout cap, upkeep K, breach cadence).
