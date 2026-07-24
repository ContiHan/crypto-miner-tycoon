import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Shared detail sheet opened when a graph node is tapped. Hosts the single real
/// BUY button (calling the existing game.buyResearch / game.buyPerk), so tapping
/// a node during a pan never triggers an accidental purchase and both TECH and
/// TALENTS share one purchase surface. Pass [buyLabel]==null for a read-only /
/// locked node (shows [lockedHint] instead of a button).
Future<void> showGraphNodeSheet(
  BuildContext context, {
  required String title,
  required String description,
  String? effectText,
  String? costLabel,
  bool canAfford = false,
  String? buyLabel,
  VoidCallback? onBuy,
  String? lockedHint,
  Color accent = AppTheme.accent,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + MediaQuery.of(ctx).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.orbitron(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(description,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          if (effectText != null && effectText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(effectText,
                style: TextStyle(
                    color: accent, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
          const SizedBox(height: 18),
          if (buyLabel != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: canAfford ? accent : Colors.grey[800],
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: canAfford
                    ? () {
                        onBuy?.call();
                        Navigator.pop(ctx);
                      }
                    : null,
                child: Text(
                  costLabel == null ? buyLabel : '$buyLabel  ·  $costLabel',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            )
          else
            Row(
              children: [
                const Icon(Icons.lock_outline, color: Colors.white38, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lockedHint ?? 'Locked.',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}
