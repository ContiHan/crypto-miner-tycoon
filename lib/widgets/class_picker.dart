import 'package:flutter/material.dart';
import '../logic/managers/class_manager.dart';
import '../logic/channels.dart';
import '../providers/game_logic.dart';
import '../theme/app_theme.dart';

/// Compact one-line effect summary for a class card.
/// The class's passive racial bonuses as individual bullet lines (one stat each),
/// shared by the picker card (joined into one line) and the CLASS BONUSES modal
/// (rendered as a vertical bullet list).
List<String> classEffectBullets(ClassDef def) {
  final parts = <String>[];
  void pct(double v, String label) {
    if (v == 0) return;
    final sign = v > 0 ? '+' : '';
    parts.add('$sign${(v * 100).toStringAsFixed(0)}% $label');
  }

  pct(def.channelBonuses[Channel.hash] ?? 0, 'hash');
  pct(def.channelBonuses[Channel.income] ?? 0, 'income');
  pct(def.channelBonuses[Channel.click] ?? 0, 'click');
  final rig = def.channelBonuses[Channel.rigCost] ?? 0;
  if (rig != 0) parts.add('-${(rig * 100).toStringAsFixed(0)}% rig cost');
  pct(def.channelBonuses[Channel.luck] ?? 0, 'luck');
  final vol = def.channelBonuses[Channel.volatility] ?? 0;
  if (vol > 0) parts.add('louder chaos (+volatility)');
  if (vol < 0) parts.add('calmer markets (-volatility)');
  if (def.prestigeGainMult > 1) {
    parts.add(
        '+${((def.prestigeGainMult - 1) * 100).toStringAsFixed(0)}% prestige gain');
  } else if (def.prestigeGainMult < 1) {
    parts.add(
        '-${((1 - def.prestigeGainMult) * 100).toStringAsFixed(0)}% prestige gain');
  }
  return parts;
}

/// One-line join of [classEffectBullets] for the compact picker cards.
String classEffectSummary(ClassDef def) => classEffectBullets(def).join(' · ');

/// Shared class-selection dialog, reused by the SKILL tab (early, ongoing pick)
/// and New Blockchain. Confirm is disabled until a class is chosen;
/// [onConfirm] receives the picked class.
void showClassPicker(
  BuildContext context, {
  required GameLogic game,
  required String title,
  required Color titleColor,
  required String confirmLabel,
  required Color confirmColor,
  required String info,
  required void Function(BtcClass) onConfirm,
  String headerLabel = 'CHOOSE YOUR CLASS:',
}) {
  final choices =
      BtcClass.values.where((c) => c != BtcClass.prospector).toList();
  BtcClass? selected = game.hasChosenClass ? game.currentClass : null;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(title, style: TextStyle(color: titleColor)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (info.isNotEmpty) ...[
                  Text(info,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 14),
                ],
                Text(
                  headerLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                for (final c in choices)
                  _ClassChoiceCard(
                    def: kClasses[c]!,
                    masteryLevel: game.masteryLevel(c),
                    selected: selected == c,
                    effect: classEffectSummary(kClasses[c]!),
                    onTap: () => setLocal(() => selected = c),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              disabledBackgroundColor: confirmColor.withValues(alpha: 0.3),
            ),
            onPressed: selected == null
                ? null
                : () {
                    onConfirm(selected!);
                    Navigator.pop(ctx);
                  },
            child: Text(confirmLabel),
          ),
        ],
      ),
    ),
  );
}

class _ClassChoiceCard extends StatelessWidget {
  final ClassDef def;
  final int masteryLevel;
  final bool selected;
  final String effect;
  final VoidCallback onTap;

  const _ClassChoiceCard({
    required this.def,
    required this.masteryLevel,
    required this.selected,
    required this.effect,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? def.color.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? def.color : Colors.white24,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(def.icon, color: def.color, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          def.name,
                          style: TextStyle(
                            color: def.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (masteryLevel > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'MASTERY $masteryLevel',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    def.tagline,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  if (effect.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      effect,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
