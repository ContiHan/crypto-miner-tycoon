import 'dart:math' as math;

/// Named multiplier channels for the economy.
///
/// The core rule (from the content plan): bonuses are ADDITIVE within a channel
/// and MULTIPLICATIVE across channels. That is what lets hundreds of upgrades
/// stack without exploding — a channel summing to +900% is a single ×10 factor,
/// not `1.08^100 ≈ 400000×`. A small, hard-counted set of true multiplicative
/// effects (future Legendary/Mythic items) can be applied on top as separate
/// factors.
enum Channel {
  hash, // global hash-rate bonus
  click, // manual click power bonus
  income, // flat income/sat bonus
  rigCost, // rig cost reduction (additive discount)
  prestige, // prestige/GovToken income bonus
  luck, // crit chance, SWEEP UTXO winnings (capped), crate/anomaly odds
  volatility, // chaos event frequency/severity (wired in a later phase)
  offline, // offline-earning fraction (base 0.70, hard cap 1.0 = live parity)
  special, // crit PAYOUT only (BLOCK REWARD attribute): critMult = 5 + 5·softcap(Σspecial)
  fortune, // crate drop-quality: chance to bump a roll up one rarity (cap 0.25)
  // Luck facets (decoupled from `luck`): each combines with shared `luck` at its
  // own consumption site, so a build can specialise one facet.
  nonce, // NONCE PRECISION — crit CHANCE luck (cap 25%)
  sweepLuck, // WHALE'S FAVOR — SWEEP payout luck (EV cap 2.5, net cap immutable)
  magnetism, // UTXO MAGNETISM — anomaly spawn luck (cap 30%/tick)
  idle, // IDLE CAPACITY — offline duration window (base 8h, cap 24h)
  // Resistances (Phase 2). Each R in [0, per-lever cap]; combined per event type
  // is clamped to 0.70 so an event always lands >= 30%.
  crashResist, // DIAMOND HANDS — market-crash magnitude (cap 0.70)
  costResist, // FEE HEDGE — cost-spike surcharge (cap 0.70)
  halvingResist, // STOCK-TO-FLOW — halving income cut (cap 0.60, never cancels)
  durationResist, // STEEL NERVES — crash/cost-spike DURATION only (cap 0.60)
  theftResist, // COLD STORAGE — breach loss (cap 0.70; theft lands in Phase 5)
  haste, // RIG COOLING — ability cooldown reduction (cap 0.40)
  bullBias, // BULL BIAS — tilt chaos toward positives (never zeroes negatives)
  overcharge, // OVERCHARGE — +ability buff MAGNITUDE & grant-seconds (cap 0.50)
  doubleDrop, // DOUBLE-DROP — chance a crate open yields a SECOND crate (cap 0.25)
}

/// Accumulates additive percentage bonuses per [Channel].
///
/// `add(Channel.hash, 0.05)` means "+5% hash". [multiplier] turns the summed
/// bonus into a `1 + sum` factor, optionally soft-capped.
class Channels {
  final Map<Channel, double> _sum = {};

  /// Adds [fraction] (e.g. 0.05 for +5%) to a channel. No-op for 0.
  void add(Channel channel, double fraction) {
    if (fraction == 0) return;
    _sum[channel] = (_sum[channel] ?? 0) + fraction;
  }

  /// Raw additive total for a channel (0.5 == +50%).
  double sum(Channel channel) => _sum[channel] ?? 0;

  /// The channel's multiplier: `1 + sum`, optionally soft-capped past
  /// [softStart] using [power] so a maxed channel decelerates rather than
  /// dominating the economy.
  double multiplier(
    Channel channel, {
    double softStart = double.infinity,
    double power = 0.5,
  }) {
    // Floor `1+sum` at a small positive epsilon BEFORE softcap: a future stack
    // of additive DEBUFFS (class/keystone/aura costs) could drive the sum below
    // -1, which would otherwise yield a negative multiplier (negative income /
    // hash / click) or a zero volatility factor (÷0 in chaos scheduling). A
    // channel can legitimately go below 1 (a debuff), just never <= 0.
    final raw = 1 + sum(channel);
    return softcap(raw < _channelFloor ? _channelFloor : raw, softStart, power);
  }

  /// Smallest a channel multiplier may reach — never negative or zero.
  static const double _channelFloor = 0.01;
}

/// Diminishing-returns softcap: identity below [start], then
/// `start * (value / start)^power` above it. Used to tame any single stat that
/// would otherwise outrun the model. Non-finite inputs are returned unchanged.
double softcap(double value, double start, double power) {
  if (!value.isFinite || start <= 0 || value <= start) return value;
  return start * math.pow(value / start, power).toDouble();
}
