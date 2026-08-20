# Bug / TODO list (living)

Bugs and rough edges found while planning the SKILL/RP/BiT rebuild. Each is
code-verified with file:line and a planned fix. Status: 🔴 open · 🟡 planned (folded
into a redesign slice) · 🟢 fixed. Most are fixed *by* the SKILL/RP redesign
(`docs/SKILL_TAB_REDESIGN.md`), so they're marked 🟡 with the slice that lands them.

Related existing backlogs (separate, not duplicated here): device findings
(`memory/device-findings-2026-08-17`), polish backlog (`memory/polish-backlog`).

---

## B1 — Can't change class after any reset 🟡 (S2)
**Symptom:** no way to switch class after a reset; the option never appears.
**Root cause:** `chooseClass` hard-locks (`if (hasChosenClass) return;`,
`game_logic.dart:1097`); re-pick is only via `newBlockchain`, itself hard-gated
`if (pendingGenesis <= 0) return;` (`game_logic.dart:2091`), and 1 Genesis needs
520,000 cumulative tokens (~254 full runs) — effectively unreachable, so the class
picker is never offered.
**Fix:** S2 — offer class change at a mined-out Hard Fork, decoupled from the Genesis
gate. (This was the originally-reported "nejde po žádném resetu měnit classa".)

## B2 — Two "HARD FORK" buttons at mined-out 🟡 (S2)
**Symptom:** when the era is mined out (difficulty ∞), the tab shows the red
`CapReachedBanner` ("ERA MINED OUT → HARD FORK NOW") **and** the normal
"HARD FORK (+X Tokens)" button — both call `hardFork`. Reads as "which do I click?".
**Root cause:** `CapReachedBanner` (`mining_banners.dart:65`, wired at
`mining_tab.dart:482`) + the plain Hard Fork button (`mining_tab.dart:535`) are both
shown at once.
**Fix:** S2 — at mined-out show only the banner (hide the plain button while
`networkDifficulty.isInfinite`); the banner carries the class-change option.

## B3 — RP hard-capped at 8 (can't reach a full branch) 🟡 (S1)
**Symptom:** RP can't reach a full 9-RP branch; it tops out at 8.
**Root cause:** `rpBudget = (3 + min(5, hardForkCount)) + min(6, 2·genesisBlocks)
+ min(4, totalMasteryLevel~/2)` (`game_logic.dart:739`) — via Hard Forks alone the
hard-fork term caps at +5 → 8 total, and Genesis (the other big term) is practically
unreachable (520k tokens), so in practice you sit at 8.
**Fix:** S1 — `rpBudget = min(18, activeClassLevel)`; RP comes from mining the class.
_(Note: "era reset gives no RP" was a misread — the owner thought they were doing a
Genesis but weren't. Not a bug; the real issue is the 8 cap.)_

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

## Not-yet-triaged (add here as we hit them)
- _(owner: drop any phone-tested bugs here and I'll verify + slot them)_
