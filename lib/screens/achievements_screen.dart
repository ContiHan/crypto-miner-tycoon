import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../content/achievement_defs.dart';
import '../providers/game_logic.dart';
import '../theme/app_theme.dart';
import '../widgets/stylized_card.dart';
import '../widgets/pulse_button.dart';

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
        final unclaimed = game.unclaimedAchievements;

        // Order: claimable first (call to action), then claimed, then locked —
        // each group preserves catalogue order (stable).
        final claimable = <Achievement>[];
        final claimed = <Achievement>[];
        final locked = <Achievement>[];
        for (final a in game.achievements) {
          if (game.isAchievementClaimable(a.id)) {
            claimable.add(a);
          } else if (game.isAchievementClaimed(a.id)) {
            claimed.add(a);
          } else {
            locked.add(a);
          }
        }
        final ordered = [...claimable, ...claimed, ...locked];

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
                  if (unclaimed > 0) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: PulseButton(
                        animate: true,
                        onPressed: () => game.claimAllAchievements(),
                        child: Text('CLAIM ALL  ($unclaimed)'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: ordered.length,
                itemBuilder: (context, i) {
                  final a = ordered[i];
                  return _AchievementCard(
                    achievement: a,
                    claimable: game.isAchievementClaimable(a.id),
                    claimed: game.isAchievementClaimed(a.id),
                    color: _categoryColor[a.category] ?? AppTheme.accent,
                    onClaim: () => game.claimAchievement(a.id),
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
  final bool claimable;
  final bool claimed;
  final Color color;
  final VoidCallback onClaim;

  const _AchievementCard({
    required this.achievement,
    required this.claimable,
    required this.claimed,
    required this.color,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final unlocked = claimable || claimed;
    // Locked secret is fully hidden ("???"); locked normal shows its goal.
    final bool hideDetails = !unlocked && achievement.secret;
    final String title = hideDetails ? '???' : achievement.title;
    final String desc = hideDetails
        ? 'Secret achievement — discover it by playing.'
        : achievement.description;

    return StylizedCard(
      color: claimable
          ? color.withValues(alpha: 0.20)
          : (claimed ? color.withValues(alpha: 0.10) : Colors.black26),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: claimable
              ? Border.all(color: color, width: 2)
              : Border.all(color: Colors.transparent, width: 2),
        ),
        padding: const EdgeInsets.all(10.0),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: unlocked ? color.withValues(alpha: 0.20) : Colors.white10,
                border: Border.all(color: unlocked ? color : Colors.white24),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                unlocked
                    ? Icons.emoji_events
                    : (achievement.secret
                        ? Icons.help_outline
                        : Icons.lock_outline),
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
            const SizedBox(width: 8),
            // Trailing swaps between CLAIM -> checkmark with a scale pop.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (c, anim) =>
                  ScaleTransition(scale: anim, child: c),
              child: _trailing(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _trailing() {
    if (claimable) {
      return ElevatedButton(
        key: const ValueKey('claim'),
        onPressed: onClaim,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        child: Text(achievement.secret ? 'CLAIM' : 'CLAIM\n+1%',
            textAlign: TextAlign.center),
      );
    }
    if (claimed) {
      return Icon(Icons.check_circle, key: const ValueKey('done'), color: color, size: 24);
    }
    if (!achievement.secret) {
      return const Icon(Icons.circle_outlined,
          key: ValueKey('lock'), color: Colors.white24, size: 22);
    }
    return const SizedBox(key: ValueKey('empty'), width: 22);
  }
}
