import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../content/achievement_defs.dart';
import '../providers/game_logic.dart';
import '../theme/app_theme.dart';
import '../widgets/stylized_card.dart';
import '../widgets/pulse_button.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  static const Map<AchCategory, Color> _categoryColor = {
    AchCategory.earnings: AppTheme.accent,
    AchCategory.rigs: Colors.cyanAccent,
    AchCategory.tech: Colors.lightBlueAccent,
    AchCategory.prestige: Colors.redAccent,
    AchCategory.collection: Colors.purpleAccent,
    AchCategory.meta: Colors.amberAccent,
    AchCategory.secret: Colors.pinkAccent,
  };

  // Display order is captured once per screen mount: UNLOCKED (claimable first
  // as a call-to-action, then claimed) → LOCKED (known goals) → UNKNOWN (secret
  // + locked), rarest first within each group. It is intentionally NOT recomputed
  // when an item is claimed while the screen stays open: keeping each card in
  // place lets the CLAIM -> checkmark pop animation play where the user tapped,
  // instead of the card teleporting to a new position. Re-sorting happens the
  // next time the screen is entered (it remounts on bottom-nav switch).
  List<Achievement>? _ordered;

  List<Achievement> _orderFor(GameLogic game) => orderedAchievements(
        game.achievements,
        isClaimable: game.isAchievementClaimable,
        isClaimed: game.isAchievementClaimed,
      );

  @override
  Widget build(BuildContext context) {
    return Consumer<GameLogic>(
      builder: (context, game, child) {
        final total = game.achievementsTotal;
        final unlocked = game.achievementsUnlocked;
        final pct = total == 0 ? 0.0 : unlocked / total;
        final unclaimed = game.unclaimedAchievements;

        final ordered = _ordered ??= _orderFor(game);

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
                        onPressed: () {
                          // Claiming here makes the "tap to claim" unlock toast
                          // stale — dismiss it so it doesn't linger for its 4s.
                          ScaffoldMessenger.of(context).clearSnackBars();
                          game.claimAllAchievements();
                        },
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
                    key: ValueKey(a.id),
                    achievement: a,
                    claimable: game.isAchievementClaimable(a.id),
                    claimed: game.isAchievementClaimed(a.id),
                    color: _categoryColor[a.category] ?? AppTheme.accent,
                    onClaim: () {
                      // Dismiss the stale "tap to claim" unlock toast on claim.
                      ScaffoldMessenger.of(context).clearSnackBars();
                      game.claimAchievement(a.id);
                    },
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
    super.key,
    required this.achievement,
    required this.claimable,
    required this.claimed,
    required this.color,
    required this.onClaim,
  });

  static Color _rarityColor(AchRarity r) {
    switch (r) {
      case AchRarity.common:
        return Colors.blueGrey;
      case AchRarity.rare:
        return const Color(0xFF3987e5);
      case AchRarity.epic:
        return const Color(0xFF9085e9);
      case AchRarity.legendary:
        return const Color(0xFFeda100);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = claimable || claimed;
    // Locked secret is fully hidden ("???"); locked normal shows its goal.
    final bool hideDetails = !unlocked && achievement.secret;
    final String title = hideDetails ? '???' : achievement.title;
    final String desc = hideDetails
        ? 'Secret achievement — discover it by playing.'
        : achievement.description;
    final rarity = achievementRarity(achievement.id);
    final rarityColor = _rarityColor(rarity);

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
                  if (!hideDetails) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.circle, size: 7, color: rarityColor),
                        const SizedBox(width: 4),
                        Text(
                          rarity.name.toUpperCase(),
                          style: TextStyle(
                            color: rarityColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Fixed-width trailing slot so the CLAIM button / checkmark always
            // align and never crowd the title/description.
            SizedBox(
              width: 72,
              child: Center(
                // Trailing swaps between CLAIM -> checkmark with a scale pop.
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (c, anim) =>
                      ScaleTransition(scale: anim, child: c),
                  child: _trailing(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _trailing() {
    if (claimable) {
      // Single-line, bold, black-on-colour — consistent with the BUY buttons.
      // (The +1% Notoriety per claim is shown in the header readout.)
      return ElevatedButton(
        key: const ValueKey('claim'),
        onPressed: onClaim,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        child: const Text('CLAIM'),
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
