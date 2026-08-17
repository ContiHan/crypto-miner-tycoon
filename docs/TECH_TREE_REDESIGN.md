# TECH tree redesign — "lean, not a combination" (device finding #5)

> **STATUS: DESIGN NOTE — awaiting owner approval before any code.** Owner asked
> for this design-first (it's a big structural change and the render pane is down
> this session, so it can't be visually verified here). Pick a direction below and
> I'll implement + test it.

## The owner's finding (2026-08-17, phone)

> "The TECH tree is too wide, and the lock + doctrines don't sit well with the
> character of the bonuses. It should connect and flow better — so it isn't a
> *combination*, but more a *lean toward a few attributes*."

Three distinct complaints:

1. **Too wide.** The graph lays nodes out by prerequisite depth (row = depth) and
   spreads all siblings at that depth horizontally, so the canvas width grows with
   the *widest* depth bucket. With 6 doctrines fanning out, the middle rows are
   very wide and you pan sideways a lot.
2. **Locks/doctrines feel disconnected from the bonuses.** The exclusive doctrine
   pairs (MEGA-HASH⟂LEAN-RIG, HODLER⟂DEGEN-YIELD, DEGEN-LUCK⟂COLD-STORAGE) are a
   rule bolted on *top* of the tree; which nodes belong to which doctrine isn't
   visually obvious, so committing one and locking its sibling feels arbitrary.
3. **"A combination, not a lean."** Because affordable nodes are scattered across
   the width, players buy a shallow mix of everything instead of committing hard
   to a couple of attributes. The build reads as a grab-bag, not a specialization.

## What the tree is today (as-built)

- ~40+ research nodes. **TRUNK** (shared on-ramp, ~9 nodes) → **META spur** (AI
  Manager, Firmware Bay) → six **doctrines**, each a themed cluster:
  - MEGA-HASH (9 nodes, hash) ⟂ LEAN-RIG (7, rig-cost/idle)
  - HODLER (4, prestige/offline) ⟂ DEGEN-YIELD (6, income/volatility)
  - DEGEN-LUCK (5, crit/nonce/fortune) ⟂ COLD-STORAGE (6, resistances/offline)
- Commitment budget = 2 pairs; committing a doctrine locks its sibling for the run;
  keystones live at each doctrine's capstone.
- Layout: memoized depth (longest prereq chain) → row; siblings centred per row →
  wide canvas; elbow edges.

So the *data* already leans (doctrines are coherent attribute clusters). The
problem is the **layout and the legibility of the lock**, not the content.

## The direction I recommend — DOCTRINE LANES (vertical columns)

Give every doctrine its **own vertical lane** (a fixed X column) and let its nodes
flow straight **down** that lane, deepening the *same* attributes as you go. TRUNK
is a short shared stem at the top; the six lanes drop out of it; the sibling of a
committed doctrine greys its **whole lane**.

Why it answers all three complaints:

- **Narrower.** Width becomes `#lanes × laneGap` (fixed, ~6 columns), not "widest
  depth bucket." You scroll *down* a lane, not sideways across everything.
- **The lock becomes obvious.** A doctrine is now a visible column with a header
  chip (e.g. "MEGA-HASH — hash"). Committing lights the whole column; its paired
  sibling column visibly greys with a chain icon. The exclusivity reads as
  "pick a lane," which is exactly the mental model.
- **Leaning is the default.** Progress within a lane escalates the same 1–2
  attributes (hash → hash → hash), so going deep = a real specialization. Buying
  across lanes is possible but visibly costs you your commitment budget.

Sketch:

```
                 ┌─ TRUNK (shared stem) ─┐
                 │  basic → chip → …     │
     ┌───────┬───────┬────┴───┬───────┬───────┬────────┐
   MEGA-HASH LEAN-RIG HODLER DEGEN-Y DEGEN-L COLD-STOR   ← doctrine headers
     hash    cost    prestige income  crit   resist
      │        │        │       │       │       │
      ▼        ▼        ▼       ▼       ▼       ▼         ← nodes deepen the
      │        │        │       │       │       │           same attributes
    keystone keystone  …       …       …       …         ← capstone keystone
   (MEGA-HASH ⟂ LEAN-RIG greyed if you commit the other)
```

Paired siblings sit **adjacent** (MEGA-HASH next to LEAN-RIG, etc.) so the "one or
the other" is spatially clear.

## Alternatives (if you'd rather)

- **B — Keep the graph, just fix width + lock legibility (smaller change).** Tint
  each node by its doctrine colour, draw a faint labelled band behind each
  doctrine's nodes, and compress the layout (tighter gaps / collapse fully-owned
  TRUNK). Cheapest; addresses "wide" + "lock unclear" but not really "lean vs
  combination."
- **C — Collapsible doctrines.** Show the six doctrines collapsed as six big
  buttons; tap one to expand its chain inline. Very compact, very clearly "pick a
  lane," but it's a bigger UI build and loses the at-a-glance whole-tree view.

## What I'd change in code (for the recommended lanes option)

- `research_defs`: add/confirm a stable **lane order** for doctrines and a
  per-node lane (already have `_doctrineOf`); optionally a within-lane `tier` so
  nodes stack cleanly even with uneven depths.
- `research_tab._graph`: replace depth-bucket X placement with **lane X = doctrine
  index**, **Y = within-lane tier**; TRUNK as a centred stem above the lanes; add
  per-lane header chips; grey a locked sibling's entire lane.
- No economy/balance change — same nodes, same costs, same doctrine rules; this is
  layout + legibility only. Existing tests (doctrine locks, presets, blueprints,
  respec) stay green.

## Open questions for the owner

1. **Direction:** LANES (recommended), B (light touch), or C (collapsible)?
2. Should TRUNK stay a shared stem, or also become its own left-most lane?
3. Do you want the **attribute each lane leans into** printed on its header
   (e.g. "MEGA-HASH · +hash"), for the "lean" to be explicit? (I recommend yes.)
