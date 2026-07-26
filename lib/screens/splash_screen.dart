import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Branded loading screen shown while the save is being read, so there is no
/// white flash between the native launch screen and the first game frame.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.accent, width: 2),
              ),
              child: const Center(
                child: Text(
                  '₿', // ₿
                  style: TextStyle(
                    color: AppTheme.accent,
                    fontSize: 46,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'BTC ONLY TYCOON',
              textAlign: TextAlign.center,
              style: GoogleFonts.orbitron(
                color: AppTheme.accent,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'INITIALIZING NODE…',
              style: GoogleFonts.orbitron(
                color: Colors.white38,
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
              ),
            ),
            // NOTE: the "vibecoded" author blurb used to live here, but the
            // Android 12+ cold-start splash (the launcher ₿ icon) eats the first
            // seconds and this Flutter splash only shows briefly, so the text was
            // barely visible. It now lives on the CREDITS & THANKS screen
            // (Settings → Credits, and the GENESIS COMPLETE ending finale).
          ],
        ),
      ),
    );
  }
}
