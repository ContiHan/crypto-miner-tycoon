import 'dart:async';
import 'dart:math';
import '../../core/constants.dart';

/// Breach severity tiers (docs §E). DUST is frequent + tiny; BREACH is normal;
/// the rare 51% ATTACK steals more and leaves a brief market dip.
enum BreachTier { dust, breach, fiftyOne }

extension BreachTierInfo on BreachTier {
  String get label {
    switch (this) {
      case BreachTier.dust:
        return 'DUST ATTACK';
      case BreachTier.breach:
        return 'SECURITY BREACH';
      case BreachTier.fiftyOne:
        return '51% ATTACK';
    }
  }

  /// Multiplier on breachBaseLoss for this tier.
  double get lossMult {
    switch (this) {
      case BreachTier.dust:
        return GameConstants.breachTierDustMult;
      case BreachTier.breach:
        return GameConstants.breachTierNormalMult;
      case BreachTier.fiftyOne:
        return GameConstants.breachTier51Mult;
    }
  }
}

/// THE BREACH — a telegraphed hot-wallet theft (Phase 5). A countdown starts
/// during which the player can tap SECURE for zero loss; otherwise the wallet is
/// skimmed. The FIRST breach of a save is a 0-loss drill. Severity is tiered, the
/// telegraph lengthens with Cold Storage, and breaches obey a frequency floor.
///
/// Extracted from the GameLogic god-object (mirrors AnomalySystem /
/// ChaosEventSystem): this owns the state machine + telegraph timer; GameLogic
/// supplies the callbacks that touch shared state.
class BreachSystem {
  bool pending = false;
  bool firstBreachDone = false; // the first breach of a save is a 0-loss drill
  double lastLoss = 0; // for the UI result readout
  BreachTier tier = BreachTier.breach; // severity of the CURRENT/last threat
  Timer? _timer;
  int _telegraphEndMs = 0; // wall-clock end of the SECURE window (for the countdown)
  int _lastStartMs = 0; // frequency-floor gate
  final Random _rng;

  final void Function() onChanged; // notifyListeners
  final void Function() onSave; // persist
  final void Function() playThreatCue; // bad-event sound + heavy haptic
  final bool Function() blocked; // offline sim OR COLD MINER immunity
  final double Function() applyLoss; // deduct wallet + fire procs, return loss
  final int Function() nowMs; // wall clock
  final int Function() extraTelegraphSeconds; // Cold-Storage bonus window

  BreachSystem({
    required this.onChanged,
    required this.onSave,
    required this.playThreatCue,
    required this.blocked,
    required this.applyLoss,
    required this.nowMs,
    required this.extraTelegraphSeconds,
    Random? rng,
  }) : _rng = rng ?? Random();

  BreachTier _rollTier() {
    var r = _rng.nextInt(GameConstants.breachTierDustWeight +
        GameConstants.breachTierNormalWeight +
        GameConstants.breachTier51Weight);
    if (r < GameConstants.breachTierDustWeight) return BreachTier.dust;
    r -= GameConstants.breachTierDustWeight;
    if (r < GameConstants.breachTierNormalWeight) return BreachTier.breach;
    return BreachTier.fiftyOne;
  }

  /// Seconds left in the SECURE window (0 when none pending / already up).
  int secondsRemaining() {
    if (!pending) return 0;
    final left = ((_telegraphEndMs - nowMs()) / 1000).ceil();
    return left < 0 ? 0 : left;
  }

  /// Starts a telegraphed breach. Only one at a time; never while blocked
  /// (offline / immune) or within the frequency floor of the previous one. The
  /// tier is rolled up front so the telegraph can show its severity; the SECURE
  /// window lengthens with Cold Storage.
  void startThreat() {
    if (pending || blocked()) return;
    final now = nowMs();
    if (_lastStartMs != 0 && now - _lastStartMs < GameConstants.breachMinGapMs) {
      return; // frequency floor
    }
    _lastStartMs = now;
    pending = true;
    tier = _rollTier();
    final seconds = GameConstants.breachTelegraphSeconds + extraTelegraphSeconds();
    _telegraphEndMs = now + seconds * 1000;
    playThreatCue();
    onChanged();
    _timer?.cancel();
    _timer = Timer(Duration(seconds: seconds), () => resolve(secured: false));
  }

  /// Resolves a pending breach. [secured] (SECURE tapped) = 0 loss. The first
  /// breach is a 0-loss drill; otherwise [applyLoss] steals the hot wallet only
  /// (scaled by the tier via [BreachTier.lossMult], applied in the callback).
  void resolve({required bool secured}) {
    _timer?.cancel();
    _timer = null;
    if (!pending) return;
    pending = false;
    double loss = 0;
    if (!secured && firstBreachDone) loss = applyLoss();
    firstBreachDone = true; // the drill is spent (or a real breach happened)
    lastLoss = loss;
    onChanged();
    onSave();
  }

  /// Player tapped SECURE within the telegraph window — 0 loss.
  void secure() => resolve(secured: true);

  /// Cancel any in-flight telegraph (app pause / dispose) without resolving.
  void stop() {
    _timer?.cancel();
    _timer = null;
    pending = false;
  }

  /// Clears the frequency-floor gate so the next [startThreat] fires immediately
  /// (test seam / used by the debug breach trigger).
  void clearFrequencyFloor() => _lastStartMs = 0;

  // ---- persistence: only the drill-spent flag is saved ----
  void loadFrom(bool spent) => firstBreachDone = spent;

  /// Full wipe: fresh save → the next breach is a drill again.
  void reset() {
    stop();
    firstBreachDone = false;
    lastLoss = 0;
    _lastStartMs = 0;
  }
}
