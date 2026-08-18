import 'package:flutter/material.dart';
import '../providers/game_logic.dart';
import '../theme/app_theme.dart';
import '../logic/systems/aura_system.dart';

/// AURAS/STANCE loadout panel. One exclusive stance + up to 3 auras; a 60s switch
/// lockout blocks flicker. Auras are live conditional passives (e.g. "while a bad
/// event hits: +income").
class AurasPanel extends StatelessWidget {
  final GameLogic game;
  const AurasPanel({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final available = game.availableAuras();
    if (available.isEmpty) return const SizedBox.shrink();
    final stances = available.where((a) => a.kind == AuraKind.stance).toList();
    final auras = available.where((a) => a.kind == AuraKind.aura).toList();
    final locked = game.auraSwitchCooldownMs() > 0;

    Widget chip(AuraDef d, bool on) {
      // Live LIT/dim: an equipped aura only ACTS while its while-condition holds.
      // ● filled = active now; ○ hollow = equipped but dormant (waiting).
      final live = on && game.auraConditionHolds(d.id);
      final dormant = on && !live;
      return Padding(
        padding: const EdgeInsets.only(right: 6, bottom: 6),
        child: Tooltip(
          message: on
              ? '${d.description}\n${live ? '● ACTIVE now' : '○ equipped — waiting for its condition'}'
              : d.description,
          child: GestureDetector(
            onTap: () {
              final ok = d.kind == AuraKind.stance
                  ? game.equipStance(d.id)
                  : game.toggleAura(d.id);
              if (!ok) {
                final cd = game.auraSwitchCooldownMs();
                final msg = cd > 0
                    ? 'Loadout locked — you can swap again in ${(cd / 1000).ceil()}s'
                    : 'Aura slots full (3/3) — remove one to add another';
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(msg),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ));
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: live
                    ? AppTheme.accent.withValues(alpha: 0.18)
                    : dormant
                        ? AppTheme.accent.withValues(alpha: 0.05)
                        : AppTheme.background,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: live
                        ? AppTheme.accent
                        : dormant
                            ? AppTheme.accent.withValues(alpha: 0.4)
                            : Colors.white24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (on) ...[
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: live ? AppTheme.accent : Colors.transparent,
                        border: Border.all(
                            color: live ? AppTheme.accent : Colors.white38),
                      ),
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(d.name,
                      style: TextStyle(
                          fontSize: 11,
                          color: live
                              ? AppTheme.accent
                              : dormant
                                  ? Colors.white54
                                  : Colors.white70)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('AURAS & STANCE',
                  style: TextStyle(
                      color: AppTheme.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1)),
              const Spacer(),
              if (locked)
                Text('switch in ${(game.auraSwitchCooldownMs() / 1000).ceil()}s',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 6),
          const Text('STANCE (pick one)',
              style: TextStyle(color: Colors.white54, fontSize: 10)),
          const SizedBox(height: 4),
          Wrap(
              children: [
            for (final s in stances) chip(s, game.equippedStance == s.id)
          ]),
          const SizedBox(height: 4),
          Text('AURAS (${game.equippedAuras.length}/3)',
              style: const TextStyle(color: Colors.white54, fontSize: 10)),
          const SizedBox(height: 4),
          Wrap(
              children: [
            for (final a in auras) chip(a, game.equippedAuras.contains(a.id))
          ]),
          if (auras.length < AuraSystem.maxAuras) ...[
            const SizedBox(height: 2),
            Text(
              '${AuraSystem.maxAuras - auras.length} more aura slot'
              '${AuraSystem.maxAuras - auras.length == 1 ? '' : 's'} unlock as '
              'your class Mastery rises.',
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
          const SizedBox(height: 2),
          const Text(
            'Conditional passives — active only while their condition holds. '
            '● lit = acting now · ○ = equipped, waiting for its condition. '
            'Shown raw %; on-channel bonuses soft-cap when stacked.',
            style: TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
