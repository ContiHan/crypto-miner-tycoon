import '../../core/constants.dart';
import '../channels.dart';
import 'proc_system.dart';

/// Rarity of a firmware affix — cosmetic banding for the socket UI.
enum FirmwareRarity { common, rare, epic, legendary }

/// A socketable Rig Firmware affix: a named [ProcSignal] the player can equip into
/// the RIG FIRMWARE LOADOUT. Equipped affixes are rolled alongside the class
/// signature procs (same ICD / token-bucket / per-tick brakes). The affix POOL is
/// open (anything can be socketed); the LOADOUT size is the constraint.
class FirmwareAffix {
  final String id;
  final String name;
  final String description;
  final FirmwareRarity rarity;
  final ProcSignal signal;
  const FirmwareAffix({
    required this.id,
    required this.name,
    required this.description,
    required this.rarity,
    required this.signal,
  });
}

/// The starter firmware library. Universal (class-agnostic) signals that exercise
/// the broader proc hooks + the new GRANT kinds from Slice 73a. Numbers are
/// bounded and [TUNE]-able; every one obeys the engine's ICD/limiter brakes.
const List<FirmwareAffix> kFirmwareAffixes = [
  FirmwareAffix(
    id: 'fw_nonce_cache',
    name: 'Nonce Cache',
    description: 'Crit streak → +3 UTXO.',
    rarity: FirmwareRarity.rare,
    signal: ProcSignal(
      id: 'fw_nonce_cache',
      name: 'Nonce Cache',
      event: ProcEvent.onCritStreak,
      chance: 1.0,
      kind: ProcEffectKind.grantUtxo,
      magnitude: 3,
    ),
  ),
  FirmwareAffix(
    id: 'fw_crit_capacitor',
    name: 'Crit Capacitor',
    description: '8% of crits → click ×1.5 for 6s.',
    rarity: FirmwareRarity.common,
    signal: ProcSignal(
      id: 'fw_crit_capacitor',
      name: 'Crit Capacitor',
      event: ProcEvent.onCrit,
      chance: 0.08,
      kind: ProcEffectKind.buff,
      buffChannel: Channel.click,
      magnitude: 1.5,
      buffDurationMs: 6000,
    ),
  ),
  FirmwareAffix(
    id: 'fw_overflow_buffer',
    name: 'Overflow Buffer',
    description: 'Block found → income ×1.25 for 8s (ICD-gated).',
    rarity: FirmwareRarity.common,
    signal: ProcSignal(
      id: 'fw_overflow_buffer',
      name: 'Overflow Buffer',
      event: ProcEvent.onBlockFound,
      chance: 0.12,
      kind: ProcEffectKind.buff,
      buffChannel: Channel.income,
      magnitude: 1.25,
      buffDurationMs: 8000,
    ),
  ),
  FirmwareAffix(
    id: 'fw_tap_reactor',
    name: 'Tap Reactor',
    description: '3% of taps → hash ×1.2 for 5s.',
    rarity: FirmwareRarity.common,
    signal: ProcSignal(
      id: 'fw_tap_reactor',
      name: 'Tap Reactor',
      event: ProcEvent.onTap,
      chance: 0.03,
      kind: ProcEffectKind.buff,
      buffChannel: Channel.hash,
      magnitude: 1.2,
      buffDurationMs: 5000,
    ),
  ),
  FirmwareAffix(
    id: 'fw_anomaly_beacon',
    name: 'Anomaly Beacon',
    description: 'Good market event → spawn an anomaly.',
    rarity: FirmwareRarity.rare,
    signal: ProcSignal(
      id: 'fw_anomaly_beacon',
      name: 'Anomaly Beacon',
      event: ProcEvent.onGoodChaos,
      chance: 0.6,
      kind: ProcEffectKind.grantAnomaly,
      magnitude: 1,
    ),
  ),
  FirmwareAffix(
    id: 'fw_insurance_rider',
    name: 'Insurance Rider',
    description: 'On a breach → bank 60s of income (softens the loss).',
    rarity: FirmwareRarity.rare,
    signal: ProcSignal(
      id: 'fw_insurance_rider',
      name: 'Insurance Rider',
      event: ProcEvent.onBreach,
      chance: 1.0,
      kind: ProcEffectKind.grantSats,
      magnitude: 60,
    ),
  ),
  FirmwareAffix(
    id: 'fw_cold_boot',
    name: 'Cold Boot',
    description: 'Soft Fork → refund 50% of ability cooldowns.',
    rarity: FirmwareRarity.epic,
    signal: ProcSignal(
      id: 'fw_cold_boot',
      name: 'Cold Boot',
      event: ProcEvent.onSoftFork,
      chance: 1.0,
      kind: ProcEffectKind.grantCdRefund,
      magnitude: 0.5,
    ),
  ),
  FirmwareAffix(
    id: 'fw_halving_rebate',
    name: 'Halving Rebate',
    description: 'Halving → refund 50% of ability cooldowns.',
    rarity: FirmwareRarity.epic,
    signal: ProcSignal(
      id: 'fw_halving_rebate',
      name: 'Halving Rebate',
      event: ProcEvent.onHalving,
      chance: 1.0,
      kind: ProcEffectKind.grantCdRefund,
      magnitude: 0.5,
    ),
  ),
  FirmwareAffix(
    id: 'fw_fork_dividend',
    name: 'Fork Dividend',
    description: 'Hard Fork → +5 UTXO (survives the reset).',
    rarity: FirmwareRarity.epic,
    signal: ProcSignal(
      id: 'fw_fork_dividend',
      name: 'Fork Dividend',
      event: ProcEvent.onHardFork,
      chance: 1.0,
      kind: ProcEffectKind.grantUtxo,
      magnitude: 5,
    ),
  ),
  FirmwareAffix(
    id: 'fw_genesis_windfall',
    name: 'Genesis Windfall',
    description: 'New Blockchain → a free supply crate.',
    rarity: FirmwareRarity.legendary,
    signal: ProcSignal(
      id: 'fw_genesis_windfall',
      name: 'Genesis Windfall',
      event: ProcEvent.onGenesis,
      chance: 1.0,
      kind: ProcEffectKind.grantCrateRoll,
      magnitude: 1,
    ),
  ),
];

/// Owns the equipped firmware loadout (≤ capacity), capacity math, the
/// equipped-signal projection (with CO-PROCESSOR chance scaling), and
/// persistence. The loadout is a Time-Capsule loadout: it survives every prestige
/// reset and is cleared only by a full Wipe.
class FirmwareSystem {
  final List<String> equipped = []; // ordered socket contents (affix ids)

  static FirmwareAffix? byId(String id) {
    for (final a in kFirmwareAffixes) {
      if (a.id == id) return a;
    }
    return null;
  }

  bool isEquipped(String id) => equipped.contains(id);

  /// Socket capacity: base 3 + [bonusSlots] (Firmware Bay / Mastery 2 / deep
  /// doctrine), clamped to the [firmwareMaxSlots] cap — unless CO-PROCESSOR is
  /// equipped, which overrides to [firmwareCoProcessorSlots] (at reduced chance).
  static int capacity({required int bonusSlots, required bool coProcessor}) {
    if (coProcessor) return GameConstants.firmwareCoProcessorSlots;
    final n = GameConstants.firmwareBaseSlots + bonusSlots;
    return n > GameConstants.firmwareMaxSlots
        ? GameConstants.firmwareMaxSlots
        : n;
  }

  /// Equip/unequip [id]. Refuses to equip an unknown affix or past [cap]. Returns
  /// the new equipped state (or the current one on refusal).
  bool toggle(String id, int cap) {
    if (equipped.contains(id)) {
      equipped.remove(id);
      return false;
    }
    if (byId(id) == null) return false;
    if (equipped.length >= cap) return false;
    equipped.add(id);
    return true;
  }

  /// The ProcSignals of the ACTIVE equipped affixes — the first [cap] sockets
  /// (chance-scaled when CO-PROCESSOR trades chance for extra sockets). The saved
  /// loadout is never trimmed, so an era-scoped capacity dip (e.g. doctrines reset
  /// by a Hard Fork) just parks the overflow affixes dormant until it returns —
  /// they are not lost.
  List<ProcSignal> equippedSignals({required bool coProcessor, required int cap}) {
    final out = <ProcSignal>[];
    for (final id in equipped.take(cap < 0 ? 0 : cap)) {
      final a = byId(id);
      if (a == null) continue;
      out.add(coProcessor
          ? a.signal.withChanceMult(GameConstants.firmwareCoProcessorChanceMult)
          : a.signal);
    }
    return out;
  }

  List<String> toJson() => List<String>.from(equipped);
  void loadFrom(dynamic data) {
    equipped.clear();
    if (data is List) {
      equipped.addAll(data.whereType<String>());
    }
  }

  void reset() => equipped.clear();
}
