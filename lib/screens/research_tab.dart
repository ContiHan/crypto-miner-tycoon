import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_logic.dart';
import '../models/research_node.dart';
import '../theme/app_theme.dart';
import '../utils/formatter.dart';
import '../widgets/stylized_card.dart';

class ResearchTab extends StatelessWidget {
  const ResearchTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameLogic>(
      builder: (context, game, child) {
        return Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              color: AppTheme.surface,
              width: double.infinity,
              child: Column(
                children: [
                  const Icon(Icons.science, size: 40, color: AppTheme.accent),
                  const SizedBox(height: 5),
                  const Text(
                    'LABORATORY',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accent,
                      letterSpacing: 2,
                    ),
                  ),
                  const Text(
                    'Unlock advanced technologies with Money.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => game.toggleFiatDisplay(),
                    child: Text(
                      'BALANCE: ${game.showFiatPrices ? '\$ ${Formatter.formatNumber(game.toFiat(game.wallet))}' : Formatter.formatBitcoin(game.wallet)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: _buildResearchList(context, game),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Unlocked/completed nodes, followed by a SINGLE "???" teaser for the next
  /// frontier node (matches the Perks screen) — not one teaser per frontier.
  List<Widget> _buildResearchList(BuildContext context, GameLogic game) {
    final widgets = <Widget>[];
    bool teaserShown = false;
    for (final node in game.researchNodes) {
      if (node.isCompleted || node.isUnlocked) {
        widgets.add(_buildResearchItem(context, game, node));
      } else if (!teaserShown) {
        final onFrontier = node.requirements.every((reqId) {
          final req = game.researchNodes.firstWhere(
            (r) => r.id == reqId,
            orElse: () => node,
          );
          return req.isCompleted || req.isUnlocked;
        });
        if (onFrontier) {
          widgets.add(_buildLockedResearchTeaser());
          teaserShown = true;
        }
      }
    }
    return widgets;
  }

  /// Dim "???" silhouette for a locked frontier research node.
  Widget _buildLockedResearchTeaser() {
    return StylizedCard(
      color: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.black26,
                border: Border.all(color: Colors.white24),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.lock_outline,
                color: Colors.white38,
                size: 28,
              ),
            ),
            const SizedBox(width: 15),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '???',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white54,
                      letterSpacing: 3,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Locked — complete the prerequisite research',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResearchItem(
    BuildContext context,
    GameLogic game,
    ResearchNode node,
  ) {
    if (!node.isUnlocked && !node.isCompleted) {
      // Progressive discovery: show a "???" silhouette only for FRONTIER nodes
      // (every prerequisite is at least visible) so the next research teases
      // into view; hide deeper nodes entirely.
      final onFrontier = node.requirements.every((reqId) {
        final req = game.researchNodes.firstWhere(
          (r) => r.id == reqId,
          orElse: () => node,
        );
        return req.isCompleted || req.isUnlocked;
      });
      if (!onFrontier) return const SizedBox.shrink();
      return _buildLockedResearchTeaser();
    }

    // node.cost is denominated in credits (USD). The wallet holds sats, and the
    // real charge is credits / exchangeRate (see GameLogic.getResearchCost), so
    // affordability and the BTC price must both go through that converter — the
    // sats price falls after a hard fork, exactly like rig prices do.
    final double costSats = game.getResearchCost(node.id);
    final bool canAfford = game.wallet >= costSats;
    final bool isCompleted = node.isCompleted;

    return StylizedCard(
      color: isCompleted
          ? Colors.green.withValues(alpha: 0.1)
          : AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppTheme.accent.withValues(alpha: 0.2)
                    : Colors.black26,
                border: Border.all(
                  color: isCompleted ? AppTheme.accent : Colors.grey,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isCompleted ? Icons.check : node.icon,
                color: isCompleted ? AppTheme.accent : Colors.grey,
                size: 30,
              ),
            ),
            const SizedBox(width: 15),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    node.name.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isCompleted ? AppTheme.accent : Colors.white,
                      decoration: isCompleted
                          ? TextDecoration.none
                          : TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    node.description,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Fixed-width action slot so BUY never grows with the price nor
            // crowds the name, and ACTIVE aligns with it. Long prices scale down
            // via FittedBox (no ellipsis).
            SizedBox(
              width: 96,
              child: isCompleted
                  ? const Center(
                      child: Text(
                        'ACTIVE',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: canAfford
                          ? () {
                              game.buyResearch(node.id);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            canAfford ? AppTheme.accent : Colors.grey[800],
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 10,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'BUY',
                            style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              game.showFiatPrices
                                  ? '\$ ${Formatter.formatNumber(game.toFiat(costSats))}'
                                  : Formatter.formatBitcoin(costSats),
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
