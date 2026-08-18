# TECH TREE REDESIGN V2 — "THE THREE ENGINES"

> Status: **DESIGN — awaiting owner buy-in.** Not built yet. Produced by a 6-agent
> judge-panel workflow (ground → 4 rival designs → judge+synthesize), grounded in
> the real 24 channels + keystones + abilities + firmware procs. Winner:
> *synergy-first "The Three Engines"* (34/35), grafting the best of the WoW-rows
> packing, the constellation shared-root + capstone-ignition, and the PoE click-rate idea.

## PITCH (read this first)

Rip out the 8-doctrine / opposed-pair maze and its locks; replace it with **three
self-contained vertical Engines — THE FOUNDRY, THE GOLDEN NONCE, THE DEGEN** — each
grouping one coherent attribute family, each a clean 2-lane column that reconverges
into a build-defining keystone, shown **one-at-a-time in a SKILL-style accordion** so
it's phone-compact and *physically cannot cross a wire*. A single **Research-Point
budget (8→14 per fork; whole tree costs 27 RP)** means you finish one Engine, half of
a second, and none of the third — and because a keystone is a **9-RP all-in**, every
run has exactly one identity. It reuses ~20 existing nodes and all 12 keystones, adds
**one new lever — `doubleDrop`** (chance for a second crate) — and a live
"SYNERGIES active" row that teaches the player why crit feeds procs feeds crit.

---

## 1. WHY THE CURRENT TECH IS "WEIRD" (root causes, confirmed in source)

- **Incoherent doctrine bundling.** HODLER welds `offline`+`idle`+`prestige` (so picking
  income permanently forfeits ALL prestige tech); DEGEN-LUCK welds 5 unrelated luck
  facets (crit chance / crit payout / sweep / anomaly / crate) into one chain you can't
  specialize; the "opposed pairs" (megaHash⟂leanRig) aren't real opposites.
- **`fee_hedge` orphaned in TRUNK** while its 4 sibling resistances are gated behind a
  doctrine — inconsistent.
- **Paths cross by construction.** The doctrine-lane layout roots spines at *centered
  trunk nodes that fork to lanes on opposite sides* (`ergonomic_rig`→leanRig **and**
  →degenLuck; `cold_storage`→hodler **and** →coldStorage), so long diagonal edges cut
  across intervening columns. It's structural, not a routing bug.
- **`luck` and `volatility` have ZERO TECH sources today.**

## 2. THE THREE BRANCHES (logical attribute groups)

| Engine | Fantasy | Channels owned (real) | Tint |
|---|---|---|---|
| **A · THE FOUNDRY** | "A machine that prints while I sleep." | `hash`, `income`, `rigCost`, `offline`, `idle`, `prestige` | Amber |
| **B · THE GOLDEN NONCE** | "Every tap is a lottery ticket, and I stacked the deck." | `click`, `nonce`, `special`, `haste`, `overcharge`, + auto-tap RATE | Cyan |
| **C · THE DEGEN** | "I don't manage risk, I farm it." | `luck`, `fortune`, `sweepLuck`, `magnetism`, `volatility`, `bullBias`, 5 resists, **`doubleDrop` (NEW)** | Violet |

Every one of the 24 channels lands in exactly one Engine. **`luck` and `volatility` —
dead in TECH today — finally get sources** (both in C). The always-on meta clutter
(`ai_manager`, `firmware_bay`, `chip_fab`) moves to a **free shared root** so no branch
shares a node with another (the structural cause of today's crossings).

### Shared free root — GENESIS CORE (tier 0, always unlocked, sats-only, 0 RP)
+1 firmware socket (absorbs `firmware_bay`), base auto-click 1 tap/5s (absorbs
`ai_manager`), +20% CPU & GPU hash (absorbs `chip_fab`). The one honest root; the three
Engines hang beneath it and share nothing else.

### Branch shape
Each Engine = **2-lane column, 5 rows**: Root (T1, spans both lanes) → Lane-L and Lane-R
each 3 deep (T2–T4) → Capstone (T5, spans both lanes, **requires the deepest node of BOTH
lanes**). 8 nodes/branch. Normal = **1 RP**, capstone = **2 RP** → a full branch = **9 RP**.
Because the capstone needs both lanes, **taking a keystone is a 9-RP all-in.** Every node
also keeps a **sats cost** (a *when*-gate: rich enough for the era); RP is the *how-many*-gate.

## 3. NODE TABLES (★ = signature-synergy node)

### A · THE FOUNDRY (amber)
| ID | Name | Tier·Lane | Effect | Prereq | RP | sats |
|---|---|---|---|---|---|---|
| A1 | Overclocked Cores | 1·root | `hash +15%` | Core | 1 | 500 |
| A2 | Neural Net Miner | 2·L | `hash +30%` | A1 | 1 | 500k |
| A4 | Quantum Entanglement | 3·L | `hash +50%` | A2 | 1 | 20M |
| A6 | Cold Storage Logistics | 4·L | `rigCost −20%`, `offline +15%`, `idle +8h` | A4 | 1 | 4M |
| A3 | Market Analytics | 2·R | `income +20%` | A1 | 1 | 100k |
| A5 | High-Frequency Trading | 3·R | `income +35%` | A3 | 1 | 2M |
| A7 | **Reinvestment Engine ★** | 4·R | `income +1%` per +20% total `hash` held, cap +50% | A5 | 1 | 100M |
| A8 | **THE CENTRAL BANK** (cap) | 5 | `income +50%`, `hash +40%`, `prestige +25%` + keystone | A6 **and** A7 | 2 | 10B |

A8 keystone (equip 1): `ks_furnace_farm` (hash ×1.6 / upkeep pinned) **or** `ks_low_time_preference` (prestige ×1.5, offline parity / income ×0.70).

### B · THE GOLDEN NONCE (cyan)
| ID | Name | Tier·Lane | Effect | Prereq | RP | sats |
|---|---|---|---|---|---|---|
| B1 | Ergonomic Rig | 1·root | `click +30%` | Core | 1 | 20k |
| B2 | Nonce Prediction | 2·L | `nonce +10%` (crit chance) | B1 | 1 | 3M |
| B4 | Precision Hashing | 3·L | `special +50%` (crit payout) | B2 | 1 | 20M |
| B6 | **Golden Nonce Protocol ★** | 4·L | `nonce +5%`; every 4th crit = guaranteed ×2-payout golden nonce | B4 | 1 | 60M |
| B3 | Macro Scripts | 2·R | `click +60%` | B1 | 1 | 400k |
| B5 | AI Co-Pilot | 3·R | auto-tap rate 1/5s → 1/2s (Golden-Rule-safe: synthetic taps proc nothing) | B3 | 1 | 15M |
| B7 | Immersion Cooling | 4·R | `haste −25%` (ability CD) | B5 | 1 | 5M |
| B8 | **OVERCLOCK THE CORE** (cap) | 5 | `click +75%`, `special +50%`, `overcharge +40%` + keystone | B6 **and** B7 | 2 | 10B |

B8 keystone (equip 1): `ks_laser_eyes` (critPayout ×2 / click ×0.5) **or** `ks_sweat_equity` (click ×2.5 / hash ×0.5, idle ×0.5).
*Owner's "click-power WITH click-rate" is literal: B3 (power) sits beside B5 (rate).*

### C · THE DEGEN (violet)
| ID | Name | Tier·Lane | Effect | Prereq | RP | sats |
|---|---|---|---|---|---|---|
| C1 | Lucky Nonce | 1·root | `luck +8%` (**first-ever TECH luck source**) | Core | 1 | 200k |
| C2 | UTXO Magnet | 2·L | `magnetism +10%`, `sweepLuck +10%` | C1 | 1 | 3M |
| C4 | Assay Lab | 3·L | `fortune +12%` (crate quality +1 rarity) | C2 | 1 | 8M |
| C6 | **Double-Drop Manifold ★** | 4·L | **`doubleDrop +15%` (NEW)** — chance a crate open yields a *second* crate | C4 | 1 | 60M |
| C3 | Volatility Engine | 2·R | `volatility +25%` (**newly wired**), `bullBias +1.0` | C1 | 1 | 12M |
| C5 | Hardened Vault | 3·R | `crashResist +25%`, `theftResist +25%`, `costResist +25%` | C3 | 1 | 6M |
| C7 | Diamond Nerves | 4·R | `halvingResist +30%`, `durationResist +30%` | C5 | 1 | 40M |
| C8 | **THE WHALE'S EYE** (cap) | 5 | `luck +15%`, `doubleDrop +10%`, `fortune +8%` + keystone | C6 **and** C7 | 2 | 10B |

C8 keystone (equip 1): `ks_degenerate_gambler` (luck ×2 / income ×0.5, hash ×0.5) **or** `ks_market_maker` (chaosPos ×1.5, chaosNeg ×1.5 / resist ×0.5).

**24 nodes total** (down from 39) + 3 free root utilities. Every channel homed.

## 4. NEW ATTRIBUTE — `doubleDrop`
- **What:** chance rolled at every crate open to yield a **second full crate** (COUNT, not quality). New `Channel.doubleDrop`, cap `doubleDropMax = 0.25`.
- **Why it's not `fortune`:** `fortune` bumps a rolled crate **+1 rarity** (quality); `doubleDrop` makes **more** crates (count). No per-open count lever exists today.
- **Consumption:** one hook at crate resolution — `if rng < doubleDrop → resolve a second standard crate of the same tier`, firing `onCrateOpen` again (throttled by the existing token-bucket).

## 5. THE PICK-BUDGET RULE (the tension engine)

**One number: Research Points (RP)** — a *permanent, growing pool* you re-spend
**in full every fork** (free respec). No BTC cost anymore (owner-confirmed). The pool
grows by **prestige-ladder breakthroughs**, so you start with little and unlock more
gradually — each milestone pops a visible "**+N RP**" toast:

| Source (breakthrough) | RP | When | Feel |
|---|---|---|---|
| **First Hard Fork** (TECH unlocks) | **4** | very start | 4 nodes → a mini-build of one lane, not a full branch |
| **Each further Hard Fork** | +1 → cap **8** | early ramp | "fork more = research more" |
| **Each Genesis Block** (New Blockchain) | +2 → cap **14** | mid/deep | reward for deep prestige |
| **Deep Mastery** (+1 per 2 levels) | +1 → cap **18** | endgame | reward for deep single-class play |

Curve: **4 → 8 → 14 → 18** (owner-confirmed, supersedes the old 8→14). Whole tree =
**27 RP** (3 × 9). The pool buys **~15% early → ~67% deep** of it. Numbers are tunable
and get a balance sim before ship. (Alternatives considered + parked: RP from
achievements; RP as a mined prestige-currency.)

| Budget | What it buys | Feel |
|---|---|---|
| 8 (first fork) | 7 nodes of one branch — but NOT its 2-RP capstone (needs 9) | "Pick a lane and you still can't finish it." |
| 11 (mid) | one full branch + keystone (9) + 2 nodes elsewhere | "Commit to a keystone, or stay flexible?" |
| 14 (deep) | **one full branch + keystone (9) + half a second (5) + none of the third** | The brief, exactly. |
| 18 (endgame) | two full branches + both keystones | Equip-cap of 2 finally reached — and earned. |

A keystone = 2 RP *and* its whole 9-RP branch → ~64% of a 14-budget in one commit.
The alternative **flex build** — two half-branches (5+5), no keystone — is a real,
viable, different choice, not a trap. Header shows `RP 9 / 14`; **no opposed-pair lock
logic to decode.** **Respec:** full free refund every fork; mid-fork "Recalibrate" = 1
GovToken. This deletes the "you touched degenYield so prestige is gone forever" trap.

## 6. TOP 5 SIGNATURE SYNERGIES
1. **CRIT CASCADE** *(B)* — `nonce`→crit chance → `special`→payout → **B6** makes every 4th crit a guaranteed ×2 → `onCrit`/`onCritStreak` firmware fire constantly; `haste`+`overcharge` recur the guaranteed-crit abilities. Detonator: `ks_laser_eyes`. A closed tap-storm engine.
2. **COMPOUND INTEREST** *(A)* — **A7 literally reads `hash` and pays it as `income`** (cap +50%), so the hash lane *feeds* the income lane — which is why A8 demands both lanes. Layer `The Long Tail` aura + `ks_furnace_farm`.
3. **DOUBLE OR NOTHING** *(C, headline)* — `luck`→`fortune` (+1 rarity) → **C6 doubleDrop** (second crate) → every open rolls twice, both bumped, each firing `onCrateOpen`. `ks_degenerate_gambler` pushes toward the 0.25 cap; crates *pour*.
4. **CHAOS SURFER** *(C→auras→firmware)* — **C3** raises event frequency + tilts positive → `Bull Rider`/`Storm Rigging` up almost always → `onGoodChaos`/`onBadChaos` procs fire on every swing; C5/C7 resists are the net that lets you *want* the storm. Crown: `ks_market_maker`.
5. **OVERCLOCK BURST** *(B→abilities→splash)* — `haste` + `overcharge` make every class's kit fire ~⅓ oftener at ~40% more punch — the designed "half a second branch" tempo splash.

## 7. VISUAL LAYOUT (top-down, zero crossings, phone-compact)

**Idiom = the SKILL tab's split, reused:** the whole tab is a single accordion list in
**TWO grouped sections** (owner-confirmed):
- **RESEARCH BRANCHES** — the three Engine cards; tapping one expands its tree, the
  others collapse to a one-line pip summary. Only one branch's graph is ever on screen.
- **KEYSTONES & SYNERGIES** — two more accordion cards, *same expand idiom*, under their
  own section header so the meta layer reads as visually separate from the branches.
  **Keystones** expands to the ≤2 equip choices grouped by branch (locked until that
  branch's capstone is owned); **Synergies** expands to the live combo checklist that
  teaches why nodes sit together.

Reuse the existing `BlockGraph` + `showGraphNodeSheet`.

**Owner visual notes (for the build):** the root node AND the capstone are both
horizontally **centered** (single/spanning nodes always centered); the background
connector wires must **never show through an un-researched node** (nodes paint a fully
opaque fill — dim locked nodes by color, never by card-opacity); and each expanded
branch carries a **faint theme-graphic wash** in its own tint (a soft radial + a large
low-opacity branch glyph) so the section has "grády". The game currently reads as
colour-poor in TECH/SKILL — this colour-coded, tinted treatment is the fix, and the
same discipline carries to the SKILL redesign.

```
┌──────────────────────────────────────────┐
│  TECH · RESEARCH            RP  9 / 14  ●  │  ← single budget number
├──────────────────────────────────────────┤
│  ▸ THE FOUNDRY        ●●●●●●●● ★ keystone │  ← collapsed: 8 pips + keystone flag
│  ▾ THE GOLDEN NONCE            5 / 9 RP    │
│            ┌─ B1 Ergonomic Rig ─┐          │  ← root spans both lanes
│           ┌┘                    └┐         │
│      [B2 Nonce +10%]     [B3 Macro +60%]   │  ← 2-wide lanes, short vertical edges
│      [B4 Special +50%]  [B5 AI Co-Pilot]   │
│      [B6 Golden Nonce★] [B7 Immersion]     │
│            └┐                    ┌┘         │
│            [ B8 OVERCLOCK CORE ] ★ KEYSTONE │  ← capstone spans both, IGNITES at 100%
├──────────────────────────────────────────┤
│  ▸ THE DEGEN                   0 / 9 RP    │
├──────────────────────────────────────────┤
│  [ KEYSTONES ]     [ SYNERGIES active ]    │  ← two tappable modal rows (SKILL idiom)
└──────────────────────────────────────────┘
```

**No-crossing guarantee:** each expanded branch is a 2-col × 5-row grid. Root spans both
cols (row 0); two lanes descend straight down cols L/R (rows 1–3); capstone spans both
(row 4). The only forks are the symmetric Y-split (root→lanes) and Y-merge
(lanes→capstone) — no diagonal is longer than one cell and **no edge leaves the branch
frame.** Crossing is impossible by construction.

**Node states:** Locked = dim slate + dashed + `???` teaser; Available = solid card,
channel-tinted left bar, bright `−1 RP` chip, gentle pulse (sats-short → chip amber);
Owned = filled channel color + check; Budget-spent = RP chip greyed red (you *see what
you gave up*); Capstone = double-height gold rim that **ignites** (particle sweep) when
both lanes complete and reveals the two keystone chips. Collapsed card = name + 8 pips +
★ + `spent/9`. Footer modal rows: **KEYSTONES** and **SYNERGIES active** (live checklist
teaching the combos: `Crit Cascade ✓ · Compound Interest ✓ · Double-or-Nothing ✗ needs C6`).

## 8. MIGRATION (incremental, not a rewrite)

- **Reused (id kept), lightly rebalanced:** neural_net→A2, quantum_entanglement→A4,
  market_analytics→A3, high_frequency_trading→A5, central_bank→A8, ergonomic_rig→B1,
  macro_scripts→B3, nonce_prediction→B2, precision_hashing→B4, immersion_cooling→B7,
  power_capacitors→B8, mempool_sniffer+utxo_magnet→C2, assay_lab→C4, sentiment_analysis→C3,
  stock_to_flow+steel_nerves+cold_storage_vault→C5/C7.
- **Renamed:** basic_overclock→A1 (+5→+15%); consensus/governance folded into A8 prestige.
- **Merged (fewer, fatter nodes):** 10-node MegaHash ladder→A1/A2/A4/A8; DegenYield ladder→A5/A8;
  cooling/solar/bulk/daemons/battery/grid→A6; fee_hedge+diamond_hands→C5. **39 → 24 nodes.**
- **Moved to free Genesis Core:** firmware_bay, ai_manager, chip_fab.
- **Added:** `Channel.doubleDrop` (+cap 0.25 + one crate hook); `volatility` wired (C3);
  B5 auto-tap-rate (explicit); A7 hash→income coupling; the RP ledger.
- **Cut:** the 8-doctrine/opposed-pair machinery (`commitmentBudget`, `isDoctrineLocked`,
  `_doctrineOf`, the doctrine-lane layout at research_tab.dart L145–274). Replace with
  per-node `rpCost`, a per-fork `rpBudget`/`rpSpent` pool, branch-depth prereqs,
  free-respec-on-fork. **Keystones gate on "capstone owned"** (one-line predicate change);
  the 12 `kKeystones` reused verbatim (6 surface as capstone choices).

### Balance risks vs the rails (verify on build)
- Fewer/fatter nodes push per-node magnitudes into the same softcaps — check `hash softStart 4.0`,
  `special` critMult cap 55 (B6's ×2 must be a discrete post-softcap event, not a `special` add),
  `nonce` 25%, `magnetism` 30%/tick, `sweepLuck` EV 2.5, `haste` .40, `overcharge` .50, resist caps.
- `doubleDrop` cap 0.25 must **sum-clamp** across C6/C8/keystone, not stack; the 2nd crate counts
  against the same proc token-bucket (8/10s) + UTXO window cap (25/min).
- A7 must read **bonus** hash (not absolute) so the income-per-hash loop can't scale with era; +50% cap is the guardrail.
- 18-RP two-keystone build must sit behind a real prestige wall (Overmind Lattice).
- B5 auto-tap stays Golden-Rule-muted for procs (throughput/payout only).

## 9. FILES A DEV WILL TOUCH
`lib/logic/channels.dart` (add `doubleDrop`), `lib/logic/managers/research_manager.dart`
(RP ledger + new node defs, replacing doctrine machinery), `lib/screens/research_tab.dart`
(accordion + 2-lane grid, replacing L145–274), `lib/logic/systems/keystone_system.dart`
(unlock predicate: capstone-owned), and the crate-resolution path (`doubleDrop` hook).

---
*Full 6-agent transcript (scorecard for all 4 rival designs + the ground-truth dossier)
lives in the workflow output; this doc captures the synthesized winner.*
