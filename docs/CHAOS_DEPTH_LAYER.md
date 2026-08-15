# Maxi-Chaos Depth Layer — Procs, Auras, Keystones, Power Bill & The Breach

Status: **PLANNING ONLY.** No code. Multi-agent design + adversarial review
(verdict *ship-with-fixes*; must-fixes folded in below ⚑). Sits on top of
[BUILD_DEPTH.md](BUILD_DEPTH.md) (25 attributes + doctrines + 5 keystones) and
[ATTRIBUTES_AND_ABILITIES.md](ATTRIBUTES_AND_ABILITIES.md) (abilities).

**Owner direction:** a "maxi-chaos / crazy game that hasn't existed before" —
bold MOBA/MMO systems — **within the non-negotiable rails**. Owner decisions
baked in: **commitment budget = 2 doctrine pairs → equip ≤2 keystones**; **upkeep
IN**; **theft BUILT**; **procs + auras + on-crit YES**. Everything ships with an
in-game **guide**.

Five interlocking systems: **(A) TRIGGERS** (on-X procs), **(B) AURAS/STANCES**
(while-conditions), **(C) 12 KEYSTONES**, **(D) THE POWER BILL** (upkeep), **(E)
THE BREACH** (theft).

---

## ⚑ The rail additions the review demands (apply to the WHOLE layer)

The old rails (per-channel softcaps, 21M wall, concave prestige, casino bounds,
≤0.70 combined mitigation) all hold — but a multiplicative temp-buff economy needs
three NEW global caps or finite peaks get large enough to trivialize the timed
endgame's pacing:

1. **ONE shared temp-buff axis per channel** — merge the proc-axis and the
   ability "own-axis" into a SINGLE outside-softcap lane per channel; two separate
   exempt lanes must not multiply.
2. **GLOBAL aggregate temp-multiplier ceiling per channel** — cap the PRODUCT of
   (base-softcapped × the merged temp axis × the chaos market lane) during any
   window (e.g. income ≤ ~x8 total, hash ≤ ~x8, click ≤ ~x6 — [TUNE]). This is the
   number that keeps a Chaos-Surfer Bull-Run stack auditable.
3. **`critPayoutMax` hard cap** — the crit-CHANCE cap (25%) has no payout twin;
   add one so LASER EYES ×2 × LASER FOCUS +50% × Difficulty Drop × proc stack
   can't reach ~50–80× per crit. (e.g. crit payout ≤ ~x20 total — [TUNE].)

Plus: **auras are ON-CHANNEL** (persistent → they get NO outside-softcap lane;
only brief CD/ICD-gated buffs do); **all proc sats-grants supply-clamped**;
**offline runs NO procs**; **skimmed/stolen sats are burned, not pooled**.

---

## A. TRIGGERS (the on-X proc engine)

A signal = `{event, chance, effect, internal-cooldown (ICD, wall-clock), source}`.
On a **real** event the engine rolls each active, off-ICD, under-limiter signal.

⚑ **GOLDEN RULE (kills every loop):** any event a proc itself produces is
`synthetic` and fires NO triggers. Auto-taps are synthetic too. Verified by review
to break proc→crit→proc, on-crate→crate, and block-faucet loops.

**Trigger tiers** (tier sets the ICD floor): HOT (onTap, onBlockFound — ICD 8–10s,
tiny effects) · CRIT (onCrit, onCritStreak — ICD 5–6s) · WARM (onAnomalyCollect,
onGoodChaos, onBadChaos, onAbilityCast — ICD 20–30s) · COLD (onCrateOpen,
onSoftFork, onHardFork, onHalving, onHackHit, onGenesis — event-gated, big effects
OK). Excluded: anything that force-fires a chaos event.

**Two effect kinds only:** GRANT (instant, supply-clamped: sats-lump / UTXO /
crate-roll / anomaly / ability-CD-refund) and BUFF (short temp multiplier on the
**merged temp axis**, aggregate-capped per #1/#2 above). Never grants a permanent
stat or prestige currency. `onCrit` never raises crit CHANCE (only payout) — the
loop-safety cornerstone. Back-in-Time: buff-boosted mining counts; GRANT lumps
credit wallet only, never `speedRunMinedSats`.

**Sourcing:** STASH **Firmware affixes** (permanent, Time-Capsule-kept) socketed
into a bounded **RIG FIRMWARE loadout** (3 slots → +1 at META "Firmware Bay" /
class Mastery 2 / a deep doctrine node → cap ~6); a few class-flavored guaranteed
TALENT procs; keystone hooks (HAIR TRIGGER, CO-PROCESSOR); onAbilityCast.

**Anti-runaway brakes:** Golden Rule · per-signal ICD floors · auto-taps fire
nothing · global token-bucket limiter (~8 resolutions / 10s) · per-tick cap ~3 ·
slot cap ~6 · the merged-axis aggregate ceiling (#1/#2) · **offline = no procs** ·
supply clamp on every grant · crate-open UTXO refunds always < crate cost (crates
stay a sink).

---

## B. AURAS / STANCES (while-conditions, MMO-style)

An aura = a **stateless** conditional passive: `WHILE <condition>: <bonus> [/ cost]`,
applied live while true, gone the instant it fails (banks nothing → root
rail-safety). ⚑ Because persistent, auras are **ON-CHANNEL** (identical math to a
TECH/STASH contributor) — they obey the base softcaps and get **no** outside lane.

**Slots:** 1 exclusive **STANCE** (big effect + mandatory cost) + up to 3 **AURAS**
(small, unlock at Mastery 1/2). 60s **switch lockout** (anti-flicker); swapping an
aura re-arms it (sub-state resets); saved into the auto-named preset.

**Conditions** — DYNAMIC (flip in play; may be modest pure-upside): while an
ability buff / while all on CD / while good/bad event / while calm / while
>75% or <N% supply mined / **while AT THE CAP** / while wallet full/empty / fleet
≥/≤N / while crit/tap streak / first 10min post-offline or post-fork / while in a
Back-in-Time run / while a breach is pending. STRUCTURAL (build-state, always true
→ **must carry a cost**): while a doctrine committed / FOCUS vs GENERALIST / while
a keystone active / at max Mastery.

**Example stances:** OVERCLOCK PROTOCOL (hash/click up; cost volatility + offline
down — ⚑ "hash doubles under Bull Run" means its *additive contribution* doubles
then softcaps, NOT a ×2 on channel output) · STORM RIGGING (while a negative
event: income + resist up; cost: positives weaker) · BULL RIDER (while positive:
income+luck up; cost: negatives last longer) · LASER FOCUS (while crit streak:
crit chance pinned to cap, payout up via the capped `special`; cost passive income
down) · THE LONG TAIL (>75% mined: hash+income ramp) · FRESH GENESIS (10min
post-fork: rigCost to floor + hash; self-expires). Passive auras: MEMPOOL SURFER,
CALM WATERS, VAULT GUARD (theft resist within the 0.70 cap), ANOMALY MAGNET, etc.

**Ceilings:** passive aura ≤+0.20/channel, stance ≤+0.75, off-channel ≤+0.10
resist / ≤+0.15 prestige-gain (all routed into the EXISTING shared hard caps, no
private lane). ⚑ Rebalance DIAMOND/HODL POSTURE — its "nothing spent 5min" cost
doesn't bite the idle build that wants it; give it a cost the beneficiary pays.

---

## C. KEYSTONES (12 — 2 per doctrine capstone, pick one)

Each = one bounded lever + a symmetric real cost. **Equip ≤2** (commitment budget
= 2 pairs → reach ≤2 capstones). Pair-exclusivity makes the scariest same-axis
double-dips structurally unreachable.

| # | Keystone | Doctrine (class) | Upside | Downside |
|---|---|---|---|---|
| 1 | ASIC MONOCULTURE* | MEGA-HASH (Corp) | +100% hash | luck ×0.4, no crits |
| 2 | FURNACE FARM | MEGA-HASH (Corp) | +60% hash | upkeep pinned to 15%, Efficiency/Fee-Hedge do nothing |
| 3 | SWEAT EQUITY | LEAN-RIG (Solo) | click ×2.5 | passive hash ×0.5, offline ×0.5 |
| 4 | JUNKYARD RIGS | LEAN-RIG (Solo) | rigCost slammed to −95% floor + fast rebuilds | −40% hash/rig, theft +50% harder |
| 5 | LOW TIME PREFERENCE* | HODLER (OG) | prestige ×1.5 + offline parity 1.0 | active income −30% |
| 6 | COLD-WALLET DISCIPLINE | HODLER (OG/Pool) | offline parity + 24h window + Idle Capacity ×2 | foreground income −45%, no crits |
| 7 | PAPER HANDS* | DEGEN-YIELD (Corp/OG) | GovToken gain ×2 | Consensus can't be held |
| 8 | MARKET MAKER | DEGEN-YIELD (OG/Corp) | positive chaos +50% | negative chaos +50% + resists halved |
| 9 | LASER EYES* | DEGEN-LUCK (Solo) | crit chance to cap + payout ×2 | non-crit taps do nothing |
| 10 | DEGENERATE GAMBLER | DEGEN-LUCK (OG/Pool) | SWEEP to EV ceiling + rarity/anomaly maxed | passive income ×0.5, hash ×0.5 |
| 11 | COLD MINER* | COLD-STORAGE (Pool) | immune to ALL negative events | ALL positive events also never fire |
| 12 | FORT KNOX | COLD-STORAGE (Pool) | ⚑ resist maxed toward the 0.70 cap + theft near-nullified via vaulting + "+15% security dividend" | luck ×0.5, no crits |

`*` = the 5 from BUILD_DEPTH. ⚑ **FORT KNOX is NOT literal passive immunity** (that
would break the ≥30%-always-lands rule); it maxes resist + leans on auto-vaulting
so breaches whiff on a near-empty hot wallet. COLD MINER is the ONE full-immunity
exception, safe because it's *symmetric* (kills positives too = net-neutral opt-out,
not a stacking resist). Cross-pair contradictions (COLD MINER + MARKET MAKER)
self-neutralize into dead picks, and the guide warns.
⚑ **Cut for v1:** class-signature keystones + a theft-offense HONEYPOT (both
reopen the equip-cap-2 bound / add an unclamped faucet).

---

## D. THE POWER BILL (upkeep / sustain axis)

⚑ Owner reversed the earlier "defer" — upkeep is **IN**. Designed so it never
reads as a punishing tax.

**Core:** upkeep is a **skim off gross income, shown as "% KEPT"** ("NET 92%"),
never a bill from a balance — no second currency, no bankruptcy, no red number.

**⚑ The critical split (safety + clarity):** upkeep taxes **spendable WALLET
sats only**, NOT mining progress. `grossMined` credits lifetime / the 21M
drawdown / Mastery XP **in full**; only `netToWallet = grossMined × (1 − upkeepRate)`
hits your spendable wallet. So upkeep only slows how fast you BUY — never the win,
never the supply fill, never Back-in-Time timing (beyond "less cash → buy slower").

**Formula:** load from the FLEET you OWN (`Σ count × tierWeight` — multipliers
aren't taxed, carpeting the 500th rig is) → `rawUpkeep = 0.15·(1 − 1/(1+load/K))`
(~0% first rigs, plateaus toward 15%) → reduced by `min(0.75, EnergyEfficiency +
FeeHedge)` → small class mod (Corp ×1.10, Pool/Solo ×0.90) → `upkeepRate =
clamp(…, 0, 0.15)`. **Net always in [0.85g, g] before reductions, never <0, never
>g** (skimmed sats burned → no faucet). This finally gives **Energy Efficiency +
Fee Hedge** real purpose.

**Chaos dual-duty:** CHEAP ENERGY also halves upkeep (→0) = "FREE POWER — NET
100%"; COST SPIKE also ×1.5 upkeep (still clamped 0.15) = a "batten down" moment
Fee Hedge blunts twice. **Offline:** one skim, not stacked. Brute fleets sit ~15%,
LEAN/Solo/Efficiency ~3–5% → a ~10% net swing that lets a cheap build rival a
brute without dominating.

---

## E. THE BREACH (theft — telegraphed + defensible)

⚑ Owner: BUILT. Renamed from "Hack" (avoids the MINE "HACK" button). Replaces the
old silent −15% wallet chaos; AIRDROP (+15%) stays as its twin.

**Signature: HOT WALLET vs COLD STORAGE.** Theft touches only your **hot**
(spendable) wallet. A **Cold Storage vault** is 100% theft-proof (tradeoff:
liquidity — buys auto-spend hot first; one WITHDRAW tap before a big buy). The
Cold Storage attribute (a) reduces breach loss %, (b) **auto-vaults** a % of each
income tick, (c) raises the vault cap → a Fortress build keeps almost nothing hot,
so breaches whiff.

**Can take:** HOT WALLET SATS ONLY. **Never** lifetime/supply/THE LAST SATOSHI,
GovTokens, Consensus, Genesis, Mastery, Stash, achievements, best times, or chips.
Permanent progress is structurally untouchable — verified by the review as the
strongest-designed of the five systems.

**Two-phase telegraph:** THREAT DETECTED (ticker + red shield + ~10s countdown,
*longer* with Cold Storage) → you tap **SECURE/VAULT**, cast a defensive ability,
or ignore → BREACH steals `loss% × (1−R)` of what's still hot (base ≤15%, floor
≥30% of base per the ≤0.70 cap → no passive immunity; only actives fully block).
**First breach of a run = 0-loss DRILL** (the tutorial). **Offline:** one batched,
capped breach max. **Frequency floor** ~10–15 min. Tiers: DUST ATTACK / BREACH /
rare 51% ATTACK (spectacle + brief bounded debuff, still capped).

⚑ **Counter-hack bounty:** surviving via a timely defense may roll a small bounty
— but its **EV must be strictly < the breach loss EV**, else defending becomes
net-positive and farmable (or cut it). ⚑ Assert **Steel Nerves does nothing to
breaches** (no duration; the telegraph scales with Cold Storage instead).

---

## New build archetypes this layer unlocks (beyond BUILD_DEPTH's 8)
1. **NONCE CASCADE** — Solo crit-proc tapper (LASER FOCUS + LASER EYES + HAIR TRIGGER + onCrit firmware). Highest active burst; crit-or-bust, offline-dead.
2. **STORM COUNTERPUNCH** — Pool fortress that eats chaos (STORM RIGGING + FORT KNOX + onBadChaos/onHackHit). Crashes/breaches become its best minutes; no crits/luck.
3. **SOLAR SIPPER** — LEAN upkeep-cheap churn (JUNKYARD RIGS + Energy Efficiency + FRESH GENESIS). ~96% net, fastest fork tempo; low ceiling.
4. **CHAOS SURFER** — Corp/OG maxi-volatility (MARKET MAKER + BULL RIDER + market firmware). Amplifies both sides of the ticker; feast-or-famine. *(The stress-test case for the aggregate temp ceiling.)*

---

## Guide coverage (hard requirement — met, with 3 additions ⚑)
- **Procs:** first-proc coach card · color-coded cause→effect flash+SFX+floating name · Firmware screen in plain language ("WHEN x: y · z% · once/Ns") + live ICD ring · trigger glossary + keyword chips · proc log (news-ticker) · progressive unlock · "?" sheet with live proc-buff totals vs ceilings.
- **Auras:** the centerpiece **LIVE LIT/DARK indicator** (icon glows while its condition holds, dims when it fails) · unlock explainer · "?" sheet "WHILE ___ : ___ (cost ___)" with a real-time condition dot · long-press preview · per-class stance recommender · switch-lockout sweep · preset integration. ⚑ **Add a softcap "diminishing returns" note** (an aura reads "+0.75 hash" but softcaps to less — teach it or it reads as a bug).
- **Keystones:** side-by-side UPSIDE-green/DOWNSIDE-red unlock modal + live preview on YOUR build + interaction warnings + fear-removal ("resets each fork + 1 free respec").
- **Upkeep:** "% KEPT" power meter + zero-tax onboarding + event inline teaching + "+0.4% power" buy-button hint (⚑ shown BEFORE the buy resolves).
- **Theft:** the first-breach 0-loss DRILL is the tutorial + hot/cold explainer + persistent SECURE button + AFK-return summary + a cross-linked **DEFENSE codex** (upkeep + theft + Cold Storage + Fee Hedge). ⚑ **Add a "not enough hot" coach tip** (or auto-withdraw-on-purchase).
- ⚑ **Add** a live readout of the WHOLE temp stack vs its aggregate ceiling (not just procs) so "why did my Bull Run stack flatten" is taught.

---

## Phasing (extends BUILD_DEPTH Phases 0–5; each slice shippable + sim-guarded)
- **Phase 5 (reactivated):** THE POWER BILL, then THE BREACH (share the "wallet-only" boundary + one DEFENSE guide).
- **Phase 6:** TRIGGERS engine (event bus + synthetic flag + ICD + limiter + supply-clamped grants + offline-off) with a small starter signal set + 3-slot Firmware; expand the library as a fast-follow.
- **Phase 7:** AURAS/STANCES (stance + first aura, LIVE LIT/DARK, Mastery unlocks, switch lockout, preset integration).
- **Phase 8:** EXPANDED KEYSTONES (5 → 12; pick-one modal + live preview + warnings). Last, because it references procs/auras/upkeep/theft.

**Sim-guards (must add):** the aggregate temp-multiplier ceiling per channel + `critPayoutMax`; run the adversarial build-matrix sim with worst-case STACKED peaks (Chaos-Surfer full Bull-Run window, Nonce-Cascade full crit-payout stack) as explicit stress cases; proc determinism (run-seeded, offline-off); upkeep net ∈ [0.85g, g]; theft wallet-only + records-untouched; aura softcap-parity; keystone equip-cap-2 + pair-exclusivity.

---

## Open decisions for the owner
1. **Tuning constants** (the big one) — upkeep K, proc limiter rate + ICD floors, the aggregate temp ceiling values, breach frequency floor + tier weights. Run through the sim.
2. **Firmware slot cap** = 6 (CO-PROCESSOR → 8 at −40% chance): confirm 8 stays comfortable under the limiter.
3. **Class-signature keystones + HONEYPOT** — cut for v1 (recommended); add later only if classes feel doctrine-bound (must count against the equip-cap-2).
4. **Stance pool size** — 9 stances is a lot; progressive-unlock them to avoid choice paralysis?
5. **Cold Storage liquidity** — auto-withdraw-on-purchase to kill "not enough hot" friction?
