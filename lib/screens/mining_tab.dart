import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../providers/game_logic.dart';
import '../theme/app_theme.dart';
import '../utils/formatter.dart';
import '../widgets/stylized_card.dart';
import '../widgets/rig_list_item.dart';
import '../widgets/pulse_button.dart';
import '../widgets/floating_text.dart';

class MiningTab extends StatefulWidget {
  final VoidCallback onHardFork; // Callback to trigger hard fork dialog from parent or here
  final Function(String) onBuyRig; // Callback for buying rig visual feedback

  const MiningTab({
    super.key, 
    required this.onHardFork,
    required this.onBuyRig,
  });

  @override
  State<MiningTab> createState() => _MiningTabState();
}

class _MiningTabState extends State<MiningTab> {
  // We manage floating text locally in the tab or lift it up?
  // Let's keep floating text strictly visual here.
  final List<Widget> _floatingTexts = [];

  void addFloatingText([String? textOverride]) {
    final  key = UniqueKey();
    final text = textOverride ?? '+${Formatter.formatCurrency(1.0)}'; // Default fallback, usually overridden
    
    setState(() {
      _floatingTexts.add(
        Positioned(
          key: key,
          bottom: 80 + (Random().nextInt(40).toDouble()),
          right: 20 + (Random().nextInt(40).toDouble()),
          child: FloatingText(
            text: text,
            onComplete: () {
              if (mounted) {
                setState(() {
                  _floatingTexts.removeWhere((w) => w.key == key);
                });
              }
            },
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameLogic>(
      builder: (context, game, child) {
        return Stack(
          children: [
            Column(
              children: [
                // Stats Panel
                StylizedCard(
                  color: AppTheme.surface,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      children: [
                        const Text(
                          'WALLET BALANCE',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              letterSpacing: 2,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                        Text(
                          '₿ ${Formatter.formatCurrency(game.wallet)}',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.accent,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const Divider(color: Colors.black54, thickness: 2, height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.flash_on, color: Colors.amber, size: 20),
                            const SizedBox(width: 5),
                            Text(
                              '${Formatter.formatNumber(game.rigs.fold(0.0, (sum, r) => sum + r.totalHashRate))} H/s',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                            if (game.govTokens > 0)
                              Text(
                                'GOV TOKENS: ${Formatter.formatNumber(game.govTokens.toDouble())} (x${game.prestigeMultiplier.toStringAsFixed(1)})',
                                style: const TextStyle(
                                    color: AppTheme.accent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14),
                              ),
                            if (game.pendingGovTokens > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: PulseButton(
                                  animate: true,
                                  onPressed: widget.onHardFork,
                                  child: Text('HARD FORK (+${Formatter.formatNumber(game.pendingGovTokens.toDouble())} Tokens)'),
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: game.rigs.length,
                    itemBuilder: (context, index) {
                      final rig = game.rigs[index];
                      return RigListItem(
                        rig: rig, 
                        game: game,
                        // Trigger visual feedback
                        onBuy: () => addFloatingText('-${Formatter.formatCurrency(game.getRigCost(rig))}'), 
                      );
                    },
                  ),
                ),
              ],
            ),
            ..._floatingTexts,
            // FAB must be here if it's specific to this tab
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton(
                onPressed: () {
                    // Manual Click
                    Provider.of<GameLogic>(context, listen: false).clickMine();
                    
                    // Calc value for visual
                    double val = (5.0 + (game.perks['click_power']! * 2)) * game.prestigeMultiplier;
                    addFloatingText('+${Formatter.formatCurrency(val)}');
                },
                child: const Icon(Icons.touch_app, size: 30),
            ),),
          ],
        );
      },
    );
  }
}
