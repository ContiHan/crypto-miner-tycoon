import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_logic.dart';
import '../theme/app_theme.dart';
import '../utils/formatter.dart';
import '../widgets/stylized_card.dart';

class PerksScreen extends StatelessWidget {
  final bool isEmbedded;

  const PerksScreen({super.key, this.isEmbedded = false});

  @override
  Widget build(BuildContext context) {
    // If embedded, don't use Scaffold/AppBar, just return the content
    final content = Consumer<GameLogic>(
        builder: (context, game, child) {
          return Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                width: double.infinity,
                color: Colors.black26,
                child: Column(
                  children: [
                    const Text('GOVERNANCE TOKENS', style: TextStyle(color: AppTheme.textSecondary, letterSpacing: 2)),
                    const SizedBox(height: 10),
                    Text(
                      Formatter.formatNumber(game.govTokens.toDouble()),
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.accent,
                      ),
                    ),
                    const Text('Tokens remain after Reset', style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildPerkItem(
                      context, 
                      game, 
                      id: 'click_power', 
                      name: 'CYBERNETIC FINGERS', 
                      desc: 'Increases manual click power by +2 per level.',
                      icon: Icons.touch_app,
                    ),
                    _buildPerkItem(
                      context, 
                      game, 
                      id: 'rig_cost', 
                      name: 'EFFICIENT BIOS', 
                      desc: 'Reduces Rig costs by 5% per level (Max 90%).',
                      icon: Icons.price_check,
                    ),
                    _buildPerkItem(
                      context, 
                      game, 
                      id: 'hash_bonus', 
                      name: 'NEURAL OVERCLOCK', 
                      desc: 'Increases total Hash Rate by 10% per level.',
                      icon: Icons.psychology,
                    ),
                  ],
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
      appBar: AppBar(
        title: const Text('PERMANENT PERKS'),
      ),
      body: content,
    );
  }

  Widget _buildPerkItem(BuildContext context, GameLogic game, {
    required String id, 
    required String name, 
    required String desc,
    required IconData icon,
  }) {
    final level = game.perks[id] ?? 0;
    final cost = game.perkCosts[id] ?? 999;
    final canAfford = game.govTokens >= cost;

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
                border: Border.all(color: AppTheme.accent.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(icon, color: AppTheme.accent, size: 30),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 5),
                  Text('Lvl $level', style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: canAfford ? () => game.buyPerk(id) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: canAfford ? AppTheme.accent : Colors.grey[800],
                foregroundColor: Colors.black,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('BUY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  Text(Formatter.formatNumber(cost.toDouble()), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
