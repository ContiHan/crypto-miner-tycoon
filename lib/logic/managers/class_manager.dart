import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../channels.dart';

/// The Bitcoin "class" you play a chain as (RPG Phase 3).
///
/// [prospector] is the class-less early game before a class is picked — no
/// bonuses, no Mastery. Once SKILL unlocks (first Hard Fork) the player picks one
/// of the four real archetypes and may switch freely thereafter; Mastery XP is
/// credited per GovToken at MINT time to whichever class was active then, so a
/// mid-run switch splits credit honestly and can't be farmed retroactively.
enum BtcClass { prospector, soloMiner, corporation, btcOg, poolMember }

/// Static definition of a class: its identity + how it reshapes the run.
///
/// Class edges are routed through the same additive channel model as every other
/// bonus (so they stack and soft-cap consistently), plus a single multiplicative
/// [prestigeGainMult] hook for CX/GT gain (the one attribute that isn't a live
/// channel). Increments are small and graduated per the RPG design (§3/§5).
class ClassDef {
  final String name;
  final String tagline;
  final String description;
  final IconData icon;
  final Color color;

  /// Additive channel weightings applied every buildChannels() (e.g. +0.20 hash).
  /// Negative values are debuffs (e.g. Corporation's worse prestige lives in
  /// [prestigeGainMult]; louder chaos is +volatility here).
  final Map<Channel, double> channelBonuses;

  /// Multiplies Consensus + GovToken GAIN (1.0 = neutral). BTC OG > 1 (best
  /// prestige farmer); Corporation < 1 (brute force, worse prestige efficiency).
  final double prestigeGainMult;

  const ClassDef({
    required this.name,
    required this.tagline,
    required this.description,
    required this.icon,
    required this.color,
    this.channelBonuses = const {},
    this.prestigeGainMult = 1.0,
  });
}

/// The four archetypes + the class-less Prospector. Weightings are intentionally
/// small (~2-20%) and each class trades a strength for a weakness so the choice
/// reshapes strategy without dominating the economy. [TUNE] via the sims.
const Map<BtcClass, ClassDef> kClasses = {
  BtcClass.prospector: ClassDef(
    name: 'PROSPECTOR',
    tagline: 'Not yet specialised',
    description:
        'The early game before your first New Genesis. No class bonuses '
        'yet — reach a New Genesis to choose your path.',
    icon: Icons.explore,
    color: Colors.blueGrey,
  ),
  BtcClass.soloMiner: ClassDef(
    name: 'SOLO MINER',
    tagline: 'Lone hacker in a garage',
    description:
        'Cheap, efficient and hands-on. Big discounts on rig cost, stronger '
        'manual clicks, and luckier anomaly/crate finds — but a lower raw '
        'output ceiling than the big players.',
    icon: Icons.person,
    color: Colors.greenAccent,
    channelBonuses: {
      Channel.rigCost: 0.20, // rigs 20% cheaper
      Channel.click: 0.15,
      Channel.luck: 0.10,
      Channel.nonce: 0.10, // hands-on: luckier critical taps
      Channel.magnetism: 0.10, // luckier anomaly/glitch finds
    },
  ),
  BtcClass.corporation: ClassDef(
    name: 'CORPORATION',
    tagline: 'Ruthless data-center',
    description:
        'Brute force — money is no object. Huge passive hash and income, but '
        'worse prestige efficiency and louder market chaos.',
    icon: Icons.corporate_fare,
    color: Colors.orangeAccent,
    channelBonuses: {
      Channel.hash: 0.20,
      Channel.income: 0.15,
      Channel.volatility: 0.15, // louder chaos (higher event frequency)
    },
    prestigeGainMult: 0.85, // worse prestige efficiency
  ),
  BtcClass.btcOg: ClassDef(
    name: 'BTC OG',
    tagline: 'Satoshi-era whale',
    description:
        'Manipulates the chain itself. The best prestige gains (Consensus / '
        'GovTokens / Genesis), luckier rare finds, steadier markets, and strong '
        'offline earnings — but a slow raw start.',
    icon: Icons.workspace_premium,
    color: Colors.amberAccent,
    channelBonuses: {
      Channel.hash: 0.05, // slow raw start
      Channel.luck: 0.08,
      Channel.volatility: -0.10, // steer the chaos: fewer events
      Channel.offline: 0.10, // Satoshi-era HODLer: earns well while away
    },
    prestigeGainMult: 1.25, // best prestige farmer
  ),
  BtcClass.poolMember: ClassDef(
    name: 'POOL MEMBER',
    tagline: 'Co-op collective',
    description:
        'Steady and low-variance. Far fewer/softer market crashes, better '
        'SWEEP odds, and reliable income — but no big spikes.',
    icon: Icons.groups,
    color: Colors.cyanAccent,
    channelBonuses: {
      Channel.income: 0.08,
      Channel.luck: 0.10,
      Channel.volatility: -0.25, // low variance: fewest events
      Channel.fortune: 0.05, // co-op collective: better crate drop quality
      Channel.sweepLuck: 0.10, // better SWEEP odds
      Channel.crashResist: 0.10, // softer crashes (resistance identity)
      Channel.durationResist: 0.10, // shorter bad events
    },
  ),
};

/// Owns the player's current class and permanent per-class Mastery.
///
/// Extracted from GameLogic (god-object pattern): GameLogic holds one instance,
/// feeds its channel/prestige contributions into the economy, and drives class
/// selection + Mastery crediting at each New Blockchain.
class ClassManager {
  BtcClass current = BtcClass.prospector;

  /// Permanent Mastery XP per class. Survives every prestige tier and only a
  /// full Wipe Save clears it. XP is the GovTokens minted while playing that
  /// class, accumulated across all of its chains.
  final Map<BtcClass, double> masteryXp = {
    for (final c in BtcClass.values) c: 0.0,
  };

  ClassDef get currentDef => kClasses[current]!;

  /// Whether the player has chosen a real class yet (past the Prospector start).
  bool get hasChosenClass => current != BtcClass.prospector;

  // ---- Mastery ------------------------------------------------------------

  /// Concave Mastery level for a class (sqrt of XP), so it always climbs but
  /// never runs away.
  int masteryLevel(BtcClass c) {
    final xp = masteryXp[c] ?? 0;
    if (xp <= 0) return 0;
    final lvl = sqrt(xp / GameConstants.masteryXpDivisor).floor();
    // Class level is capped at 18 (= the RP budget cap). See SKILL redesign S1.
    return lvl > GameConstants.classLevelMax ? GameConstants.classLevelMax : lvl;
  }

  /// Progress (0..1) toward the next class level for [c]; 1.0 once at the cap.
  double masteryProgress(BtcClass c) {
    final lvl = masteryLevel(c);
    if (lvl >= GameConstants.classLevelMax) return 1.0;
    final xp = masteryXp[c] ?? 0;
    final cur = lvl * lvl * GameConstants.masteryXpDivisor;
    final next = (lvl + 1) * (lvl + 1) * GameConstants.masteryXpDivisor;
    final span = next - cur;
    return span <= 0 ? 0.0 : ((xp - cur) / span).clamp(0.0, 1.0);
  }

  /// Sum of Mastery levels across every class — the permanent all-class bonus
  /// scales with this.
  int get totalMasteryLevel =>
      BtcClass.values.fold(0, (sum, c) => sum + masteryLevel(c));

  /// How many REAL classes (excluding Prospector) have reached Mastery >= 1 —
  /// drives the "play them all" achievement.
  int get masteredCount => BtcClass.values
      .where((c) => c != BtcClass.prospector && masteryLevel(c) >= 1)
      .length;

  /// Mastery level for a class looked up by its enum name (for AchStats, which
  /// is a plain data snapshot). Unknown names return 0.
  int masteryLevelByName(String name) {
    final c = BtcClass.values.firstWhere(
      (c) => c.name == name,
      orElse: () => BtcClass.prospector,
    );
    return masteryLevel(c);
  }

  /// Low-level: add [xp] Mastery XP to a class (Prospector earns nothing).
  void creditMastery(BtcClass playedAs, double xp) {
    if (playedAs == BtcClass.prospector || xp <= 0) return;
    masteryXp[playedAs] = (masteryXp[playedAs] ?? 0) + xp;
  }

  /// Credit Mastery from MINING: [minedSats] of income credited live to the
  /// class currently played. One full 21M supply mined = exactly one XP unit
  /// (masteryXpPerFullSupply), so Mastery tracks how much Bitcoin you've mined
  /// AS that class — un-farmable by rapid resetting (only mining grants it).
  void creditMasteryFromMining(BtcClass playedAs, double minedSats) {
    if (playedAs == BtcClass.prospector || minedSats <= 0) return;
    creditMastery(
      playedAs,
      GameConstants.masteryXpPerFullSupply *
          GameConstants.masteryXpSpeed *
          (minedSats / GameConstants.maxSupplySats),
    );
  }

  /// Debug/sim seam: set a class's level directly (by setting its XP to the amount
  /// the level curve needs). Used via GameLogic.debugSetClassLevel by tests + sims.
  void debugSetMasteryLevel(BtcClass c, int level) {
    if (c == BtcClass.prospector) return;
    final l = level < 0 ? 0 : level;
    masteryXp[c] = l * l * GameConstants.masteryXpDivisor.toDouble();
  }

  // ---- Economy contributions ---------------------------------------------

  /// Adds the current class's channel weightings AND the permanent all-class
  /// Mastery bonus into [ch]. Everything is additive within its channel and
  /// soft-capped downstream, so a class can never explode the economy.
  void contributeChannels(Channels ch) {
    currentDef.channelBonuses.forEach(ch.add);

    // Permanent Mastery bonus (all classes, including Prospector): a small hash
    // + income nudge that grows as you master more classes. Clamped so the faster
    // (level-driven) curve can't balloon it.
    final masteryBonus =
        (totalMasteryLevel * GameConstants.masteryBonusPerLevel)
            .clamp(0.0, GameConstants.masteryNudgeCap);
    if (masteryBonus > 0) {
      ch.add(Channel.hash, masteryBonus);
      ch.add(Channel.income, masteryBonus);
    }
  }

  /// Multiplier applied to Consensus + GovToken gain by the current class.
  double get prestigeGainMultiplier => currentDef.prestigeGainMult;

  // ---- Selection ----------------------------------------------------------

  /// Lock in a class for the next chain (called at a New Blockchain).
  void select(BtcClass c) => current = c;

  // ---- Persistence --------------------------------------------------------

  /// Serialises Mastery XP as {className: xp} for the save blob.
  Map<String, double> masteryJson() =>
      {for (final e in masteryXp.entries) e.key.name: e.value};

  /// Restore from a saved class name + Mastery map (both tolerant of nulls /
  /// unknown names so an old or corrupt save falls back to Prospector / 0 XP).
  void loadFrom(dynamic className, dynamic mastery) {
    current = BtcClass.values.firstWhere(
      (c) => c.name == className,
      orElse: () => BtcClass.prospector,
    );
    for (final c in BtcClass.values) {
      masteryXp[c] = 0.0;
    }
    if (mastery is Map) {
      mastery.forEach((k, v) {
        final match = BtcClass.values.firstWhere(
          (c) => c.name == k,
          orElse: () => BtcClass.prospector,
        );
        // Ignore an XP entry mislabelled as prospector (it earns none anyway).
        if (match != BtcClass.prospector && v is num) {
          masteryXp[match] = v.toDouble();
        }
      });
    }
  }

  /// Full Wipe Save: back to a class-less start with no Mastery.
  void reset() {
    current = BtcClass.prospector;
    for (final c in BtcClass.values) {
      masteryXp[c] = 0.0;
    }
  }
}
