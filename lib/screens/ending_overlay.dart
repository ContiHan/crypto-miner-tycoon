import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/game_logic.dart';
import '../theme/app_theme.dart';
import '../utils/formatter.dart';
import 'credits_screen.dart';

/// Shows the one-shot "GENESIS COMPLETE" ending overlay when the player crosses
/// the cumulative-ever endgame target. Full-screen, non-dismissible by tap-away;
/// the player chooses how to continue (New Genesis, Break the Chain, or keep
/// playing). [onNewGenesis]/[onBreakChain] are wired by HomeScreen.
Future<void> showEndingOverlay(
  BuildContext context,
  GameLogic game, {
  required VoidCallback onNewGenesis,
  required VoidCallback onBreakChain,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Genesis Complete',
    barrierColor: Colors.black,
    transitionDuration: const Duration(milliseconds: 600),
    pageBuilder: (ctx, _, _) => _EndingScreen(
      game: game,
      onNewGenesis: onNewGenesis,
      onBreakChain: onBreakChain,
    ),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(curved), child: child),
      );
    },
  );
}

class _EndingScreen extends StatelessWidget {
  final GameLogic game;
  final VoidCallback onNewGenesis;
  final VoidCallback onBreakChain;

  const _EndingScreen({
    required this.game,
    required this.onNewGenesis,
    required this.onBreakChain,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '₿',
                  style: TextStyle(
                    fontSize: 96,
                    color: AppTheme.accent,
                    shadows: [
                      Shadow(color: AppTheme.accent.withValues(alpha: 0.7), blurRadius: 30),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'GENESIS COMPLETE',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.orbitron(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: AppTheme.accent,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'You have mined more Bitcoin than will ever exist.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                const SizedBox(height: 6),
                Text(
                  Formatter.formatBitcoin(game.lifetimeEverSats),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.accent,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                _StatRow(label: 'GENESIS BLOCKS', value: '${game.genesisBlocks}'),
                _StatRow(label: 'BLOCKCHAINS FORGED', value: '${game.newChainCount}'),
                _StatRow(label: 'TOTAL MASTERY', value: '${game.totalMasteryLevel}'),
                const SizedBox(height: 28),
                const Text(
                  'The 21 million was never the limit. What now?',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 13, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 16),
                // New Genesis (NG+): reset stronger.
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('NEW GENESIS (NG+)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onNewGenesis();
                    },
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Reset for a permanent, compounding prestige boost. Keeps Stash, Mastery & trophies.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(height: 14),
                // Break the chain: uncapped sandbox.
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.all_inclusive),
                    label: const Text('BREAK THE CHAIN',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onBreakChain();
                    },
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Remove the supply cap. Numbers go to absurdity. Purely for fun.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(height: 18),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('KEEP PLAYING',
                      style: TextStyle(color: Colors.white54)),
                ),
                // The credits/thanks finale — the win is the right place for it.
                TextButton.icon(
                  onPressed: () => CreditsScreen.open(context),
                  icon: const Icon(Icons.favorite_border,
                      size: 15, color: Colors.white38),
                  label: const Text('CREDITS & THANKS',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
