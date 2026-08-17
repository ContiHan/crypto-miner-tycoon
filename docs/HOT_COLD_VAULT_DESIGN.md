# Hot / Cold Wallet Vault — design decision (F-F)

> **STATUS: DESIGN NOTE — awaiting owner approval before any code.** You asked to
> design this first. It's balance-affecting and the design doc
> ([CHAOS_DEPTH_LAYER.md](CHAOS_DEPTH_LAYER.md) §"Signature: HOT WALLET vs COLD
> STORAGE") deliberately deferred it to v1. Pick a direction below.

## What ships today vs the original vision

**Shipped:** THE BREACH steals a telegraphed % (base 10%, ≤0.70 mitigation cap) of
your **whole** wallet; the "Cold Storage" investment (`Channel.theftResist`) only
**reduces that %**. It never touches permanent progress (lifetime/supply, GovTokens,
Consensus, Genesis, Mastery, Stash, chips, best times). First breach of a run is a
0-loss drill. Since this session, breaches also have **tiers + a frequency floor +
a Cold-Storage-scaled telegraph** (F-A).

**The unshipped "signature":** a real **HOT vs COLD** split of the spendable wallet:
- (a) reduce breach loss % — *shipped*.
- (b) **auto-vault** a % of each income tick into a theft-proof COLD balance — *not
  shipped*.
- (c) a **vault cap** that Cold Storage raises → a Fortress build keeps almost
  nothing HOT, so breaches whiff — *not shipped*.
- A **WITHDRAW** action (COLD → HOT) because buys spend HOT first — *not shipped*.

## The honest question first: is it worth it?

Theft is already ≤10% of the **hot** wallet, capped, telegraphed, and can **never**
touch permanent progress. So the vault's upside is *modest* — it mainly removes a
small, avoidable annoyance for the Fortress/Cold-Storage archetype. The cost is
**real UI + balance surface**: a second balance to show everywhere, a WITHDRAW flow,
and liquidity edge-cases (a buy you can't afford because your sats are cold). That
tradeoff is exactly why the doc deferred it. My honest read: only build it if you
want the *archetype fantasy* ("I'm a paranoid cold-storage hodler, breaches bounce
off me"), not for balance reasons.

## Option 1 — LIGHT auto-vault (recommended if we build anything)

The fantasy with the least UI:

- Unlocks with the **Cold Storage Vault** TECH node (already exists). Once owned, a
  % of each income tick is **auto-skimmed into COLD** (theft-proof). The % scales
  with your `theftResist` investment (e.g. `autoVault% = theftResist`, so a maxed
  Fortress vaults ~70% of income and keeps little hot → breaches mostly whiff).
- **HOT** stays the spend balance. Buys spend HOT; if HOT can't cover it, the game
  **auto-withdraws** the shortfall from COLD (no friction, no haircut) — so there is
  **never** a "can't afford, sats are stuck" moment. One **VAULT ALL / WITHDRAW ALL**
  toggle for players who want manual control.
- Breach steals only HOT (unchanged rule). No vault cap to micromanage.
- **UI:** MINE header shows `HOT ⟨spend⟩ + COLD 🔒⟨safe⟩`; a small lock chip. That's
  it.

Why recommended: delivers the "keep nothing hot" payoff, **no liquidity trap** (auto
-withdraw), minimal new UI, and it's a **build reward** (gated behind Cold Storage),
not a universal nerf to theft.

## Option 2 — FULL vault (the original vision)

Everything in Option 1 **plus** a real **vault cap** (c) and a **manual WITHDRAW**
requirement (buys do NOT auto-withdraw — you must move COLD→HOT yourself before a big
purchase). This is the "liquidity is the tradeoff" version. More strategic, but it
introduces the exact friction (a buy you can't make until you withdraw) that annoys
casual players and needs careful UI. Higher build + balance-sim cost.

## Option 3 — SKIP (leave as-is)

Keep the shipped theft-resist lever. The Breach is already the best-reviewed of the
five chaos systems; the vault adds surface for a modest payoff. Wholly defensible.

## Rails (apply to any option we build)

- **Compliance:** HOT and COLD are both simulated in-game sats — no real money, no
  cash-out, no value. The vault is purely a hot/cold split of the *spendable* wallet.
- **Permanent progress stays untouchable** regardless of vault state — lifetime/
  supply/THE LAST SATOSHI, GovTokens, Consensus, Genesis, Mastery, Stash, chips,
  best times are never HOT and never stealable. (Unchanged invariant.)
- **No new income.** Auto-vaulting must **not** earn interest or multiply — it only
  *moves* sats HOT→COLD. Otherwise it's a farmable income lane. COLD sats count for
  nothing except being safe + spendable-after-withdraw.
- **Balance-sim gate:** before shipping, run the build-matrix sim with a Fortress
  build to confirm the vault only protects (doesn't accelerate the win) and doesn't
  make theft irrelevant for *non*-Cold-Storage builds (it shouldn't — it's gated).
- Persist HOT/COLD split in the save (era-scoped; forks/wipe reset like the wallet).

## Decision requested

1. **Build it?** Option 1 (light, recommended) · Option 2 (full) · Option 3 (skip).
2. If built: auto-withdraw on buys (Option 1, frictionless) or manual WITHDRAW
   (Option 2, strategic)?
