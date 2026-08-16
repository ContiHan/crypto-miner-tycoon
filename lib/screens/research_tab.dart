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
/// top→down by prerequisite depth, chained to their parents. Tapping a node
/// opens a detail sheet with the real BUY button.
class ResearchTab extends StatelessWidget {
  const ResearchTab({super.key});

  static const double _levelH = 130; // vertical gap between prerequisite depths
  static const double _nodeGap = 172; // horizontal gap between sibling nodes

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
                const SizedBox(height: 10),
                _PresetBar(game: game),
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

    // STABLE layout: bucket ALL nodes (not just the visible ones) by depth and
    // give each a FIXED position. Vertical: prereq depth → row (top-down),
    // siblings within a depth → columns centred on the canvas. Because positions
    // come from the WHOLE tree, buying a node changes only which nodes are DRAWN,
    // never where any node sits — so the view never jumps to a newly-revealed
    // node on a purchase.
    final allBuckets = <int, List<ResearchNode>>{};
    for (final n in game.researchNodes) {
      allBuckets.putIfAbsent(depth[n.id] ?? 0, () => []).add(n);
    }
    final maxDepth =
        allBuckets.keys.isEmpty ? 0 : allBuckets.keys.reduce(math.max);
    final maxBucket =
        allBuckets.values.fold(1, (m, l) => math.max(m, l.length));
    final canvasW = math.max(360.0, maxBucket * _nodeGap + 160);
    final centerX = canvasW / 2;
    final pos = <String, Offset>{};
    allBuckets.forEach((d, list) {
      for (int s = 0; s < list.length; s++) {
        final x = centerX + (s - (list.length - 1) / 2) * _nodeGap;
        final y = 90 + d * _levelH;
        pos[list[s].id] = Offset(x, y.toDouble());
      }
    });

    // Render only the visible subset, at their stable positions.
    final nodes = <GraphNode>[];
    final edges = <GraphEdge>[];
    for (final n in game.researchNodes) {
      if (!rendered(n)) continue;
      final p = pos[n.id]!;
      final costSats = game.getResearchCost(n.id);
      final canAfford = game.wallet >= costSats;
      // Doctrine exclusivity: a requirement-unlocked node whose pair is closed
      // (sibling committed, or the 2-pair budget is spent) is LOCKED for the run.
      final doctrineLocked =
          n.isUnlocked && !n.isCompleted && game.isResearchDoctrineLocked(n.id);
      GraphNodeState state;
      String sublabel;
      if (n.isCompleted) {
        state = GraphNodeState.owned;
        sublabel = 'ACTIVE';
      } else if (doctrineLocked) {
        state = GraphNodeState.available; // name/icon shown, but not buyable
        sublabel = 'LOCKED';
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
        icon: doctrineLocked ? Icons.lock_outline : n.icon,
        state: state,
        canAfford: canAfford && !doctrineLocked,
        isGenesis: n.requirements.isEmpty,
        onTap: () => doctrineLocked
            ? _openDoctrineLockedSheet(context, game, n)
            : _openResearchSheet(context, game, n, costSats, canAfford, state),
      ));
      for (final r in n.requirements) {
        final req = byId[r];
        if (req != null && rendered(req)) edges.add(GraphEdge(r, n.id));
      }
    }

    return BlockGraph(
      nodes: nodes,
      edges: edges,
      graphSize: Size(canvasW, 90 + maxDepth * _levelH + 160),
      initialFocus: Offset(centerX, 90), // centre on the root (top)
      edgeStyle: GraphEdgeStyle.elbow, // clean circuit routing for the tree
    );
  }

  void _openDoctrineLockedSheet(
      BuildContext context, GameLogic game, ResearchNode n) {
    final atBudget =
        game.committedDoctrinePairs >= GameLogic.doctrineCommitmentBudget;
    showGraphNodeSheet(
      context,
      title: n.name.toUpperCase(),
      description: n.description,
      lockedHint: atBudget
          ? 'DOCTRINE LOCKED — you\'ve committed your '
              '${GameLogic.doctrineCommitmentBudget} doctrine pairs. This branch '
              'frees up when TECH resets at your next fork.'
          : 'DOCTRINE LOCKED — you committed the opposing doctrine in this pair. '
              'Only one side per pair; it frees up at your next fork.',
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

/// Compact preset controls: save the current build, one-tap re-apply a saved
/// build, and toggle auto-apply. Guide text is inline (guide-everywhere).
class _PresetBar extends StatelessWidget {
  final GameLogic game;
  const _PresetBar({required this.game});

  @override
  Widget build(BuildContext context) {
    final presets = game.techPresets;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () {
                game.saveTechPreset();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Build saved'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ));
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accent,
                side: const BorderSide(color: AppTheme.accent),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: const Size(0, 34),
              ),
              icon: const Icon(Icons.bookmark_add_outlined, size: 16),
              label: const Text('SAVE BUILD', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 8),
            // AUTO-APPLY toggle.
            GestureDetector(
              onTap: () => game.setAutoApplyPresets(!game.autoApplyPresets),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: game.autoApplyPresets
                      ? AppTheme.accent.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: game.autoApplyPresets
                          ? AppTheme.accent
                          : Colors.white24),
                ),
                child: Text(
                  game.autoApplyPresets ? 'AUTO ✓' : 'AUTO',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: game.autoApplyPresets
                        ? AppTheme.accent
                        : Colors.white54,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (presets.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < presets.length; i++)
                ActionChip(
                  label: Text(presets[i].name,
                      style: const TextStyle(fontSize: 11)),
                  avatar: Icon(
                    i == game.activeTechPreset
                        ? Icons.play_circle_fill
                        : Icons.play_circle_outline,
                    size: 15,
                    color: AppTheme.accent,
                  ),
                  backgroundColor: i == game.activeTechPreset
                      ? AppTheme.accent.withValues(alpha: 0.15)
                      : AppTheme.background,
                  onPressed: () {
                    final n = game.applyTechPreset(i);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(n > 0
                          ? 'Applied ${presets[i].name} (+$n nodes)'
                          : '${presets[i].name}: nothing affordable yet'),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ));
                  },
                ),
            ],
          ),
        ],
        const SizedBox(height: 6),
        Text(
          game.autoApplyPresets
              ? 'Your active build re-applies automatically after every reset. Tap a build to apply it now.'
              : 'Auto-apply is OFF. Tap a saved build to re-tech it manually.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
      ],
    );
  }
}
