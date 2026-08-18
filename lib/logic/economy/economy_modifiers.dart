import '../channels.dart';
import '../systems/keystone_system.dart';
import '../../core/constants.dart';

/// Pure derived economy modifiers over the channel economy + committed keystones.
///
/// Every value here is a pure function of `buildChannels()` + `keystoneMods`
/// (no wallet / rig / class / ability / time state), so GameLogic supplies both
/// via [channels] / [keystones] suppliers and forwards each getter through a thin
/// proxy — the public API and all callers are unchanged.
///
/// Deliberately NOT here (they are not pure over channels+keystones, so they stay
/// in GameLogic): the ability-coupled luck FACETS (`_combinedLuck` / crit / sweep
/// / anomaly luck, which read the AbilitySystem + foreground clock), and
/// `upkeepRate` (reads the owned rig fleet, the current class, and the live chaos
/// cost multiplier).
class EconomyModifiers {
  EconomyModifiers({required this.channels, required this.keystones});

  final Channels Function() channels;
  final KeystoneModifiers Function() keystones;

  /// Aggregate (shared) Luck factor (>=1, softcapped). Kept for the STASH readout;
  /// the three effect sites use the decoupled facet getters (in GameLogic).
  double get luckMultiplier =>
      channels().multiplier(Channel.luck, softStart: 1.5, power: 0.5);

  /// IDLE CAPACITY — the offline-accrual WINDOW in seconds. Base 8h + `idle`
  /// sources (in hours), hard-capped at 24h (#16). COLD-WALLET DISCIPLINE ×2 (or
  /// Sweat Equity ×0.5) scales the window, but the 24h FINAL cap still binds.
  double get idleCapacitySeconds {
    final hours = ((GameConstants.offlineWindowBaseHours +
                channels().sum(Channel.idle)) *
            keystones().idleMult)
        .clamp(0.0, GameConstants.offlineWindowMaxHours);
    return hours * 3600.0;
  }

  // --- Resistances (Phase 2) ---------------------------------------------
  // Each resistance is a `[0, per-lever cap]` value summed from its channel, then
  // scaled by any keystone resist lever (FORT KNOX ×1.3 toward the cap / MARKET
  // MAKER ×0.5), still clamped to its per-lever cap so the ≤0.70 rail holds.
  double _resist(Channel ch, double cap) =>
      (channels().sum(ch) * keystones().resistMult).clamp(0.0, cap);
  double get crashResistance =>
      _resist(Channel.crashResist, GameConstants.resistCapMagnitude);
  double get costResistance =>
      _resist(Channel.costResist, GameConstants.resistCapMagnitude);
  double get halvingResistance =>
      _resist(Channel.halvingResist, GameConstants.resistCapHalving);
  double get durationResistance =>
      _resist(Channel.durationResist, GameConstants.resistCapDuration);
  double get theftResistance =>
      _resist(Channel.theftResist, GameConstants.resistCapMagnitude);

  /// Aggregate Volatility factor (1.0 with no sources) — scales chaos-event
  /// frequency. Sources arrive with classes (Pool lowers it, others raise it).
  double get volatilityMultiplier =>
      channels().multiplier(Channel.volatility, softStart: 1.5, power: 0.5);

  /// BULL BIAS attribute — tilts chaos-event selection toward positives (never
  /// zeroes negatives). Summed from Channel.bullBias, capped.
  double get bullBiasStrength =>
      channels().sum(Channel.bullBias).clamp(0.0, GameConstants.bullBiasCap);

  /// OVERCHARGE attribute — scales active ability BUFF magnitude and grant-seconds
  /// (NOT durations/cooldowns). 1.0 with no sources; +overchargeCap (0.50) at most.
  double get overchargeFactor =>
      1.0 +
      channels()
          .sum(Channel.overcharge)
          .clamp(0.0, GameConstants.overchargeCap);

  /// OFFLINE YIELD fraction: the share of the live per-second rate earned while
  /// the app is closed. Base 0.70 + additive `offline` sources (TECH/class/etc.),
  /// hard-capped at 1.0 so offline can never out-earn active play. LOW TIME
  /// PREFERENCE / COLD-WALLET DISCIPLINE force full offline parity.
  double get offlineFraction {
    if (keystones().offlineForceParity) return GameConstants.offlineFractionCap;
    return (GameConstants.offlineBaseFraction + channels().sum(Channel.offline))
        .clamp(0.0, GameConstants.offlineFractionCap);
  }

  /// BLOCK REWARD: the crit PAYOUT multiplier. Base 5x, raised (concavely) by the
  /// `special` channel and hard-capped at critPayoutMax so stacked crit-power can
  /// never produce an absurd per-tap payout (#11). LASER EYES ×2.
  double get critPayoutMultiplier => ((GameConstants.clickCritMultiplier +
              GameConstants.clickCritPayoutSpecialScale *
                  softcap(channels().sum(Channel.special), 1.0, 0.5)) *
          keystones().critPayoutMult)
      .clamp(0.0, GameConstants.critPayoutMax);

  /// PROSPECTOR'S EYE: the per-crate-roll chance to bump the rolled rarity up one
  /// step. Additive `fortune` sources, hard-capped at fortuneMaxTierShiftChance
  /// (#22) so loot can never be dominated (and never a guaranteed top rarity).
  double get fortuneBonus => channels()
      .sum(Channel.fortune)
      .clamp(0.0, GameConstants.fortuneMaxTierShiftChance);
}
