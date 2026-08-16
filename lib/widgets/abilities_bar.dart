import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_logic.dart';
import '../logic/systems/ability_system.dart';
import '../theme/app_theme.dart';

/// The Abilities Bar docked above the HACK button: up to three class abilities.
/// Renders only once a real class is chosen. Ready abilities glow; locked ones
/// show a lock + Mastery hint; on-cooldown ones show a wall-clock countdown.
/// Minimal by design (functional first) — polish the visuals later.
class AbilitiesBar extends StatelessWidget {
  const AbilitiesBar({super.key});

  static String _fmt(int ms) {
    if (ms <= 0) return '';
    final s = (ms / 1000).ceil();
    if (s >= 3600) {
      final h = s ~/ 3600;
      final m = (s % 3600) ~/ 60;
      return '${h}h${m.toString().padLeft(2, '0')}';
    }
    if (s >= 60) {
      final m = s ~/ 60;
      final sec = s % 60;
      return '$m:${sec.toString().padLeft(2, '0')}';
    }
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameLogic>(
      builder: (context, game, _) {
        if (!game.hasChosenClass) return const SizedBox.shrink();
        final abilities = game.currentClassAbilities
          ..sort((a, b) => a.slot.index.compareTo(b.slot.index));
        return Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final def in abilities) _AbilityButton(game: game, def: def),
            ],
          ),
        );
      },
    );
  }
}

class _AbilityButton extends StatelessWidget {
  final GameLogic game;
  final AbilityDef def;
  const _AbilityButton({required this.game, required this.def});

  @override
  Widget build(BuildContext context) {
    final unlocked = game.isAbilityUnlocked(def);
    final ready = unlocked && game.isAbilityReady(def);
    final cdMs = unlocked ? game.abilityCooldownRemainingMs(def) : 0;

    final Color border = !unlocked
        ? Colors.white24
        : ready
            ? AppTheme.accent
            : Colors.white38;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!unlocked) {
            final gate = def.slot == AbilitySlot.basic2
                ? 'Reach Mastery 1 with this class'
                : def.slot == AbilitySlot.ultimate
                    ? 'Reach Mastery 2 with this class'
                    : 'Choose this class';
            _snack(context, '${def.name} — locked. $gate.');
            return;
          }
          if (!ready) {
            _snack(context,
                '${def.name} on cooldown (${AbilitiesBar._fmt(cdMs)}).');
            return;
          }
          if (game.castAbility(def.id)) {
            _snack(context, '${def.name} activated!');
          }
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: ready
                ? AppTheme.accent.withValues(alpha: 0.15)
                : Colors.black26,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border, width: ready ? 1.5 : 1),
            boxShadow: ready
                ? [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.4), blurRadius: 8)]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                unlocked ? def.icon : Icons.lock_outline,
                size: 22,
                color: !unlocked
                    ? Colors.white38
                    : ready
                        ? AppTheme.accent
                        : Colors.white54,
              ),
              const SizedBox(height: 2),
              Text(
                !unlocked
                    ? (def.slot == AbilitySlot.ultimate ? 'M2' : 'M1')
                    : ready
                        ? 'READY'
                        : AbilitiesBar._fmt(cdMs),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: !unlocked
                      ? Colors.white38
                      : ready
                          ? AppTheme.accent
                          : Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
  }
}
