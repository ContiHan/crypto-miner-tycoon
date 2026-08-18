import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_logic.dart';
import '../models/research_node.dart';
import '../logic/managers/research_manager.dart' show Doctrine;
import '../theme/app_theme.dart';
import '../utils/formatter.dart';
import '../widgets/tech_graph.dart';
import '../widgets/graph_node_sheet.dart';
import '../widgets/tech_preset_bar.dart';

/// TECH tree, rendered as a blockchain graph: research nodes are blocks laid out
/// top→down by prerequisite depth, chained to their parents. Tapping a node
/// opens a detail sheet with the real BUY button.
class ResearchTab extends StatelessWidget {
  const ResearchTab({super.key});

  static const double _levelH = 130; // vertical gap between prerequisite depths
  static const double _nodeGap = 172; // horizontal gap between sibling stem nodes
  // Doctrine LANES: each doctrine is a fixed column you scroll DOWN; paired
  // siblings sit adjacent, a wider gap separates the three pairs.
  static const double _laneGap = 150; // gap between lane columns
  static const double _pairGap = 74; // extra gap between exclusive pairs
  static const double _laneMargin = 110; // left/right margin around the lanes
  // Fixed lane order — pairs adjacent so "one or the other" reads spatially.
  static const List<Doctrine> _laneOrder = [
    Doctrine.megaHash, Doctrine.leanRig, // output: brute hash ⟂ lean click/cost
    Doctrine.degenYield, Doctrine.hodler, // money: trade ⟂ hodl
    Doctrine.degenLuck, Doctrine.coldStorage, // variance: gamble ⟂ fortress
  ];
  // Header chip per lane: name + the attribute it leans into, so "the lean" is
  // explicit. (label, colour) — colours match the redesign mockup.
  static const Map<Doctrine, (String, Color)> _laneInfo = {
    Doctrine.megaHash: ('MEGA-HASH\n+HASH', Color(0xFFFF8A3D)),
    Doctrine.leanRig: ('LEAN-RIG\nCLICK + COST', Color(0xFFFFD23D)),
    Doctrine.degenYield: ('DEGEN-YIELD\n+INCOME', Color(0xFF3FD07F)),
    Doctrine.hodler: ('HODLER\nPATIENCE', Color(0xFF3FB6D0)),
    Doctrine.degenLuck: ('DEGEN-LUCK\n+LUCK', Color(0xFFC46BFF)),
    Doctrine.coldStorage: ('COLD-STORAGE\n+RESIST', Color(0xFF5D7BFF)),
  };

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
                TechPresetBar(game: game),
                RespecBar(game: game),
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

    // STABLE LANE layout. TRUNK + META are a short shared stem centred at the top
    // (kept depth-bucketed). Each of the six doctrines is a fixed vertical COLUMN
    // below the stem — its nodes stack straight down in commit order. Canvas width
    // is capped by the lane count (~6 columns), NOT the widest depth row, so you
    // scroll DOWN a lane instead of panning sideways. Positions come from the WHOLE
    // tree, so buying only changes which nodes DRAW, never where any node sits.
    final stem = <ResearchNode>[];
    final lanes = <Doctrine, List<ResearchNode>>{};
    for (final n in game.researchNodes) {
      final doc = game.researchDoctrine(n.id);
      if (doc == Doctrine.trunk || doc == Doctrine.meta) {
        stem.add(n);
      } else {
        lanes.putIfAbsent(doc, () => []).add(n);
      }
    }
    final stemBuckets = <int, List<ResearchNode>>{};
    for (final n in stem) {
      stemBuckets.putIfAbsent(depth[n.id] ?? 0, () => []).add(n);
    }
    final stemMaxDepth =
        stemBuckets.keys.isEmpty ? 0 : stemBuckets.keys.reduce(math.max);
    final stemMaxBucket =
        stemBuckets.values.fold(1, (m, l) => math.max(m, l.length));

    double laneX(int lane) =>
        _laneMargin + lane * _laneGap + (lane ~/ 2) * _pairGap;
    final canvasW = math.max(
      stemMaxBucket * _nodeGap + 160, // the stem must fit
      laneX(_laneOrder.length - 1) + _laneMargin,
    );
    final centerX = canvasW / 2;
    final pos = <String, Offset>{};
    // Stem: centred per depth, top band.
    stemBuckets.forEach((d, list) {
      for (int s = 0; s < list.length; s++) {
        pos[list[s].id] = Offset(
          centerX + (s - (list.length - 1) / 2) * _nodeGap,
          (90 + d * _levelH).toDouble(),
        );
      }
    });
    // Lanes start below the stem; each doctrine sorted by depth → row (tier).
    final laneTop = 90 + (stemMaxDepth + 1) * _levelH + 24;
    var maxTier = 0;
    lanes.forEach((doc, list) {
      list.sort((a, b) => (depth[a.id] ?? 0).compareTo(depth[b.id] ?? 0));
      final lane = _laneOrder.indexOf(doc);
      final x = lane < 0 ? centerX : laneX(lane);
      for (int t = 0; t < list.length; t++) {
        pos[list[t].id] = Offset(x, laneTop + t * _levelH);
      }
      if (list.length > maxTier) maxTier = list.length;
    });
    final canvasH = laneTop + maxTier * _levelH + 120;

    // One header chip per lane, naming the attribute it leans into.
    final headers = <GraphHeader>[];
    for (var i = 0; i < _laneOrder.length; i++) {
      final info = _laneInfo[_laneOrder[i]];
      if (info == null) continue;
      headers.add(GraphHeader(
        x: laneX(i),
        y: laneTop - 74,
        label: info.$1,
        color: info.$2,
      ));
    }

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
      headers: headers,
      graphSize: Size(canvasW, canvasH),
      initialFocus: Offset(centerX, 90), // centre on the root (top of the stem)
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
        // Live: re-enable BUY the moment income covers the cost while the sheet
        // is open (was a one-shot snapshot that stayed "can't afford").
        refreshOn: game,
        canAffordLive: () => game.wallet >= game.getResearchCost(n.id),
        costLabelLive: () {
          final c = game.getResearchCost(n.id);
          return game.showFiatPrices
              ? '\$ ${Formatter.formatNumber(game.toFiat(c))}'
              : Formatter.formatBitcoin(c);
        },
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

