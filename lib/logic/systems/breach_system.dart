import 'dart:async';
import '../../core/constants.dart';

/// THE BREACH — a telegraphed hot-wallet theft (Phase 5). A countdown starts
/// during which the player can tap SECURE for zero loss; otherwise the wallet is
/// skimmed. The FIRST breach of a save is a 0-loss drill.
///
/// Extracted from the GameLogic god-object (mirrors AnomalySystem /
/// ChaosEventSystem): this owns the state machine + telegraph timer; GameLogic
/// supplies the callbacks that touch shared state (the loss math on the wallet,
/// the immunity/offline gate, the cue, notify + save).
class BreachSystem {
  bool pending = false;
  bool firstBreachDone = false; // the first breach of a save is a 0-loss drill
  double lastLoss = 0; // for the UI result readout
  Timer? _timer;

  final void Function() onChanged; // notifyListeners
  final void Function() onSave; // persist
  final void Function() playThreatCue; // bad-event sound + heavy haptic
  final bool Function() blocked; // offline sim OR COLD MINER immunity
  final double Function() applyLoss; // deduct wallet + fire procs, return loss

  BreachSystem({
    required this.onChanged,
    required this.onSave,
    required this.playThreatCue,
    required this.blocked,
    required this.applyLoss,
  });

  /// Starts a telegraphed breach: a countdown during which SECURE vaults the
  /// wallet. Only one at a time; never while blocked (offline / immune).
  void startThreat() {
    if (pending || blocked()) return;
    pending = true;
    playThreatCue();
    onChanged();
    _timer?.cancel();
    _timer = Timer(
      const Duration(seconds: GameConstants.breachTelegraphSeconds),
      () => resolve(secured: false),
    );
  }

  /// Resolves a pending breach. [secured] (SECURE tapped) = 0 loss. The first
  /// breach is a 0-loss drill; otherwise [applyLoss] steals the hot wallet only.
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

  // ---- persistence: only the drill-spent flag is saved ----
  void loadFrom(bool spent) => firstBreachDone = spent;

  /// Full wipe: fresh save → the next breach is a drill again.
  void reset() {
    stop();
    firstBreachDone = false;
    lastLoss = 0;
  }
}
