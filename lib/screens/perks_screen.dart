import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/game_logic.dart';
import '../logic/channels.dart';
import '../logic/managers/perk_manager.dart';
import '../theme/app_theme.dart';
import '../utils/formatter.dart';
import '../widgets/tech_graph.dart';
import '../widgets/graph_node_sheet.dart';
import '../widgets/class_picker.dart';
import '../widgets/loadout_panels.dart';

/// SKILL — the active class's BESPOKE skill tree, rendered as a left→right depth
/// tree (elbow edges, same clean look as TECH). Each class has its own tailored
/// nodes; a node unlocks once its prerequisites are bought. Before a class is
/// chosen (Prospector) the tab prompts the player to pick one. Tap a node to open
/// its upgrade sheet (bought with GovTokens; resets each New Blockchain).
class PerksScreen extends StatelessWidget {
  final bool isEmbedded;

  const PerksScreen({super.key, this.isEmbedded = false});

  static const double _levelH = 130; // vertical gap between prerequisite depths
  static const double _nodeGap = 172; // horizontal gap between sibling nodes

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        // Header (verbatim): the GENESIS currency.
        Consumer<GameLogic>(
          builder: (context, game, _) => Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            color: Colors.black26,
            child: Column(
              children: [
                const Text('GOVERNANCE TOKENS',
                    style: TextStyle(
                        color: AppTheme.textSecondary, letterSpacing: 2)),
                const SizedBox(height: 6),
                Text(
                  Formatter.formatNumber(game.govTokens.toDouble()),
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.accent,
                  ),
                ),
                const Text('Tap a node to spend tokens. Drag to explore.',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
                const SizedBox(height: 10),
                // Class: pickable HERE as the FIRST choice (early, right when
                // SKILL unlocks). Once chosen you're LOCKED to it for the whole
                // run — re-pick only at a New Blockchain — so after the first
                // pick this becomes a locked readout, not a switch button.
                if (game.hasChosenClass)
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(game.currentClassDef.icon,
                              size: 16, color: game.currentClassDef.color),
                          const SizedBox(width: 6),
                          Text(
                            'CLASS: ${game.currentClassDef.name}',
                            style: TextStyle(
                              color: game.currentClassDef.color,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.lock_outline,
                              size: 13, color: Colors.white38),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Locked in until your next New Genesis',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  )
                else
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accent,
                      side: const BorderSide(color: AppTheme.accent),
                    ),
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('CHOOSE YOUR CLASS'),
                    onPressed: () => showClassPicker(
                      context,
                      game: game,
                      title: 'CHOOSE YOUR CLASS',
                      titleColor: AppTheme.accent,
                      confirmLabel: 'CHOOSE',
                      confirmColor: AppTheme.accent,
                      headerLabel: 'PICK AN ARCHETYPE:',
                      info: 'Your class reshapes the whole run (hash, cost, '
                          'prestige, luck). You LOCK IN to it until your next '
                          'New Genesis, so choose deliberately — Mastery is '
                          'earned per class and kept forever.',
                      onConfirm: (c) => game.chooseClass(c),
                    ),
                  ),
                // Live overview: passive racials + bonuses from SKILL nodes
                // bought this run + Mastery (so you can always see the class state).
                if (game.hasChosenClass) _classOverview(context, game),
                // Auras + keystones moved into a modal (like CLASS BONUSES) to
                // free up the cramped header — a summary row opens the loadout.
                if (game.hasChosenClass) _loadoutOverview(context, game),
              ],
            ),
          ),
        ),
        Expanded(
          child: Selector<GameLogic, String>(
            selector: (_, g) {
              final sb = StringBuffer()
                ..write(g.currentClass.name)
                ..write('|');
              for (final id in g.perkDefs.keys) {
                if (!g.isPerkUnlocked(id)) {
                  sb.write('.');
                } else if (g.isPerkMaxed(id)) {
                  sb.write('M');
                } else {
                  final lvl = g.perks[id] ?? 0;
                  sb
                    ..write(g.govTokens >= (g.perkCosts[id] ?? 1 << 30)
                        ? 'A'
                        : 'a')
                    ..write(lvl);
                }
              }
              sb.write('|${g.govTokens}');
              return sb.toString();
            },
            builder: (context, _, _) =>
                _graph(context, context.read<GameLogic>()),
          ),
        ),
      ],
    );

    if (isEmbedded) return content;
    return Scaffold(appBar: AppBar(title: const Text('SKILL')), body: content);
  }

  Widget _graph(BuildContext context, GameLogic game) {
    // Before a class is chosen there is no tree — prompt the player to pick one
    // (the chooser lives in the header above).
    if (!game.hasChosenClass) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_tree, size: 48, color: Colors.white24),
              SizedBox(height: 12),
              Text(
                'Choose your class above to unlock its skill tree.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // The active class's nodes (+ universal) laid out left→right by prereq depth.
    final cls = game.currentClass;
    final visible = <String, PerkDef>{
      for (final e in game.perkDefs.entries)
        if (e.value.btcClass == null || e.value.btcClass == cls) e.key: e.value,
    };

    // Depth = longest prerequisite chain (memoized; order-independent, no cycles).
    final depth = <String, int>{};
    int computeDepth(String id) {
      final cached = depth[id];
      if (cached != null) return cached;
      final def = visible[id];
      if (def == null || def.requires.isEmpty) return depth[id] = 0;
      var d = 0;
      for (final r in def.requires) {
        if (visible.containsKey(r)) d = math.max(d, computeDepth(r) + 1);
      }
      return depth[id] = d;
    }

    for (final id in visible.keys) {
      computeDepth(id);
    }

    // Bucket by depth (universal node shares column 0 with the class roots).
    final buckets = <int, List<String>>{};
    for (final id in visible.keys) {
      buckets.putIfAbsent(depth[id] ?? 0, () => []).add(id);
    }
    final maxDepth = buckets.keys.isEmpty ? 0 : buckets.keys.reduce(math.max);

    // Vertical layout: prereq depth → row (top-down); siblings within a depth →
    // column (centred on the canvas). Reads better on a tall/narrow phone.
    final maxBucket =
        buckets.values.fold(1, (m, l) => math.max(m, l.length));
    final canvasW = math.max(360.0, maxBucket * _nodeGap + 160);
    final centerX = canvasW / 2;
    final pos = <String, Offset>{};
    buckets.forEach((d, list) {
      for (int s = 0; s < list.length; s++) {
        final x = centerX + (s - (list.length - 1) / 2) * _nodeGap;
        final y = 90 + d * _levelH;
        pos[list[s]] = Offset(x, y.toDouble());
      }
    });

    final nodes = <GraphNode>[];
    final edges = <GraphEdge>[];
    visible.forEach((id, def) {
      final p = pos[id]!;
      final unlocked = game.isPerkUnlocked(id);
      final maxed = game.isPerkMaxed(id);
      final level = game.perks[id] ?? 0;
      final cost = game.perkCosts[id] ?? def.baseCost;
      final canAfford = unlocked && !maxed && game.govTokens >= cost;

      GraphNodeState state;
      String sublabel;
      if (maxed) {
        state = GraphNodeState.maxed;
        sublabel = 'MAX';
      } else if (level > 0) {
        state = GraphNodeState.owned;
        sublabel = 'Lv $level';
      } else if (unlocked) {
        state = GraphNodeState.available;
        sublabel = '${Formatter.formatNumber(cost.toDouble())} GT';
      } else {
        state = GraphNodeState.teaser;
        sublabel = '';
      }

      nodes.add(GraphNode(
        id: id,
        x: p.dx,
        y: p.dy,
        label: def.name,
        sublabel: sublabel,
        icon: def.icon,
        state: state,
        canAfford: canAfford,
        isGenesis: def.requires.isEmpty,
        onTap: () =>
            _openPerkSheet(context, game, id, def, cost, canAfford, state),
      ));
      for (final r in def.requires) {
        if (pos.containsKey(r)) edges.add(GraphEdge(r, id));
      }
    });

    return BlockGraph(
      nodes: nodes,
      edges: edges,
      graphSize: Size(canvasW, 90 + maxDepth * _levelH + 160),
      initialFocus: Offset(centerX, 90), // centre on the roots (top)
      edgeStyle: GraphEdgeStyle.elbow, // clean circuit routing like TECH
    );
  }

  /// Collapsible summary of the current class: passive racials + the bonuses the
  /// player has actually bought in the tree this run + Mastery.
  /// Tappable summary row that opens the CLASS BONUSES modal (replaces the old
  /// squished accordion — the modal lays each stat out as its own bullet line).
  Widget _classOverview(BuildContext context, GameLogic game) {
    final def = game.currentClassDef;
    return InkWell(
      onTap: () => _showClassBonusModal(context, game),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: def.color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(def.icon, color: def.color, size: 18),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('CLASS BONUSES',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
            ),
            Text('VIEW',
                style: TextStyle(
                    color: AppTheme.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1)),
            const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
          ],
        ),
      ),
    );
  }

  void _showClassBonusModal(BuildContext context, GameLogic game) {
    final def = game.currentClassDef;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: def.color.withValues(alpha: 0.5)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(def.icon, color: def.color, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        def.name.toUpperCase(),
                        style: GoogleFonts.orbitron(
                          color: def.color,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text('CLASS BONUSES',
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        letterSpacing: 2)),
                const SizedBox(height: 18),
                _bonusGroup('RACIALS', classEffectBullets(def), def.color),
                const SizedBox(height: 16),
                _bonusGroup('SKILLS', _activeSkillBullets(game), AppTheme.accent),
                const SizedBox(height: 16),
                _bonusGroup('MASTERY', _masteryBullets(game), Colors.greenAccent),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('CLOSE',
                        style: TextStyle(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Tappable summary row that opens the LOADOUT modal (auras/stance + keystones).
  /// Moved off the cramped SKILL header — mirrors the CLASS BONUSES row. Hidden
  /// until at least one of the two systems has something to show.
  Widget _loadoutOverview(BuildContext context, GameLogic game) {
    final hasAuras = game.availableAuras().isNotEmpty;
    final hasKeystones = game.availableKeystones().isNotEmpty;
    if (!hasAuras && !hasKeystones) return const SizedBox.shrink();

    final parts = <String>[];
    if (hasAuras) {
      final stance = game.equippedStance != null ? '1 stance' : 'no stance';
      parts.add('$stance · ${game.equippedAuras.length}/3 auras');
    }
    if (hasKeystones) parts.add('${game.equippedKeystoneCount}/2 keystones');

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: InkWell(
        onTap: () => _showLoadoutModal(context),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.tune, color: AppTheme.accent, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('AURAS & KEYSTONES',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5)),
                    if (parts.isNotEmpty)
                      Text(parts.join('  ·  '),
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 10)),
                  ],
                ),
              ),
              Text('VIEW',
                  style: TextStyle(
                      color: AppTheme.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
              const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  void _showLoadoutModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.accent.withValues(alpha: 0.4)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          // Consumer so toggling an aura/keystone inside the modal re-lights the
          // chips live (the modal is its own subtree, outside the header Consumer).
          child: Consumer<GameLogic>(
            builder: (context, game, _) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LOADOUT',
                      style: GoogleFonts.orbitron(
                        color: AppTheme.accent,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      )),
                  const Text('STANCE · AURAS · KEYSTONES',
                      style: TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                          letterSpacing: 2)),
                  const SizedBox(height: 8),
                  // Plain-language rules so the mechanic is self-explanatory.
                  const Text(
                    'Pick 1 STANCE and up to 3 AURAS (conditional passives). '
                    'KEYSTONES (up to 2) are build-defining levers you unlock by '
                    'finishing a TECH branch to its capstone. Filling an empty slot '
                    'is instant; swapping or removing one has a 60s lockout.',
                    style: TextStyle(
                        color: Colors.white54, fontSize: 11, height: 1.4),
                  ),
                  AurasPanel(game: game),
                  KeystonesPanel(game: game),
                  // When no branch capstone is owned yet, the keystones panel is
                  // empty — say why instead of showing nothing.
                  if (game.availableKeystones().isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        'KEYSTONES — none yet. Finish a TECH branch to its capstone '
                        'node to unlock that branch\'s keystones here.',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('CLOSE',
                          style: TextStyle(
                              color: AppTheme.accent,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A heading over a vertical bullet list of individual stat lines. Empty lists
  /// render a single muted "—" so the group never collapses to nothing.
  Widget _bonusGroup(String heading, List<String> bullets, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(heading,
            style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5)),
        const SizedBox(height: 8),
        if (bullets.isEmpty)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text('—',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
          )
        else
          ...bullets.map((b) => Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6, right: 10),
                      width: 5,
                      height: 5,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    Expanded(
                      child: Text(b,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              height: 1.3)),
                    ),
                  ],
                ),
              )),
      ],
    );
  }

  /// The channel bonuses from the active class's bought SKILL nodes (+ the
  /// universal flat-click node), one stat per bullet line.
  List<String> _activeSkillBullets(GameLogic game) {
    final cls = game.currentClass;
    final sums = <Channel, double>{};
    int flatClick = 0;
    game.perkDefs.forEach((id, def) {
      final lvl = game.perks[id] ?? 0;
      if (lvl <= 0) return;
      if (def.channel == null) {
        if (def.btcClass == null) flatClick += lvl * 2; // universal click node
        return;
      }
      if (def.btcClass != cls) return;
      double v = lvl * def.perLevel;
      if (def.maxLevel > 0) v = v.clamp(0.0, def.maxLevel * def.perLevel);
      sums[def.channel!] = (sums[def.channel!] ?? 0) + v;
    });

    final parts = <String>[];
    void add(Channel ch, String label, {bool neg = false}) {
      final v = sums[ch] ?? 0;
      if (v == 0) return;
      parts.add('${neg ? '-' : '+'}${(v * 100).toStringAsFixed(0)}% $label');
    }

    add(Channel.hash, 'hash');
    add(Channel.income, 'income');
    add(Channel.click, 'click');
    add(Channel.rigCost, 'rig cost', neg: true);
    add(Channel.luck, 'luck');
    if (flatClick > 0) parts.add('+$flatClick click power');
    return parts; // empty => modal shows "—" / "no skills bought yet"
  }

  /// Mastery status as bullet lines (or a single hint line when none earned yet).
  List<String> _masteryBullets(GameLogic game) {
    if (game.totalMasteryLevel <= 0) {
      return const ['None yet — earned by MINING as this class (one full 21M '
          'supply mined = Mastery 1); permanent, kept across resets'];
    }
    return [
      'Lv ${game.currentClassMasteryLevel} — this class',
      '+${(game.totalMasteryLevel * 0.5).toStringAsFixed(1)}% hash & income (all classes)',
    ];
  }

  void _openPerkSheet(BuildContext context, GameLogic game, String id,
      PerkDef def, int cost, bool canAfford, GraphNodeState state) {
    if (state == GraphNodeState.teaser) {
      final missing = def.requires
          .where((r) => (game.perks[r] ?? 0) < 1)
          .map((r) => game.perkDefs[r]?.name ?? r)
          .join(', ');
      showGraphNodeSheet(
        context,
        title: '???',
        description: 'A locked skill node.',
        lockedHint: missing.isEmpty
            ? 'Locked.'
            : 'Requires: $missing',
      );
      return;
    }
    if (state == GraphNodeState.maxed) {
      showGraphNodeSheet(
        context,
        title: def.name,
        description: def.description,
        effectText: game.perkBonusText(id),
        lockedHint: 'Maxed out.',
      );
      return;
    }
    showGraphNodeSheet(
      context,
      title: def.name,
      description: def.description,
      effectText: 'Current: ${game.perkBonusText(id)}',
      costLabel: '${Formatter.formatNumber(cost.toDouble())} GovTokens',
      canAfford: canAfford,
      buyLabel: 'UPGRADE',
      onBuy: () => game.buyPerk(id),
    );
  }
}

