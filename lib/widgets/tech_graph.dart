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

/// How edges are drawn: [straight] (radial spider — TALENTS) or [elbow]
/// (orthogonal circuit routing — TECH tree, much tidier than fanned diagonals).
enum GraphEdgeStyle { straight, elbow }

const double kNodeW = 128;
const double kNodeH = 62;

/// A pannable/zoomable blockchain-styled graph: chain-link edges painted behind
/// block nodes. Reused by TECH (depth-column tree) and TALENTS (radial spider).
/// A lane header chip painted in graph-space (pans/zooms with the tree), used by
/// the TECH tree to label each doctrine column with the attribute it leans into.
class GraphHeader {
  final double x; // lane centre
  final double y; // top of the chip
  final String label;
  final Color color;
  const GraphHeader({
    required this.x,
    required this.y,
    required this.label,
    required this.color,
  });
}

class BlockGraph extends StatefulWidget {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final List<GraphHeader> headers;
  final Size graphSize;

  /// Graph-space point to centre in the viewport on first open (e.g. the root /
  /// GENESIS node), so the player doesn't land on empty canvas.
  final Offset? initialFocus;

  /// Edge routing (straight for the radial spider, elbow for the TECH tree).
  final GraphEdgeStyle edgeStyle;

  const BlockGraph({
    super.key,
    required this.nodes,
    required this.edges,
    required this.graphSize,
    this.headers = const [],
    this.initialFocus,
    this.edgeStyle = GraphEdgeStyle.straight,
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
        // Once we know the viewport, translate so initialFocus (the root) lands
        // horizontally centred and near the TOP — the tree grows downward, so
        // this leaves the whole depth below it to scroll into.
        if (!_framed &&
            widget.initialFocus != null &&
            constraints.hasBoundedWidth &&
            constraints.hasBoundedHeight) {
          _framed = true;
          final f = widget.initialFocus!;
          final dx = constraints.maxWidth * 0.5 - f.dx;
          final dy = constraints.maxHeight * 0.2 - f.dy;
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
                          painter: _ChainPainter(
                              centers, widget.edges, states, widget.edgeStyle),
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
                    for (final h in widget.headers)
                      Positioned(
                        left: h.x - kNodeW / 2,
                        top: h.y,
                        width: kNodeW,
                        child: _LaneHeader(header: h),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Gold used for maxed nodes (distinct from the amber accent used for owned).
/// Public so screens' legends can match the node colour.
const Color kMaxedGold = Color(0xFFFFCC46);

/// A doctrine lane header: a colored chip naming the lane + the attribute it
/// leans into (e.g. "MEGA-HASH\n+HASH"). Sits above the lane's first node.
class _LaneHeader extends StatelessWidget {
  final GraphHeader header;
  const _LaneHeader({required this.header});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: header.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border:
            Border.all(color: header.color.withValues(alpha: 0.85), width: 1.2),
      ),
      child: Text(
        header.label,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: header.color,
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
          height: 1.15,
        ),
      ),
    );
  }
}

class _BlockNode extends StatelessWidget {
  final GraphNode node;
  const _BlockNode({required this.node});

  @override
  Widget build(BuildContext context) {
    final isTeaser = node.state == GraphNodeState.teaser;
    final owned = node.state == GraphNodeState.owned;
    final maxed = node.state == GraphNodeState.maxed;
    final available = node.state == GraphNodeState.available;
    final affordable = available && node.canAfford;
    final earned = owned || maxed;

    // Per-state accent (border/icon/sublabel) and card gradient (top → bottom).
    final Color accent;
    final List<Color> grad;
    switch (node.state) {
      case GraphNodeState.owned:
        accent = AppTheme.accent;
        grad = [
          AppTheme.accent.withValues(alpha: 0.34),
          AppTheme.accent.withValues(alpha: 0.10),
        ];
        break;
      case GraphNodeState.maxed:
        accent = kMaxedGold;
        grad = [
          kMaxedGold.withValues(alpha: 0.30),
          kMaxedGold.withValues(alpha: 0.08),
        ];
        break;
      case GraphNodeState.available:
        accent = affordable ? AppTheme.accent : Colors.white54;
        grad = const [Color(0xFF23262E), Color(0xFF141519)];
        break;
      case GraphNodeState.teaser:
        accent = Colors.white24;
        grad = const [Color(0xFF16171B), Color(0xFF101114)];
        break;
    }

    final borderColor = isTeaser
        ? Colors.white12
        : accent.withValues(alpha: earned || affordable ? 0.95 : 0.5);
    final borderWidth = node.isGenesis ? 2.6 : (earned || affordable ? 1.8 : 1.2);

    return GestureDetector(
      onTap: node.onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: grad,
          ),
          border: Border.all(color: borderColor, width: borderWidth),
          borderRadius: BorderRadius.circular(11),
          boxShadow: [
            const BoxShadow(
                color: Colors.black54, blurRadius: 7, offset: Offset(0, 3)),
            if (affordable)
              BoxShadow(
                  color: accent.withValues(alpha: 0.45),
                  blurRadius: 15,
                  spreadRadius: 0.5),
            if (maxed)
              BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 12),
          ],
        ),
        child: Stack(
          children: [
            // Glassy top highlight for a little depth.
            Positioned(
              left: 1,
              right: 1,
              top: 1,
              height: kNodeH * 0.4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(10)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: isTeaser ? 0.03 : 0.07),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  // Icon chip.
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isTeaser
                          ? Colors.white10
                          : accent.withValues(alpha: earned ? 0.22 : 0.14),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: accent.withValues(alpha: 0.4), width: 1),
                    ),
                    child: Icon(
                      isTeaser
                          ? Icons.lock_outline
                          : (node.isGenesis ? Icons.hub : node.icon),
                      size: 16,
                      color: isTeaser ? Colors.white38 : accent,
                    ),
                  ),
                  const SizedBox(width: 7),
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
                            letterSpacing: 0.3,
                          ),
                        ),
                        if (node.sublabel.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              node.sublabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: earned ? accent : Colors.white70,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // A small state pip: check when owned, star when maxed.
                  if (earned)
                    Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Icon(
                        maxed ? Icons.star_rounded : Icons.check_circle,
                        size: 13,
                        color: accent,
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

/// Draws the connectors between nodes as clean glowing "conduits" — a soft blur
/// underlay + a crisp core line, with small pads where they meet a node. Earned
/// links (child owned/maxed) glow in the accent; the rest stay faint. Elbow edges
/// route orthogonally with ROUNDED corners (reads as a tidy circuit, not the old
/// fanned diagonals studded with little chain rectangles).
class _ChainPainter extends CustomPainter {
  final Map<String, Offset> centers;
  final List<GraphEdge> edges;
  final Map<String, GraphNodeState> states;
  final GraphEdgeStyle edgeStyle;
  _ChainPainter(this.centers, this.edges, this.states, this.edgeStyle);

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in edges) {
      final a = centers[e.fromId];
      final b = centers[e.toId];
      if (a == null || b == null) continue;
      final childState = states[e.toId];
      final earned = childState == GraphNodeState.owned ||
          childState == GraphNodeState.maxed;
      final base = earned ? AppTheme.accent : Colors.white;

      if (edgeStyle == GraphEdgeStyle.elbow) {
        _drawConduit(canvas, _elbowPath(a, b), base, earned);
        // Connection pads at the parent output (bottom) and child input (top).
        _pad(canvas, Offset(a.dx, a.dy + kNodeH / 2), base, earned);
        _pad(canvas, Offset(b.dx, b.dy - kNodeH / 2), base, earned);
      } else {
        _drawConduit(
            canvas, Path()..moveTo(a.dx, a.dy)..lineTo(b.dx, b.dy), base, earned);
      }
    }
  }

  /// Orthogonal parent→child route with rounded corners, VERTICAL (top-down):
  /// out of the parent's bottom edge, down to a mid-row, across to the child's
  /// column, then into the child's top edge.
  Path _elbowPath(Offset a, Offset b) {
    final startY = a.dy + kNodeH / 2;
    final endY = b.dy - kNodeH / 2;
    final midY = (startY + endY) / 2;
    final path = Path()..moveTo(a.dx, startY);
    final dxAbs = (b.dx - a.dx).abs();
    if (dxAbs < 1) {
      path.lineTo(b.dx, endY); // same column → a straight run down
      return path;
    }
    final dir = b.dx > a.dx ? 1.0 : -1.0;
    final cr = math.max(
        0.0, math.min(12.0, math.min((endY - startY).abs() / 2, dxAbs / 2)));
    path
      ..lineTo(a.dx, midY - cr)
      ..quadraticBezierTo(a.dx, midY, a.dx + dir * cr, midY)
      ..lineTo(b.dx - dir * cr, midY)
      ..quadraticBezierTo(b.dx, midY, b.dx, midY + cr)
      ..lineTo(b.dx, endY);
    return path;
  }

  void _drawConduit(Canvas canvas, Path path, Color base, bool earned) {
    // Soft glow underlay.
    canvas.drawPath(
      path,
      Paint()
        ..color = base.withValues(alpha: earned ? 0.20 : 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    // Crisp core.
    canvas.drawPath(
      path,
      Paint()
        ..color = base.withValues(alpha: earned ? 0.95 : 0.32)
        ..style = PaintingStyle.stroke
        ..strokeWidth = earned ? 2.4 : 1.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _pad(Canvas canvas, Offset c, Color base, bool earned) {
    canvas.drawCircle(
      c,
      3.2,
      Paint()..color = base.withValues(alpha: earned ? 0.95 : 0.45),
    );
  }

  @override
  bool shouldRepaint(covariant _ChainPainter old) =>
      old.edgeStyle != edgeStyle ||
      !mapEquals(old.centers, centers) ||
      !mapEquals(old.states, states) ||
      old.edges.length != edges.length;
}
