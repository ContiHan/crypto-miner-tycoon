import '../managers/research_manager.dart';

/// A keystone: one BIG build-defining lever with a symmetric real cost. You may
/// equip at most [KeystoneSystem.equipCap] (owner: 2), and only from doctrines
/// you've committed (they live at each doctrine's capstone). Effects are declared
/// as neutral-default modifier fields; GameLogic folds the equipped ones into a
/// [KeystoneModifiers] aggregate and applies it at the consumption sites.
class KeystoneDef {
  final String id;
  final String name;
  final String description;
  final Doctrine doctrine;

  // Multiplicative levers (1.0 = neutral).
  final double hashMult;
  final double incomeMult;
  final double clickMult;
  final double luckMult;
  final double prestigeGainMult;
  final double govTokenGainMult;
  final double idleMult;
  final double critPayoutMult;
  final double chaosPositiveMult;
  final double chaosNegativeMult;
  final double resistMult;
  final double breachLossMult;

  // Additive / flags.
  final double rigCostBonus; // + into the rigCost channel
  final bool offlineForceParity; // offline fraction → 1.0
  final bool noCrits; // taps never crit
  final bool immuneNegatives; // negative chaos never lands
  final bool suppressPositives; // positive chaos never fires
  final bool upkeepPinned; // upkeep forced to its cap

  const KeystoneDef({
    required this.id,
    required this.name,
    required this.description,
    required this.doctrine,
    this.hashMult = 1.0,
    this.incomeMult = 1.0,
    this.clickMult = 1.0,
    this.luckMult = 1.0,
    this.prestigeGainMult = 1.0,
    this.govTokenGainMult = 1.0,
    this.idleMult = 1.0,
    this.critPayoutMult = 1.0,
    this.chaosPositiveMult = 1.0,
    this.chaosNegativeMult = 1.0,
    this.resistMult = 1.0,
    this.breachLossMult = 1.0,
    this.rigCostBonus = 0.0,
    this.offlineForceParity = false,
    this.noCrits = false,
    this.immuneNegatives = false,
    this.suppressPositives = false,
    this.upkeepPinned = false,
  });
}

/// The aggregate of all equipped keystones' modifiers.
class KeystoneModifiers {
  final double hashMult;
  final double incomeMult;
  final double clickMult;
  final double luckMult;
  final double prestigeGainMult;
  final double govTokenGainMult;
  final double idleMult;
  final double critPayoutMult;
  final double chaosPositiveMult;
  final double chaosNegativeMult;
  final double resistMult;
  final double breachLossMult;
  final double rigCostBonus;
  final bool offlineForceParity;
  final bool noCrits;
  final bool immuneNegatives;
  final bool suppressPositives;
  final bool upkeepPinned;

  const KeystoneModifiers({
    this.hashMult = 1.0,
    this.incomeMult = 1.0,
    this.clickMult = 1.0,
    this.luckMult = 1.0,
    this.prestigeGainMult = 1.0,
    this.govTokenGainMult = 1.0,
    this.idleMult = 1.0,
    this.critPayoutMult = 1.0,
    this.chaosPositiveMult = 1.0,
    this.chaosNegativeMult = 1.0,
    this.resistMult = 1.0,
    this.breachLossMult = 1.0,
    this.rigCostBonus = 0.0,
    this.offlineForceParity = false,
    this.noCrits = false,
    this.immuneNegatives = false,
    this.suppressPositives = false,
    this.upkeepPinned = false,
  });

  static const KeystoneModifiers none = KeystoneModifiers();
}

/// The 12 keystones (2 per doctrine capstone). Each = one bounded lever + a
/// symmetric cost. Numbers from CHAOS_DEPTH §3.
const List<KeystoneDef> kKeystones = [
  // MEGA-HASH
  KeystoneDef(
    id: 'ks_asic_monoculture',
    name: 'ASIC Monoculture',
    description: '+100% hash — but luck ×0.4 and taps never crit.',
    doctrine: Doctrine.megaHash,
    hashMult: 2.0,
    luckMult: 0.4,
    noCrits: true,
  ),
  KeystoneDef(
    id: 'ks_furnace_farm',
    name: 'Furnace Farm',
    description: '+60% hash — but upkeep is pinned to its cap.',
    doctrine: Doctrine.megaHash,
    hashMult: 1.6,
    upkeepPinned: true,
  ),
  // LEAN-RIG
  KeystoneDef(
    id: 'ks_sweat_equity',
    name: 'Sweat Equity',
    description: 'Click ×2.5 — but passive hash ×0.5 and offline ×0.5.',
    doctrine: Doctrine.leanRig,
    clickMult: 2.5,
    hashMult: 0.5,
    idleMult: 0.5,
  ),
  KeystoneDef(
    id: 'ks_junkyard_rigs',
    name: 'Junkyard Rigs',
    description: 'Rigs slammed to the −95% floor — but −40% hash and breaches '
        'hit harder to shrug off.',
    doctrine: Doctrine.leanRig,
    rigCostBonus: 0.95,
    hashMult: 0.6,
    breachLossMult: 1.5,
  ),
  // HODLER
  KeystoneDef(
    id: 'ks_low_time_preference',
    name: 'Low Time Preference',
    description: 'Prestige gain ×1.5 and full offline parity — but −30% active '
        'income.',
    doctrine: Doctrine.hodler,
    prestigeGainMult: 1.5,
    offlineForceParity: true,
    incomeMult: 0.70,
  ),
  KeystoneDef(
    id: 'ks_cold_wallet_discipline',
    name: 'Cold Wallet Discipline',
    description: 'Offline parity and ×2 idle window — but −45% foreground income '
        'and no crits.',
    doctrine: Doctrine.hodler,
    offlineForceParity: true,
    idleMult: 2.0,
    incomeMult: 0.55,
    noCrits: true,
  ),
  // DEGEN-YIELD
  KeystoneDef(
    id: 'ks_paper_hands',
    name: 'Paper Hands',
    description: 'GovToken gain ×2 — but −25% passive income (you fork before it '
        'compounds).',
    doctrine: Doctrine.degenYield,
    govTokenGainMult: 2.0,
    incomeMult: 0.75, // the real, symmetric cost (was a phantom "Consensus decays")
  ),
  KeystoneDef(
    id: 'ks_market_maker',
    name: 'Market Maker',
    description: 'Positive events +50% — but negative events +50% and resists '
        'halved.',
    doctrine: Doctrine.degenYield,
    chaosPositiveMult: 1.5,
    chaosNegativeMult: 1.5,
    resistMult: 0.5,
  ),
  // DEGEN-LUCK
  KeystoneDef(
    id: 'ks_laser_eyes',
    name: 'Laser Eyes',
    description: 'Crit payout ×2 — but non-crit taps do far less.',
    doctrine: Doctrine.degenLuck,
    critPayoutMult: 2.0,
    clickMult: 0.5,
  ),
  KeystoneDef(
    id: 'ks_degenerate_gambler',
    name: 'Degenerate Gambler',
    description: 'Luck maxed for loot/SWEEP — but passive income ×0.5 and hash '
        '×0.5.',
    doctrine: Doctrine.degenLuck,
    luckMult: 2.0,
    incomeMult: 0.5,
    hashMult: 0.5,
  ),
  // COLD-STORAGE
  KeystoneDef(
    id: 'ks_cold_miner',
    name: 'Cold Miner',
    description: 'Immune to ALL negative events — but ALL positive events also '
        'never fire.',
    doctrine: Doctrine.coldStorage,
    immuneNegatives: true,
    suppressPositives: true,
  ),
  KeystoneDef(
    id: 'ks_fort_knox',
    name: 'Fort Knox',
    description: 'Breaches nearly nullified and resists maxed — but luck ×0.5 '
        'and no crits.',
    doctrine: Doctrine.coldStorage,
    breachLossMult: 0.2,
    resistMult: 1.3, // pushes resistances toward their caps
    luckMult: 0.5,
    noCrits: true,
  ),
];

/// Owns the equipped keystones (≤2, from committed doctrines) + persistence.
class KeystoneSystem {
  static const int equipCap = 2; // == the commitment budget

  final Set<String> equipped = {};

  KeystoneDef? byId(String id) {
    for (final k in kKeystones) {
      if (k.id == id) return k;
    }
    return null;
  }

  /// Keystones offered by the doctrines the run has committed to.
  List<KeystoneDef> availableFor(Set<Doctrine> committed) =>
      kKeystones.where((k) => committed.contains(k.doctrine)).toList();

  /// What the equip panel should list: the committed-doctrine keystones PLUS any
  /// still-equipped keystone whose doctrine is no longer committed (the loadout
  /// survives forks, but a fork resets doctrines — without this an equipped
  /// keystone from a now-uncommitted doctrine would keep applying yet be invisible
  /// and impossible to unequip).
  List<KeystoneDef> availableOrEquipped(Set<Doctrine> committed) {
    final out = availableFor(committed);
    final ids = out.map((k) => k.id).toSet();
    for (final id in equipped) {
      if (!ids.contains(id)) {
        final def = byId(id);
        if (def != null) out.add(def);
      }
    }
    return out;
  }

  bool isEquipped(String id) => equipped.contains(id);

  /// Toggle a keystone. Refuses if its doctrine isn't committed or the ≤2 cap is
  /// reached. Returns the new equipped state (or the current one on refusal).
  bool toggle(String id, Set<Doctrine> committed) {
    if (equipped.contains(id)) {
      equipped.remove(id);
      return false;
    }
    final def = byId(id);
    if (def == null || !committed.contains(def.doctrine)) return false;
    if (equipped.length >= equipCap) return false;
    equipped.add(id);
    return true;
  }

  /// Fold every equipped keystone's modifiers into one aggregate (mults multiply,
  /// flags OR, bonuses add).
  KeystoneModifiers aggregate() {
    double hash = 1, income = 1, click = 1, luck = 1, prestige = 1, gt = 1;
    double idle = 1, crit = 1, cpos = 1, cneg = 1, resist = 1, breach = 1;
    double rigCost = 0;
    bool offlineParity = false,
        noCrits = false,
        immuneNeg = false,
        suppressPos = false,
        upkeepPin = false;
    for (final id in equipped) {
      final k = byId(id);
      if (k == null) continue;
      hash *= k.hashMult;
      income *= k.incomeMult;
      click *= k.clickMult;
      luck *= k.luckMult;
      prestige *= k.prestigeGainMult;
      gt *= k.govTokenGainMult;
      idle *= k.idleMult;
      crit *= k.critPayoutMult;
      cpos *= k.chaosPositiveMult;
      cneg *= k.chaosNegativeMult;
      resist *= k.resistMult;
      breach *= k.breachLossMult;
      rigCost += k.rigCostBonus;
      offlineParity |= k.offlineForceParity;
      noCrits |= k.noCrits;
      immuneNeg |= k.immuneNegatives;
      suppressPos |= k.suppressPositives;
      upkeepPin |= k.upkeepPinned;
    }
    return KeystoneModifiers(
      hashMult: hash,
      incomeMult: income,
      clickMult: click,
      luckMult: luck,
      prestigeGainMult: prestige,
      govTokenGainMult: gt,
      idleMult: idle,
      critPayoutMult: crit,
      chaosPositiveMult: cpos,
      chaosNegativeMult: cneg,
      resistMult: resist,
      breachLossMult: breach,
      rigCostBonus: rigCost,
      offlineForceParity: offlineParity,
      noCrits: noCrits,
      immuneNegatives: immuneNeg,
      suppressPositives: suppressPos,
      upkeepPinned: upkeepPin,
    );
  }

  List<String> toJson() => equipped.toList();
  void loadFrom(dynamic data) {
    equipped.clear();
    if (data is List) {
      equipped.addAll(data.whereType<String>().take(equipCap));
    }
  }

  void reset() => equipped.clear();
}
