import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:crypto_miner_tycoon/widgets/graph_node_sheet.dart';

/// Device bug: opening a TECH node you can't afford, then mining enough while the
/// sheet is open, left BUY greyed as "can't afford" — the sheet was a one-shot
/// snapshot. It now rebuilds on the passed Listenable.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('BUY re-enables live when affordability flips', (tester) async {
    final tick = ValueNotifier<int>(0);
    var afford = false;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showGraphNodeSheet(
              context,
              title: 'Overclock',
              description: 'faster hashing',
              buyLabel: 'RESEARCH',
              costLabel: '1 BTC',
              canAfford: false,
              refreshOn: tick,
              canAffordLive: () => afford,
              onBuy: () {},
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final buy = find.widgetWithText(ElevatedButton, 'RESEARCH  ·  1 BTC');
    expect(buy, findsOneWidget);
    expect(tester.widget<ElevatedButton>(buy).enabled, false,
        reason: 'not affordable yet → disabled');

    // Mine enough (afford flips) and the game notifies its listeners.
    afford = true;
    tick.value++;
    await tester.pump();

    expect(tester.widget<ElevatedButton>(buy).enabled, true,
        reason: 'now affordable → BUY re-enables without reopening the sheet');
  });
}
