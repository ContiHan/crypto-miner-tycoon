import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_logic.dart';
import '../logic/managers/perk_manager.dart';
import '../theme/app_theme.dart';
import '../utils/formatter.dart';
import '../widgets/tech_graph.dart';
import '../widgets/graph_node_sheet.dart';
import '../widgets/class_picker.dart';

/// SKILL — the active class's BESPOKE skill tree, rendered as a left→right depth
/// tree (elbow edges, same clean look as TECH). Each class has its own tailored
/// nodes; a node unlocks once its prerequisites are bought. Before a class is
/// chosen (Prospector) the tab prompts the player to pick one. Tap a node to open
/// its upgrade sheet (bought with GovTokens; resets each New Blockchain).
class PerksScreen extends StatelessWidget {
  final bool isEmbedded;

  const PerksScreen({super.key, this.isEmbedded = false});

  static const double _colW = 200;
  static const double _rowH = 110;
  static const double _canvasH = 1000;

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
                        'Locked in until your next New Blockchain',
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
                          'New Blockchain, so choose deliberately — Mastery is '
                          'earned per class and kept forever.',
                      onConfirm: (c) => game.chooseClass(c),
                    ),
                  ),
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

    final pos = <String, Offset>{};
    buckets.forEach((d, list) {
      for (int s = 0; s < list.length; s++) {
        final x = 100 + d * _colW;
        final y = _canvasH / 2 + (s - (list.length - 1) / 2) * _rowH;
        pos[list[s]] = Offset(x.toDouble(), y);
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
      graphSize: Size(100 + maxDepth * _colW + 200, _canvasH),
      initialFocus: const Offset(100, _canvasH / 2), // centre on the roots
      edgeStyle: GraphEdgeStyle.elbow, // clean circuit routing like TECH
      legend: const _PerkLegend(),
    );
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

class _PerkLegend extends StatelessWidget {
  const _PerkLegend();
  @override
  Widget build(BuildContext context) {
    Widget row(Color c, String t) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10, color: c),
            const SizedBox(width: 6),
            Text(t,
                style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          row(AppTheme.accent, 'owned / affordable'),
          row(Colors.greenAccent, 'maxed'),
          row(Colors.white24, 'locked → buy the prerequisite'),
        ],
      ),
    );
  }
}
