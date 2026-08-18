/// THE LAST SATOSHI endgame latch. Holds the three persisted/one-shot endgame
/// fields and the win-once logic; the crediting orchestration (Mastery + Speed
/// Run + UI side effects) stays in GameLogic's `_creditLifetimeEver`, which drives
/// this via [addEver] + [tryWin].
///
/// - [lifetimeEverSats]: cosmetic cumulative-ever mined across ALL eras (survives
///   every reset; cleared only by a full Wipe Save).
/// - [hasWonGame]: persisted latch — true once a single era mines the full 21M
///   supply. Makes the win fire EXACTLY once.
/// - [pendingWinCelebration]: one-shot, NOT persisted — drained by the UI to show
///   the "GENESIS COMPLETE" ending, then cleared via [clearWin].
class EndgameSystem {
  double lifetimeEverSats = 0;
  bool hasWonGame = false;
  bool pendingWinCelebration = false;

  /// Accumulate the cumulative-ever stat (finite-clamped). Amount is assumed
  /// already validated positive+finite by the caller.
  void addEver(double amount) {
    lifetimeEverSats += amount;
    if (!lifetimeEverSats.isFinite) lifetimeEverSats = double.maxFinite;
  }

  /// The win latch: fires the FIRST time [capReached] holds (one full era's 21M
  /// supply mined). Returns true only on that first crossing — every later call
  /// is a cheap no-op, so it's safe to call every tick. On a true return the
  /// caller plays the ending; [pendingWinCelebration] is set for the UI to drain.
  bool tryWin({required bool capReached}) {
    if (hasWonGame) return false;
    if (!capReached) return false;
    hasWonGame = true;
    pendingWinCelebration = true; // drained once by the UI (not persisted)
    return true;
  }

  /// Drain the one-shot ending trigger after the UI has shown it. Returns true if
  /// it was pending (so the caller can notify), false if already drained.
  bool clearWin() {
    if (!pendingWinCelebration) return false;
    pendingWinCelebration = false;
    return true;
  }

  /// Unlocks BACK IN TIME (the post-credits replay loop) — only after the win.
  bool get speedRunUnlocked => hasWonGame;

  /// Load-time self-heal: an already-capped save is treated as won so the offline
  /// catch-up can't falsely re-fire the ending.
  void healWonIf(bool capReached) {
    if (capReached) hasWonGame = true;
  }

  /// Full Wipe Save only — the endgame spine is never cleared by any prestige.
  void reset() {
    lifetimeEverSats = 0;
    hasWonGame = false;
    pendingWinCelebration = false;
  }

  /// Restore persisted endgame state on load ([pendingWinCelebration] is never
  /// persisted — it starts false).
  void restore({required double lifetimeEverSats, required bool hasWonGame}) {
    this.lifetimeEverSats = lifetimeEverSats;
    this.hasWonGame = hasWonGame;
  }
}
