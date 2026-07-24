import 'dart:math' as math;
import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Visual state of a graph node. TECH never uses [maxed] (research is one-shot).
enum GraphNodeState { teaser, available, owned, maxed }

/// One block in the tech-tree / talent spider graph. Positions are logical
/// (unscaled) pixel CENTERS in graph space. This widget is DUMB — each screen
/// (TECH / TALENTS) computes positions, labels and state and supplies an onTap.
@immutable
class GraphNode {
  final String id;
  final double x; // center
  final double y; // center
  final String label;
  final String sublabel;
  final IconData icon;
  final GraphNodeState state;
  final bool canAfford;
  final bool isGenesis;
  final VoidCallback? onTap;

  const GraphNode({
    required this.id,
    required this.x,
    required this.y,
    required this.label,
    this.sublabel = '',
    this.icon = Icons.memory,
    this.state = GraphNodeState.teaser,
    this.canAfford = false,
    this.isGenesis = false,
    this.onTap,
  });
}

/// Directed parent -> child link (drawn as a glowing chain segment).
@immutable
class GraphEdge {
  final String fromId;
  final String toId;
  const GraphEdge(this.fromId, this.toId);
}

const double kNodeW = 128;
const double kNodeH = 62;

/// A pannable/zoomable blockchain-styled graph: chain-link edges painted behind
/// block nodes. Reused by TECH (depth-column tree) and TALENTS (radial spider).
class BlockGraph extends StatefulWidget {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final Size graphSize;
  final Widget? legend;

  /// Graph-space point to centre in the viewport on first open (e.g. the root /
  /// GENESIS node), so the player doesn't land on empty canvas.
  final Offset? initialFocus;

  const BlockGraph({
    super.key,
    required this.nodes,
    required this.edges,
    required this.graphSize,
    this.legend,
    this.initialFocus,
  });

  @override
  State<BlockGraph> createState() => _BlockGraphState();
}

class _BlockGraphState extends State<BlockGraph> {
  final TransformationController _tc = TransformationController();
  bool _framed = false;

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.nodes.isEmpty) {
      return const Center(
        child: Text('Nothing here yet.',
            style: TextStyle(color: Colors.white38)),
      );
    }
    final centers = {for (final n in widget.nodes) n.id: Offset(n.x, n.y)};
    final states = {for (final n in widget.nodes) n.id: n.state};

    return LayoutBuilder(
      builder: (context, constraints) {
        // Once we know the viewport, translate so initialFocus lands a little
        // left-of/above centre (leaving room for the tree to extend).
        if (!_framed &&
            widget.initialFocus != null &&
            constraints.hasBoundedWidth &&
            constraints.hasBoundedHeight) {
          _framed = true;
          final f = widget.initialFocus!;
          final dx = constraints.maxWidth * 0.4 - f.dx;
          final dy = constraints.maxHeight * 0.45 - f.dy;
          _tc.value = Matrix4.translationValues(dx, dy, 0);
        }
        return Stack(
          children: [
            InteractiveViewer(
              transformationController: _tc,
              constrained: false,
              boundaryMargin: const EdgeInsets.all(600),
              minScale: 0.4,
              maxScale: 2.5,
              child: SizedBox(
                width: widget.graphSize.width,
                height: widget.graphSize.height,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter:
                              _ChainPainter(centers, widget.edges, states),
                        ),
                      ),
                    ),
                    for (final n in widget.nodes)
                      Positioned(
                        left: n.x - kNodeW / 2,
                        top: n.y - kNodeH / 2,
                        width: kNodeW,
                        height: kNodeH,
                        child: RepaintBoundary(child: _BlockNode(node: n)),
                      ),
                  ],
                ),
              ),
            ),
            if (widget.legend != null)
              Positioned(left: 12, bottom: 12, child: widget.legend!),
          ],
        );
      },
    );
  }
}

class _BlockNode extends StatelessWidget {
  final GraphNode node;
  const _BlockNode({required this.node});

  @override
  Widget build(BuildContext context) {
    Color border;
    Color fill;
    List<BoxShadow> shadow = const [];
    switch (node.state) {
      case GraphNodeState.owned:
        border = AppTheme.accent;
        fill = AppTheme.accent.withValues(alpha: 0.18);
        break;
      case GraphNodeState.maxed:
        border = Colors.greenAccent;
        fill = Colors.greenAccent.withValues(alpha: 0.16);
        break;
      case GraphNodeState.available:
        if (node.canAfford) {
          border = AppTheme.accent;
          fill = AppTheme.surface;
          shadow = [
            BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.55), blurRadius: 12),
          ];
        } else {
          border = Colors.white38;
          fill = Colors.black26;
        }
        break;
      case GraphNodeState.teaser:
        border = Colors.white24;
        fill = Colors.black26;
        break;
    }
    final isTeaser = node.state == GraphNodeState.teaser;

    return GestureDetector(
      onTap: node.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(color: border, width: node.isGenesis ? 3 : 2),
          borderRadius: BorderRadius.circular(6),
          boxShadow: shadow,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          children: [
            Icon(
              isTeaser
                  ? Icons.lock_outline
                  : (node.isGenesis ? Icons.hub : node.icon),
              size: 20,
              color: isTeaser ? Colors.white38 : border,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isTeaser ? '???' : node.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.orbitron(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isTeaser ? Colors.white54 : Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (node.sublabel.isNotEmpty)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        node.sublabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: node.state == GraphNodeState.owned ||
                                  node.state == GraphNodeState.maxed
                              ? border
                              : Colors.white70,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Draws glowing amber "chain" segments between node centers, brightening the
/// links whose child node is already earned.
class _ChainPainter extends CustomPainter {
  final Map<String, Offset> centers;
  final List<GraphEdge> edges;
  final Map<String, GraphNodeState> states;
  _ChainPainter(this.centers, this.edges, this.states);

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in edges) {
      final a = centers[e.fromId];
      final b = centers[e.toId];
      if (a == null || b == null) continue;
      final childState = states[e.toId];
      final earned = childState == GraphNodeState.owned ||
          childState == GraphNodeState.maxed;
      final base = earned ? AppTheme.accent : Colors.white24;

      // Wide translucent glow under a thin bright line.
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = base.withValues(alpha: earned ? 0.22 : 0.10)
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = base.withValues(alpha: earned ? 0.9 : 0.4)
          ..strokeWidth = 2,
      );

      // A few small rotated links along the segment for the "chain" read.
      final dx = b.dx - a.dx, dy = b.dy - a.dy;
      final len = math.sqrt(dx * dx + dy * dy);
      if (len < 1) continue;
      final angle = math.atan2(dy, dx);
      const linkCount = 4;
      final linkPaint = Paint()
        ..color = base.withValues(alpha: earned ? 0.8 : 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      for (int i = 1; i <= linkCount; i++) {
        final t = i / (linkCount + 1);
        final p = Offset(a.dx + dx * t, a.dy + dy * t);
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.rotate(angle);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-6, -3.5, 12, 7),
            const Radius.circular(3),
          ),
          linkPaint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChainPainter old) =>
      !mapEquals(old.centers, centers) ||
      !mapEquals(old.states, states) ||
      old.edges.length != edges.length;
}
