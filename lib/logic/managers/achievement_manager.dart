import '../../content/achievement_defs.dart';
import '../../core/constants.dart';

/// Tracks unlocked achievements and the "Notoriety" income bonus they grant.
///
/// Notoriety is its own lane (kept off the perk/lab power budget): each NORMAL
/// (non-secret) achievement adds a small permanent income bonus. It persists
/// across every prestige tier — like the Stash — so achievements feel permanent.
class AchievementManager {
  final Set<String> unlocked = {}; // condition met (shows in GOALS, toasts)
  final Set<String> claimed = {}; // collected by the player — grants Notoriety

  int get unlockedCount => unlocked.length;
  int get total => kAchievements.length;

  /// Unlocked-but-not-yet-claimed count (drives the GOALS badge + CLAIM ALL).
  int get unclaimedCount => unlocked.where((id) => !claimed.contains(id)).length;

  /// Non-secret CLAIMED achievements — only these grant Notoriety (the reward is
  /// gated on the player actively claiming it).
  int get notorietyCount =>
      kAchievements.where((a) => !a.secret && claimed.contains(a.id)).length;

  /// Permanent income bonus fraction from Notoriety (0.0 with none claimed).
  double get notorietyBonus =>
      notorietyCount * GameConstants.perAchievementNotoriety;

  /// Income multiplier from Notoriety (1.0 with none).
  double get notorietyMultiplier => 1.0 + notorietyBonus;

  bool isUnlocked(String id) => unlocked.contains(id);
  bool isClaimed(String id) => claimed.contains(id);
  bool isClaimable(String id) =>
      unlocked.contains(id) && !claimed.contains(id);

  /// Claim an unlocked achievement (idempotent). Returns true if it moved to
  /// claimed (activating its Notoriety).
  bool claim(String id) {
    if (unlocked.contains(id) && !claimed.contains(id)) {
      claimed.add(id);
      return true;
    }
    return false;
  }

  /// Claim every currently-claimable achievement (CLAIM ALL). Returns the count.
  int claimAll() {
    final before = claimed.length;
    claimed.addAll(unlocked);
    return claimed.length - before;
  }

  /// Unlock every not-yet-unlocked achievement whose condition now holds.
  /// Returns the ones newly unlocked (for toast notifications).
  List<Achievement> evaluate(AchStats stats) {
    final newly = <Achievement>[];
    for (final a in kAchievements) {
      if (unlocked.contains(a.id)) continue;
      if (a.condition(stats)) {
        unlocked.add(a.id);
        newly.add(a);
      }
    }
    return newly;
  }

  /// Only a full wipe (Wipe Save) clears achievements — prestige never does.
  void reset() {
    unlocked.clear();
    claimed.clear();
  }

  List<String> save() => unlocked.toList();
  List<String> saveClaimed() => claimed.toList();

  void load(Iterable<String> ids) {
    unlocked
      ..clear()
      ..addAll(ids);
  }

  void loadClaimed(Iterable<String> ids) {
    claimed
      ..clear()
      ..addAll(ids);
  }

  /// Migration for pre-claim saves: everything already unlocked counts as
  /// claimed so no Notoriety income is retroactively lost.
  void claimAllUnlockedForMigration() => claimed.addAll(unlocked);
}
