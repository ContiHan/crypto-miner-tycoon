# TECH V2 build plan + doctrine blast-radius map (Slice 2)

Companion to docs/TECH_TREE_REDESIGN_V2.md (the design). This is the executable
blueprint for the interlocked swap. **Slice 1 (Channel.doubleDrop) shipped: `b2bc035`.**

## Scoping decisions (locked)
- **BTC stays as the era "when-gate"** (rich enough for the era); RP is layered on as the
  commitment "how-many-gate". Presets/blueprints/auto-apply keep working untouched.
  Fully removing BTC (→ retire blueprints/retech) is a clean FOLLOW-UP, not Slice 2.
- **3 bespoke-mechanic nodes ship as placeholder channel effects in Slice 2**, wired fully
  in a later slice: `reinvestmentEngine` (flat income now → +1%/+20%hash cap50), `goldenNonceProtocol`
  (nonce now → +guaranteed ×2 every 4th crit), `aiCoPilot` (click now → auto-tap 1/5→1/2s).
- Doctrines are **never serialized** (derived on demand) → renaming Doctrine enum values is
  save-safe. The ONLY save risk is renaming NODE ids (unmatched ids drop harmlessly on load) —
  so we REUSE existing ids wherever possible and add new ids only for genuinely new nodes.

## Change order (dependency order — one gated commit, interlocked)
1. **research_node.dart** — add `Map<Channel,double> effects` (default const {}, not serialized) +
   `String? branch` + `String? lane` + `int tier` + `int rpCost`. contributeChannels applies
   effectChannel (if set) AND effects.
2. **research_manager.dart** — new 24-node catalog (see §Catalog) with branch/lane/tier/rpCost;
   repurpose `Doctrine` enum → `{core, meta, foundry, nonce, degen}`; remap `_doctrineOf`→branch;
   `doctrineOf`→`branchOf` (default core); DELETE `doctrineSibling`, `commitmentBudget`,
   `committedPairCount`, `isDoctrineLocked`; repurpose `committedDoctrines()`→branches-with-capstone-owned;
   add `rpSpent` (Σ owned rpCost) + `capstoneId(branch)`; rewrite `tryBuy` gate: replace
   `isDoctrineLocked` check with an RP-budget check `rpSpent + node.rpCost <= rpBudget`
   (rpBudget passed in). tryBuy signature likely gains rpBudget param (also called by rebuildFromPreset).
3. **keystone_system.dart** — `KeystoneDef.doctrine`→branch; remap the 12 defs to 3 branches
   (6 surface: A8→furnace_farm/low_time_preference, B8→laser_eyes/sweat_equity,
   C8→degenerate_gambler/market_maker); `availableFor/availableOrEquipped/toggle` gate on
   "branch capstone owned" (feed the Set from branches-with-capstone-owned).
4. **game_logic.dart** — `researchDoctrine`→`branchOf` proxy; DELETE `isResearchDoctrineLocked`,
   `committedDoctrinePairs`, `doctrineCommitmentBudget`; `committedDoctrines()`→capstone-owned set;
   compute `rpBudget` = `(3+min(5,hardForkCount)) + min(6,2*genesisBlocks) + min(4,totalMasteryLevel~/2)`
   clamped [4,18]; expose `rpBudget`/`rpSpent`; thread rpBudget into buyResearch/tryBuy;
   `firmwareCapacity` :791 → key on capstones-owned (N capstones ≥ 2 ? +1) instead of pairs.
5. **research_tab.dart** — accordion rewrite (RESEARCH BRANCHES: 3 engine cards, 2-lane grid,
   centered root+capstone, opaque nodes, theme wash; KEYSTONES & SYNERGIES section). Delete the
   doctrine-lane layout + locked sheet. RP header (rpSpent/rpBudget). Per the mockup.
6. **Copy-only:** tech_preset_bar (respec wording), perks_screen (keystone empty-state → "own a
   branch's capstone"), firmware_panel (socket-bonus help), loadout_panels doc, tech_graph comments,
   constants comments.
7. **Tests:** rewrite doctrine_test → tech_tree_test (branch membership, rpCost accounting, budget
   refusal, branch-consistency invariant); keystone_test (capstone-owned gating; aggregate tests
   survive w/ relabeled sets); respec_test :37-50; build_matrix_sim_test rep-node map → capstones;
   firmware_test/preset comment updates. Add doubleDrop end-to-end (research C6 → crates double).

## Catalog (24 nodes + genesisCore free root) — id · tier·lane · rp · effects · prereq
GENESIS CORE: `genesisCore` "Genesis Core", tier0, rp0, isUnlocked, effects{} (root everything requires).
Keep chipFab/aiManager/firmwareBay special effects wired as-is under core for now.

**A · FOUNDRY (branch 'A', amber)**
- `basicOverclock` Overclocked Cores · 1·root · 1 · {hash .15} · genesisCore
- `neuralNet` Neural Net Miner · 2·L · 1 · {hash .30} · basicOverclock
- `quantumEntanglement` Quantum Entanglement · 3·L · 1 · {hash .50} · neuralNet
- `coldStorageLogistics`(NEW) Cold Storage Logistics · 4·L · 1 · {rigCost .20, offline .15, idle 8} · quantumEntanglement
- `marketAnalytics` Market Analytics · 2·R · 1 · {income .20} · basicOverclock
- `highFrequencyTrading` High-Frequency Trading · 3·R · 1 · {income .35} · marketAnalytics
- `reinvestmentEngine`(NEW,★,STUB) Reinvestment Engine · 4·R · 1 · {income .10} · highFrequencyTrading
- `centralBank` THE CENTRAL BANK (cap) · 5 · 2 · {income .50, hash .40, prestige .25} · [coldStorageLogistics, reinvestmentEngine]

**B · GOLDEN NONCE (branch 'B', cyan)**
- `ergonomicRig` Ergonomic Rig · 1·root · 1 · {click .30} · genesisCore
- `noncePrediction` Nonce Prediction · 2·L · 1 · {nonce .10} · ergonomicRig
- `precisionHashing` Precision Hashing · 3·L · 1 · {special .50} · noncePrediction
- `goldenNonceProtocol`(NEW,★,STUB) Golden Nonce Protocol · 4·L · 1 · {nonce .05} · precisionHashing
- `macroScripts` Macro Scripts · 2·R · 1 · {click .60} · ergonomicRig
- `aiCoPilot`(NEW,STUB) AI Co-Pilot · 3·R · 1 · {click .15} · macroScripts
- `immersionCooling` Immersion Cooling · 4·R · 1 · {haste .25} · aiCoPilot
- `powerCapacitors` OVERCLOCK THE CORE (cap) · 5 · 2 · {click .75, special .50, overcharge .40} · [goldenNonceProtocol, immersionCooling]

**C · DEGEN (branch 'C', violet)**
- `luckyNonce`(NEW) Lucky Nonce · 1·root · 1 · {luck .08} · genesisCore
- `utxoMagnet` UTXO Magnet · 2·L · 1 · {magnetism .10, sweepLuck .10} · luckyNonce
- `assayLab` Assay Lab · 3·L · 1 · {fortune .12} · utxoMagnet
- `doubleDropManifold`(NEW,★) Double-Drop Manifold · 4·L · 1 · {doubleDrop .15} · assayLab
- `volatilityEngine`(NEW) Volatility Engine · 2·R · 1 · {volatility .25, bullBias 1.0} · luckyNonce
- `hardenedVault`(NEW) Hardened Vault · 3·R · 1 · {crashResist .25, theftResist .25, costResist .25} · volatilityEngine
- `diamondNerves`(NEW) Diamond Nerves · 4·R · 1 · {halvingResist .30, durationResist .30} · hardenedVault
- `whalesEye`(NEW) THE WHALE'S EYE (cap) · 5 · 2 · {luck .15, doubleDrop .10, fortune .08} · [doubleDropManifold, diamondNerves]

New ids to add: genesisCore, coldStorageLogistics, reinvestmentEngine, aiCoPilot, goldenNonceProtocol,
luckyNonce, volatilityEngine, hardenedVault, diamondNerves, doubleDropManifold, whalesEye.
Capstones: A=centralBank, B=powerCapacitors, C=whalesEye.

## Progress
- [x] Slice 1 — Channel.doubleDrop + hook (`b2bc035`)
- [x] Slice 2 — structural swap: 28-node catalog, RP ledger, doctrine removal, accordion UI (`eb40607`)
- [x] Slice 3 — bespoke mechanics + doubleDrop reveal UI:
  - **B6 goldenNonceProtocol** → bounded pity timer: every 12th real tap is a guaranteed
    golden nonce (crit). `GameConstants.goldenNonceEvery`, `_goldenNonceCounter`.
  - **B5 aiCoPilot** → tightens the silent auto-tap interval 5→3 ticks.
    `autoClickEveryBase`/`autoClickEveryFast`.
  - **A7 reinvestmentEngine** → reinvest 20% of the raw hash-channel sum into income,
    capped at +0.75 (folded into `buildChannels`). No static channel anymore.
  - **doubleDrop reveal** → `_showCrateOpening` drains `drainBonusCrates()`; the reveal card
    shows a "DOUBLE DROP!" section listing the bonus artifact(s).
  - Tests: `tech_v2_synergies_test.dart` (B5/B6/A7), `double_drop_test.dart` (banking+drain).
  - NOTE: the branch theme-wash + centered nodes already shipped in the Slice-2 accordion.
    A dedicated "ignite" node-purchase animation was NOT added (deferred — needs device
    visual QA, which is owner-side).
- [ ] Slice 4 — balance sim (NOTE: the RP-gated tree kept every economy sim green as-is;
  the build-matrix sim now seeds a mature rpBudget since mining a full 21M supply is a
  late-game feat. No separate re-baseline was required.)
