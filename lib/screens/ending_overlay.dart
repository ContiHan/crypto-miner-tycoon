import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/game_logic.dart';
import '../theme/app_theme.dart';
import 'credits_screen.dart';

/// Shows the one-shot "THE LAST SATOSHI" ending overlay the moment the player
/// mines a full 21,000,000-coin supply within a single era — the true win.
/// Full-screen, non-dismissible by tap-away; the player chooses how to continue
/// (go Back in Time for a timed re-mine, or keep mining this chain). The credits
/// finale lives here. [onBackInTime] is wired by HomeScreen (startSpeedRun).
Future<void> showEndingOverlay(
  BuildContext context,
  GameLogic game, {
  required VoidCallback onBackInTime,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'The Last Satoshi',
    barrierColor: Colors.black,
    transitionDuration: const Duration(milliseconds: 600),
    pageBuilder: (ctx, _, _) => _EndingScreen(
      game: game,
      onBackInTime: onBackInTime,
    ),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
            scale: Tween(begin: 0.85, end: 1.0).animate(curved), child: child),
      );
    },
  );
}

class _EndingScreen extends StatelessWidget {
  final GameLogic game;
  final VoidCallback onBackInTime;

  const _EndingScreen({
    required this.game,
    required this.onBackInTime,
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
                      Shadow(
                          color: AppTheme.accent.withValues(alpha: 0.7),
                          blurRadius: 30),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'THE LAST SATOSHI',
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
                  'You mined the last satoshi.\n'
                  'Every coin that will ever exist — in a single era.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                const SizedBox(height: 6),
                Text(
                  '21,000,000 BTC',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.accent,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                _StatRow(label: 'GENESIS BLOCKS', value: '${game.genesisBlocks}'),
                _StatRow(
                    label: 'GENESIS RESETS', value: '${game.newChainCount}'),
                _StatRow(
                    label: 'TOTAL MASTERY', value: '${game.totalMasteryLevel}'),
                const SizedBox(height: 28),
                const Text(
                  'There will never be a 21,000,001st. So how fast can you do it '
                  'all again?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                      fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 16),
                // Back in Time: a timed re-mine of the whole 21M. Keeps your
                // Time Capsule (crate items), Stash & Mastery.
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.history_toggle_off),
                    label: const Text('GO BACK IN TIME',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onBackInTime();
                    },
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Race the clock to re-mine all 21,000,000. Beat your best time.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(height: 18),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('KEEP MINING',
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
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
