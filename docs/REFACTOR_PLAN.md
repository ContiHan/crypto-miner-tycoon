# Refactor plan — "get the code in order" (structure, not behavior)

> Grounded in a read-only 4-agent codebase-health audit (2026-08-18). The app
> works and has a strong suite (378 tests: unit + widget + economy sims). Every
> item here is **behavior-preserving** and kept green by that suite. Ordered by
> payoff ÷ risk: cheap high-value cleanups first, the serialization rewrite last.

## Health baseline (what's already good — don't "fix")

`flutter analyze` is clean (no unused imports/members). No TODO/FIXME/HACK in real
code. Softcaps (channels.dart) + number formatting (formatter.dart) are already
centralized. The ~13 `debug*`/`@visibleForTesting` seams are proper injection
(heavily used), not hacks — **leave them**. `game_logic.dart` is already a
coordinator delegating to ~20 subsystems; `buildChannels()` is a clean single
economy seam; ~7 subsystems already self-serialize. The layering
(screens → GameLogic → systems/managers/services → repository) is sound.

Prior god-object extractions this session: Breach, **SpeedRun** (`4c2abf9`),
**RigReveal** — `game_logic.dart` 2921 → 2790.

## Guiding rules

- One cohesive slice per commit; suite green before each commit. Never push.
- Extraction pattern (established): a subsystem **owns** its state + logic;
  GameLogic supplies suppliers/callbacks and keeps **thin proxies** so the public
  API (and tests) are unchanged.
- Screen splits: keep each extracted piece behind the **same `Consumer`/`Selector`**
  it has today — those rebuild-isolation boundaries are deliberate (and commented).
- Save/load is correctness-critical (migrations + ordering); it goes **last**,
  behind round-trip + economy-sim tests.

---

## Phase A — quick wins (S, low risk, immediate clarity)

- **A1. Delete the dead `bitcoinExchangeRate` mechanic + collapse rig-cost methods.**
  The rate is pinned to `1.0` (init, reset, force-set on load) and never varies, yet
  is threaded through save/load and every rig/research cost divides by it (identity).
  Remove the field (MiningManager + GameLogic proxy + save param/key, tolerant of the
  legacy key on load); collapse the 3 names `getRigCostInCredits`/`getRigCost`/
  `getRigCostInSats` → the one `getRigCostInSats` (5 tests use it); drop the
  `/rate` divide in `research_manager.getCostInSats`. *M/low; economy sims cover it.*
- **A2. Relocate already-separated private widgets into `lib/widgets/`.** These are
  clean self-contained classes just sitting at the bottom of huge files: research_tab
  `_PresetBar`/`_PresetRow`/`_RespecBar`; perks `_AurasPanel`/`_KeystonesPanel`;
  mining `_LockedRigTeaser`/`_CapReachedBanner`. Pure move → research_tab ~627→~340,
  perks ~891→~660. *S/low.*
- **A3. Shared rarity presentation.** `FirmwareRarity` and `AchRarity` are the same
  4-value enum with byte-identical color maps (duplicated in firmware_panel +
  achievements_screen). Add `lib/core/rarity.dart` (one `Rarity` enum) +
  `AppTheme.rarityColor(index)`, and a `RarityBadge` widget for the repeated
  "dot + UPPERCASE name" (3–4 sites). *S/low.*

## Phase B — god-object extractions (the core of "the big one")

- **B1. `CasinoManager`.** The whole SWEEP economy (anti-farm per-window net cap +
  resolve/commit split for slots/flip/plinko, ~140 lines) lives in the coordinator.
  Move to `lib/logic/systems/casino_manager.dart`, wrapping the existing pure
  `CasinoService`. Seam: `chips` get/spend, `sweepLuck` supplier, `onWin`/`onJackpot`
  + `evaluateAchievements`/`save` callbacks; `casinoSpins`/`casinoJackpots` move with
  it. Proxies keep casino_test + the STASH screen stable. *M/low/high — top pick.*
- **B2. `TabUnlockSystem`** (+ fold the endgame win-latch into a small system).
  The sticky nav-tab reveal (4 bools + toast queue + threshold ladder) and the
  one-shot win latch (`lifetimeEverSats`/`hasWonGame`/`pendingWinCelebration`) are
  self-contained micro-state-machines. *S/low.*
- **B3. `SettingsController`.** sound/haptics/fiat/onboarding flags + `_seenTips` +
  the `_haptic*` helpers (~80 lines) read no economy state. Own them + `_settingsRepo`.
  *M/low.*
- **B4. `EconomyModifiers`** — the single biggest bulk (~300 lines, game_logic
  340–644): the pure derived getters (5 resistances, luck facets, upkeepRate,
  offlineFraction, idleCapacity, fortune, volatility, bullBias, overcharge,
  critPayout, event-resistance math). All pure derivation over
  channels+keystones+abilities. Move to `lib/logic/economy/economy_modifiers.dart`
  with `channels: buildChannels` etc. suppliers; GameLogic forwards via proxies.
  *L/medium/high.*
- **B5. Move auto-apply re-tech into `ResearchManager`.** `_rebuildFromPreset` +
  `_maybeAutoApplyPreset` + the RE-TECH spend accumulators (~90 lines) only touch
  `wallet` + the research manager, which already owns presets/costs/tryBuy. Move via
  a `WalletBox` (get/set) seam. *M/medium.*

## Phase C — screen splits (readability + rebuild isolation)

- **C1. `CasinoTab` widget out of stash_screen** — ~700 of stash's 1527 lines are
  the three minigames (3 timers, an AnimationController, commit lifecycle, the
  `_PlinkoPainter`). Move to `lib/widgets/casino_tab.dart` (+ `plinko_painter.dart`).
  Pairs with B1. Drops stash → ~800. *L/medium/high.*
- **C2. `CratesTab` + `CollectionTab` + `crate_reveal_dialog.dart`** out of stash;
  move `_crateColor`/`_crateIcon`/`_rarityColor` into a `stash_visuals` helper (or the
  models). StashScreen becomes a ~80-line TabController shell. *M/low/high.*
- **C3. `MiningStatsPanel`** (the 345-line stats `Consumer`) + `BreachAlertBanner` +
  `AnomalyLayer` + `HackButton` out of mining_tab, each behind its existing
  Selector/Consumer; `_buildStatItem` → a shared `StatReadout`. mining_tab 1077 →
  a readable Column of named widgets. *M/low/high.*
- **C4. `GraphLayout` dedup** — perks `_graph` and research `_graph` copy-paste the
  same depth-memoize + bucket + position math (~34 lines). Extract a `GraphLayout`
  next to `BlockGraph` taking a lane-vs-centered mode. *M/medium/high.*
- **C5. Dialogs + notifications host** — perk `ClassBonusDialog`/`LoadoutDialog`
  (move the bullet-string business logic onto GameLogic so it's unit-testable),
  home_screen prestige/offline dialogs, and a `GameNotificationsHost` widget owning
  the toast/overlay queue + guards (`_fullScreenOverlayUp`, defer-until-dismissed).
  *M/medium; do the host last, preserve the guards verbatim.*
- **Shared shells** applied opportunistically as screens are split:
  `PanelCard`, `SummaryRowButton`, `CyberDialog`, `ConfirmDialog` (built on the
  existing `StylizedCard`) — collapse the re-hand-rolled boxes/dialogs.

## Phase D — architecture (higher risk, last)

- **D1. Merge `systems/` and `managers/`** into one `lib/logic/subsystems/` with a
  `GameSubsystem` marker + a `TickingSubsystem` interface (start/stop) that only
  anomaly/breach/chaos_event/rig-reveal implement, so GameLogic can iterate timers
  instead of hand-calling each. Pure mechanical rename; the whole suite is the net.
  *M/low.*
- **D2. Serialization contract — the biggest maintainability tax, done LAST.** Today
  every persisted field lives in **5 hand-synced places** (saveGameState params, the
  state map, `_normalize`, the `_saveGame` call, the `loadGame` read-back). Introduce
  a `Persistable` mixin (`toJson`/`loadFrom`) on every subsystem + a `GameSave` DTO
  (or `toSnapshot()`/`restore(Map)` on GameLogic) that owns all keys/defaults/coercion
  once, and shrink `GameRepository` to a dumb blob store (jsonEncode/decode + atomic
  write + corrupt-fallback). Migrate field-group by field-group behind round-trip
  tests, keep a v2→v3 (flat→nested) shim so old saves survive. *L/high/high.*
- **D3. Shared income-accrual context** — `calculateMiningIncome`'s arg bundle is
  spelled out at 4–5 sites (`_baseIncomePerSecond`, `_accrueMining`, `_clickSatsBase`,
  `estimatedClickValue`, auto-tap). Add one `miningContext()` builder + `_incomeFor`
  helper so tick and click can't diverge. *M/low.*
- **D4. Un-envy the system closures** — the breach loss math and the airdrop-gain math
  live in lambdas in GameLogic's constructor, not in Breach/Chaos systems. Move the
  math into the systems; GameLogic supplies only read closures + a `creditWallet`
  mutator. *M/medium.*
- **Deferred indefinitely: `MiningEngine`.** The passive/click/auto-tap tick (~280
  lines) is the genuine coordinator heart (mutates wallet/lifetime, drives the
  `_creditLifetimeEver` chokepoint, reads everything). The seam is too wide; extracting
  it just relocates the fan-out. *XL/high — only if the class is still unwieldy after
  A–D, and only then.*
- **Keep as coordinator glue (do NOT extract):** constructor wiring, `buildChannels`,
  `_creditLifetimeEver`, `_buildAchStats`, prestige-reset orchestration, timer
  lifecycle, `resetGame`, the thin subsystem proxies. Moving these worsens coupling.

## Provider granularity (decided: don't split)

One `ChangeNotifier` + 97 mostly-proxy getters is the deliberate, acceptable cost of a
stable API against 378 tests. **Do not** split into multiple providers. Where the 1 Hz
tick causes rebuild jank, use `Selector`/`context.select` at the **read** sites
(as `main.dart` already does). One real leak to fix: `stash_screen` reaches through
`game.stashService` directly — add a GameLogic proxy so the screen never touches a service.

## Suggested execution order

A1 → A2 → A3 (quick wins, warm up) → B1 → C1 (casino logic + UI together) →
B2 → B3 → C2 → C3 → B4 → B5 → C4 → C5 → D1 → D3 → D4 → **D2 (serialization) last**.
Each is independently shippable and suite-gated.

## PROGRESS (all commits LOCAL on main, suite-gated +378 ~1)

- ✅ **A1** `b396b85` — deleted dead `bitcoinExchangeRate`; collapsed rig-cost →
  the one `getRigCostInSats`; dropped the `/rate` divide.
- ✅ **A2** — pure widget relocations: research_tab 627→345 (`b0dc2d5`,
  `tech_preset_bar.dart`), perks 891→658 (`a16beca`, `loadout_panels.dart`),
  mining_tab 1077→935 (`7c90262`, `mining_banners.dart`).
- ✅ **A3** `529964b` — `AppTheme.rarityColor(index)` + `RarityBadge`
  (`rarity_badge.dart`); both firmware/achievement `_rarityColor` now delegate.
  DEVIATION from plan: no standalone `Rarity` enum in `lib/core/rarity.dart` —
  `FirmwareRarity`/`AchRarity` stay as domain enums (73 AchRarity refs); a third
  enum nothing adopts would be dead indirection. STASH's 6-tier `ArtifactRarity`
  is a genuinely different palette, left untouched.
- ✅ **B1 CasinoManager** `c1754da` — whole SWEEP economy (window cap + resolve/
  commit split) → `lib/logic/systems/casino_manager.dart` wrapping CasinoService.
  chips stays in GameLogic (crate shop shares it), seamed get/set; counters +
  window fields move into the manager; full public casino API proxied (STASH +
  casino_test untouched). Verified by a 3-lens adversarial review (currency /
  window-cap / silent+serialization — all CLEAN). game_logic −125 net lines.
- ✅ **B2a TabUnlockSystem** — the 4 sticky nav-tab reveal flags + pending-toast
  queue + the threshold ladder (`refresh`) → `lib/logic/systems/tab_unlock_system.dart`.
  Thresholds read GameLogic via suppliers; unlock cue/save/notify injected.
  GameLogic proxies unlockedTech/Stash/Skill/Goal (get+set for tests),
  pendingTabUnlockToasts, clearTabUnlockToasts, debugUnlockAllTabs; save/load/reset
  wire through restore()/reset(). home_screen + disclosure tests untouched.
- ✅ **B2b EndgameSystem (win-latch)** — the THE-LAST-SATOSHI latch state
  (lifetimeEverSats / hasWonGame / pendingWinCelebration) + win-once logic →
  `lib/logic/systems/endgame_system.dart`. `_creditLifetimeEver` STAYS the
  orchestrator (Mastery + Speed Run + UI cues); it now calls `addEver` +
  `tryWin(capReached:)`. GameLogic proxies get/set lifetimeEverSats + hasWonGame,
  get pendingWinCelebration, clearWinCelebration→clearWin, speedRunUnlocked;
  save via proxies, load via restore()+healWonIf(), reset via reset(). Verified by
  a 2-lens adversarial review (win-once/offline-defer + serialization/self-heal —
  CLEAN). Screens/widgets/endgame tests untouched.
- ⏭️ **B3 SettingsController** — NEXT (sound/haptics/fiat/onboarding flags +
  _seenTips + _haptic* helpers).
