import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_logic.dart';
import '../widgets/stylized_card.dart';
import '../widgets/rig_list_item.dart';
import '../widgets/floating_text.dart';
import '../widgets/pulse_button.dart';
import '../theme/app_theme.dart';
import 'perks_screen.dart';
import 'dart:math';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  // Floating Text Logic
  final List<Widget> _floatingTexts = [];

  void _addFloatingText([String? textOverride]) {
    // Basic unique key to ensure widget identity
    final  key = UniqueKey();
    final text = textOverride ?? '+${Provider.of<GameLogic>(context, listen: false).prestigeMultiplier.toStringAsFixed(1)}';
    
    setState(() {
      _floatingTexts.add(
        Positioned(
          key: key,
          bottom: 80 + (Random().nextInt(40).toDouble()), // Randomize slightly so they don't stack perfectly
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
  void initState() {
    super.initState();
    // Check for offline earnings after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final game = Provider.of<GameLogic>(context, listen: false);
      if (game.offlineEarningsAmount != null) {
        _showOfflineEarningsDialog(context, game, game.offlineEarningsAmount!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CRYPTO TYCOON'),
      ),
      body: Consumer<GameLogic>(
        builder: (context, game, child) {
          // Listen for delayed offline earnings (if loaded later)
          if (game.offlineEarningsAmount != null) {
             Future.microtask(() => 
                _showOfflineEarningsDialog(context, game, game.offlineEarningsAmount!)
             );
          }
          
          return Stack( // Use Stack to overlay floating text
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
                          Text(
                            'WALLET BALANCE',
                            style: TextStyle(
                                color: AppTheme.textSecondary,
                                letterSpacing: 2,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                          Text(
                            '₿ ${game.wallet.toStringAsFixed(2)}',
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
                                '${game.rigs.fold(0.0, (sum, r) => sum + r.totalHashRate).toStringAsFixed(1)} H/s',
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
                              'GOV TOKENS: ${game.govTokens} (x${game.prestigeMultiplier.toStringAsFixed(1)})',
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
                                onPressed: () => _showHardForkDialog(context, game),
                                child: Text('HARD FORK (+${game.pendingGovTokens} Tokens)'),
                              ),
                            ),
                          // Always show Perks Shop button if we have tokens or have prestiged once
                          if (game.govTokens > 0 || game.lifetimeEarnings > 1000)
                             Padding(
                               padding: const EdgeInsets.only(top: 8.0),
                               child: OutlinedButton(
                                 onPressed: () => Navigator.push(
                                   context, 
                                   MaterialPageRoute(builder: (_) => const PerksScreen())
                                 ),
                                 style: OutlinedButton.styleFrom(
                                   foregroundColor: AppTheme.accent,
                                   side: const BorderSide(color: AppTheme.accent),
                                 ),
                                 child: const Text('PERMANENT PERKS SHOP'),
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
                          onBuy: () => _addFloatingText('-${rig.currentCost.toStringAsFixed(0)}'),
                        );
                      },
                    ),
                  ),
                ],
              ),
              // Floating Text Layer
              ..._floatingTexts,
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Provider.of<GameLogic>(context, listen: false).clickMine();
          _addFloatingText();
        },
        child: const Icon(Icons.touch_app, size: 30),
      ),
    );
  }

  void _showHardForkDialog(BuildContext context, GameLogic game) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('EXECUTE HARD FORK?', style: TextStyle(color: Colors.redAccent)),
        content: Text(
          'This will reset your Money and Rigs.\n\n'
          'You will gain ${game.pendingGovTokens} GovTokens.\n'
          'Current Multiplier: x${game.prestigeMultiplier.toStringAsFixed(1)}\n'
          'New Multiplier: x${(1.0 + ((game.govTokens + game.pendingGovTokens) * 0.1)).toStringAsFixed(1)}',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              game.hardFork();
              Navigator.pop(ctx);
            },
            child: const Text('RESET & CLAIM'),
          ),
        ],
      ),
    );
  }

  void _showOfflineEarningsDialog(BuildContext context, GameLogic game, double amount) {
    // Prevent multiple dialogs if one is already showing? 
    // Ideally GameLogic clears it immediately, but let's be safe.
    // For now, simple implementation.
    
    // We need to clear it from GameLogic so it doesn't loop
    game.clearOfflineEarnings();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('WELCOME BACK!', style: TextStyle(color: AppTheme.accent)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('While you were away, your rigs mined:', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 20),
            Text(
              '₿ ${amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 32, 
                fontWeight: FontWeight.bold, 
                color: AppTheme.accent
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('COLLECT'),
          ),
        ],
      ),
    );
  }
}
