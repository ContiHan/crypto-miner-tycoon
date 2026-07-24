import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_logic.dart';
import '../models/research_node.dart';
import '../theme/app_theme.dart';
import '../utils/formatter.dart';
import '../widgets/tech_graph.dart';
import '../widgets/graph_node_sheet.dart';

/// TECH tree, rendered as a blockchain graph: research nodes are blocks laid out
/// left→right by prerequisite depth, chained to their parents. Tapping a node
/// opens a detail sheet with the real BUY button.
class ResearchTab extends StatelessWidget {
  const ResearchTab({super.key});

  static const double _colW = 200;
  static const double _rowH = 110;
  static const double _canvasH = 1000;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header — reactive (balance + fiat toggle), verbatim from the old list.
        Consumer<GameLogic>(
          builder: (context, game, _) => Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.surface,
            width: double.infinity,
            child: Column(
              children: [
                const Icon(Icons.science, size: 40, color: AppTheme.accent),
                const SizedBox(height: 5),
                const Text(
                  'TECH TREE',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accent,
                    letterSpacing: 2,
                  ),
                ),
                const Text(
                  'Tap a block to research it. Pinch/drag to explore the chain.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => game.toggleFiatDisplay(),
                  child: Text(
                    'BALANCE: ${game.showFiatPrices ? '\$ ${Formatter.formatNumber(game.toFiat(game.wallet))}' : Formatter.formatBitcoin(game.wallet)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Graph — gated by a fingerprint so the 1Hz income tick doesn't rebuild
        // it; only completion/unlock/affordability/fiat changes do.
        Expanded(
          child: Selector<GameLogic, String>(
            selector: (_, g) {
              final sb = StringBuffer();
              for (final n in g.researchNodes) {
                if (n.isCompleted) {
                  sb.write('C');
                } else if (n.isUnlocked) {
                  sb.write(g.wallet >= g.getResearchCost(n.id) ? 'A' : 'a');
                } else {
                  sb.write('.');
                }
              }
              sb.write(g.showFiatPrices ? 'F' : 'B');
              return sb.toString();
            },
            builder: (context, _, _) =>
                _graph(context, context.read<GameLogic>()),
          ),
        ),
      ],
    );
  }

  Widget _graph(BuildContext context, GameLogic game) {
    final byId = {for (final n in game.researchNodes) n.id: n};

    bool rendered(ResearchNode n) {
      if (n.isCompleted || n.isUnlocked) return true;
      // Frontier teaser: every prerequisite is at least visible.
      return n.requirements.every((r) {
        final req = byId[r];
        return req != null && (req.isCompleted || req.isUnlocked);
      });
    }

    // Depth = longest prerequisite chain from a root. Memoized recursion so it
    // is INDEPENDENT of list order (a node defined before its prereq still gets
    // the right column) — the DAG has no cycles.
    final depth = <String, int>{};
    int computeDepth(ResearchNode n) {
      final cached = depth[n.id];
      if (cached != null) return cached;
      if (n.requirements.isEmpty) return depth[n.id] = 0;
      var d = 0;
      for (final r in n.requirements) {
        final req = byId[r];
        if (req != null) d = math.max(d, computeDepth(req) + 1);
      }
      return depth[n.id] = d;
    }

    for (final n in game.researchNodes) {
      computeDepth(n);
    }

    // Bucket rendered nodes by depth (list order = slot order).
    final buckets = <int, List<ResearchNode>>{};
    for (final n in game.researchNodes) {
      if (!rendered(n)) continue;
      buckets.putIfAbsent(depth[n.id] ?? 0, () => []).add(n);
    }
    final maxDepth =
        buckets.keys.isEmpty ? 0 : buckets.keys.reduce(math.max);

    final pos = <String, Offset>{};
    buckets.forEach((d, list) {
      for (int s = 0; s < list.length; s++) {
        final x = 100 + d * _colW;
        final y = _canvasH / 2 + (s - (list.length - 1) / 2) * _rowH;
        pos[list[s].id] = Offset(x.toDouble(), y);
      }
    });

    final nodes = <GraphNode>[];
    final edges = <GraphEdge>[];
    buckets.forEach((d, list) {
      for (final n in list) {
        final p = pos[n.id]!;
        final costSats = game.getResearchCost(n.id);
        final canAfford = game.wallet >= costSats;
        GraphNodeState state;
        String sublabel;
        if (n.isCompleted) {
          state = GraphNodeState.owned;
          sublabel = 'ACTIVE';
        } else if (n.isUnlocked) {
          state = GraphNodeState.available;
          sublabel = game.showFiatPrices
              ? '\$ ${Formatter.formatNumber(game.toFiat(costSats))}'
              : Formatter.formatBitcoin(costSats);
        } else {
          state = GraphNodeState.teaser;
          sublabel = '';
        }
        nodes.add(GraphNode(
          id: n.id,
          x: p.dx,
          y: p.dy,
          label: n.name.toUpperCase(),
          sublabel: sublabel,
          icon: n.icon,
          state: state,
          canAfford: canAfford,
          isGenesis: n.requirements.isEmpty,
          onTap: () =>
              _openResearchSheet(context, game, n, costSats, canAfford, state),
        ));
        for (final r in n.requirements) {
          if (pos.containsKey(r)) edges.add(GraphEdge(r, n.id));
        }
      }
    });

    return BlockGraph(
      nodes: nodes,
      edges: edges,
      graphSize: Size(100 + maxDepth * _colW + 200, _canvasH),
      initialFocus: const Offset(100, _canvasH / 2), // centre on the root
      edgeStyle: GraphEdgeStyle.elbow, // clean circuit routing for the tree
      legend: const _Legend(lockedHint: 'locked → research the prerequisite'),
    );
  }

  void _openResearchSheet(BuildContext context, GameLogic game,
      ResearchNode n, double costSats, bool canAfford, GraphNodeState state) {
    final price = game.showFiatPrices
        ? '\$ ${Formatter.formatNumber(game.toFiat(costSats))}'
        : Formatter.formatBitcoin(costSats);
    if (state == GraphNodeState.owned) {
      showGraphNodeSheet(
        context,
        title: n.name.toUpperCase(),
        description: n.description,
        effectText: 'RESEARCHED — ACTIVE',
        lockedHint: 'Already researched.',
      );
    } else if (state == GraphNodeState.available) {
      showGraphNodeSheet(
        context,
        title: n.name.toUpperCase(),
        description: n.description,
        costLabel: price,
        canAfford: canAfford,
        buyLabel: 'RESEARCH',
        onBuy: () => game.buyResearch(n.id),
      );
    } else {
      // Teaser: name the missing prerequisites.
      final missing = n.requirements
          .map((r) => game.researchNodes
              .firstWhere((x) => x.id == r,
                  orElse: () => ResearchNode(id: r, name: r))
              .name)
          .join(', ');
      showGraphNodeSheet(
        context,
        title: '???',
        description: 'A locked research node.',
        lockedHint: missing.isEmpty
            ? 'Research the prerequisite first.'
            : 'Requires: $missing',
      );
    }
  }
}

/// Small legend chip anchored bottom-left of a graph.
class _Legend extends StatelessWidget {
  final String lockedHint;
  const _Legend({required this.lockedHint});

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
          row(Colors.white38, 'need more'),
          row(Colors.white24, lockedHint),
        ],
      ),
    );
  }
}
