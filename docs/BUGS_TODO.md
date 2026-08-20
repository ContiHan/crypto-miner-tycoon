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

## B3 — RP capped at 8 / era reset adds no RP 🟡 (S1)
**Symptom:** RP can't reach a full branch (9 needed); an era reset grants no RP.
**Root cause:** `rpBudget = (3 + min(5, hardForkCount)) + min(6, 2·genesisBlocks)
+ min(4, totalMasteryLevel~/2)` (`game_logic.dart:739`) — hard-fork term caps at
+5 (→ 8 total), and a soft/era reset doesn't move any of these.
**Fix:** S1 — `rpBudget = min(18, activeClassLevel)`; RP comes from mining the class.

## B4 — Soft Fork is a near-free click 🟡 (S2)
**Symptom:** clicking Soft Fork costs effectively nothing meaningful.
**Root cause:** Soft Fork now only resets TECH (which is RP-only → re-clicked
instantly for free) + banks Consensus (`game_logic.dart:1177`).
**Fix:** S2 — remove the Soft Fork tier; the single Hard Fork is the real reset;
Consensus removed.

## B5 — TECH auto-buy (preset auto-apply) 🟡 (S3)
**Symptom (owner dislike, not a crash):** TECH re-buys itself via preset auto-apply.
**Root cause:** `_maybeAutoApplyPreset` / `maybeAutoApply` auto path
(`game_logic.dart:890`, `research_manager.dart`).
**Fix:** S3 — remove the auto path; presets stay only as manual dual-spec storage.

---

## Not-yet-triaged (add here as we hit them)
- _(owner: drop any phone-tested bugs here and I'll verify + slot them)_
