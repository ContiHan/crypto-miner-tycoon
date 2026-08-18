import 'package:flutter/material.dart';
import '../providers/game_logic.dart';
import 'stylized_card.dart';

/// Greyed "???" teaser for the next still-locked rig (progressive discovery).
class LockedRigTeaser extends StatelessWidget {
  final String hint;
  const LockedRigTeaser({super.key, required this.hint});

  @override
  Widget build(BuildContext context) {
    return StylizedCard(
      color: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white10,
                border: Border.all(color: Colors.white24),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.lock_outline,
                color: Colors.white38,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '???',
                    style: TextStyle(
                      color: Colors.white54,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hint,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when a single era's entire 21M supply is mined (networkDifficulty is ∞,
/// income clamped to 0). Replaces the "looks broken" dead-end with a clear
/// message + the right next step to move on to a fresh era: start a New
/// Blockchain if one is banked, else Hard Fork (always available at the cap).
class CapReachedBanner extends StatelessWidget {
  final GameLogic game;
  final VoidCallback? onNewBlockchain;
  final VoidCallback? onHardFork;

  const CapReachedBanner({
    super.key,
    required this.game,
    required this.onNewBlockchain,
    required this.onHardFork,
  });

  @override
  Widget build(BuildContext context) {
    String cta;
    VoidCallback? action;
    if (game.pendingGenesis > 0 && onNewBlockchain != null) {
      cta = 'START NEW GENESIS';
      action = onNewBlockchain;
    } else {
      cta = 'HARD FORK NOW';
      action = onHardFork;
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          const Text(
            'ERA MINED OUT',
            style: TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "This blockchain's entire 21M supply is mined — income is capped. "
            'Move on to keep growing.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: action,
              child: Text(cta,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
