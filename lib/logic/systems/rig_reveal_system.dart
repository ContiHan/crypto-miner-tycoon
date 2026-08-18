import '../../core/ids.dart';
import '../../models/rig.dart';

/// Progressive rig reveal (milestone unlocks), lifted out of the GameLogic
/// god-object. You start with just the first rig; each later rig reveals when a
/// distinct MILESTONE — drawn from a different system (rigs bought, hash rate,
/// crates opened, market events, SWEEP games) — is met, measured relative to a
/// SNAPSHOT taken when the previous rig revealed. So a task can't be pre-satisfied
/// out of order and revealing one rig never cascades into the next.
///
/// Owns the reveal set, the per-target baselines, and `eventsSeen` (any market
/// event witnessed). Reads live counters (rigs, crates, spins, hash) via
/// suppliers so GameLogic stays the single source of those.
class RigRevealSystem {
  final List<Rig> Function() rigs;
  final int Function() cratesOpened;
  final int Function() casinoSpins;
  final double Function() globalHashRate;

  RigRevealSystem({
    required this.rigs,
    required this.cratesOpened,
    required this.casinoSpins,
    required this.globalHashRate,
  });

  /// Rig ids REVEALED this era (sticky until a rig-wiping reset).
  final Set<String> unlockedRigs = {};

  // Baselines snapshotted when the unlock target last advanced.
  int snapRigs = 0;
  int snapCrates = 0;
  int snapSpins = 0;
  int snapEvents = 0;
  double snapHash = 0;

  /// Lifetime count of market events witnessed (ANY chaos event) — drives the
  /// "witness any market event" milestone and ticks regardless of the open tab.
  int eventsSeen = 0;

  int _totalRigsOwned() => rigs().fold<int>(0, (a, r) => a + r.amount);

  /// Re-baseline to the current counters (after a rig reveals or a rig wipe).
  void snapshotTarget() {
    snapRigs = _totalRigsOwned();
    snapCrates = cratesOpened();
    snapSpins = casinoSpins();
    snapEvents = eventsSeen;
    snapHash = globalHashRate();
  }

  /// Clear the reveal set + re-baseline — called on any rig-wiping reset.
  void resetAndSnapshot() {
    unlockedRigs.clear();
    snapshotTarget();
  }

  /// Each rig's unlock MILESTONE, measured as progress SINCE the snapshot.
  bool conditionMet(String id) {
    switch (id) {
      case RigIds.gpuRig: // buy your first rig
        return _totalRigsOwned() >= snapRigs + 1;
      case RigIds.asicRig: // buy a few more rigs
        return _totalRigsOwned() >= snapRigs + 3;
      case RigIds.miningFarm: // double your hash rate
        return globalHashRate() >= snapHash * 2;
      case RigIds.quantumRig: // dip into the STASH
        return cratesOpened() >= snapCrates + 1;
      case RigIds.fusionRig: // witness any market event (Speed-Run reachable)
        return eventsSeen >= snapEvents + 1;
      case RigIds.photonicRig: // play the SWEEP mini-games
        return casinoSpins() >= snapSpins + 3;
      case RigIds.datacenterRig: // scale the farm up
        return _totalRigsOwned() >= snapRigs + 6;
      case RigIds.dysonRig: // quadruple your hash rate
        return globalHashRate() >= snapHash * 4;
      case RigIds.singularityRig: // a serious mining empire
        return _totalRigsOwned() >= snapRigs + 12;
      default:
        return false;
    }
  }

  /// The locked-rig teaser hint (with live progress) for the next rig.
  String hint(String id) {
    String p(int cur, int need) => ' (${cur.clamp(0, need)}/$need)';
    switch (id) {
      case RigIds.gpuRig:
        return 'Buy your first rig';
      case RigIds.asicRig:
        return 'Buy 3 more rigs${p(_totalRigsOwned() - snapRigs, 3)}';
      case RigIds.miningFarm:
        return 'Double your hash rate';
      case RigIds.quantumRig:
        return 'Open a supply crate';
      case RigIds.fusionRig:
        return 'Witness any market event';
      case RigIds.photonicRig:
        return 'Play 3 SWEEP games${p(casinoSpins() - snapSpins, 3)}';
      case RigIds.datacenterRig:
        return 'Buy 6 more rigs${p(_totalRigsOwned() - snapRigs, 6)}';
      case RigIds.dysonRig:
        return 'Quadruple your hash rate';
      case RigIds.singularityRig:
        return 'Own 12 more rigs${p(_totalRigsOwned() - snapRigs, 12)}';
      default:
        return 'Keep playing to reveal';
    }
  }

  /// Whether rig [i] is revealed. ORDERED: the first always shows; each later rig
  /// needs the previous revealed AND its milestone met. Owned/latched always show.
  bool revealed(int i) {
    final list = rigs();
    final r = list[i];
    if (r.amount > 0 || i == 0 || unlockedRigs.contains(r.id)) return true;
    if (!revealed(i - 1)) return false; // keep the reveal order
    return conditionMet(r.id);
  }

  /// Latch newly-revealed rigs and re-snapshot for the NEXT milestone (so at most
  /// one rig reveals per completed milestone — no cascade).
  void refresh() {
    final list = rigs();
    for (int i = 1; i < list.length; i++) {
      final id = list[i].id;
      if (!unlockedRigs.contains(id) && revealed(i)) {
        unlockedRigs.add(id);
        snapshotTarget();
      }
    }
  }

  /// Rigs the player should currently SEE.
  List<Rig> get visibleRigs {
    final list = rigs();
    final out = <Rig>[];
    for (int i = 0; i < list.length; i++) {
      if (revealed(i)) out.add(list[i]);
    }
    return out;
  }

  /// The next still-locked rig (a "???" teaser), or null if all revealed.
  Rig? get nextLockedRig {
    final list = rigs();
    for (int i = 0; i < list.length; i++) {
      if (!revealed(i)) return list[i];
    }
    return null;
  }
}
