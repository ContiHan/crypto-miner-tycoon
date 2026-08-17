# BTC Only Tycoon — Parameter Reference

Every stat the game tracks, what it means, what raises it, and what it affects.
All numeric values are the `[TUNE]` defaults in `lib/core/constants.dart` /
`lib/logic/managers/class_manager.dart`; the code is the source of truth.

> This doc mirrors the **currently-shipped** code. A large **planned redesign**
> (endgame → "THE LAST SATOSHI" / Back-in-Time, ~25 attributes + resistances,
> exclusive TECH doctrines, procs/auras/keystones, upkeep, theft) is specified in
> `docs/ENDGAME_REDESIGN.md`, `BUILD_DEPTH.md`, `CHAOS_DEPTH_LAYER.md`,
> `ATTRIBUTES_AND_ABILITIES.md`, with the authoritative cap checklist in
> `BALANCE_AND_BOUNDS.md`. Update this reference as those ship. The old
> win/sandbox/NG+ rows below are current-code, and are RETIRED by that redesign.

---

## 1. Currencies

| Currency | Earned by | Spent on / effect | Reset by |
|---|---|---|---|
| **Sats / BTC** (`wallet`) | mining (passive + taps) | buying rigs; the visible balance | every Hard Fork+ |
| **GovTokens** (`govTokens`) | Hard Fork (`floor(sqrt(lifetimeSats / 5e8))` × class/trophy/genesis gain) | SKILL nodes; drives `prestigeMultiplier` | New Blockchain |
| **Consensus / CX** | Soft Fork (`floor(cbrt(eraSats / 2e9) …)`) | always-on income bonus | Hard Fork |
| **Genesis Blocks / GB** | New Blockchain (`floor(sqrt(chainGovTokens / 520000))`) | multiplies CX+GT **gain** (not raw income) | never (permanent) |
| **UTXO** (`chips`, internal) | anomaly pop-ups (+1), SWEEP wins | crates; SWEEP stakes | New Blockchain |
| **Trophies** (`winCount`) | reaching the ending / NG+ | permanent prestige-gain bonus | never |
| **Mastery XP** (per class) | Bitcoin **mined while playing that class** (1 full 21M supply = 1 XP unit) | permanent all-class bonus | full wipe only |

---

## 2. Channels — the core stat model

All hash/income/click/etc. bonuses funnel into **channels** (`lib/logic/channels.dart`).
Within a channel bonuses are **additive** (`1 + Σ`), and channels multiply across
each other. Past a **soft-cap** a channel decelerates (diminishing returns) so no
single stat runs the economy away.

| Channel | Affects | Soft-cap (start / power) | Notes |
|---|---|---|---|
| **hash** | global hash rate → mining income | 4.0× / 0.6 | the main output stat |
| **income** | sats per second (passive **and** taps) | 3.0× / 0.6 | also × Notoriety × prestige × market |
| **click** | manual tap power | 3.0× / 0.6 | stacks with the flat click node + stash click mult |
| **rigCost** | rig price discount | hard-capped at −95% | higher = cheaper rigs |
| **luck** | see §6 | 1.5× / 0.5 | crit, SWEEP payouts, anomaly/crate odds |
| **volatility** | market-event **frequency** | 1.5× / 0.5 | >1 = more events, <1 = fewer (see §8) |
| prestige | *(reserved — unused)* | — | prestige power comes from GT/CX/GB lanes directly |
| special | *(not a multiplier)* | — | flat click node, Chip Fab, AI Manager handled explicitly |

**Soft-cap formula:** below `softStart` the multiplier is untouched; above it,
`applied = start × (raw / start)^power`. So e.g. a raw ×10 hash with start 4.0 /
power 0.6 applies as `4 × (10/4)^0.6 ≈ 6.8×`.

---

## 3. Where channel bonuses come from

| Source | File | Feeds |
|---|---|---|
| **Rigs** | `lib/content/rig_defs.dart` | base hash (per rig type) |
| **TECH** (research) | `lib/logic/managers/research_manager.dart` | hash / income / click / rigCost (one-shot nodes) |
| **SKILL** (class tree) | `lib/logic/managers/perk_manager.dart` | class-specific channels (bought with GovTokens, reset per chain) |
| **Stash** artifacts | `lib/services/stash_service.dart` | hash / click / rigCost / luck (permanent collection) |
| **Class racials** | `lib/logic/managers/class_manager.dart` | passive per-class channel bonuses (see §4) |
| **Mastery** | `class_manager.dart` | +0.5% hash & income **per total mastery level**, all classes |
| **Notoriety** | `lib/logic/managers/achievement_manager.dart` | +1% income per claimed non-secret achievement (own lane) |

---

## 4. Classes (racials + prestige)

Passive racials are additive channel bonuses (always on for the chosen class) plus
one multiplicative **prestige-gain** hook. Locked for the whole run; re-pick at a
New Blockchain.

| Class | Hash | Income | Click | RigCost | Luck | Volatility | Prestige gain |
|---|---|---|---|---|---|---|---|
| **Prospector** (start) | — | — | — | — | — | — | ×1.0 |
| **Solo Miner** | — | — | +15% | −20% cost | +10% | — | ×1.0 |
| **Corporation** | +20% | +15% | — | — | — | +15% (louder) | ×0.85 |
| **BTC OG** | +5% | — | — | — | +8% | −10% (calmer) | ×1.25 |
| **Pool Member** | — | +8% | — | — | +10% | −25% (calmest) | ×1.0 |

- **Prestige gain** scales how much Consensus + GovTokens you bank per fork
  (BTC OG farms prestige fastest; Corporation slowest but brute-force output).
- **Mastery**: XP = Bitcoin MINED while playing that class (1 full 21M supply
  mined = 1 XP unit; credited live in `_creditLifetimeEver`, un-farmable by
  resetting). Level = `floor(sqrt(XP / 10000))`. Total mastery level across all
  classes grants a tiny permanent hash+income bonus to *every* class. Only a full
  wipe clears it.

---

## 5. Prestige tiers

| Tier | Action | Grants | Resets |
|---|---|---|---|
| 1 | **Soft Fork** | Consensus (income bonus = `0.10 × sqrt(CX)`) | TECH only + era sats |
| 2 | **Hard Fork** | GovTokens (`prestigeMultiplier = 1 + 0.50 × sqrt(GT+spent)`) | wallet, rigs, TECH, SKILL, CX |
| 3 | **New Blockchain** | Genesis Blocks (`gain × = 1 + 0.5 × sqrt(GB)`) | everything except Stash + GB + endgame spine |
| ★ | **Ending / NG+** | Trophy (`prestige gain × = 1 + 0.10 × winCount`) | like New Blockchain, keeps the trophy |

Genesis Blocks and Trophies multiply the **gain** of the lower currencies, so each
deep reset makes future runs farm prestige faster (compounding, but concave via
`sqrt` so it converges instead of exploding).

---

## 6. Luck — what it actually does

Luck is a single stat (`luckMultiplier`, soft-capped) fed by the **luck channel**
(Stash artifacts, some class racials, and the OG/Pool SKILL nodes). It affects
**four** things — note it boosts *outcomes/odds*, never a shown percentage:

1. **Crit taps** — raises the manual-tap crit chance (base 6%, hard cap 25%). A
   crit pays 5× that tap.
2. **SWEEP (casino) winnings** — multiplies your **payout** via `effectiveLuck`,
   bounded by `casinoEvCeiling = 2.5×`. ⚠️ It does **not** change the win *odds*
   (e.g. Hash Flip's tier weights are fixed) — it makes the amounts you win
   bigger. The casino tab shows your live `LUCK ×N` so the boost is visible.
3. **Anomaly spawn rate** — how often a UTXO pops up on MINE (base 5%/tick, cap 30%).
4. **Crate / anomaly odds** — luckier rare finds.

So with BTC OG + luck SKILL nodes, your Hash Flip tier odds are unchanged, but
each win pays more, jackpots hit more often, and UTXOs surface faster.

---

## 7. SWEEP minigame (simulated casino)

In-game **UTXO** only — no real money or value. Deliberately **player-favoured**
(you raise on average), bounded by a per-window net cap, not by the odds.

| Game | Base return (EV) | Feel |
|---|---|---|
| **Block Scanner** (slots) | ~1.65× | ~80% don't lose (47% win / 32% refund / 20% bust); 25× jackpot |
| **Packet Relay** (plinko) | ~1.55× | the SAFE game — worst bucket refunds the stake; 20× edges |
| **Hash Flip** (leading-zeros lottery) | ~1.50× | the HIGH-VARIANCE game — ~76% bust, ~24% pay (2×/5×), rare **30×** "block found" (3%). Same EV as the others, just swingier |

- **Luck** boosts payouts up to `casinoEvCeiling = 2.5×`.
- **Anti-farm cap:** once net gain reaches `casinoDailyNetCap = 400` UTXO within a
  `casinoWindowHours = 24` h window, sweeps are blocked ("MEMPOOL CONGESTED") until
  it resets. The crossing sweep is still paid in full.

---

## 8. Market ticker / chaos events

The top news-ticker bar. Logic: `lib/logic/systems/chaos_event_system.dart`;
flavour lines: `lib/content/news_flavor.dart`; the enum: `lib/models/news_event.dart`.

**Idle** (white) shows rotating funny headlines — no effect. The random events are
**three buff/debuff pairs**, each pair a temporary buff and a debuff on one axis:

| Event | Bar colour | Effect | Duration |
|---|---|---|---|
| **BULL RUN** | green | income **×2.0** (+100%) | 90–150 s |
| **MARKET CRASH** | red | income **×0.5** (−50%) | 90–150 s |
| **AIRDROP** | amber | one-shot **+15% to wallet** | 45 s |
| **HACK** | red | one-shot **−15% from wallet** | 45 s |
| **CHEAP ENERGY** | cyan | rig cost **×0.7** (−30%) | 120 s |
| **COST SPIKE** | deep orange | rig cost **×1.5** (+50%) | 120 s |

(`info` is a neutral type used **only** for manual banners such as the halving — it
is *not* rolled as a random event.) Income and cost buffs run on **independent**
timers, so e.g. a Bull Run and Cheap Energy stack instead of cancelling. The
**volatility** channel scales how *often* events fire (Corporation = more, Pool
Member = fewer).

---

## 9. Other mechanics

- **Halving** (`halvingFirstThreshold = 15000` blocks, then doubles each time):
  block reward halves; income scales by `blockReward / initialBlockReward`. Gentle
  pacing, not an income killer.
- **Crit tap:** base 6% chance, 5× payout, chance raised by Luck up to 25%.
- **Endgame:** the win is the monotonic `lifetimeEverSats` (never reset) crossing
  `endgameTargetSats = 2.1e20` (~100,000× the 21M supply) — a `[TUNE]` ~1-year goal.
- **Sandbox ("Break the Chain"):** post-win toggle that lifts the per-era 21M cap.
