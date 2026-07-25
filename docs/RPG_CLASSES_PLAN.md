# BTC Only Tycoon — RPG Classes, Skill Trees & Endgame (design proposal v1)

> **Status: SHIPPED — this vision is built (RPG Phases 1–6).** This is the original
> design proposal, kept for history; the game has since evolved. For **current**
> as-built mechanics/values, [**docs/GAME_PARAMETERS.md**](GAME_PARAMETERS.md) is the
> source of truth. Key **deviations from this proposal**:
>
> - **Casino:** proposed as a negative-EV (< 1) "chip sink" for compliance; SHIPPED
>   **player-favoured** ("SWEEP", EV > 1) instead — kept safe not by a house edge but
>   by a per-real-time-window **net cap**. Still fully compliant: in-game **UTXO** only,
>   no real value, payout RNG-decided. ("chips" are displayed as **UTXO**.)
> - **Class pick timing:** proposed first-pick at the first New Blockchain; SHIPPED
>   first-pick **early, at the first Hard Fork** (when SKILL unlocks), then **locked for
>   the run**, re-picked only at a New Blockchain. Mastery is credited per GovToken at
>   **Hard Fork (mint) time**.
> - **Skill trees:** live on the **SKILL** tab (bespoke per-class GovToken trees drawn
>   like the TECH tree).
> - **Endgame target:** `endgameTargetSats = 2.1e20` (~1-year goal); the "ALL BITCOIN"
>   progress bar is **log-scaled**.
> - **Nav order:** SKILL · TECH · MINE · STASH · GOAL (GOAL unlocks on the first
>   achievement).
>
> Original framing (historical): the "think it through" answer to the owner's RPG
> vision (2026-07-24); **[TUNE]** = needs a balancing sim, **[DECIDE]** = needed an
> owner call.

---

## 1. The core problem this solves

Today **Lab** (one-shot money sinks) and **Perks** (leveled GovToken sinks) feel
like the same thing twice, and every bonus is "+x% hash / -x% cost". The RPG layer
gives (a) **identity** (who am I this run?), (b) **divergent strategies** (the same
game plays differently), and (c) a **reason to replay** (master all classes) that
carries to a real **ending** and then a **sandbox**.

Design pillars: *everything affects everything* (small %), *the theme is Bitcoin*,
*it must end once*, *beatable in ~1 year of engaged play, then sandbox forever*.

---

## 2. Restructure: from "Lab + Perks" → "TECH + TALENTS"

Rename and split by **what they are** and **when they reset**, so they stop feeling
the same:

| New name | Was | Currency | Node style | Resets on | Shared or class? |
|---|---|---|---|---|---|
| **TECH TREE** (R&D) | Lab | Money (BTC) | one-shot unlocks, prerequisite graph | Soft/Hard Fork (as today) | **Shared** (all classes) — the "trunk" |
| **TALENTS** | Perks | GovTokens | **leveled** nodes, class-specific branches | **New Blockchain** (with your class) | **Class-specific** — the "branches" |

- **Verdict:** keep two systems but make them *feel* different: TECH = the common
  blockchain research trunk (cheap, frequent, resets often); TALENTS = your class
  power fantasy (deep, permanent-ish within a chain, resets only at tier‑3).
- Both render as the **blockchain "spider" graph** (nodes = blocks, edges = chain
  links, pan/zoom). TECH is one shared graph; TALENTS is a per-class graph that
  swaps when you change class.
- **[DECIDE]** naming: TECH TREE / TALENTS vs keeping LAB / PERKS labels. Recommend
  renaming — it signals the new depth.

---

## 3. Classes (the RPG identity)

Pick a **class** that reshapes the whole run. Four, each a distinct Bitcoin
archetype with a *mechanical* identity (not just a flavor coat):

| Class | Fantasy | Plays like | Signature edge | Weakness |
|---|---|---|---|---|
| **Solo Miner** | lone hacker in a garage | cheap, efficient, hands-on | big discounts on TECH/TALENT/rig **cost**; +manual click & +**glitch/anomaly (chip) find rate** | low raw ceiling |
| **Corporation** | ruthless data-center | brute force, money is no object | huge **hash/passive output** multipliers; ignores cost scaling | worse prestige efficiency; louder chaos (higher energy/cost swings) |
| **BTC OG** | Satoshi-era whale | manipulates the chain itself | best **prestige gains** (CX/GT/Genesis); can **influence chaos/halving** (re-roll or extend events); better rare‑stash odds | slow raw start |
| **Pool Member** | co-op collective | steady, low-variance | **reduces chaos volatility** (fewer/softer crashes); better **casino odds & duplicate value**; bonuses scale with total rigs/collection | no big spikes |

- **When you pick / change:** first pick at the **first New Blockchain** (tier‑3);
  thereafter you re-pick **only at each New Blockchain**. Locked for the whole chain
  run — the choice must matter. (Early game before tier‑3 is class-less "prospector".)
  - **[DECIDE]** alt: allow one free early pick, then lock to NB resets.
- **Class Mastery (permanent):** each class earns **Mastery XP** as you play it;
  Mastery **never resets** and grants a small permanent all-class bonus + unlocks
  class-specific achievements. This is the "play them all" driver.

---

## 4. What resets at which tier (the loop skeleton)

| Reset tier | Keeps | Wipes | Class stuff |
|---|---|---|---|
| **Soft Fork** (CX) | everything except TECH progress | TECH tree | class unchanged |
| **Hard Fork** (GT) | GovTokens, TALENTS, Genesis, Stash, Mastery | wallet/era, rigs, TECH | class unchanged |
| **New Blockchain** (Genesis) | Stash, Genesis, Mastery, achievements | GovTokens, TALENTS, everything | **re-pick class + reset its TALENT tree** |
| **True End → Sandbox** (§6) | Stash, Mastery, achievements, "trophies" | (your choice) | new game+ or uncapped |

- **Verdict:** TALENTS reset with the class at New Blockchain (so class choice
  reshapes each chain). TECH stays a shared per-era trunk. Stash + Mastery +
  achievements are the permanent spine across everything.

---

## 5. Attributes: connect everything to everything (small %)

Define a compact attribute set; TECH, TALENTS, class weightings, and Stash all
nudge these. **Increments ~1–3% per node with softcaps** (today's 10% steps make
progress too fast — the owner flagged this). More nodes, smaller each.

Core attributes:
1. **Hash rate** (passive output)
2. **Click power** (manual)
3. **Cost** (rig/tech/talent discount, hard-capped ~90%)
4. **Prestige gain** (CX / GT / Genesis multipliers)
5. **Luck** — *one stat, many effects, all tiny:* casino RTP nudge **(hard-capped so EV stays < 1 — compliance!)**, glitch/anomaly (chip) spawn rate, crate rarity odds, tap **crit** chance
6. **Volatility** — chaos event frequency/severity (Pool lowers, OG steers, Corp shrugs)

- **Verdict:** route class edges through *weightings* on these (e.g. Solo Miner:
  cost ×0.7, luck +; Corp: hash ×+, cost/prestige −; OG: prestige +, volatility
  control; Pool: volatility −, luck +). Same tree nodes, different class multipliers.
- **Compliance guardrail:** the casino stays a **negative-EV chip sink**. "Luck"
  may raise RTP toward — never to — 1.0 (e.g. cap the bonus so RTP ≤ ~0.97). Never
  advertise or enable +EV gambling.

---

## 6. The ending + sandbox (it must end once)

The owner wants a real finish — "own all 21 million BTC" — then a sandbox.

- **The true goal = cumulative 21M BTC mined *ever*** (a new lifetime-EVER counter,
  distinct from the per-era 2.1e15 cap that already exists as the prestige
  soft-wall). Tuned to ~**1 year** of engaged play. **[TUNE]** via the economy sims.
- Hitting it → a **"GENESIS COMPLETE / You own all Bitcoin" ending screen** (real
  credits-style beat, a meta achievement, a permanent trophy on the profile).
- Then unlock **SANDBOX**, a **[DECIDE]** between two flavors (offer both):
  1. **New Genesis (NG+):** reset for a permanent prestige boost, keep Stash +
     Mastery + trophies — the "do it again, faster, as another class" loop.
  2. **Break the chain:** remove the 21M cap, numbers go to absurdity (uncapped
     mining for fun) — the "sandbox nonsense" the owner described.
- **Ties to New Blockchain:** tier‑3 stays the *mid-game* meta-loop; the 21M-ever
  ending is *above* it. And the per-era cap dead-end (∞ difficulty / 0 income) becomes
  a clear **"era mined — start a New Blockchain"** CTA (already queued) — that's the
  in-game teacher for the whole prestige ladder.

---

## 7. Replay & retention (beatable, but sticky)

- **Achievements** for: reach each milestone *as each class*, hit class Mastery
  tiers, first ending, sandbox feats. This is the "play all four" hook.
- Keep the **~1 year to first ending** honest; Mastery + class-diverse achievements
  are the long tail after. Sandbox is infinite for the number-go-brrr crowd.

---

## 8. Suggested build order (each shippable, sim-guarded)

1. **Restructure** Lab+Perks → TECH (shared) + TALENTS (data model), keep current
   effects/values (no balance change yet). *Safe refactor.*
2. **Attribute broadening**: wire Luck (casino RTP-capped, anomaly rate, crate odds,
   crit) + Volatility, convert increments to ~1–3% + softcaps. *Sim-tune.*
3. **Class system**: pick-at-NB + lock-between + Mastery-persists; 4 class weightings.
4. **Spider/tech-tree UI** for TECH + TALENTS (blockchain-themed graph).
5. **Endgame**: cumulative-21M ending + Sandbox (NG+ / Break-the-chain).
6. **Role achievements** + final balance pass across both economy sims.

Do 1–2 first (foundation + pacing); classes (3) are where the identity lands; UI (4)
and endgame (5) make it feel like a finished RPG idle.

---

## 9. Open decisions for the owner
- **[DECIDE]** Rename Lab/Perks → Tech/Talents? (recommend yes)
- **[DECIDE]** Class change only at New Blockchain? (recommend yes)
- **[DECIDE]** Sandbox = offer BOTH NG+ and Break-the-chain? (recommend yes)
- **[DECIDE]** Are the 4 classes the right set, or add/rename any?
- **[TUNE]** Target time-to-first-ending (~1 year?) and per-node % (~1–3%).
