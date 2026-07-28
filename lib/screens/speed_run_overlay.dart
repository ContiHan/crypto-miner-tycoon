import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/game_logic.dart';
import '../theme/app_theme.dart';
import '../widgets/speed_run.dart';

/// The one-shot "BACK IN TIME" completion overlay, shown when a jump's mined
/// total first reaches one full 21M-BTC supply. Reads the completed time / best
/// off [game] (the pending flag is drained by the caller). Offers GO AGAIN
/// (immediately starts another jump) or DONE.
Future<void> showSpeedRunCompleteOverlay(BuildContext context, GameLogic game) {
  final timeStr = formatSpeedRunTime(game.speedRunLastMs);
  final bestStr = formatSpeedRunTime(game.speedRunBestMs);
  final isRecord = game.speedRunWasRecord;

  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Speed Run Complete',
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (ctx, _, _) => Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kSpeedRunColor.withValues(alpha: 0.6)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.history, color: kSpeedRunColor, size: 56),
                const SizedBox(height: 10),
                Text(
                  'SUPPLY RE-MINED',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.orbitron(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: kSpeedRunColor,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'You went back and re-mined all 21,000,000 BTC.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 18),
                if (isRecord)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: kSpeedRunColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'NEW RECORD!',
                      style: GoogleFonts.orbitron(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                Text(
                  timeStr,
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isRecord ? 'YOUR NEW BEST' : 'BEST  $bestStr',
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kSpeedRunColor,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text('GO AGAIN',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      game.startSpeedRun();
                    },
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('DONE',
                      style: TextStyle(color: Colors.white54)),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (ctx, anim, _, child) => FadeTransition(
      opacity: anim,
      child: ScaleTransition(
        scale: Tween(begin: 0.9, end: 1.0).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
        child: child,
      ),
    ),
  );
}
