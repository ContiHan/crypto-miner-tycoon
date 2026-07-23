import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_logic.dart';
import '../logic/managers/perk_manager.dart';
import '../theme/app_theme.dart';
import '../utils/formatter.dart';
import '../widgets/stylized_card.dart';

class PerksScreen extends StatelessWidget {
  final bool isEmbedded;

  const PerksScreen({super.key, this.isEmbedded = false});

  @override
  Widget build(BuildContext context) {
    final content = Consumer<GameLogic>(
      builder: (context, game, child) {
        final entries = game.perkDefs.entries.toList();

        // Progressive discovery: show unlocked perks, then a single "???" teaser
        // for the next locked one so the player always sees a goal.
        final widgets = <Widget>[];
        bool teaserShown = false;
        for (final e in entries) {
          if (game.isPerkUnlocked(e.key)) {
            widgets.add(_buildPerkItem(context, game, e.key, e.value));
          } else if (!teaserShown) {
            widgets.add(_buildLockedPerkTeaser(e.value));
            teaserShown = true;
          }
        }

        return Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              color: Colors.black26,
              child: Column(
                children: [
                  const Text('GOVERNANCE TOKENS',
                      style: TextStyle(
                          color: AppTheme.textSecondary, letterSpacing: 2)),
                  const SizedBox(height: 10),
                  Text(
                    Formatter.formatNumber(game.govTokens.toDouble()),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.accent,
                    ),
                  ),
                  const Text('Tokens remain after a Hard Fork',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: widgets,
              ),
            ),
          ],
        );
      },
    );

    if (isEmbedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('PERMANENT PERKS')),
      body: content,
    );
  }

  Widget _buildPerkItem(
    BuildContext context,
    GameLogic game,
    String id,
    PerkDef def,
  ) {
    final level = game.perks[id] ?? 0;
    final cost = game.perkCosts[id] ?? 999;
    final isMaxed = game.isPerkMaxed(id);
    final canAfford = !isMaxed && game.govTokens >= cost;

    return StylizedCard(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.black38,
                border:
                    Border.all(color: AppTheme.accent.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(def.icon, color: AppTheme.accent, size: 30),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(def.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white)),
                  Text(def.description,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 5),
                  Text('Level $level',
                      style: const TextStyle(
                          color: AppTheme.accent, fontWeight: FontWeight.bold)),
                  Text(game.perkBonusText(id),
                      style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: canAfford ? () => game.buyPerk(id) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isMaxed
                    ? Colors.grey
                    : (canAfford ? AppTheme.accent : Colors.grey[800]),
                foregroundColor: Colors.black,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(isMaxed ? 'MAX' : 'BUY',
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold)),
                  if (!isMaxed)
                    Text(Formatter.formatNumber(cost.toDouble()),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Dim "???" silhouette for the next locked perk (progressive discovery).
  Widget _buildLockedPerkTeaser(PerkDef def) {
    return StylizedCard(
      color: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white10,
                border: Border.all(color: Colors.white24),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.lock_outline,
                  color: Colors.white38, size: 28),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('???',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white54,
                          letterSpacing: 2)),
                  const SizedBox(height: 4),
                  Text(
                    'Unlocks at ${Formatter.formatNumber(def.unlockAtTokensEver)} GovTokens earned',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
