import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// CREDITS & THANKS — the "endings & thanks" screen. Reached from the GENESIS
/// COMPLETE ending overlay (as the win finale) and from Settings → About at any
/// time. This is the proper home for the author/game blurb that used to flash by
/// on the loading screen (where the Android cold-start splash ate the first
/// seconds and the text was barely visible).
class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  /// Push the credits screen onto [context]'s navigator.
  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreditsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'CREDITS & THANKS',
          style: GoogleFonts.orbitron(
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: AppTheme.accent,
            fontSize: 16,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 40),
          child: Column(
            children: [
              // --- Hero ---
              Text(
                '₿',
                style: TextStyle(
                  fontSize: 84,
                  color: AppTheme.accent,
                  shadows: [
                    Shadow(
                        color: AppTheme.accent.withValues(alpha: 0.6),
                        blurRadius: 28),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'BTC ONLY TYCOON',
                textAlign: TextAlign.center,
                style: GoogleFonts.orbitron(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  color: AppTheme.accent,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'v1.0.0',
                style: GoogleFonts.orbitron(
                  fontSize: 11,
                  letterSpacing: 2,
                  color: Colors.white38,
                ),
              ),

              const SizedBox(height: 28),

              // --- The story (the moved splash blurb) ---
              const _CreditBlock(
                label: 'THE STORY',
                lines: [
                  'This game was vibecoded —',
                  'but orchestrated by a human.',
                  '',
                  'Every rig, prestige tier and absurd number',
                  'was shaped by hand, then built at the',
                  'speed of thought.',
                ],
              ),

              // --- Author ---
              const _CreditBlock(
                label: 'CREATED BY',
                lines: ['contihan'],
                highlight: true,
              ),

              // --- Thanks (ties into the GENESIS COMPLETE ending) ---
              const _CreditBlock(
                label: 'THANKS',
                lines: [
                  'To everyone chasing all 21 million.',
                  'You mined more Bitcoin than will',
                  'ever exist. Respect.',
                ],
              ),

              // --- Tech / attribution ---
              const _CreditBlock(
                label: 'BUILT WITH',
                lines: [
                  'Flutter · Dart',
                  'Orbitron typeface (SIL OFL 1.1)',
                ],
              ),

              const SizedBox(height: 12),
              // Compliance note — a crypto-themed title should be explicit that
              // it is a parody with no real money or assets involved.
              Text(
                'A parody idle game. Not affiliated with Bitcoin or any '
                'cryptocurrency. No real money, coins or assets — ever.',
                textAlign: TextAlign.center,
                style: GoogleFonts.orbitron(
                  fontSize: 9.5,
                  height: 1.6,
                  letterSpacing: 0.5,
                  color: Colors.white24,
                ),
              ),

              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('CLOSE',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A titled block: a small amber label over one or more centered text lines.
/// Empty strings render as vertical gaps so blocks can hold short stanzas.
class _CreditBlock extends StatelessWidget {
  final String label;
  final List<String> lines;
  final bool highlight;
  const _CreditBlock({
    required this.label,
    required this.lines,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.orbitron(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
              color: AppTheme.accent.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 10),
          for (final line in lines)
            line.isEmpty
                ? const SizedBox(height: 8)
                : Text(
                    line,
                    textAlign: TextAlign.center,
                    style: highlight
                        ? GoogleFonts.orbitron(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: Colors.white,
                          )
                        : const TextStyle(
                            color: Colors.white70,
                            fontSize: 13.5,
                            height: 1.55,
                          ),
                  ),
        ],
      ),
    );
  }
}
