/// Progressive disclosure for the four gated bottom-nav tabs (TECH / STASH /
/// SKILL / GOAL — MINE is always available). Owns the four sticky reveal flags
/// and the pending-toast queue; the reveal thresholds read live GameLogic state
/// through suppliers, and the reveal cue / save / notify are injected.
///
/// STICKY: once a tab unlocks it stays unlocked forever (a New Blockchain wiping
/// rigs must not re-lock TECH). Only a full Wipe Save re-locks them (via [reset]).
class TabUnlockSystem {
  TabUnlockSystem({
    required this.lifetimeEarnings,
    required this.chips,
    required this.cratesOpened,
    required this.hardForkCount,
    required this.achievementsUnlocked,
    required this.onUnlockSound,
    required this.save,
    required this.notify,
  });

  final double Function() lifetimeEarnings;
  final int Function() chips;
  final int Function() cratesOpened;
  final int Function() hardForkCount;
  final int Function() achievementsUnlocked;
  final void Function() onUnlockSound;
  final void Function() save;
  final void Function() notify;

  bool tech = false; // after 10k sats mined
  bool stash = false; // after 1M sats / a chip / a crate
  bool skill = false; // after the first Hard Fork (first GovTokens)
  bool goal = false; // after the first achievement is earned

  /// Tab names newly unlocked this session, drained by the UI for a toast.
  final List<String> pendingToasts = [];
  void clearToasts() => pendingToasts.clear();

  /// Reveal tabs as the player progresses (sticky — never re-locks).
  /// [silent] sets the flags without queuing a toast (used on load so returning
  /// players / newly-added gates don't spam notifications). Conditions are
  /// deliberately gentle so content unfolds instead of arriving all at once:
  ///   TECH  after 10k sats mined (a bit of play, not the very first rig);
  ///   STASH after 1M sats / a chip / a crate;
  ///   SKILL after the first Hard Fork (when GovTokens first exist to spend).
  void refresh({bool silent = false, bool suppressSound = false}) {
    final newly = <String>[];
    var changed = false;
    if (!tech && lifetimeEarnings() >= 10000) {
      tech = true;
      changed = true;
      newly.add('TECH');
    }
    if (!stash &&
        (lifetimeEarnings() >= 1e6 || chips() >= 1 || cratesOpened() >= 1)) {
      stash = true;
      changed = true;
      newly.add('STASH');
    }
    if (!skill && hardForkCount() >= 1) {
      skill = true;
      changed = true;
      newly.add('SKILL');
    }
    if (!goal && achievementsUnlocked() >= 1) {
      goal = true;
      changed = true;
      newly.add('GOAL');
    }
    if (!changed) return;
    if (!silent) {
      pendingToasts.addAll(newly);
      if (!suppressSound) onUnlockSound();
      save();
      notify();
    }
  }

  /// Debug/test seam: reveal every tab at once (no toast/sound).
  void unlockAll() {
    tech = stash = skill = goal = true;
  }

  /// Full Wipe Save: re-lock everything (fresh-start feel).
  void reset() {
    tech = stash = skill = goal = false;
    pendingToasts.clear();
  }

  /// Restore the persisted flags on load.
  void restore({
    required bool tech,
    required bool stash,
    required bool skill,
    required bool goal,
  }) {
    this.tech = tech;
    this.stash = stash;
    this.skill = skill;
    this.goal = goal;
  }
}
