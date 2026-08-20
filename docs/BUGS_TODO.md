# Bug / TODO list (living)

Bugs and rough edges found while planning the SKILL/RP/BiT rebuild. Each is
code-verified with file:line and a planned fix. Status: 🔴 open · 🟡 planned (folded
into a redesign slice) · 🟢 fixed. Most are fixed *by* the SKILL/RP redesign
(`docs/SKILL_TAB_REDESIGN.md`), so they're marked 🟡 with the slice that lands them.

Related existing backlogs (separate, not duplicated here): device findings
(`memory/device-findings-2026-08-17`), polish backlog (`memory/polish-backlog`).

---

## B1 — Can't change class after any reset 🟢 FIXED (S2b)
**Was:** no way to switch class after a reset; the option never appeared.
**Root cause:** `chooseClass` hard-locked after the first pick; the only re-pick
path was `newBlockchain`, itself gated on a Genesis needing 520,000 cumulative
tokens (~254 full runs) — effectively unreachable.
**Fixed in S2b:** class change is now offered at a **mined-out Hard Fork** via
`hardFork({BtcClass? chosenClass})` (honored only when `isMinedOut`), decoupled
from any Genesis gate. Picking a different class re-teches TECH + swaps perks;
keeping the same class (the preselected default) keeps everything. The New
Blockchain flow that used to carry the picker was removed.

## B2 — Two "HARD FORK" buttons at mined-out 🟢 FIXED (S2b)
**Was:** at mined-out the tab showed the red `CapReachedBanner` CTA **and** the
plain "HARD FORK (+X Tokens)" button (plus a NEW GENESIS button) — 2-3 competing
CTAs.
**Fixed in S2b:** the plain Hard Fork button is now hidden while
`networkDifficulty.isInfinite`, so the `CapReachedBanner` is the single mined-out
CTA (it carries the class-change picker). The NEW GENESIS button was removed
entirely (Genesis is passive now).

## B3 — RP hard-capped at 8 (can't reach a full branch) 🟢 FIXED (S1)
**Was:** RP topped out at 8 (fork-term formula), never reaching a full 9-RP branch.
**Fixed in S1:** `rpBudget = 2 (base, for having TECH) + min(18, activeClassLevel)`
→ max 20 = 2 full branches (capstone raised to 3 RP → branch = 10). RP comes from
mining the class (linear level: 1 full supply = 2 levels, maxing 18 ≈ 9 supplies —
first mined-out is NOT instant max). All-class Mastery nudge capped +10%. A runtime
`TEST · GAME SPEED` control (Settings → Danger Zone) speeds testing (not persisted).
_(Note: "era reset gives no RP" was a misread — not a bug; the 8 cap was.)_

## B4, B5 — removed from the bug list (not bugs)
Soft Fork being a free click (was B4) and TECH auto-buy (was B5) are **planned
design removals**, not defects: Soft Fork disappears (single Hard Fork model) and
auto-buy disappears (superseded by dual-spec). Tracked in
`docs/SKILL_TAB_REDESIGN.md` (S2 / S3), not here.

---

## U1 — Guides everywhere + strip in-game descriptive text 🔴
**Principle:** every mechanic is explained **once, in a guide**; the game screens
stay **clean** — no inline tutorial blurbs, hint paragraphs, or filler descriptions.
**Two halves:**
1. **Guides everywhere** — ensure a guide entry exists for every mechanic (old +
   all the new ones: class level/RP, one-fork model, dual-spec, auras, talents,
   BIPs, Back-in-Time). This is where explanation lives.
2. **Strip in-game text** — screens become label + value only.
**Scope:** cross-cutting. Much of the worst filler lives in the very screens we're
rebuilding (SKILL loadout copy, mining/fork descriptions, casino, research/keystone
blurbs), so **the cleanup rides along with each rebuild slice**; a **closing sweep**
catches the rest (settings, stash, goal, dialogs) + confirms every new mechanic has
its guide. Grep for leftover long `Text(...)` blocks before shipping.

---

## Deferred cleanups surfaced by the S2b adversarial review 🟡
The one-fork rework left three known **content** loose ends (core logic verified
clean). Each belongs to a later slice, tracked here so they aren't forgotten:
- **Dead achievements → S8.** `soft_first` (needs `softForkCount≥1`, never
  incremented now), `consensus_50` / `consensus_500` (fed `consensus: 0`) can never
  unlock, so 100% completion is unattainable. `chain_5` ("Start 5 New Genesis
  resets") is now silently gated on `newChainCount`, which only increments on
  Back-in-Time — relabel/re-gate. `chain_first` already got a `|| genesisBlocks≥1`
  fallback; `chain_5` did not. `achievement_defs.dart` ~199/206/327/346.
- **"Genesis Windfall" firmware copy → S5b.** Its `onGenesis` proc now fires only
  on Back-in-Time; description still says "New Genesis → free crate" (dead in
  normal play). Firmware→BIPs (S5b) rewrites these affixes anyway.
- **"GENESIS RESETS" ending-overlay stat** (`ending_overlay.dart:101`) now counts
  Back-in-Time runs — relabel with the achievements pass (S8).

## Not-yet-triaged (add here as we hit them)
- _(owner: drop any phone-tested bugs here and I'll verify + slot them)_
