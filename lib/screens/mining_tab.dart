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
import '../widgets/binary_particle.dart';

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

class _MiningTabState extends State<MiningTab> with TickerProviderStateMixin {
  final List<Widget> _floatingTexts = [];
  late AnimationController _buttonScaleController;
  late Animation<double> _buttonScaleAnimation;

  @override
  void initState() {
    super.initState();
    _buttonScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100), // Fast press
    );
     _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _buttonScaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _buttonScaleController.dispose();
    super.dispose();
  }

  void spawnBinaryExplosion(Offset position) {
    if (!mounted) return;
    
    // Spawn fewer but bigger particles (3-5)
    final random = Random();
    int count = 3 + random.nextInt(3);
    
    for (int i = 0; i < count; i++) {
        final key = UniqueKey();
        
        // Random direction, biased towards sides
        // dx: -6 to -2 (Left) OR 2 to 6 (Right)
        bool goLeft = random.nextBool();
        double dx = goLeft 
            ? (random.nextDouble() * -4) - 2 
            : (random.nextDouble() * 4) + 2;
            
        double dy = (random.nextDouble() * -3) - 2; // Upwards (-2 to -5)
        
        Offset endOffset = Offset(dx, dy);
        String text = '₿'; // BTC Symbol
        
        setState(() {
          _floatingTexts.add(
              Positioned(
                  key: key,
                  top: position.dy - 20, 
                  left: position.dx,
                  child: BinaryParticle( // Reusing widget but with BTC style
                      text: text,
                      endOffset: endOffset,
                      color: Colors.amber,
                      onComplete: () {
                          if (mounted) {
                              setState(() {
                                  _floatingTexts.removeWhere((w) => w.key == key);
                              });
                          }
                      },
                  ),
              )
          );
        });
    }
  }

  void addFloatingText([String? textOverride, Offset? position]) {
    final  key = UniqueKey();
    final text = textOverride ?? '+${Formatter.formatCurrency(1.0)}'; 
    
    // Default position
    double bottom = position == null ? 80 + (Random().nextInt(40).toDouble()) : 0; 
    double right = position == null ? 20 + (Random().nextInt(40).toDouble()) : 0;
    
    setState(() {
      _floatingTexts.add(
        Positioned(
          key: key,
          top: position?.dy != null ? position!.dy - 40 : null, 
          left: position?.dx != null ? position!.dx : null, 
          bottom: position == null ? bottom : null,
          right: position == null ? right : null,
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
                              '${Formatter.formatNumber(game.globalHashRate)} H/s',
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
                        onBuy: (pos) {
                           addFloatingText('-₿', pos); 
                        }, 
                      );
                    },
                  ),
                ),
                // Wide Action Button (Bottom Sticky)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: GestureDetector(
                    onTapDown: (_) => _buttonScaleController.forward(),
                    onTapUp: (details) {
                        _buttonScaleController.reverse();
                        
                        final game = Provider.of<GameLogic>(context, listen: false);
                        game.clickMine();
                        
                        RenderBox box = context.findRenderObject() as RenderBox;
                        Offset localPos = box.globalToLocal(details.globalPosition);

                        addFloatingText('+₿', localPos);
                        spawnBinaryExplosion(localPos);
                    },
                    onTapCancel: () => _buttonScaleController.reverse(),
                    child: ScaleTransition(
                      scale: _buttonScaleAnimation,
                      child: Container(
                        width: double.infinity,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppTheme.accent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.black, width: 2),
                          boxShadow: const [BoxShadow(color: Colors.black45, offset: Offset(0, 4), blurRadius: 4)],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.terminal, size: 24, color: Colors.black),
                                SizedBox(width: 8),
                                Text(
                                  'HACK NETWORK',
                                  style: TextStyle(
                                    fontSize: 18, 
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            Consumer<GameLogic>(builder: (context, game, _) {
                               // Formula: (5 + (Level * 2)) * Prestige
                               double base = 5.0 + (game.perks['click_power']! * 2);
                               return Text(
                                 'Click Power: ${Formatter.formatNumber(base)} x ${game.prestigeMultiplier.toStringAsFixed(1)} (Prestige)',
                                 style: const TextStyle(fontSize: 10, color: Colors.black87),
                               );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            ..._floatingTexts,
            // FAB Removed
          ],
        );
      },
    );
  }
}
