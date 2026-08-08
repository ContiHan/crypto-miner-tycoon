# Endgame + Prestige Redesign — "THE LAST SATOSHI"

Status: **DESIGN (not yet implemented)** — awaiting owner sign-off.
Produced via a multi-agent design pass (3 independent designs → synthesis →
adversarial review, verdict *ship-with-fixes*; the fixes are folded in below).

## The problem we're fixing

- The old win — cumulative-ever `lifetimeEverSats >= 2.1e20` (~100,000× the 21M
  supply) — **fights Bitcoin's identity** (21M is THE hard cap) and would take
  tens of thousands of era-fills. The "ALL BITCOIN: X%" bar was log-scaled and
  read ~56% after a single era → misleading.
- No clear pinnacle or credits moment; the whole reset/endgame felt incoherent.
- Class Mastery XP was tied to Hard-Fork cadence, not to mining.

## The core reframe

**21M is sacred. You win by mining the *last satoshi* of the one and only 21M
supply — and the endgame is re-mining that same supply faster, forever.**

- **THE LAST SATOSHI (the win + credits):** the FIRST time a single era mines the
  full supply, i.e. `lifetimeEarnings` first reaches `maxSupplySats` (2.1e15 sats
  = 21,000,000 BTC). This is exactly today's "SUPPLY MINED OUT" wall, now
  recognized as the victory. 100% BTC-true (you mined every coin that will ever
  exist), guaranteed reachable through the core loop (prestige multipliers let an
  era eventually saturate the cap), one-time (latched via the reused `hasWonGame`
  bool). → rolls the **existing CreditsScreen**.
- **BACK IN TIME (the endgame, post-credits):** rewind to the genesis block and
  re-mine the same 21M as fast as possible. Optimize ONE number — best wall-clock
  time (overall + per class). Only permanent progression (the Time Capsule)
  shortens the clock, so every run makes the next faster.

## Reset ladder (renamed — no conceptual collisions)

| Tier | Name | Grants | Wipes | Keeps | Cadence |
|---|---|---|---|---|---|
| 1 | **SOFT FORK** | Consensus (CX), +0.10·√CX income | TECH only | everything else | frequent, cheap; mid-chain |
| 2 | **HARD FORK** | GovTokens (income ×(1+0.5·√GT) + spent on TALENTS) | wallet, era earnings, rigs, TECH, CX, mining state | GovTokens, TALENTS, chips, Time Capsule | main mid-loop; **before** the cap |
| 3 | **NEW GENESIS** (post-credits button flips to **GO BACK IN TIME**, timed) | Genesis Blocks (×(1+0.5·√GB) on CX+GT gain); picks next class | wallet, era, GovTokens, spent, rigs, TECH, TALENTS, CX, mining | Time Capsule | the chain's **bookend** — see below |

### SUPPLY MINED OUT is *not* a separate tier — it's the completion of tier 3

Filling the supply (`lifetimeEarnings` reaches the 21M cap) and starting the next
rewind are the **two ends of one loop**, not two mechanics:

- **Finish:** mining the full 21M **completes** the chain (this is "SUPPLY MINED
  OUT"). It is the *dojezd/cílová páska*, not a dead-end wall.
- **Start:** **NEW GENESIS / GO BACK IN TIME** rewinds to the genesis block for
  the next run.

So the cap is the natural **New Genesis trigger**: once the supply is full,
income is 0 and the only meaningful move is the deep rewind. First completion =
THE LAST SATOSHI (win + credits); every later completion = one Back-in-Time run
finished (record the time) → rewind again. This also kills the old "capped at ∞
difficulty, looks broken" dead-end — the cap now flows straight into the next
rewind. **Hard Fork stays a mid-chain tool** (you bank GovTokens *before* the
cap); at the cap you Genesis.

**One deep-reset concept** (`_newChainInternal`) powers tier 3. Pre-credits it's
"NEW GENESIS" (untimed). Post-credits the **same** entry flips to the timed "GO
BACK IN TIME". This kills the current collision where "NEW BLOCKCHAIN" and a
standalone "BACK IN TIME" button both showed at once. *(Review's #1 fix: gate the
BACK IN TIME button on `hasWonGame`, not on the first Hard Fork.)*

### "What else should the deep reset wipe?" → nothing more; wipe **less**

The current wipe set is exactly the run-scoped-power set and is correct. The one
miscategorized item is **CHIPS (UTXO)**: they only buy crates that fill the
permanent Stash, so wiping them destroys convertible-to-permanent value. **Make
chips permanent** (kept by every tier; cleared only by a full Wipe Save). Safe:
chips make no mining income, SWEEP is bounded by `casinoDailyNetCap`, crates are
a finite sink.

**THE TIME CAPSULE** (survives every deep reset): Stash collection, achievements
+ Notoriety, Mastery, Genesis Blocks, best times, and now **chips**.

## Class XP (Mastery) — moved to "mined supply"

Off per-Hard-Fork entirely; credited by **sats actually mined**, in the single
income chokepoint (`_creditLifetimeEver`, which passive/click/offline/Back-in-Time
all flow through):

```
masteryXp[current] += masteryXpPerFullSupply * (income / maxSupplySats)
```

So one full 21M supply mined = exactly **one Mastery unit**; `level =
floor(√(supplies_mined))` (1 supply = L1, 4 = L2, 9 = L3 — concave, un-farmable
by rapid resetting, naturally capped at 1 unit/era). Prospector still earns none.
A completed Back-in-Time run always banks one full unit → the endgame is the
primary Mastery engine.

## What gets retired

- The 2.1e20 win / `endgameTargetSats`, the log "ALL BITCOIN" bar → replaced by a
  linear **"SUPPLY MINED — X / 21,000,000 BTC (Y%)"** bar (tops out at 100% at
  the win; never implies mining more than exists).
- **Sandbox** ("Break the Chain" / `sandboxNoCap`) → deleted, so the 21M cap is
  inviolable (also simplifies the hot mining paths).
- **NG+** (`newGenesisPlus`, `winCount`, trophy multiplier) → deleted
  (economy-neutral: trophy factor was ×1).
- Retired words: New Blockchain, ERA, ALL BITCOIN, GENESIS COMPLETE, New Genesis+,
  Break the Chain / Sandbox.

## Post-credits long tail (optional, play continues)

- Beat your best Back-in-Time time (overall + per class).
- Time medals off `speedRunBestMs`: Bronze / Silver / Gold / a sub-threshold
  **SATOSHI** medal. *(Review #3: add `speedRunBestMs` + per-class bests to
  AchStats for these.)*
- Completionist capstone **THE TIMECHAIN** — finish a Back-in-Time re-mine with
  all four classes at Mastery ≥ 1. This is an **achievement/medal, NOT a second
  credits roll** (exactly one clean "beaten" moment).

## Implementation sketch (reuses existing machinery)

1. `constants.dart`: drop `endgameTargetSats`, `perWinTrophyBonus`; add
   `masteryXpPerFullSupply = 10000.0`.
2. `class_manager.dart`: add `creditMasteryFromMining(c, sats)`.
3. `game_logic.dart`: remove Mastery-at-Hard-Fork; add per-mining Mastery; delete
   the 2.1e20 branch + `endgameProgress` + sandbox + NG+/`winCount` + all
   `noCap/ignoreCap` plumbing; add the Last-Satoshi latch on
   `lifetimeEarnings >= maxSupplySats`; add `supplyProgress` getter; stop wiping
   `chips` in `_newChainInternal`; gate timed Back-in-Time to `hasWonGame`.
4. `mining_tab.dart`: linear SUPPLY MINED bar; NEW BLOCKCHAIN → NEW GENESIS
   (flips to GO BACK IN TIME post-credits, single entry point); cap-banner CTA
   routes to `startSpeedRun()` post-credits.
5. `home_screen.dart` / `ending_overlay.dart`: repurpose GENESIS COMPLETE →
   "THE LAST SATOSHI" finale (VIEW CREDITS + GO BACK IN TIME + KEEP MINING); drop
   NG+/sandbox wiring.
6. `speed_run*.dart`: copy → "RE-MINING THE SUPPLY" / "SUPPLY RE-MINED"; per-class
   best-time display.
7. Achievements: repoint `meta_genesis_complete` → hasWonGame ("The Last
   Satoshi"); `ng_plus` → "first Back in Time"; add time medals + THE TIMECHAIN;
   drop `winCount`/`inSandbox` from AchStats, add `speedRunBestMs`.
8. Save migration: tolerate dropped fields; silently latch `hasWonGame` for legacy
   saves already at the cap; leave `masteryXp` as an earned head-start.
9. Tests: update endgame/speed_run/class/achievement/repository; keep the economy
   sims green (curves unchanged).

## Open decisions for the owner

1. **Mastery tuning** — 1 supply = L1, 9 supplies as ONE class = L3. The old
   basis (per-Hard-Fork GT sums) reached L3 faster, so this may be grindier.
   Raise `masteryXpPerFullSupply` (or lower the L3 threshold) if so.
2. **Legacy Mastery** — leave saved values as a head-start (recommended) vs a
   one-time rescale.
3. **Chips permanent** — recommended yes (above); confirm.
4. **Keep `lifetimeEverSats`** as a cosmetic lifetime stat, or delete it.
5. **THE TIMECHAIN gate** — all-4-classes-mastered only (recommended) vs also
   Genesis ≥ N.
