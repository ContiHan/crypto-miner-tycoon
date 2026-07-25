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
  special, // catch-all / utility
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
    return softcap(1 + sum(channel), softStart, power);
  }
}

/// Diminishing-returns softcap: identity below [start], then
/// `start * (value / start)^power` above it. Used to tame any single stat that
/// would otherwise outrun the model. Non-finite inputs are returned unchanged.
double softcap(double value, double start, double power) {
  if (!value.isFinite || start <= 0 || value <= start) return value;
  return start * math.pow(value / start, power).toDouble();
}
