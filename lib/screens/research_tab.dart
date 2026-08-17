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
                _RespecBar(game: game),
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
          for (var i = 0; i < presets.length; i++)
            _PresetRow(game: game, index: i),
        ],
        const SizedBox(height: 6),
        Text(
          game.autoApplyPresets
              ? 'APPLY re-teches a build now; your active build (▶) also re-applies '
                'automatically after every reset. UPDATE overwrites a slot with '
                'your current build; ✕ deletes it.'
              : 'Auto-apply is OFF. APPLY re-teches a build now; UPDATE overwrites '
                'a slot with your current build; ✕ deletes it.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
      ],
    );
  }
}

/// One saved-build row: APPLY (re-tech now) + UPDATE (overwrite this slot with
/// the current build) + delete. Separating APPLY from a tap-anywhere chip fixes
/// the "it auto-applies and I can't overwrite an older slot" complaint.
class _PresetRow extends StatelessWidget {
  final GameLogic game;
  final int index;
  const _PresetRow({required this.game, required this.index});

  @override
  Widget build(BuildContext context) {
    final preset = game.techPresets[index];
    final active = index == game.activeTechPreset;
    void snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ));

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.only(left: 10, right: 4),
      decoration: BoxDecoration(
        color: active
            ? AppTheme.accent.withValues(alpha: 0.12)
            : AppTheme.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: active ? AppTheme.accent : Colors.white12),
      ),
      child: Row(
        children: [
          Icon(active ? Icons.play_circle_fill : Icons.bookmark_outline,
              size: 15, color: AppTheme.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(preset.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              final n = game.applyTechPreset(index);
              snack(n > 0
                  ? 'Applied ${preset.name} (+$n nodes)'
                  : '${preset.name}: nothing affordable yet');
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.accent,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('APPLY', style: TextStyle(fontSize: 11)),
          ),
          IconButton(
            tooltip: 'Overwrite this slot with your current build',
            icon: const Icon(Icons.sync, size: 17),
            color: Colors.white54,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            onPressed: () {
              final ok = game.overwriteTechPreset(index);
              snack(ok
                  ? 'Updated slot to your current build (${game.techPresets[index].name})'
                  : 'Nothing researched yet — build not changed');
            },
          ),
          IconButton(
            tooltip: 'Delete this saved build',
            icon: const Icon(Icons.close, size: 17),
            color: Colors.white38,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            onPressed: () => _confirmDelete(context, preset.name),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String name) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('DELETE BUILD',
            style: TextStyle(color: Colors.orangeAccent)),
        content: Text('Delete the saved build "$name"? Your researched nodes '
            'stay — this only removes the saved preset.',
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              game.deleteTechPreset(index);
              Navigator.of(ctx).pop();
            },
            child: const Text('DELETE',
                style: TextStyle(
                    color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

/// The one-per-era free respec: wipes the TECH tree (uncommitting doctrines) so a
/// mis-picked build can be re-teched WITHOUT waiting for a fork. Blueprints (the
/// permanent re-tech discount) survive, so it's cheap to rebuild. Refreshes at
/// every fork. Only rendered once something is researched (nothing to undo before
/// then); shows a dim "spent" hint after use.
class _RespecBar extends StatelessWidget {
  final GameLogic game;
  const _RespecBar({required this.game});

  @override
  Widget build(BuildContext context) {
    if (game.respecSpent) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          'FREE RESPEC SPENT — refreshes at your next fork.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 10),
        ),
      );
    }
    if (!game.respecAvailable) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          OutlinedButton.icon(
            onPressed: () => _confirm(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orangeAccent,
              side: const BorderSide(color: Colors.orangeAccent),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              minimumSize: const Size(0, 34),
            ),
            icon: const Icon(Icons.restart_alt, size: 16),
            label: const Text('FREE RESPEC', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(height: 4),
          const Text(
            'One per era: clears the whole TECH tree and frees your committed '
            'doctrines. Blueprints (your re-tech discount) are kept.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }

  void _confirm(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('FREE RESPEC',
            style: TextStyle(color: Colors.orangeAccent)),
        content: const Text(
          'Clear the entire TECH tree? This uncommits every researched node and '
          'doctrine so you can pick a new build. You keep your blueprints, so '
          're-teching is cheaper.\n\nYou get ONE respec per era — it refreshes at '
          'your next fork.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              game.respecTech();
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('TECH tree cleared — pick a fresh build'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ));
            },
            child: const Text('RESPEC',
                style: TextStyle(
                    color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
