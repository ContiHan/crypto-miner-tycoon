import 'package:flutter/material.dart';
import '../providers/game_logic.dart';
import '../theme/app_theme.dart';

/// Compact preset controls: save the current build, one-tap re-apply a saved
/// build, and toggle auto-apply. Guide text is inline (guide-everywhere).
class TechPresetBar extends StatelessWidget {
  final GameLogic game;
  const TechPresetBar({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final presets = game.techPresets;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () {
                game.saveTechPreset();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Build saved'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ));
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accent,
                side: const BorderSide(color: AppTheme.accent),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: const Size(0, 34),
              ),
              icon: const Icon(Icons.bookmark_add_outlined, size: 16),
              label: const Text('SAVE BUILD', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 8),
            // AUTO-APPLY toggle.
            GestureDetector(
              onTap: () => game.setAutoApplyPresets(!game.autoApplyPresets),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: game.autoApplyPresets
                      ? AppTheme.accent.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: game.autoApplyPresets
                          ? AppTheme.accent
                          : Colors.white24),
                ),
                child: Text(
                  game.autoApplyPresets ? 'AUTO ✓' : 'AUTO',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: game.autoApplyPresets
                        ? AppTheme.accent
                        : Colors.white54,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (presets.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (var i = 0; i < presets.length; i++)
            _PresetRow(game: game, index: i),
        ],
        const SizedBox(height: 6),
        Text(
          game.autoApplyPresets
              ? 'APPLY re-teches a build now; your active build (▶) also re-applies '
                'automatically after every reset. UPDATE overwrites a slot with '
                'your current build; ✕ deletes it.'
              : 'Auto-apply is OFF. APPLY re-teches a build now; UPDATE overwrites '
                'a slot with your current build; ✕ deletes it.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
      ],
    );
  }
}

/// One saved-build row: APPLY (re-tech now) + UPDATE (overwrite this slot with
/// the current build) + delete. Separating APPLY from a tap-anywhere chip fixes
/// the "it auto-applies and I can't overwrite an older slot" complaint.
class _PresetRow extends StatelessWidget {
  final GameLogic game;
  final int index;
  const _PresetRow({required this.game, required this.index});

  @override
  Widget build(BuildContext context) {
    final preset = game.techPresets[index];
    final active = index == game.activeTechPreset;
    void snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ));

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.only(left: 10, right: 4),
      decoration: BoxDecoration(
        color: active
            ? AppTheme.accent.withValues(alpha: 0.12)
            : AppTheme.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: active ? AppTheme.accent : Colors.white12),
      ),
      child: Row(
        children: [
          Icon(active ? Icons.play_circle_fill : Icons.bookmark_outline,
              size: 15, color: AppTheme.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(preset.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              final n = game.applyTechPreset(index);
              snack(n > 0
                  ? 'Applied ${preset.name} (+$n nodes)'
                  : '${preset.name}: nothing affordable yet');
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.accent,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('APPLY', style: TextStyle(fontSize: 11)),
          ),
          IconButton(
            tooltip: 'Overwrite this slot with your current build',
            icon: const Icon(Icons.sync, size: 17),
            color: Colors.white54,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            onPressed: () {
              final ok = game.overwriteTechPreset(index);
              snack(ok
                  ? 'Updated slot to your current build (${game.techPresets[index].name})'
                  : 'Nothing researched yet — build not changed');
            },
          ),
          IconButton(
            tooltip: 'Delete this saved build',
            icon: const Icon(Icons.close, size: 17),
            color: Colors.white38,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            onPressed: () => _confirmDelete(context, preset.name),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String name) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('DELETE BUILD',
            style: TextStyle(color: Colors.orangeAccent)),
        content: Text('Delete the saved build "$name"? Your researched nodes '
            'stay — this only removes the saved preset.',
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              game.deleteTechPreset(index);
              Navigator.of(ctx).pop();
            },
            child: const Text('DELETE',
                style: TextStyle(
                    color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

/// The one-per-era free respec: wipes the TECH tree (uncommitting doctrines) so a
/// mis-picked build can be re-teched WITHOUT waiting for a fork. Blueprints (the
/// permanent re-tech discount) survive, so it's cheap to rebuild. Refreshes at
/// every fork. Only rendered once something is researched (nothing to undo before
/// then); shows a dim "spent" hint after use.
class RespecBar extends StatelessWidget {
  final GameLogic game;
  const RespecBar({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    if (game.respecSpent) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          'FREE RESPEC SPENT — refreshes at your next fork.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 10),
        ),
      );
    }
    if (!game.respecAvailable) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          OutlinedButton.icon(
            onPressed: () => _confirm(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orangeAccent,
              side: const BorderSide(color: Colors.orangeAccent),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              minimumSize: const Size(0, 34),
            ),
            icon: const Icon(Icons.restart_alt, size: 16),
            label: const Text('FREE RESPEC', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(height: 4),
          const Text(
            'One per era: clears the whole TECH tree and frees your committed '
            'doctrines. Blueprints (your re-tech discount) are kept.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }

  void _confirm(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('FREE RESPEC',
            style: TextStyle(color: Colors.orangeAccent)),
        content: const Text(
          'Clear the entire TECH tree? This frees every researched node so you can '
          're-spend your Research Points on a new build.\n\nYou get ONE respec per '
          'era — it refreshes at your next fork.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              game.respecTech();
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('TECH tree cleared — pick a fresh build'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ));
            },
            child: const Text('RESPEC',
                style: TextStyle(
                    color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
