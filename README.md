# BTC Only Tycoon

A cross-platform **idle / incremental RPG** built with Flutter. Mine Bitcoin, pick
a mining archetype, climb three tiers of prestige, and push toward the "own all the
Bitcoin" endgame.

## 🎮 The game

- **Core loop** — passive mining (hash rate) + manual tapping (with crit hits),
  reinvested into ever-bigger rigs.
- **Channel economy** — every bonus funnels through additive, soft-capped
  channels (hash / income / click / rig-cost / luck / volatility) so nothing runs
  away. See [docs/GAME_PARAMETERS.md](docs/GAME_PARAMETERS.md).
- **Classes + Mastery** — four archetypes (Solo Miner, Corporation, BTC OG, Pool
  Member), each with passive racials and a **bespoke SKILL tree**; permanent
  per-class Mastery.
- **3-tier prestige** — Soft Fork (Consensus) → Hard Fork (GovTokens) → New
  Blockchain (Genesis Blocks), all concave so the endgame stays bounded.
- **Progressive disclosure** — TECH / STASH / SKILL tabs unlock as you grow.
- **TECH & SKILL trees** — pan/zoom blockchain-styled graphs.
- **Achievements + Notoriety** — a permanent income lane.
- **SWEEP** — a simulated, player-favoured, in-game-only minigame (no real money),
  bounded by a daily net cap.
- **Endgame** — a monotonic "cumulative BTC ever" goal + a post-win sandbox.

## 📚 Documentation

Everything is signposted from the **[docs hub](docs/README.md)** — start there.
Quick links:
- **[Game parameters reference](docs/GAME_PARAMETERS.md)** — what every stat means.
- **[Design plan / roadmap](docs/GAME_PLAN.md)** — the economy blueprint.
- **[RPG classes plan](docs/RPG_CLASSES_PLAN.md)** — the class system design.

## 🗂 Project layout

- `lib/providers/game_logic.dart` — the game "brain" (tick, economy, prestige, save).
- `lib/logic/` — extracted managers (`managers/`) & systems (`systems/`: prestige,
  chaos events, anomaly).
- `lib/services/` — economy, casino, stash, sound.
- `lib/content/` — data-driven catalogues (rigs, research, achievements, news).
- `lib/screens/` & `lib/widgets/` — UI.
- `lib/core/constants.dart` — all `[TUNE]` numbers.
- `test/` — unit tests + multi-week economy simulations (the balance guardrails).

## 🚀 Run

```bash
flutter run
```

Or, on the maintainer's Windows setup, the PowerShell helpers:
`run-android` (boot the emulator), `reset-android` (fresh build + wipe + install +
launch — clears the save), `kill-android` (stop the emulator).

## ✅ Tests

```bash
flutter test
```

The economy simulations (`test/*_sim_test.dart`) drive the real game logic over
weeks of simulated time — **re-run them after any economy/constant change.**
