import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/widgets/tech_graph.dart';

void main() {
  testWidgets('BlockGraph renders nodes, hides teaser labels, fires onTap',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlockGraph(
            graphSize: const Size(600, 300),
            edges: const [GraphEdge('a', 'b'), GraphEdge('b', 'c')],
            nodes: [
              const GraphNode(
                  id: 'a',
                  x: 90,
                  y: 90,
                  label: 'ALPHA',
                  sublabel: 'ACTIVE',
                  state: GraphNodeState.owned),
              GraphNode(
                id: 'b',
                x: 260,
                y: 90,
                label: 'BETA',
                sublabel: '5 GT',
                state: GraphNodeState.available,
                canAfford: true,
                onTap: () => tapped = true,
              ),
              const GraphNode(
                  id: 'c',
                  x: 430,
                  y: 90,
                  label: 'GAMMA',
                  state: GraphNodeState.teaser),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('ALPHA'), findsOneWidget);
    expect(find.text('BETA'), findsOneWidget);
    // Teaser hides its real label behind '???'.
    expect(find.text('GAMMA'), findsNothing);
    expect(find.text('???'), findsOneWidget);

    await tester.tap(find.text('BETA'));
    expect(tapped, true);
  });
}
