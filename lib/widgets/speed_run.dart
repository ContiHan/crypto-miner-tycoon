import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/game_logic.dart';
import '../theme/app_theme.dart';

// "Back in Time" (internally the Speed Run / Genesis Sprint): rewind to the
// genesis block and re-mine the full 21M-BTC supply as fast as you can. Your
// TIME CAPSULE keeps your Collection (crate items), achievements, Mastery and
// Genesis Blocks — so every jump back is faster. Code identifiers keep the
// speedRun* names; only the user-facing copy is themed (as with casino->SWEEP).

/// The "Back in Time" accent — a temporal cyan-green, distinct from the prestige
/// colours (cyan soft-fork, amber GovTokens, purple Genesis).
const Color kSpeedRunColor = Color(0xFF69F0AE);

/// Format a stopwatch time from milliseconds: "M:SS" under an hour, else
/// "H:MM:SS". Shared by the HUD and the completion overlay.
String formatSpeedRunTime(int ms) {
  if (ms < 0) ms = 0;
  final totalSec = ms ~/ 1000;
  final h = totalSec ~/ 3600;
  final m = (totalSec % 3600) ~/ 60;
  final s = totalSec % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}

/// The "Back in Time" block on the MINE prestige panel: a GO BACK button when
/// idle (and unlocked), or the live run HUD while a jump is running. Hidden
/// until unlocked.
class SpeedRunSection extends StatelessWidget {
  final GameLogic game;
  const SpeedRunSection({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    if (!game.speedRunUnlocked) return const SizedBox.shrink();
    if (game.speedRunActive) return _SpeedRunHud(game: game);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          if (game.speedRunBestMs > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'BEST TIME: ${formatSpeedRunTime(game.speedRunBestMs)}',
                style: const TextStyle(
                  color: kSpeedRunColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: kSpeedRunColor,
                side: BorderSide(color: kSpeedRunColor.withValues(alpha: 0.7)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.history, size: 18),
              label: const Text(
                'BACK IN TIME',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              onPressed: () => showStartSpeedRunDialog(context, game),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedRunHud extends StatefulWidget {
  final GameLogic game;
  const _SpeedRunHud({required this.game});

  @override
  State<_SpeedRunHud> createState() => _SpeedRunHudState();
}

class _SpeedRunHudState extends State<_SpeedRunHud> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // The elapsed clock is wall-clock; tick once a second to refresh the display
    // even on frames where the parent doesn't rebuild.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final pct = game.speedRunProgress * 100;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSpeedRunColor.withValues(alpha: 0.08),
        border: Border.all(color: kSpeedRunColor.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.history, color: kSpeedRunColor, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'BACK IN TIME',
                    style: GoogleFonts.orbitron(
                      color: kSpeedRunColor,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Text(
                formatSpeedRunTime(game.speedRunElapsedMs),
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: game.speedRunProgress,
                  backgroundColor: Colors.black54,
                  color: kSpeedRunColor.withValues(alpha: 0.7),
                  minHeight: 14,
                ),
              ),
              Text(
                'RE-MINE 21M BTC: ${pct.toStringAsFixed(1)}%',
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                game.speedRunBestMs > 0
                    ? 'BEST ${formatSpeedRunTime(game.speedRunBestMs)}'
                    : 'NO RECORD YET',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              TextButton(
                onPressed: () => _confirmAbort(context, game),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: const Text('RETURN',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Confirm the jump (it rewinds/resets the run), then begin it.
Future<void> showStartSpeedRunDialog(BuildContext context, GameLogic game) {
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Text('GO BACK IN TIME?',
          style: GoogleFonts.orbitron(
              color: kSpeedRunColor, fontWeight: FontWeight.bold, fontSize: 16)),
      content: const Text(
        'Rewind to the genesis block and re-mine the full 21,000,000 BTC supply '
        'as fast as you can.\n\n'
        'Your TIME CAPSULE keeps your Collection (crate items), achievements, '
        'Mastery and Genesis Blocks — so every jump back is faster. Your wallet, '
        'rigs, TECH, TALENTS and GovTokens rewind to zero.',
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: kSpeedRunColor, foregroundColor: Colors.black),
          onPressed: () {
            Navigator.pop(ctx);
            game.startSpeedRun();
          },
          child: const Text('GO BACK', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

Future<void> _confirmAbort(BuildContext context, GameLogic game) {
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Return to the present?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: const Text(
        'The clock stops and this jump is not recorded. Your current progress '
        'stays — you just leave the timed run.',
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('KEEP GOING',
              style: TextStyle(color: Colors.white54)),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            game.abortSpeedRun();
          },
          child: const Text('RETURN', style: TextStyle(color: Colors.redAccent)),
        ),
      ],
    ),
  );
}
