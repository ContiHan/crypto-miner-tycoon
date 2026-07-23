import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../content/achievement_defs.dart';
import '../providers/game_logic.dart';
import '../theme/app_theme.dart';
import '../widgets/stylized_card.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  static const Map<AchCategory, Color> _categoryColor = {
    AchCategory.earnings: AppTheme.accent,
    AchCategory.rigs: Colors.cyanAccent,
    AchCategory.tech: Colors.lightBlueAccent,
    AchCategory.prestige: Colors.redAccent,
    AchCategory.collection: Colors.purpleAccent,
    AchCategory.meta: Colors.amberAccent,
    AchCategory.secret: Colors.pinkAccent,
  };

  @override
  Widget build(BuildContext context) {
    return Consumer<GameLogic>(
      builder: (context, game, child) {
        final total = game.achievementsTotal;
        final unlocked = game.achievementsUnlocked;
        final pct = total == 0 ? 0.0 : unlocked / total;

        return Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              color: AppTheme.surface,
              width: double.infinity,
              child: Column(
                children: [
                  const Icon(Icons.emoji_events, size: 36, color: AppTheme.accent),
                  const SizedBox(height: 4),
                  const Text(
                    'ACHIEVEMENTS',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accent,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$unlocked / $total  (${(pct * 100).toStringAsFixed(0)}%)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 8,
                      backgroundColor: Colors.black45,
                      color: AppTheme.accent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'NOTORIETY: +${(game.notorietyBonus * 100).toStringAsFixed(0)}% income',
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: game.achievements.length,
                itemBuilder: (context, i) {
                  final a = game.achievements[i];
                  return _AchievementCard(
                    achievement: a,
                    unlocked: game.isAchievementUnlocked(a.id),
                    color: _categoryColor[a.category] ?? AppTheme.accent,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final Achievement achievement;
  final bool unlocked;
  final Color color;

  const _AchievementCard({
    required this.achievement,
    required this.unlocked,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // A locked secret achievement is fully hidden ("???"); a locked normal one
    // shows its goal so the player has something to chase.
    final bool hideDetails = !unlocked && achievement.secret;
    final String title = hideDetails ? '???' : achievement.title;
    final String desc = hideDetails
        ? 'Secret achievement — discover it by playing.'
        : achievement.description;

    return StylizedCard(
      color: unlocked
          ? color.withValues(alpha: 0.12)
          : Colors.black26,
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: unlocked ? color.withValues(alpha: 0.20) : Colors.white10,
                border: Border.all(
                  color: unlocked ? color : Colors.white24,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                unlocked
                    ? Icons.emoji_events
                    : (achievement.secret ? Icons.help_outline : Icons.lock_outline),
                color: unlocked ? color : Colors.white38,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: unlocked ? color : Colors.white54,
                      letterSpacing: hideDetails ? 3 : 0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    desc,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (unlocked)
              Icon(Icons.check_circle, color: color, size: 22)
            else if (!achievement.secret)
              const Icon(Icons.circle_outlined, color: Colors.white24, size: 22),
          ],
        ),
      ),
    );
  }
}
