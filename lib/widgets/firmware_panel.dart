import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/game_logic.dart';
import '../logic/systems/firmware_system.dart';
import '../theme/app_theme.dart';
import 'stylized_card.dart';
import 'rarity_badge.dart';

/// RIG FIRMWARE loadout — socket bounded [FirmwareAffix]es (proc triggers) into
/// the rig. Sockets = base 3, grown by the Firmware Bay node / class Mastery 2 /
/// deep doctrine commitment. The loadout is Time-Capsule kept (survives resets).
/// Lives on the STASH tab.
class FirmwarePanel extends StatelessWidget {
  final GameLogic game;
  const FirmwarePanel({super.key, required this.game});

  static Color _rarityColor(FirmwareRarity r) => AppTheme.rarityColor(r.index);

  /// Affix pool sorted LOWEST rarity first (common → legendary), catalogue order
  /// as a stable tiebreak — matches the GOAL list's rarity ordering.
  List<FirmwareAffix> _sortedByRarity() {
    final src = game.availableFirmware();
    final indexed = [for (var i = 0; i < src.length; i++) MapEntry(i, src[i])];
    indexed.sort((x, y) {
      final r = x.value.rarity.index.compareTo(y.value.rarity.index);
      return r != 0 ? r : x.key.compareTo(y.key);
    });
    return [for (final e in indexed) e.value];
  }

  @override
  Widget build(BuildContext context) {
    final affixes = _sortedByRarity();
    final used = game.equippedFirmwareCount;
    final cap = game.firmwareCapacity;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Icon(Icons.memory, color: AppTheme.accent, size: 20),
            const SizedBox(width: 8),
            Text('RIG FIRMWARE',
                style: GoogleFonts.orbitron(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            const Spacer(),
            Text('$used / $cap sockets',
                style: TextStyle(
                    color: used >= cap ? AppTheme.accent : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ],
        ),
        const SizedBox(height: 8),
        // Guide-everywhere: firmware is a LOADOUT, not an unlock ladder — this
        // answers "why is everything already available?" up front.
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FIRMWARE = passive auto-effects for your rig. Each chip you '
                'SOCKET fires a bonus when something happens — a mined block, an '
                'ability cast, a Breach, a crit streak (e.g. a free crate, bonus '
                'UTXO, or a short income burst).',
                style:
                    TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
              SizedBox(height: 6),
              Text(
                'Everything is available from the start ON PURPOSE — this is a '
                'LOADOUT you tune, not an unlock grind. The limit is SOCKETS, not '
                'owning chips: you start with 3 and earn up to 8 (Firmware Bay in '
                'TECH, class Mastery 2, two committed doctrines). Rarer chips do '
                'more but still cost one socket — so pick your few. Kept across '
                'every reset. Listed common → legendary.',
                style:
                    TextStyle(color: Colors.white54, fontSize: 11, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final a in affixes)
          _firmwareCard(context, a, game.isFirmwareEquipped(a.id), used >= cap),
      ],
    );
  }

  Widget _firmwareCard(
      BuildContext context, FirmwareAffix a, bool equipped, bool full) {
    final color = _rarityColor(a.rarity);
    final canSocket = equipped || !full;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: StylizedCard(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(a.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                        ),
                        const SizedBox(width: 6),
                        RarityBadge(
                          color: color,
                          label: a.rarity.name,
                          showDot: false,
                          fontSize: 9,
                          letterSpacing: 0.5,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(a.description,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 11, height: 1.3)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: canSocket ? () => game.toggleFirmware(a.id) : null,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: equipped
                        ? AppTheme.accent.withValues(alpha: 0.18)
                        : canSocket
                            ? AppTheme.background
                            : Colors.black26,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: equipped
                            ? AppTheme.accent
                            : canSocket
                                ? Colors.white24
                                : Colors.white12),
                  ),
                  child: Text(
                    equipped ? 'EQUIPPED' : (canSocket ? 'SOCKET' : 'FULL'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: equipped
                          ? AppTheme.accent
                          : canSocket
                              ? Colors.white70
                              : Colors.white30,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
