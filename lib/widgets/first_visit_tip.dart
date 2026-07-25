import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/game_logic.dart';
import '../theme/app_theme.dart';

/// A one-beat, centered coach card shown the FIRST time the player opens a
/// screen, then dismissed forever (persisted via [GameLogic.markTipSeen]). Drop
/// one into a screen's (or the nav host's) Stack — it renders nothing once
/// [tipId] has been seen, so it's cheap to leave in place.
///
/// This is the lightweight sibling of the MINE-tab [OnboardingCoach]: no
/// spotlight, just a titled explanation for a whole screen the first time it's
/// reached (the other tabs unlock progressively, so this fires with good timing).
class FirstVisitTip extends StatelessWidget {
  final String tipId;
  final IconData icon;
  final String title;
  final String body;

  const FirstVisitTip({
    super.key,
    required this.tipId,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<GameLogic, bool>(
      selector: (_, g) => g.hasSeenTip(tipId),
      builder: (context, seen, _) {
        if (seen) return const SizedBox.shrink();
        // SizedBox.expand (not Positioned) so this works as a plain, non-
        // positioned child of whatever Stack it's dropped into.
        return SizedBox.expand(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.read<GameLogic>().markTipSeen(tipId),
            child: Container(
              color: Colors.black.withValues(alpha: 0.82),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 340),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accent, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withValues(alpha: 0.25),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: AppTheme.accent, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.orbitron(
                              color: AppTheme.accent,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      body,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14, height: 1.35),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () =>
                            context.read<GameLogic>().markTipSeen(tipId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('GOT IT'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
