import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_logic.dart';
import '../logic/channels.dart';
import '../logic/managers/perk_manager.dart';
import '../theme/app_theme.dart';
import '../utils/formatter.dart';
import '../widgets/tech_graph.dart';
import '../widgets/graph_node_sheet.dart';
import '../widgets/class_picker.dart';

/// TALENTS (perks), rendered as a radial "spider" around a central GENESIS hub —
/// one branch per channel (click / hash / income / rigCost / special), perks
/// chained outward in unlock order. Perks have no real prerequisites, so the
/// edges are synthetic progression links. Tap a node to open its upgrade sheet.
class PerksScreen extends StatelessWidget {
  final bool isEmbedded;

  const PerksScreen({super.key, this.isEmbedded = false});

  static const double _r = 190;
  static const Offset _center = Offset(1200, 1200);
  static const double _canvas = 2400;

  // Branch angle per channel (clockwise from straight up). null = special spur.
  static const Map<Channel?, double> _branchDeg = {
    Channel.click: 0,
    Channel.hash: 72,
    Channel.income: 144,
    Channel.rigCost: 216,
    null: 288, // special (flat click-power perk)
  };

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
              final sb = StringBuffer();
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
    // Bucket perks by channel, ordered by unlock threshold.
    final buckets = <Channel?, List<MapEntry<String, PerkDef>>>{};
    for (final e in game.perkDefs.entries) {
      buckets.putIfAbsent(e.value.channel, () => []).add(e);
    }
    for (final list in buckets.values) {
      list.sort(
          (a, b) => a.value.unlockAtTokensEver.compareTo(b.value.unlockAtTokensEver));
    }

    final nodes = <GraphNode>[
      GraphNode(
        id: 'genesis',
        x: _center.dx,
        y: _center.dy,
        label: 'GENESIS',
        sublabel: Formatter.formatNumber(game.govTokens.toDouble()),
        icon: Icons.hub,
        state: GraphNodeState.owned,
        isGenesis: true,
      ),
    ];
    final edges = <GraphEdge>[];

    buckets.forEach((channel, list) {
      final deg = _branchDeg[channel] ?? 0;
      final theta = deg * math.pi / 180;
      String? prevId;
      for (int i = 0; i < list.length; i++) {
        final id = list[i].key;
        final def = list[i].value;
        final dist = (i + 1) * _r;
        final x = _center.dx + dist * math.sin(theta);
        final y = _center.dy - dist * math.cos(theta);

        final unlocked = game.isPerkUnlocked(id);
        final maxed = game.isPerkMaxed(id);
        final level = game.perks[id] ?? 0;
        final cost = game.perkCosts[id] ?? def.baseCost;
        final canAfford = unlocked && !maxed && game.govTokens >= cost;

        GraphNodeState state;
        String sublabel;
        if (!unlocked) {
          state = GraphNodeState.teaser;
          sublabel = '';
        } else if (maxed) {
          state = GraphNodeState.maxed;
          sublabel = 'MAX';
        } else if (level > 0) {
          state = GraphNodeState.owned;
          sublabel = 'Lv $level';
        } else {
          state = GraphNodeState.available;
          sublabel = '${Formatter.formatNumber(cost.toDouble())} GT';
        }

        nodes.add(GraphNode(
          id: id,
          x: x,
          y: y,
          label: def.name,
          sublabel: sublabel,
          icon: def.icon,
          state: state,
          canAfford: canAfford,
          onTap: () =>
              _openPerkSheet(context, game, id, def, cost, canAfford, state),
        ));

        edges.add(GraphEdge(prevId ?? 'genesis', id));
        prevId = id;
      }
    });

    return BlockGraph(
      nodes: nodes,
      edges: edges,
      graphSize: const Size(_canvas, _canvas),
      initialFocus: _center, // centre on the GENESIS hub
      legend: const _PerkLegend(),
    );
  }

  void _openPerkSheet(BuildContext context, GameLogic game, String id,
      PerkDef def, int cost, bool canAfford, GraphNodeState state) {
    if (state == GraphNodeState.teaser) {
      showGraphNodeSheet(
        context,
        title: '???',
        description: 'A locked talent.',
        lockedHint:
            'Unlocks at ${Formatter.formatNumber(def.unlockAtTokensEver)} GovTokens earned.',
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
          row(Colors.white24, 'locked → earn GovTokens'),
        ],
      ),
    );
  }
}
