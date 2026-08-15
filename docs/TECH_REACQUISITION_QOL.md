# TECH Re-acquisition — anti-tedium plan

> ⚠️ **SUPERSEDED by [BUILD_DEPTH.md](BUILD_DEPTH.md).** That doc's exclusive
> doctrine pairs + **presets + build-aware auto-apply + blueprints** replace the
> plain "buy-all-affordable REBUILD/AUTO" below. Do NOT build the cumulative
> auto-buy from this doc — build the preset system instead. Kept for the
> problem statement + the auto-buy internals, which the preset apply() reuses.

Status: **SUPERSEDED — PLANNING ONLY.** No code.

## The problem

TECH (research) is wiped on every Soft Fork (its whole point — reset LAB for
Consensus), every Hard Fork, and every New Genesis. Since Soft/Hard Forks are
frequent, the player re-clicks the same tree over and over — a boring, repetitive
chore, and it gets worse the deeper the tree grows. The RESET must stay (it's core
to the prestige loop), so the fix is to remove the *manual clicking*, not the
re-buying.

## Design goal

Keep TECH **meaningful** (you still pay sats; the ramp still takes real time as
income grows) but make re-acquiring it **one tap or zero taps** — never a
click-marathon.

## Recommendation (core: A + B)

**A. One-tap REBUILD (auto-buy all affordable).**
A single "REBUILD TECH" button on the TECH tab that buys every node you can
currently afford, in dependency order, looping until nothing more is affordable.
Instant catch-up of the whole click labor; you still pay full sat cost, so it's
pure de-tedium, not a power gain. Lowest effort, biggest win.

**B. AUTO-RESEARCH toggle (continuous).**
A toggle that keeps doing A automatically as income grows — so after a fork the
tree self-rebuilds and you never manually click TECH again. This is the "set and
forget" version and the real fix for the frequent Soft-Fork loop.
- Gate it as a light **unlock** so it feels earned but arrives early — a cheap TECH
  node ("Auto-Research Daemon") or bundle it with the existing AI Manager
  (which already auto-clicks). Recommendation: a dedicated early TECH node, so a
  brand-new player still learns the tree manually the first time or two, then
  unlocks automation.
- Runs on the existing tick (buy affordable in prereq order, a few per tick to
  avoid lag) — same cadence as the auto-clicker.

Together: first run you learn the tree by hand; once Auto-Research is unlocked,
every subsequent fork re-teches itself (or one tap if you leave it off).

## Optional later (nice-to-have, not needed for the fix)

**C. TECH loadout / "last build" memory.** Remember the node set you had before the
reset and rebuild toward exactly that (in order) as you afford it. Mostly redundant
with "buy all affordable" since TECH here is cumulative (no mutually-exclusive
branches) — only worth it if we later add exclusive branches or a player wants a
partial build. Skip for v1.

**D. BLUEPRINTS (meta-progression).** A node researched many times across resets
gets a small permanent cost discount (or starts partially researched) on future
runs — turns repetition into a reward loop and makes late re-teching faster. Nice
long-tail meta; defer until the core (A+B) ships and only if re-teching still
feels slow.

## Considered and rejected

**E. Change what resets.** E.g. stop wiping TECH on Hard Fork, or make TECH
persist. Rejected: the reset is core to the prestige loop (Soft Fork's entire
purpose is resetting LAB for Consensus; Genesis/Hard Fork wiping the run is the
point). Solve the tedium with automation (A+B), not by gutting the loop.

## UI

- **REBUILD TECH** button in the TECH tab header (next to the tree). Disabled when
  nothing is affordable; shows a quick count ("+7 nodes") on tap.
- **AUTO** toggle beside it (once unlocked); when on, the button/label reads
  "AUTO-RESEARCH ON" and the tree fills itself. Persist the toggle in settings.
- Same pattern could later extend to TALENTS if their re-buy becomes tedious too
  (TALENTS reset only on New Genesis, so far less frequent — lower priority).

## Implementation sketch (reuses existing systems)

- `research_manager.dart` / `game_logic.dart`: a `rebuildTech()` that loops
  `buyResearch` over affordable+unlocked+incomplete nodes in dependency order
  until none remain affordable (guarded loop, batches sound/save/notify like
  `buyRigMax`). An `autoResearchEnabled` bool (persisted) that calls `rebuildTech()`
  on the tick (throttled) and right after any reset.
- Unlock flag: a TECH node id (e.g. `autoResearchDaemon`) or reuse the AI Manager
  gate.
- `research_tab.dart`: REBUILD button + AUTO toggle in the header; reuse the
  existing buy flow (no new economic path — nodes buy at normal cost).
- No economy change: auto-buying the same nodes at the same cost is identical to
  buying them by hand, just without the clicks — the sims are unaffected.

## Open decisions for the owner

1. **Auto-Research gate** — a dedicated early TECH node (recommended), bundle with
   AI Manager, or a free QoL toggle from the start (zero friction, but removes the
   first-time learning of the tree)?
2. Ship **A + B** now, or start with just **A** (one-tap REBUILD) and add the
   continuous toggle later?
3. **Blueprints (D)** — worth the meta later, or keep it simple (A+B only)?
