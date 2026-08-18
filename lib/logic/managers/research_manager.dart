import 'package:flutter/material.dart';
import '../../models/research_node.dart';
import '../../core/constants.dart';
import '../../core/ids.dart';
import '../channels.dart';

/// A saved TECH build: a name + the set of completed node ids. Applied by the
/// preset auto-buy to re-tech a build after a reset. Survives prestige resets.
class TechPreset {
  String name;
  final Set<String> nodeIds;
  TechPreset({required this.name, required this.nodeIds});

  Map<String, dynamic> toJson() => {'name': name, 'nodeIds': nodeIds.toList()};

  static TechPreset? fromJson(dynamic j) {
    if (j is! Map) return null;
    final name = j['name'];
    final ids = j['nodeIds'];
    if (name is! String || ids is! List) return null;
    return TechPreset(
      name: name,
      nodeIds: ids.whereType<String>().toSet(),
    );
  }
}

/// The three TECH V2 branches (see docs/TECH_TREE_REDESIGN_V2.md). Nodes carry a
/// `branch` string ('A' Foundry / 'B' Golden Nonce / 'C' Degen); the free CORE
/// spine has none. No opposed-pair locks — how many nodes you can own is bounded
/// by the per-fork Research-Point budget. Keystones unlock at each branch capstone.
class ResearchManager {
  // Data-driven LAB catalog. Most nodes declare an (effectChannel, effectValue)
  // applied generically via contributeChannels — adding a channel-effect node is
  // a one-line data edit. A null effectChannel marks a SPECIAL node (Chip Fab
  // per-rig-type bonus, AI auto-clicker) handled explicitly elsewhere.
  List<ResearchNode> researchNodes = [
    // === TECH V2 "Three Engines" ===
    // CORE spine (free — rpCost 0; sats-gated utility, absorbs the old
    // firmware/auto-click/chip-fab meta). Genesis Core is the shared root.
    ResearchNode(
      id: ResearchIds.genesisCore,
      name: 'Genesis Core',
      description: 'The mining rig boots. Unlocks the three research engines.',
      cost: 100,
      icon: Icons.hub,
      isUnlocked: true,
      isCompleted: true, // free root — always owned so the engines' roots unlock
      tier: 0,
      rpCost: 0,
    ),
    ResearchNode(
      id: ResearchIds.chipFab,
      name: 'Chip Fabrication',
      description: '+20% CPU & GPU Hash Rate',
      cost: 50000,
      icon: Icons.memory,
      requirements: [ResearchIds.genesisCore],
      tier: 0,
      rpCost: 0,
    ),
    ResearchNode(
      id: ResearchIds.aiManager,
      name: 'AI Management',
      description: 'Auto-clicks every 5 seconds',
      cost: 1000000,
      icon: Icons.psychology,
      requirements: [ResearchIds.chipFab],
      tier: 0,
      rpCost: 0,
    ),
    ResearchNode(
      id: ResearchIds.firmwareBay,
      name: 'Firmware Bay',
      description: '+1 Rig Firmware socket',
      cost: 15000000,
      icon: Icons.dashboard_customize,
      requirements: [ResearchIds.aiManager],
      tier: 0,
      rpCost: 0,
    ),
    // === A - THE FOUNDRY (hash + income) ===
    ResearchNode(
      id: ResearchIds.basicOverclock,
      name: 'Overclocked Cores',
      description: '+15% Global Hash Rate',
      cost: 500,
      icon: Icons.speed,
      requirements: [ResearchIds.genesisCore],
      effectChannel: Channel.hash,
      effectValue: 0.15,
      branch: 'A',
      tier: 1,
      rpCost: 1,
    ),
    ResearchNode(
      id: ResearchIds.neuralNet,
      name: 'Neural Net Miner',
      description: '+30% Global Hash Rate',
      cost: 500000,
      icon: Icons.hub,
      requirements: [ResearchIds.basicOverclock],
      effectChannel: Channel.hash,
      effectValue: 0.3,
      branch: 'A',
      lane: 'L',
      tier: 2,
      rpCost: 1,
    ),
    ResearchNode(
      id: ResearchIds.quantumEntanglement,
      name: 'Quantum Entanglement',
      description: '+50% Global Hash Rate',
      cost: 20000000,
      icon: Icons.blur_on,
      requirements: [ResearchIds.neuralNet],
      effectChannel: Channel.hash,
      effectValue: 0.5,
      branch: 'A',
      lane: 'L',
      tier: 3,
      rpCost: 1,
    ),
    ResearchNode(
      id: ResearchIds.coldStorageLogistics,
      name: 'Cold Storage Logistics',
      description: 'Rigs 20% cheaper, +15% offline, +8h idle',
      cost: 4000000,
      icon: Icons.ac_unit,
      requirements: [ResearchIds.quantumEntanglement],
      effects: {Channel.rigCost: 0.2, Channel.offline: 0.15, Channel.idle: 8.0},
      branch: 'A',
      lane: 'L',
      tier: 4,
      rpCost: 1,
    ),
    ResearchNode(
      id: ResearchIds.marketAnalytics,
      name: 'Market Analytics',
      description: '+20% Income',
      cost: 100000,
      icon: Icons.analytics,
      requirements: [ResearchIds.basicOverclock],
      effectChannel: Channel.income,
      effectValue: 0.2,
      branch: 'A',
      lane: 'R',
      tier: 2,
      rpCost: 1,
    ),
    ResearchNode(
      id: ResearchIds.highFrequencyTrading,
      name: 'High-Frequency Trading',
      description: '+35% Income',
      cost: 2000000,
      icon: Icons.trending_up,
      requirements: [ResearchIds.marketAnalytics],
      effectChannel: Channel.income,
      effectValue: 0.35,
      branch: 'A',
      lane: 'R',
      tier: 3,
      rpCost: 1,
    ),
    ResearchNode(
      id: ResearchIds.reinvestmentEngine,
      name: 'Reinvestment Engine',
      description: 'Reinvest 20% of your hash bonus as income (capped)',
      cost: 100000000,
      icon: Icons.autorenew,
      requirements: [ResearchIds.highFrequencyTrading],
      // No static channel: its whole effect is the bespoke hash->income synergy
      // folded into buildChannels (A7).
      branch: 'A',
      lane: 'R',
      tier: 4,
      rpCost: 1,
    ),
    ResearchNode(
      id: ResearchIds.centralBank,
      name: 'The Central Bank',
      description: '+50% Income, +40% Hash, +25% Prestige',
      cost: 10000000000,
      icon: Icons.account_balance,
      requirements: [ResearchIds.coldStorageLogistics, ResearchIds.reinvestmentEngine],
      effects: {Channel.income: 0.5, Channel.hash: 0.4, Channel.prestige: 0.25},
      branch: 'A',
      tier: 5,
      rpCost: 2,
    ),
    // === B - THE GOLDEN NONCE (click + crit) ===
    ResearchNode(
      id: ResearchIds.ergonomicRig,
      name: 'Ergonomic Rig',
      description: '+30% Click Power',
      cost: 20000,
      icon: Icons.back_hand,
      requirements: [ResearchIds.genesisCore],
      effectChannel: Channel.click,
      effectValue: 0.3,
      branch: 'B',
      tier: 1,
      rpCost: 1,
    ),
    ResearchNode(
      id: ResearchIds.noncePrediction,
      name: 'Nonce Prediction',
      description: '+10% Crit Chance',
      cost: 3000000,
      icon: Icons.casino,
      requirements: [ResearchIds.ergonomicRig],
      effectChannel: Channel.nonce,
      effectValue: 0.1,
      branch: 'B',
      lane: 'L',
      tier: 2,
      rpCost: 1,
    ),
    ResearchNode(
      id: ResearchIds.precisionHashing,
      name: 'Precision Hashing',
      description: '+50% Crit Payout',
      cost: 20000000,
      icon: Icons.center_focus_strong,
      requirements: [ResearchIds.noncePrediction],
      effectChannel: Channel.special,
      effectValue: 0.5,
      branch: 'B',
      lane: 'L',
      tier: 3,
      rpCost: 1,
    ),
    ResearchNode(
      id: ResearchIds.goldenNonceProtocol,
      name: 'Golden Nonce Protocol',
      description: '+5% Crit, every 12th tap a guaranteed golden nonce',
      cost: 60000000,
      icon: Icons.stars,
      requirements: [ResearchIds.precisionHashing],
      effectChannel: Channel.nonce,
      effectValue: 0.05,
      branch: 'B',
      lane: 'L',
      tier: 4,
      rpCost: 1,
    ),
    ResearchNode(
      id: ResearchIds.macroScripts,
      name: 'Macro Scripts',
      description: '+60% Click Power',
      cost: 400000,
      icon: Icons.terminal,
      requirements: [ResearchIds.ergonomicRig],
      effectChannel: Channel.click,
      effectValue: 0.6,
      branch: 'B',
      lane: 'R',
      tier: 2,
      rpCost: 1,
    ),
    ResearchNode(
      id: ResearchIds.aiCoPilot,
      name: 'AI Co-Pilot',
      description: '+15% Click Power, tightens the auto-tap interval',
      cost: 15000000,
      icon: Icons.smart_toy,
      requirements: [ResearchIds.macroScripts],
      effectChannel: Channel.click,
      effectValue: 0.15,
      branch: 'B',
      lane: 'R',
      tier: 3,
      rpCost: 1,
    ),
    ResearchNode(
      id: ResearchIds.immersionCooling,
      name: 'Immersion Cooling',
      description: '-25% Ability Cooldown',
      cost: 5000000,
      icon: Icons.water_drop,
      requirements: [ResearchIds.aiCoPilot],
      effectChannel: Channel.haste,
      effectValue: 0.25,
      branch: 'B',
      lane: 'R',
      tier: 4,
      rpCost: 1,
    ),
    ResearchNode(
      id: ResearchIds.powerCapacitors,
      name: 'Overclock The Core',
      description: '+75% Click, +50% Crit Payout, +40% Overcharge',
      cost: 10000000000,
      icon: Icons.bolt,
      requirements: [ResearchIds.goldenNonceProtocol, ResearchIds.immersionCooling],
      effects: {Channel.click: 0.75, Channel.special: 0.5, Channel.overcharge: 0.4},
      branch: 'B',
      tier: 5,
      rpCost: 2,
    ),
    // === C - THE DEGEN (luck + loot + chaos) ===
    ResearchNode(
      id: ResearchIds.luckyNonce,
      name: 'Lucky Nonce',
      description: '+8% Luck (crit, sweep, crate and anomaly odds)',
      cost: 200000,
      icon: Icons.auto_awesome,
      requirements: [ResearchIds.genesisCore],
      effectChannel: Channel.luck,
      effectValue: 0.08,
      branch: 'C',
      tier: 1,
      rpCost: 1,
    ),
    ResearchNode(
      id: ResearchIds.utxoMagnet,
      name: 'UTXO Magnet',
      description: '+10% Anomaly Luck, +10% SWEEP Luck',
      cost: 3000000,
      icon: Icons.explore,
      requirements: [ResearchIds.luckyNonce],
      effects: {Channel.magnetism: 0.1, Channel.sweepLuck: 0.1},
      branch: 'C',
      lane: 'L',
      tier: 2,
      rpCost: 1,
    ),
    ResearchNode(
      id: ResearchIds.assayLab,
      name: 'Assay Lab',
      description: '+12% Crate Drop Quality (+1 rarity)',
      cost: 8000000,
      icon: Icons.science,
      requirements: [ResearchIds.utxoMagnet],
      effectChannel: Channel.fortune,
      effectValue: 0.12,
      branch: 'C',
      lane: 'L',
      tier: 3,
      rpCost: 1,
    ),
    ResearchNode(
      id: ResearchIds.doubleDropManifold,
      name: 'Double-Drop Manifold',
      description: '+15% chance a crate open yields a SECOND crate',
      cost: 60000000,
      icon: Icons.inventory_2,
      requirements: [ResearchIds.assayLab],
      effectChannel: Channel.doubleDrop,
      effectValue: 0.15,
      branch: 'C',
      lane: 'L',
      tier: 4,
      rpCost: 1,
    ),
    ResearchNode(
      id: ResearchIds.volatilityEngine,
      name: 'Volatility Engine',
      description: '+25% Event Frequency, tilts chaos positive',
      cost: 12000000,
      icon: Icons.show_chart,
      requirements: [ResearchIds.luckyNonce],
      effects: {Channel.volatility: 0.25, Channel.bullBias: 1.0},
      branch: 'C',
      lane: 'R',
      tier: 2,
      rpCost: 1,
    ),
    ResearchNode(
      id: ResearchIds.hardenedVault,
      name: 'Hardened Vault',
      description: '+25% Crash / Theft / Cost resist',
      cost: 6000000,
      icon: Icons.shield,
      requirements: [ResearchIds.volatilityEngine],
      effects: {Channel.crashResist: 0.25, Channel.theftResist: 0.25, Channel.costResist: 0.25},
      branch: 'C',
      lane: 'R',
      tier: 3,
      rpCost: 1,
    ),
    ResearchNode(
      id: ResearchIds.diamondNerves,
      name: 'Diamond Nerves',
      description: '+30% Halving / Duration resist',
      cost: 40000000,
      icon: Icons.diamond,
      requirements: [ResearchIds.hardenedVault],
      effects: {Channel.halvingResist: 0.3, Channel.durationResist: 0.3},
      branch: 'C',
      lane: 'R',
      tier: 4,
      rpCost: 1,
    ),
    ResearchNode(
      id: ResearchIds.whalesEye,
      name: 'The Whale\'s Eye',
      description: '+15% Luck, +10% Double-Drop, +8% Drop Quality',
      cost: 10000000000,
      icon: Icons.visibility,
      requirements: [ResearchIds.doubleDropManifold, ResearchIds.diamondNerves],
      effects: {Channel.luck: 0.15, Channel.doubleDrop: 0.1, Channel.fortune: 0.08},
      branch: 'C',
      tier: 5,
      rpCost: 2,
    ),
  ];

  /// BLUEPRINTS: permanent per-node completion count. Survives every prestige
  /// reset (only a full Wipe Save clears it) and drives the re-tech discount.
  final Map<String, int> researchCount = {};

  /// Blueprint re-tech discount for a node id (0..blueprintMaxDiscount), concave
  /// in how many times it has been researched across all past runs.
  double blueprintDiscount(String id) {
    final n = researchCount[id] ?? 0;
    if (n <= 0) return 0.0;
    return GameConstants.blueprintMaxDiscount *
        (1 - 1 / (1 + n / GameConstants.blueprintDivisor));
  }

  /// Serialise blueprint counts for the save blob.
  Map<String, int> researchCountJson() => Map<String, int>.from(researchCount);

  /// Restore blueprint counts (tolerant of nulls / non-int values).
  void loadResearchCounts(dynamic data) {
    researchCount.clear();
    if (data is Map) {
      data.forEach((k, v) {
        if (k is String && v is num) researchCount[k] = v.toInt();
      });
    }
  }

  /// Full Wipe Save only: clears the permanent blueprint dividend.
  void wipeBlueprints() => researchCount.clear();

  // ---- Presets (Phase 3 QoL) ---------------------------------------------
  // A saved TECH build the player can one-tap re-apply after a reset. Presets
  // survive prestige resets (only a full Wipe clears them). Capped at 3 slots.

  final List<TechPreset> presets = [];
  int activePreset = -1; // index into [presets]; -1 = none
  bool autoApplyPresets = true; // owner: default ON, opt-out

  static const int maxPresets = 3;

  /// Themed auto-name from the dominant effect-channel of a completed set.
  String autoNameFor(Set<String> nodeIds) {
    final counts = <Channel, int>{};
    for (final id in nodeIds) {
      final node = researchNodes.firstWhere((n) => n.id == id,
          orElse: () => ResearchNode(id: ''));
      final ch = node.effectChannel;
      if (ch != null) counts[ch] = (counts[ch] ?? 0) + 1;
    }
    if (counts.isEmpty) return 'Custom Build';
    final dominant =
        counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    switch (dominant) {
      case Channel.hash:
        return 'Hash Whale';
      case Channel.income:
        return 'Yield Farmer';
      case Channel.rigCost:
        return 'Lean Machine';
      case Channel.click:
        return 'Click Tapper';
      case Channel.prestige:
        return 'Prestige Farmer';
      case Channel.offline:
        return 'HODLer';
      case Channel.special:
        return 'Crit Tapper';
      case Channel.fortune:
        return 'Fortune Hunter';
      case Channel.doubleDrop:
        return 'Loot Goblin';
      case Channel.nonce:
        return 'Sharp Shooter';
      case Channel.sweepLuck:
        return 'High Roller';
      case Channel.magnetism:
        return 'Anomaly Hunter';
      case Channel.idle:
        return 'Deep Sleeper';
      case Channel.crashResist:
      case Channel.costResist:
      case Channel.halvingResist:
      case Channel.durationResist:
      case Channel.theftResist:
        return 'Fortress';
      case Channel.haste:
      case Channel.overcharge:
        return 'Overclocker';
      case Channel.bullBias:
        return 'Bull Rider';
      case Channel.luck:
      case Channel.volatility:
        return 'Wildcard';
    }
  }

  /// Snapshot the currently-completed nodes into a new preset (auto-named),
  /// making it the active one. Capped at [maxPresets] (drops the oldest).
  /// No-op if nothing is completed. Returns the saved preset (or null).
  TechPreset? savePreset() {
    final ids = researchNodes
        .where((n) => n.isCompleted)
        .map((n) => n.id)
        .toSet();
    if (ids.isEmpty) return null;
    final preset = TechPreset(name: autoNameFor(ids), nodeIds: ids);
    presets.add(preset);
    while (presets.length > maxPresets) {
      presets.removeAt(0);
    }
    activePreset = presets.length - 1;
    return preset;
  }

  void renamePreset(int index, String name) {
    if (index >= 0 && index < presets.length && name.trim().isNotEmpty) {
      presets[index].name = name.trim();
    }
  }

  /// Overwrite an EXISTING slot with the currently-completed nodes (re-auto-named)
  /// and make it active. Lets the player update any slot (not only append a new
  /// one). No-op if the index is out of range or nothing is completed. Returns the
  /// updated preset (or null).
  TechPreset? overwritePreset(int index) {
    if (index < 0 || index >= presets.length) return null;
    final ids = researchNodes
        .where((n) => n.isCompleted)
        .map((n) => n.id)
        .toSet();
    if (ids.isEmpty) return null;
    final preset = TechPreset(name: autoNameFor(ids), nodeIds: ids);
    presets[index] = preset;
    activePreset = index;
    return preset;
  }

  /// Remove a preset slot, keeping [activePreset] pointing at the same preset (or
  /// clearing it if the active one was deleted). No-op if out of range.
  void deletePreset(int index) {
    if (index < 0 || index >= presets.length) return;
    presets.removeAt(index);
    if (activePreset == index) {
      activePreset = -1; // the active build is gone
    } else if (activePreset > index) {
      activePreset -= 1; // everything after the hole shifted down one
    }
    if (activePreset >= presets.length) activePreset = presets.length - 1;
  }

  List<Map<String, dynamic>> presetsJson() =>
      presets.map((p) => p.toJson()).toList();

  void loadPresets(dynamic data, dynamic active, dynamic auto) {
    presets.clear();
    if (data is List) {
      for (final e in data) {
        final p = TechPreset.fromJson(e);
        if (p != null) presets.add(p);
      }
    }
    activePreset = (active is num) ? active.toInt() : -1;
    if (activePreset >= presets.length) activePreset = presets.length - 1;
    autoApplyPresets = auto is bool ? auto : true;
  }

  void wipePresets() {
    presets.clear();
    activePreset = -1;
    autoApplyPresets = true;
  }

  // ---- Auto-apply re-tech (owner: default ON) ---------------------------
  // Auto-apply spends real (blueprint-discounted) BTC re-teching after a fork —
  // tiny vs. a built-up wallet, so it looks free. We accumulate the spend across
  // the (possibly multi-tick) rebuild and flush it once the batch settles, so the
  // UI can flash a "RE-TECH · −X" toast that makes the cost visible without
  // changing the economy. The wallet is reached through a per-call seam (getWallet
  // / setWallet) so this manager never owns the wallet.
  double _retechSpendAccum = 0;
  double _pendingRetechSpend = 0;

  /// BTC the last settled auto-apply batch spent (0 = nothing to show). The UI
  /// drains it with [clearReTechToast] after toasting it.
  double get pendingReTechSpend => _pendingRetechSpend;
  void clearReTechToast() => _pendingRetechSpend = 0;

  void _flushRetechSpend() {
    if (_retechSpendAccum <= 0) return;
    _pendingRetechSpend += _retechSpendAccum; // += so an undrained batch isn't lost
    _retechSpendAccum = 0;
  }

  double _costById(String id) {
    final node = researchNodes.firstWhere((r) => r.id == id,
        orElse: () => ResearchNode(id: ''));
    return node.id.isEmpty ? 0 : getCostInSats(node);
  }

  /// Buys every affordable, unlocked, still-incomplete node in [preset], cheapest
  /// first, repeating until a full pass buys nothing (so deeper nodes unlock as
  /// their prereqs complete). Reaches the wallet through the [getWallet]/[setWallet]
  /// seam. Returns how many nodes were bought.
  int rebuildFromPreset(TechPreset preset,
      {required double Function() getWallet,
      required void Function(double) setWallet,
      int rpBudget = 1 << 30}) {
    int bought = 0;
    final ids = preset.nodeIds.toList()
      ..sort((a, b) => _costById(a).compareTo(_costById(b)));
    bool progress = true;
    while (progress) {
      progress = false;
      for (final id in ids) {
        final cost = tryBuy(id, getWallet(), rpBudget: rpBudget);
        if (cost > 0) {
          setWallet(getWallet() - cost);
          bought++;
          progress = true;
        }
      }
    }
    return bought;
  }

  /// AUTO-APPLY: on the tick / after a reset, rebuild the active preset as income
  /// allows (fast no-op once complete / off / no preset). Accumulates the BTC
  /// spent (for the RE-TECH toast) and flushes it once the batch settles. Returns
  /// the nodes bought this call — >0 signals the caller to notify + save.
  int maybeAutoApply(
      {required double Function() getWallet,
      required void Function(double) setWallet,
      int rpBudget = 1 << 30}) {
    if (!autoApplyPresets) {
      _flushRetechSpend();
      return 0;
    }
    final i = activePreset;
    if (i < 0 || i >= presets.length) {
      _flushRetechSpend();
      return 0;
    }
    final preset = presets[i];
    final anyIncomplete = preset.nodeIds.any((id) {
      final n = researchNodes.firstWhere((r) => r.id == id,
          orElse: () => ResearchNode(id: ''));
      return n.id.isNotEmpty && !n.isCompleted;
    });
    if (!anyIncomplete) {
      _flushRetechSpend();
      return 0;
    }
    final before = getWallet();
    final bought = rebuildFromPreset(preset,
        getWallet: getWallet, setWallet: setWallet, rpBudget: rpBudget);
    if (bought > 0) {
      _retechSpendAccum += (before - getWallet()); // BTC spent this tick
    } else {
      _flushRetechSpend(); // couldn't afford more this tick — the batch settled
    }
    return bought;
  }

  void reset() {
    for (var node in researchNodes) {
      // The free Genesis Core root stays owned so the engines' roots stay reachable.
      if (node.id == ResearchIds.genesisCore) {
        node.isCompleted = true;
        node.isUnlocked = true;
        continue;
      }
      node.isCompleted = false;
      node.isUnlocked = node.requirements.isEmpty;
    }
    _checkUnlocks(); // re-unlock the branch roots (their prereq, the core, is owned)
    // NOTE: researchCount (blueprints) is intentionally NOT cleared here — it is
    // permanent across prestige resets.
  }

  // ---- TECH V2: branches + Research-Point budget -------------------------
  /// The branch a node belongs to ('A'/'B'/'C'), or null for the free core spine.
  String? branchOf(String id) {
    final i = researchNodes.indexWhere((n) => n.id == id);
    return i == -1 ? null : researchNodes[i].branch;
  }

  /// The capstone (tier-5) node id of [branch], or null.
  String? capstoneIdOf(String branch) {
    for (final n in researchNodes) {
      if (n.branch == branch && n.tier == 5) return n.id;
    }
    return null;
  }

  /// Branches whose CAPSTONE node is owned — this is what unlocks that branch's
  /// keystones (replaces the old "doctrine committed" gate).
  Set<String> branchesWithCapstoneOwned() {
    final s = <String>{};
    for (final n in researchNodes) {
      if (n.tier == 5 && n.isCompleted && n.branch != null) s.add(n.branch!);
    }
    return s;
  }

  /// Research Points currently spent = sum of the rpCost of every completed node.
  /// The free core spine (rpCost 0) never consumes budget.
  int get rpSpent {
    var t = 0;
    for (final n in researchNodes) {
      if (n.isCompleted) t += n.rpCost;
    }
    return t;
  }

  /// Re-derives unlock state from completed nodes. Called after loading a save so
  /// that nodes ADDED after that save was written (whose prerequisites are
  /// already completed) become purchasable instead of being stuck as locked
  /// "???" frontier teasers — otherwise a content update soft-locks the LAB.
  void refreshUnlocks() => _checkUnlocks();

  /// Adds every completed node's declared channel effect to [ch].
  void contributeChannels(Channels ch) {
    for (final node in researchNodes) {
      if (!node.isCompleted) continue;
      if (node.effectChannel != null) {
        ch.add(node.effectChannel!, node.effectValue);
      }
      // TECH V2 multi-channel nodes (capstones etc.) add every declared effect.
      node.effects.forEach(ch.add);
    }
  }

  // Returns cost if success (so caller can deduct wallet), 0 if failed.
  // [rpBudget] caps how much total rpCost the completed nodes may sum to (the
  // per-fork Research-Point budget); default unbounded for callers that don't gate.
  double tryBuy(
    String researchId,
    double currentWallet, {
    int rpBudget = 1 << 30,
  }) {
    int index = researchNodes.indexWhere((r) => r.id == researchId);
    if (index == -1) return 0;

    ResearchNode node = researchNodes[index];
    if (node.isCompleted) return 0;
    // Branch-depth gate: every prerequisite must already be owned.
    if (!node.requirements.every(isResearched)) return 0;
    // Research-Point budget: owning this node must not exceed the fork's budget.
    if (rpSpent + node.rpCost > rpBudget) return 0;

    double costSats = getCostInSats(node);

    if (currentWallet >= costSats) {
      node.isCompleted = true;
      // BLUEPRINTS: record the completion permanently (drives the re-tech discount
      // on every future run).
      researchCount[researchId] = (researchCount[researchId] ?? 0) + 1;
      _checkUnlocks();
      return costSats;
    }
    return 0;
  }

  double getCostInSats(ResearchNode node) {
    final double base = node.cost;
    // Combined discount (blueprint now; a future R&D doctrine adds here), with the
    // #3 FLOOR so stacked discounts can never drive the price below techCostFloor.
    final double totalDiscount = blueprintDiscount(node.id);
    double factor = 1.0 - totalDiscount;
    if (factor < GameConstants.techCostFloor) factor = GameConstants.techCostFloor;
    return base * factor;
  }

  void _checkUnlocks() {
    for (var node in researchNodes) {
      if (!node.isUnlocked && !node.isCompleted) {
        bool allMet = node.requirements.every((reqId) {
          var reqNode = researchNodes.firstWhere(
            (r) => r.id == reqId,
            orElse: () => ResearchNode(
              id: '',
              name: '',
              description: '',
              cost: 0,
              icon: Icons.error,
            ),
          );
          return reqNode.isCompleted;
        });
        if (allMet) node.isUnlocked = true;
      }
    }
  }

  bool isResearched(String id) {
    var node = researchNodes.firstWhere(
      (r) => r.id == id,
      orElse: () => ResearchNode(
        id: '',
        name: '',
        description: '',
        cost: 0,
        icon: Icons.error,
      ),
    );
    return node.isCompleted;
  }
}
