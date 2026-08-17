# TECH tree redesign — "lean, not a combination" (device finding #5)

> **STATUS: DESIGN NOTE — awaiting owner approval before code.** Grounded in a
> read-only audit of the live tree (node ids, prereqs, effects, layout math).
> Render pane is down this session, so it can't be visually verified here — pick
> the direction + the open decisions below and I implement in the sliced plan.

## The owner's finding (2026-08-17, phone)

> "The TECH tree is too wide, and the lock + doctrines don't sit well with the
> character of the bonuses. It should connect and flow better — so it isn't a
> *combination*, but more a *lean toward a few attributes*."

## What the tree actually is today (audited)

52 nodes, defined inline in `research_manager.dart:71-625`; doctrine membership is
a hand-kept side table `_doctrineOf` (`:812-862`); layout is `research_tab._graph`
(`:93-206`). Six doctrines in three exclusive pairs + TRUNK (13, never lockable) +
META (2). Commitment budget = 2 pairs.

**Why it's too wide (measured).** Layout width = `maxBucket × 172 + 160`, where
`maxBucket` is the most nodes in any single prereq-depth row. The widest row is
**depth 2 with 14 nodes → ~2568px wide**, while the tree is only ~8 rows tall. Those
14 come from doctrines that *fan out in parallel* instead of chaining down:
- **DEGEN-LUCK's 5 nodes all sit at depth 2, side by side** (the single biggest
  cause), each an unrelated one-off luck facet.
- 3 MEGA-HASH branches also open at depth 2.
- plus 4 trunk + 1 meta + 1 leanRig.

**Why doctrines feel like grab-bags (coherence audit).** Every node pushes exactly
one channel. Only two doctrines are true single-attribute spines; the rest are
mixes:

| Doctrine | Attributes pushed | Verdict |
|---|---|---|
| **MEGA-HASH** (9) | hash ×9 (+.15 → +1.0) | ✅ tight spine (the template) |
| **DEGEN-YIELD** (6) | income ×6 | ✅ tight spine |
| **HODLER** (4) | offline + prestige | ~ two-axis, theme-bound ("patience") |
| **LEAN-RIG** (7) | rigCost + click, **two disjoint parallel chains** | ~ mini-combination |
| **COLD-STORAGE** (6) | 4 resist lanes + idle, spread thin | ✗ grab-bag |
| **DEGEN-LUCK** (5) | special/nonce/sweepLuck/magnetism/fortune — **5 unrelated, unchained, flat +10%** | ✗ worst grab-bag |

**Why the lock feels disconnected.** Exclusivity is a pure membership tag checked
at buy time, entirely separate from what a node *does*. It fires on your **first
shallow purchase** in a doctrine (buy one +10% luck node → the whole Fortress tree
greys for the run). Nothing in the effects creates the opposition — it's a label.

So the earlier note's "data already leans, layout-only" was wrong: **two doctrines
lean, four are grab-bags.** The real fix is content (re-chain into spines) **and**
layout (lanes).

## The design — DOCTRINE LANES + re-chained spines

Keep the 6 doctrines / 3 pairs / budget-2 (they map 1:1 onto six attribute
families). Change **broad-and-shallow → narrow-and-deep**: each doctrine becomes
ONE flowing vertical lane that deepens the same 1–3 named attributes, laid out as a
fixed column you scroll *down*. Committing = "I'm specializing into X"; its paired
sibling greys the whole adjacent lane ("pick a lane").

Each pair is a genuine contest on a shared axis:
- **MEGA-HASH** (brute auto hash) ⟂ **LEAN-RIG** (scrappy manual click + cheap rigs) — two ways to drive output
- **DEGEN-YIELD** (active market income) ⟂ **HODLER** (passive patience: offline/idle/prestige) — trade vs hodl
- **DEGEN-LUCK** (embrace variance) ⟂ **COLD-STORAGE** (eliminate variance) — gamble vs fortress

### The six lanes (existing node ids re-chained; effects unchanged)

- **MEGA-HASH → HASH.** advancedOverclock→neuralNet→distributedComputing→quantumEntanglement→quantumOverclock→fusionOverclock→plasmaOverclock→antimatterCores→zeroPointHash*(capstone)*. (pull the 2 parallel d2 branches inline)
- **LEAN-RIG → CLICK + RIG-COST.** one interleaved spine: macroScripts→geothermalCooling→neuralInterface→nanofabrication→quantumReflexes→orbitalLogistics→selfReplicatingRigs*(capstone)*.
- **DEGEN-YIELD → INCOME.** defiYield→taxHaven→liquidityMining→algorithmicTrading→hedgeFund→centralBank*(capstone)*. (fold the taxHaven dead-end into the spine)
- **HODLER → PATIENCE (offline+idle+prestige).** absorbs the 2 idle nodes from cold-storage: autonomousDaemons→batteryBank→miningDaemonSwarm→gridStorage→consensusProtocol→governanceCartel*(capstone)*.
- **DEGEN-LUCK → LUCK.** collapse the 5 parallel facets into one gamble spine (biggest width win): noncePrediction→precisionHashing→mempoolSniffer→utxoMagnet→assayLab*(capstone)*.
- **COLD-STORAGE → RESIST.** pull feeHedge in from trunk to complete the fortress: diamondHands→feeHedge→stockToFlow→steelNerves→coldStorageVault*(capstone)*.

TRUNK stays a short centered stem above the lanes; META a small spur off it.

### Layout fix (`research_tab._graph`)

Replace depth-bucket X placement with **X = laneIndex × laneGap, Y = tier × levelH**
(paired siblings adjacent). Width becomes `laneCount × laneGap` — fixed ~7 columns,
regardless of content. Per-lane header chip prints the attribute ("MEGA-HASH ·
+hash"); a committed sibling greys its whole lane. Positions still derive from the
whole tree, so buying never reflows (invariant preserved).

## Incremental slice plan (each revertable; only 3–4 need the sim gate)

1. **Re-chain (data only, rail-safe by construction).** Rewrite each doctrine's
   `requirements` into single spines. No effect edits, no doctrine moves → every
   (channel, value) and membership identical → per-channel rails hold. This alone
   empties the fat depth-2 row and narrows the current graph. Run doctrine-lock /
   preset / respec tests.
2. **Lane layout (UI only).** Rewrite `_graph` to lane columns + trunk stem +
   header chips + grey-whole-lane on sibling commit. No economy touch.
3. **Doctrine moves (needs re-sim).** `batteryBank`/`gridStorage` coldStorage→hodler
   (idle = patience), `feeHedge` trunk→coldStorage (completes the fortress). These
   change what's lockable-together → build-matrix + economy re-sim; update
   BUILD_DEPTH + BALANCE_AND_BOUNDS.
4. **(Optional, needs re-sim) Re-point DEGEN-YIELD keystones to income.** Paper
   Hands / Market Maker currently drift to govToken/chaos; income-axis fits the
   lane. Highest balance risk (multiplicative income rail) — its own slice or defer.
5. **Docs + mark #5 done.**

## Balance note (the rails)

Pure re-chaining preserves every (channel, value) but changes cost-gating **depth**
(a deep node is reachable only after its whole spine), which shifts pacing — so even
Slice 1 gets an economy sim pass. Slices 3–4 change reachable channel maxima /a
multiplicative rail → full build-matrix + economy re-sim before merge, checked
against the per-channel softcaps and the net-income bound in BALANCE_AND_BOUNDS.
Rule: re-sim whenever a node changes doctrine, a keystone effect changes, or chain
depth re-gates a cost. Nothing is cut — all 52 nodes survive.

## Open decisions for the owner (my recommendation in bold)

1. **Direction: DOCTRINE LANES + re-chained spines** — **yes** (realizes all three
   complaints; the light-touch "just recolor the graph" alternative doesn't fix
   "combination vs lean").
2. Keep 6 doctrines / 3 pairs / budget-2? — **yes** (1:1 with the attribute
   families; no lock-logic rewrite).
3. LEAN-RIG as one "lean operator" lane (click + rigCost together), or split click
   into its own lane? — **keep paired** (its two keystones already match; "few
   attributes" is the ask).
4. Move idle (batteryBank/gridStorage) coldStorage→HODLER? — **yes** (idle = patience). *needs Slice-3 re-sim.*
5. Pull feeHedge trunk→COLD-STORAGE? — **yes** for coherence, but it makes costResist *lockable* (a real gameplay change). *owner's call.*
6. Re-point DEGEN-YIELD keystones to income? — **yes** for coherence, but it's the only genuine balance risk — **defer to its own slice** so the layout/flow win ships first.
7. TRUNK as centered stem (not its own lane)? — **yes.** Print each lane's attribute on its header? — **yes** (makes the lean explicit).
