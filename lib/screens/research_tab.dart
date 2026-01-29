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
                        letterSpacing: 2),
                  ),
                  const Text(
                    'Unlock advanced technologies with Money.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                   const SizedBox(height: 10),
                   Text(
                    'BALANCE: ₿ ${Formatter.formatCurrency(game.wallet)}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: game.researchNodes.length,
                itemBuilder: (context, index) {
                  final node = game.researchNodes[index];
                  return _buildResearchItem(context, game, node);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildResearchItem(BuildContext context, GameLogic game, ResearchNode node) {
    if (!node.isUnlocked && !node.isCompleted) {
       // Optional: Show locked items as mysterious or just hide them?
       // Let's show them as Locked (Greyed out) if we want the user to see the tree
       // user asked for tree/list, let's keep it simple: Show only unlocked or visible?
       // Logic in GameLogic.checkUnlocks() handles setting isUnlocked.
       // If isUnlocked is false, we generally shouldn't show it unless we want a "Coming Soon" feel.
       // But let's stick to showing only Unlocked + Completed for now to reduce clutter.
       return const SizedBox.shrink(); 
    }

    final bool canAfford = game.wallet >= node.cost;
    final bool isCompleted = node.isCompleted;

    return StylizedCard(
      color: isCompleted ? Colors.green.withOpacity(0.1) : AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isCompleted ? AppTheme.accent.withOpacity(0.2) : Colors.black26,
                border: Border.all(color: isCompleted ? AppTheme.accent : Colors.grey),
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
                      decoration: isCompleted ? TextDecoration.none : TextDecoration.none,
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
            // Action
            if (isCompleted)
              const Text('ACTIVE', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
            else
              ElevatedButton(
                onPressed: canAfford
                    ? () {
                        game.buyResearch(node.id);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canAfford ? AppTheme.accent : Colors.grey[800],
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: Text(
                  'RESEARCH\n₿ ${Formatter.formatCurrency(node.cost)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
