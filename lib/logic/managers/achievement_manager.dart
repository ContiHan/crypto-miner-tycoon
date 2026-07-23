import '../../content/achievement_defs.dart';
import '../../core/constants.dart';

/// Tracks unlocked achievements and the "Notoriety" income bonus they grant.
///
/// Notoriety is its own lane (kept off the perk/lab power budget): each NORMAL
/// (non-secret) achievement adds a small permanent income bonus. It persists
/// across every prestige tier — like the Stash — so achievements feel permanent.
class AchievementManager {
  final Set<String> unlocked = {};

  int get unlockedCount => unlocked.length;
  int get total => kAchievements.length;

  /// Non-secret achievements unlocked (only these grant Notoriety).
  int get notorietyCount =>
      kAchievements.where((a) => !a.secret && unlocked.contains(a.id)).length;

  /// Permanent income bonus fraction from Notoriety (0.0 with none).
  double get notorietyBonus =>
      notorietyCount * GameConstants.perAchievementNotoriety;

  /// Income multiplier from Notoriety (1.0 with none).
  double get notorietyMultiplier => 1.0 + notorietyBonus;

  bool isUnlocked(String id) => unlocked.contains(id);

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
  void reset() => unlocked.clear();

  List<String> save() => unlocked.toList();

  void load(Iterable<String> ids) {
    unlocked
      ..clear()
      ..addAll(ids);
  }
}
