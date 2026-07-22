# BTC Only Tycoon — Restructuring & Content Plan

> Status: design blueprint (v1). Grounded in research of Antimatter Dimensions, Cookie Clicker,
> Realm Grinder, NGU Idle, Melvor Idle, AdVenture Capitalist, Path of Exile, Universal Paperclips,
> A Dark Room, Idle Iktah + Google Play policy. Architecture section is grounded in the current
> codebase (this repo as of the sound/hold-to-buy work).

---

## 0. TL;DR / verdict

The current game is a solid **proof of concept** with the *correct mathematical skeleton*
(`1.15^n` rig cost, `sqrt(lifetime)` prestige, halvings). It is not production-grade because it can
be finished in hours and everything is visible at once. The fix is **not new math** — it's
**sequencing, content volume, and layering**, plus an **architecture refactor** so 100+ upgrades and
several new systems are even feasible to build.

The plan rests on **one foundational decision** that unblocks everything else:

> **Adopt a "channel" economy model: bonuses are ADDITIVE within a channel, MULTIPLICATIVE across
> channels; all prestige currencies are SUB-LINEAR in production; every runaway is tamed by an
> explicit softcap.**

Do that first (Phase 1). Then content, prestige layers, casino, achievements, and discovery all
slot in without breaking the numbers.

**Biggest risks to design around (from research):**
1. Making 100+ items multiplicative → `1.08^100 ≈ 400,000x` → economy explodes in one prestige.
2. Current **difficulty grows linearly** while **hash grows exponentially** → income already runs away.
3. The **2.1e15 sat hard cap** (real 21M BTC) is far too small for a weeks-long game and sits right at the float-precision edge.
4. Showing all content at once → min-maxer finishes in an afternoon.
5. Crypto theme + gambling + any hint of real value → **Google Play rejection** as unlicensed real-money gambling.

---

## 1. Retention model & pacing targets

Design for **three nested time horizons on one loop** (industry standard):

| Horizon | Window | Engine | Target in BTC Only Tycoon |
|---|---|---|---|
| **Hook** | 0–30 min | instant gratification | first rig + first halving + first anomaly all happen in the first session |
| **Habit** | 1–7 days | daily check-ins | first **Soft Fork** reachable day 1–2, repeatable many times/day |
| **Hobby** | weeks–months | deep systems | **Hard Fork** ~week 1, **New Blockchain** ~week 3–4+ |

**Pacing levers:**
- **Purchases decay in value** — keep rig cost growth (`1.15^n`) above income growth so each buy
  buys slightly less time than the last (this is what pushes players forward). ✅ already on-spec.
- **Staggered re-engagement clocks** at exponentially spaced intervals so every session cadence has
  something optimal: e.g. a *mempool* that caps chips every ~20 min (browser-tab player), a
  *crate/anomaly cache* every ~4–5 h, a *daily block bonus* every ~24 h (once-a-day player).
- **Deliberate multi-day soft walls** (1–2 per prestige layer), each passable by a *specific,
  visible, investable lever* — a wall with a clear "raise X to pass" hint converts a quitter into a
  returning player.
- **Offline earnings**: cap at ~24 h, pay ~50–60% of active rate; make cap extensions a top-tier
  reward. Uncapped offline trains players to never open the app.
- **Reveal, don't dump** — see §6 (progressive discovery). Content is rationed by *affordability +
  unlock gates*, not by a wall of visible options.

**Target metric:** idle-genre D7 retention 10–15%. Instrument time-to-first-prestige and
time-to-each-tier.

---

## 2. Economy math framework (build this FIRST)

Everything else depends on this. This is Phase 1.

### 2.1 The channel model
Define a fixed, small set of **multiplier channels**. Every perk / lab / stash / rarity / achievement
bonus routes into exactly one:

```
HASH · CLICK · INCOME · RIG_COST · PRESTIGE · SPECIAL
```

- **Within a channel: additive.** `channelMult = 1 + Σ(bonus_i)`.
- **Across channels: multiplicative.** `income = base · hashMult · incomeMult · prestigeMult · chaosMult`.

Why: ~90% of incremental bonuses "want" to be multiplicative, and 100 multiplicative items =
nonsense (`1.08^100 ≈ 4e5`). Additive-within-channel self-limits (diminishing marginal value: a +2%
item among +900% is a rounding error), so you can safely ship *hundreds* of items. A handful of true
multiplicative "more" effects (Legendary/Mythic only) stay countable. This is Path of Exile's
"increased vs more" and Realm Grinder's "additive unless stated."

### 2.2 Softcaps
Implement as an explicit piecewise function `softcap(value, start, power)`: identity below `start`,
`start·(value/start)^power` above. Apply to any channel/stat that can outrun the model (e.g. total
stash bonus past +2000%, or a "per-rig-owned" scaling bonus → `k·sqrt(count)`). The existing rig
cost-discount clamp (floor at 5% cost / 95% max discount) is exactly the right pattern — replicate it
for every channel. **Cost-reduction stays additive and hard-capped at ~80%** (multiplicative discount
stacking toward 100% makes rigs free and destroys the whole economy).

### 2.3 Fix the difficulty runaway (must)
Today: `difficulty = 100 + lifetime/1000 + asymptote` (linear in lifetime) while hash grows
exponentially → `income = hash/difficulty` accelerates without bound.
Fix (pick one):
- **A (production-tracked):** `difficulty ∝ totalHashRate^0.92` → `income ≈ hash^0.08` (grows but decelerates).
- **B (explicit income softcap):** keep difficulty simple, pass income through `softcap(income, start, 0.6)`.

Target: mid-game per-second income should roughly double every 20–40 min, not every minute.

### 2.4 Remove the 21M / 2.1e15 hard cap
It kills a weeks-long game and sits at the float precision edge (`double` exact only to `2^53≈9e15`).
- Keep "halving" as **flavor**, decouple it from a supply ceiling.
- Let the economy scale to ~`1e30`–`1e60`+.
- Use plain `double` below ~`1e15`, then switch large sat values to a **mantissa/exponent big-number
  type** (Dart port of `break_infinity`) as Antimatter Dimensions does. Keep integer counts (rig
  amounts, token counts) as `int`.
- If you want to keep the 21M cap for theme, apply it **per-run only**, never globally.

### 2.5 Number formatting
Extend the existing `Formatter`: named short scale (K/M/B/T) → letter-pair suffixes
(`aa=1e15, ab=1e18, ac=1e21…`) → scientific only at extremes. `1e29` vs `1e30` must *look* different or
the felt sense of growth dies.

### 2.6 Balancing methodology (the real tool)
Build a **14-day tick-by-tick spreadsheet** (or a Dart sim harness). One row per interval; columns:
time, sats, each rig count/cost/income, each channel mult, pending currency for all 3 prestige tiers.
Derive `timeToNextBuy = cost / incomePerSec` and accumulate to get **real wall-clock pacing**. Tune so:
- a purchase every ~30–90 s in hour 1, stretching to minutes/hours later;
- first Soft Fork ~day 1, first Hard Fork ~day 2–3, first New Blockchain ~week 1–2;
- each reset yields ~1.5–3× effective speedup over the prior run;
- no channel exceeds its softcap in a normal run.

**Tune on elapsed time, not static cost/income ratios** — the #1 balancing mistake.

---

## 3. Content & rarity system

### 3.1 Six rarities → additive bonus bands
| Rarity | Additive band (into a channel) | Notes |
|---|---|---|
| Common | +1–3% | workhorse; where most of the 20–100 items live |
| Uncommon | +4–8% | |
| Rare | +6–20% | |
| Epic | +12–50% | |
| Legendary | switches type → **×1.35–1.8 multiplicative** *or* +75–150% additive-that-scales | the "chase" |
| Mythic | **unlock/utility** (+ optionally one ×2) | cap the game to ~5–10 distinct Mythics total |

**Bonus TYPE mapped to rarity** so composition is automatic and never collides:
- Common→Epic = percentage-additive into a channel.
- Legendary = one controlled multiplicative factor or a scaling bonus.
- Mythic = a *mechanic* (auto-clicker, extra crate slot, offline-cap, halving-penalty reducer) + maybe one ×2.
- Flat-absolute (+X/click) only on early Common/Uncommon (dies late-game by design).

Budget total reserved multiplicative power from items (excluding prestige/chaos) to a ceiling like
**×8–×12** so the model stays bounded.

### 3.2 Keeping low rarities relevant
Otherwise +2% among +900% is dead filler:
- **Set / family bonuses** at owned-counts 1/3/5/10/25 (Cookie Clicker milestone model): e.g. "own 5
  CPU-family artifacts → +25% CPU hash."
- **Scaling clauses** on a subset of Commons: "+0.3% total hash per ASIC owned," "+0.5% per
  achievement" (wrap large counts in `sqrt` softcap).
- **Duplicate handling**: auto-salvage dupes into a currency, or fuse 3 → next rarity up.

### 3.3 Crates & drops (Stash)
- **Tiered crates** gated by progression (Basic → Advanced → Quantum). Higher tiers re-weight and
  *drop the lowest rarity* (a Quantum crate can't roll Common) — this prevents "late Common beats
  early Legendary."
- **Geometric drop ladder**, e.g. base crate: Common 55 / Uncommon 27 / Rare 12 / Epic 4.5 /
  Legendary 1.2 / Mythic 0.3.
- **3-step roll** (ARPG loot): pick rarity by weight → draw effect from *that rarity's pool only* →
  roll value in range.
- **Disclose odds in-app** (see §5 compliance).

### 3.4 Data-driven content (see §7)
Items must be **definitions in data**, not hard-coded Dart lists, with each item carrying an
**unlock condition** (tier / achievement / earnings threshold). That's what lets the `1.15` curve +
unlock gates ration hundreds of items automatically.

---

## 4. Three-tier prestige

Three **nested** reset loops on deliberately different cadences, each with its **own currency** and
**own upgrade screen**. Each tier gates on the *output of the tier below* so they physically nest and
can't be skipped (Antimatter Dimensions' Reality-needs-EP rule).

| Tier | Theme | Cadence | Resets | Keeps | Currency (formula) | Sink |
|---|---|---|---|---|---|---|
| **1. Soft Fork** | consensus tweak | minutes–hours | LAB only | sats, rigs, perks, tokens, artifacts | **Consensus (CX)** = `floor(cbrt(eraSats / 1e12))` | "Node Network" tree — makes LAB re-grind faster/stronger; higher nodes *keep N LAB nodes through a soft fork* |
| **2. Hard Fork** | chain split | hours–day | LAB + perks + CX pool | GovTokens, artifacts, achievements | **GovTokens** = `floor(sqrt(lifetimeSats)/K)` (keep current) | "Governance" perk tree (current 3 perks = common tier; add offline%, crate luck, chaos duration, auto-buy…) |
| **3. New Blockchain / Time Reverse** | genesis restart | days–weeks | almost everything (sats, rigs, LAB, perks, tokens, exchange rate) | **only physical Stash artifacts** + achievements | **Genesis Blocks (GB)** = `floor((totalGovTokensEver/100)^0.5)` | "Genesis/Protocol" meta-tree that multiplies CX & GT gain, unlocks automation & new rig tiers |

**Key rules (anti-obsolescence, anti-power-creep):**
- **Currency gain is sub-linear** — exponents strictly *decrease* per tier (0.5+ / 0.55 / 0.4) and
  thresholds *increase* (1e12 / 1e9-scaled / feeds off tokens) so higher tiers fire on longer clocks.
- **Top currency feeds off the middle currency's lifetime total** (GB scales off total GovTokens ever
  earned, not raw sats) — forces genuine tier-2 mastery before tier-3 pays. This is exactly AD's
  Reality→EP design.
- **GB directly multiplies CX and GT formulas** so doing a New Blockchain makes *every* future soft/hard
  fork more rewarding → **no lower layer ever dies**. Add **automation** (auto-soft-fork at threshold)
  as a GB node so the fast loop keeps running in the background.
- **Split every tier's reward** (Cookie Clicker): an **always-on multiplier** that can never be wasted
  + a **spendable currency** into that tier's tree.
- **Soften the GovToken bonus**: +10%/token compounds too fast for a months-long game (50 tokens =
  +500%). Move to ~+1–2% additive per token (into the PRESTIGE channel) or make it sqrt-diminishing;
  keep `sqrt(lifetime)` as the *earn* side.
- **Gate the tiers**: Soft Fork visible once affordable; Hard Fork after ~3–5 soft forks; New
  Blockchain only after `totalGovTokensEver ≥ ~100` AND ≥1 hard fork — hidden until near (a genuine
  late-game reveal).
- Optional: Realm-Grinder-style `x^0.1` production penalty on the fresh blockchain for a satisfying
  small-numbers re-climb (A/B decision — may feel bad to casual mobile players).

**Reset UX (critical against reset-anxiety):** every reset button shows **"you will gain X"** live,
**blocks the reset if gain = 0**, and shows an **estimated time-to-rebuild**. Distinct audio/visual
weight per tier (small chime → big fanfare).

---

## 5. Casino / gambling

A casino is the **best controlled currency sink** in the genre — but only if it's a **net drain** and
**pure simulated gambling**.

### 5.1 Google Play compliance (do this or get rejected)
- **Wall the theme off from real value.** Visible disclaimer: *sats, chips, and all winnings are
  fictional in-game points with no monetary value and cannot be withdrawn/cashed out/converted to real
  bitcoin, crypto, cash, or gift cards.*
- **Never** sell the wagering currency for real money into a randomized outcome, and **never** let any
  currency tier exchange out to anything real. Google's Oct-2025 "indirect value transfer" rule
  reclassifies such apps as **real-money gambling** (needs per-country licenses). A BTC theme is a
  heightened risk — keep the fiction explicit.
- **Disclose all payout odds in-app** (plinko bucket probabilities, slot symbol frequencies,
  dice/roulette win chances, and the **Stash crate rarity table**). Required for loot boxes; expected by
  IARC. Show effective RTP per game ("returns ~90%").
- Expect the **"Simulated Gambling" IARC descriptor** → roughly **Teen** age rating (confirm you accept
  this — it's the price of having a casino at all).

### 5.2 Mechanics
- **Dedicated Casino Token**, bought one-way with sats/chips (sink on entry). Winnings spendable **only
  inside the casino or on exclusive cosmetics/artifacts** — never back into the core wallet (else a
  lucky streak re-inflates the economy).
- **EV < 1.0 on every bet** (RTP 85–95%). Unit-test each paytable's `Σ(prob × multiplier) < 1.0`.
  - Plinko (8-row): binomial `C(n,k)·0.5^n`; retune Stake's multipliers down to ~88–92% RTP; offer
    low/med/high risk.
  - Dice: payout `= (1/p)·0.90`. Roulette: single-zero layout, straight-up pays 30:1 (not 35:1) → ~16% edge.
  - Slots: paytable where `Σ(symbol-prob × payout) ≈ 0.90`.
- **Loss-streak pity** (Genshin-style bounded variance): a "Lucky Break" meter that fills on losses,
  forces a guaranteed win/consolation after N (~8–10) losses. Show the meter.
- **Agency + juice**: a light skill/timing element (tap-to-set plinko drop, tap-to-stop reel) + heavy
  audio-visual payoff (you already have per-sound `AudioPlayer`s). **Avoid manipulative near-miss
  animations** (ethically dark + rating risk).
- **Anti-grind**: energy-style spin resource or daily wager cap + escalating minimum bets.
- **Progressive unlock**: reveal casino after a milestone (e.g. first Hard Fork), then Dice → Plinko →
  Slots → Roulette across further milestones. Each new game = fresh dopamine + new sink.
- Optionally make the casino its own **mini idle loop** (Plinko-idle: upgrade ball value, crit,
  auto-launcher) funded by Casino Tokens — depth without touching the core economy.

---

## 6. Achievements & progressive discovery

### 6.1 Achievements do double duty
- **"Notoriety" meta-multiplier** (Cookie Clicker's milk): each *normal* achievement grants a tiny
  permanent bonus (~+0.5% each; ~80–100 normal achievements → up to +40–50% aggregate). **Keep it in
  its own lane** — surface it via one opt-in node ("Reputation Rig: +X% income per Notoriety") so it
  never collides with the perk/lab power budget.
- **Tier against actions players already take** (anti-grind): per rig type at 1/10/25/50/100/250/500
  owned; lifetime-sats ladders; halvings survived; prestiges per tier; crates opened. Never an isolated
  "tap 10,000 times."
- **Shadow/secret achievements** (~10–15): **no** bonus, invisible until earned, purely cosmetic
  badge + joke title. Tie to BTC culture: "Sold the Bottom" (sell in a crash), "Diamond Hands" (hold
  through 3 halvings), "HODL" (idle 24 h), "Bitcoin Pizza" (reach 10,000 sats), prestige with 0 rigs.
- A few **one-time headline payouts** (first prestige of each tier, first Mythic, 100th achievement)
  in Chips/GovTokens — rare, so they read as celebrations.

### 6.2 Progressive discovery ("layers of the onion")
- **Show only the next 1–2 locked items** per category (rigs/lab/perks) as greyed silhouettes with
  "???" + an unlock hint; hide the rest entirely (Idle Iktah's anti-overwhelm rule — the single
  highest-leverage lever for shipping 100 items without dumping them).
- **Stage-reveal whole systems** behind triggers: LAB after first halving; Stash/anomalies after first
  crate / ~1M lifetime sats; Casino after a threshold; Soft Fork at block N; Hard Fork after first soft
  fork; New Blockchain after first hard fork. Each reveal is a retention beat.
- **Stash Completion Log** (Melvor): undiscovered artifacts as rarity-tinted silhouettes + "???",
  per-rarity and overall completion % (a shareable identity marker). Turns crates into a collectathon.
- **Secrets via subtle in-world cues** (A Dark Room): hints in news/chaos flavor text, plus a soft
  hint (cryptic one-liner when the player gets "close") so secrets are discoverable, not wiki-only.
- **Notifications**: non-blocking toasts, batch simultaneous unlocks, red-dot badge on tabs — never
  modal-interrupt the tap/idle flow.

---

## 7. Architecture refactor (grounded in the current code)

The current structure blocks all of the above. Key blockers observed in this repo:

- **God object**: `lib/providers/game_logic.dart` (~800 lines) owns currency, the rig catalog,
  chaos/anomaly/news timers, the mining tick, persistence orchestration, and re-exposes manager
  internals via pass-through setters.
- **Hard-coded content**: rigs are a literal list in `game_logic.dart`; research nodes in
  `ResearchManager`; perks/costs as maps in `PerkManager`. Adding 100+ items this way is untenable.
- **Coarse UI**: every screen is a whole `Consumer<GameLogic>` that rebuilds on every 1 s tick.
- **Save**: single JSON blob `game_save_v2` with a version field (good — built during the fixes), but
  it serializes a fixed hand-written shape.

**Refactor targets (Phase 1–2), in priority order:**

1. **Data-driven content registry.** Introduce a generic `UpgradeDef` (id, category, rarity, channel,
   bonus type + value, cost curve, `unlockCondition`) and hold all rigs/lab/perks/stash items as
   **const definition lists** (or JSON assets) in a `content/` layer. Systems iterate definitions;
   save stores only `{id: state}` (already the pattern for rigs/research). This is the single change
   that makes "20–100 per category across 6 rarities" a data task, not a code task.

2. **A `Channels` value object** (the §2.1 model) that every system contributes to and income reads
   from — one auditable place for all multipliers. Replace `calculateGlobalHashRate` /
   `calculatePrestigeMultiplier` ad-hoc math.

3. **Break the god object into systems** behind interfaces: `MiningSystem`, `PrestigeSystem` (3 tiers),
   `ContentSystem` (upgrades), `StashSystem`, `CasinoSystem`, `AchievementSystem`, `UnlockSystem`.
   `GameLogic` becomes a thin coordinator + tick dispatcher. Inject them (repos/services already are).

4. **Unify the mining tick.** Online `_mine()` and offline `_simulateOfflineMining()` are two
   divergent copies — extract one `advanceTime(seconds)` used by both.

5. **Save schema for growing content + versioning + migrations.** Store per-id maps for every content
   category, a `schemaVersion`, and a migration chain so shipping new content/renames never wipes
   saves. (The atomic single-blob write is already in place.)

6. **Granular UI.** Replace whole-screen `Consumer`s with `Selector`s / smaller listenables; isolate
   the particle overlay and news ticker into `RepaintBoundary` leaves. Needed before the UI grows.

7. **Menu restructure.** Current bottom nav = PERKS / LAB / STASH / MINE. Proposed, revealed
   progressively:
   - **MINE** (core loop, always present)
   - **UPGRADES** (perks + lab as sub-tabs, or merged into the data-driven upgrade browser)
   - **STASH** (crates + completion log)
   - **CASINO** (unlocks later)
   - **FORKS** (the 3 prestige tiers, each a sub-panel, revealed one at a time)
   - **ACHIEVEMENTS** (with red-dot badge)
   Use a dynamic nav that only shows unlocked destinations.

---

## 8. Phased implementation roadmap

Each phase ships something playable/testable and is independently valuable. Keep the test suite green
throughout; add a **sim harness** early.

- **Phase 0 — Groundwork (safety net).** Sim harness for the 14-day curve; extend `Formatter` suffixes;
  decide the big-number strategy. *No player-facing change.*

- **Phase 1 — Economy foundation.** Implement the `Channels` model; route existing bonuses through it;
  fix the difficulty runaway; remove/scope the 21M cap; soften the GovToken multiplier. *Rebalance to
  the sim.* This is the make-or-break phase — do not skip.

- **Phase 2 — Data-driven content + refactor.** `UpgradeDef` registry; migrate rigs/lab/perks to
  definitions; save schema for per-id content; begin breaking up the god object; granular UI. *Still
  the same content count — just data-driven.*

- **Phase 3 — Rarity & content volume.** Add the 6-rarity system, the additive bands, set/scaling
  bonuses, dupe fusion; expand to the first big wave of items (e.g. 20–30 per category) with unlock
  gates. Rework Stash crates (tiers, weighted rolls, odds screen).

- **Phase 4 — Progressive discovery.** "Next 1–2 locked" reveal; stage-reveal systems behind triggers;
  Stash completion log; unlock system wired across all categories.

- **Phase 5 — 3-tier prestige.** Soft Fork + Consensus + Node Network tree; refit Hard Fork into the
  tier model; New Blockchain + Genesis Blocks + meta-tree; reset-preview UX; automation nodes.

- **Phase 6 — Achievements.** Notoriety multiplier (opt-in node), normal + shadow achievements,
  batched non-blocking notifications, headline payouts.

- **Phase 7 — Casino.** Compliance disclaimer + odds screens first; Casino Token; Dice → Plinko →
  Slots → Roulette with EV<1 + pity; progressive unlock; casino-only rewards.

- **Phase 8 — Content fill-out & polish.** Scale each category toward the 50–100 target; menu
  restructure finalization; balance pass against real telemetry; more rig tiers (Fusion, …).

Ship 1–8 as separate PRs. Phases 3/6/7 are content-parallelizable once the Phase 1–2 framework exists.

---

## 9. Open decisions (need your input before/within Phase 1)

1. **Big numbers:** migrate sats to a `break_infinity`-style type (recommended for weeks/months), or
   keep the thematic 21M cap and reset it per-run? Changes the whole scaling ceiling.
2. **Top of the curve:** should a dedicated player reach **New Blockchain** in ~3–4 weeks, or is it a
   months-out aspirational endgame? Sets every threshold constant.
3. **Monetization:** any ads/IAP? If IAP ever grants chips/casino tokens, loot-box odds disclosure
   becomes legally mandatory and soft walls must be looser. Decide before the currency flow.
4. **Casino age rating:** do you accept the **Teen-ish "Simulated Gambling"** rating bump? If not, no
   casino.
5. **GovToken bonus reshape:** OK to change +10%/token → ~+1–2% additive (or sqrt-diminishing)? Needed
   to avoid power creep, but changes the feel of existing saves.
6. **Prestige currency source:** pure cumulative totals (simpler, casual-friendly) or partly
   run-efficiency (NGU-style: sats/min, fastest halving — more skill, more punishing)?
7. **New Blockchain penalty:** clean restart with only bonuses, or Realm-Grinder `x^0.1` production
   penalty for re-climb satisfaction?
8. **Scope of Notoriety:** does the achievement multiplier persist across all 3 resets (recommended —
   makes achievements feel permanent), or partially reset?

---

## Appendix — reference games (what to steal from each)

- **Antimatter Dimensions** — 3 nested prestige layers, each a new currency + screen; top currency
  scales off the middle; log/root formulas keep 200+ h sane. → the 3-fork blueprint.
- **Cookie Clicker** — `cbrt(lifetime)` prestige at small always-on % + spendable tree; achievements =
  milk multiplier; shadow achievements cosmetic. → prestige split, Notoriety, shadow achievements.
- **Realm Grinder** — 100+ upgrades kept sane via additive-within / multiplicative-across; two reset
  tiers gated by counts; `x^0.1` ascension penalty. → the channel discipline, tier gating.
- **NGU Idle / Trimps** — whole menus unlocked by milestones; deliberate multi-day walls. → progressive
  reveal + soft walls.
- **Melvor Idle** — hundreds of items rationed by progression gating; 24 h offline; completion log. →
  content gating, completion log.
- **AdVenture Capitalist** — varied per-generator cost growth + ownership milestone multipliers. → keep
  old rigs relevant.
- **Path of Exile** — "increased vs more"; affixes gated by item level. → additive/multiplicative model,
  tiered crates.
- **Universal Paperclips / A Dark Room / Idle Iktah** — staged reveals; discovery-as-aesthetic;
  "next 1–2 locked only." → the discovery model.
- **Stake Plinko / Genshin pity** — binomial paytables + RTP tuning; bounded-variance pity. → casino math.
