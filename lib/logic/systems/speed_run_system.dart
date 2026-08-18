import '../../core/constants.dart';

/// Back-in-Time "Speed Run" state + record-keeping, lifted out of the GameLogic
/// god-object. Owns ONLY the run's data and the pure record logic (accumulate
/// mined sats, detect completion, update best + per-class best). The ORCHESTRATION
/// — the deep New-Genesis reset on start and the achievements/sound/save/notify on
/// finish — stays in GameLogic, which coordinates via [begin]/[credit]/[abort].
///
/// The clock is WALL-CLOCK (a persisted start timestamp) so backgrounding the app
/// can't pause or cheat it; GameLogic supplies [nowMs].
class SpeedRunSystem {
  final int Function() nowMs;
  SpeedRunSystem({required this.nowMs});

  bool active = false;
  int startMs = 0;
  double minedSats = 0; // sats mined since the current run started
  int bestMs = 0; // best completed time in ms (0 = no record yet)
  int lastMs = 0; // most recent completed time (for the overlay)
  // Best time per class NAME (per-class records + THE TIMECHAIN capstone).
  Map<String, int> bestByClass = {};
  // Transient (NOT persisted): drives the one-shot SPEED RUN COMPLETE overlay.
  bool pendingCelebration = false;
  bool wasRecord = false;

  /// Fraction (0..1) of one full 21M-BTC supply mined this run.
  double get progress =>
      (minedSats / GameConstants.maxSupplySats).clamp(0.0, 1.0);

  /// Live elapsed milliseconds of the active run (0 when none is running).
  int get elapsedMs {
    if (!active) return 0;
    final e = nowMs() - startMs;
    return e < 0 ? 0 : e;
  }

  /// Distinct classes with a recorded best, excluding [prospectorKey].
  int classCount(String prospectorKey) =>
      bestByClass.keys.where((k) => k != prospectorKey).length;

  int bestForClass(String className) => bestByClass[className] ?? 0;

  /// Start recording a run (the caller performs the deep reset separately).
  void begin() {
    active = true;
    startMs = nowMs();
    minedSats = 0;
    pendingCelebration = false;
    wasRecord = false;
  }

  /// Credit mined sats to an active run. Returns true when this credit COMPLETES
  /// the run (one full supply) — the run is recorded (time, best, per-class best,
  /// celebration flag) and the caller then fires the finish side-effects.
  bool credit(double amount, String classKey) {
    if (!active) return false;
    minedSats += amount;
    if (minedSats < GameConstants.maxSupplySats) return false;
    final elapsed = nowMs() - startMs;
    active = false;
    lastMs = elapsed < 0 ? 0 : elapsed;
    wasRecord = bestMs == 0 || lastMs < bestMs;
    if (wasRecord) bestMs = lastMs;
    final classBest = bestByClass[classKey];
    if (classBest == null || lastMs < classBest) bestByClass[classKey] = lastMs;
    pendingCelebration = true;
    return true;
  }

  /// Abandon the active run without recording a time.
  void abort() {
    active = false;
    minedSats = 0;
  }

  /// Drain the one-shot celebration trigger; returns true if it was set.
  bool clearCelebration() {
    if (!pendingCelebration) return false;
    pendingCelebration = false;
    return true;
  }
}
