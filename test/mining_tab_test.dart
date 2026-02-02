import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto_miner_tycoon/screens/mining_tab.dart';
import 'package:crypto_miner_tycoon/providers/game_logic.dart';

void main() {
  late GameLogic game;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    game = GameLogic(startTimers: false);
  });

  Widget createWidgetUnderTest() {
    return ChangeNotifierProvider<GameLogic>.value(
      value: game,
      child: MaterialApp(
        home: Scaffold(
          body: MiningTab(onHardFork: () {}, onBuyRig: (_) {}),
        ),
      ),
    );
  }

  testWidgets('MiningTab: Hack Network button mines crypto', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createWidgetUnderTest());

    // Initial Wallet
    expect(game.wallet, 0.0);

    // Find and Tap Button
    final hackButton = find.text('HACK NETWORK');
    expect(hackButton, findsOneWidget);

    await tester.tap(hackButton);
    await tester.pump(); // Rebuild for state update

    // Wallet should increase
    expect(game.wallet, greaterThan(0.0));
  });

  testWidgets('MiningTab: Shows Rig List', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    expect(find.text('STARTER CPU RIG'), findsOneWidget);
    expect(find.text('GPU RACK'), findsOneWidget);
  });

  testWidgets('MiningTab: Buying a Rig updates state', (
    WidgetTester tester,
  ) async {
    // Give money
    game.wallet = 10000;
    await tester.pumpWidget(createWidgetUnderTest());

    // Find Buy Button for CPU Rig
    // We look for text 'BUY'

    final cpuRigItem = find.text('STARTER CPU RIG');
    expect(cpuRigItem, findsOneWidget);

    final buyButton = find.text('BUY').first;
    await tester.tap(buyButton);
    await tester.pump();

    expect(game.rigs.first.amount, 1);
  });

  testWidgets('MiningTab: Anomaly appears when active', (
    WidgetTester tester,
  ) async {
    game.isAnomalyActive = true;
    game.anomalyPosition = const Offset(50, 50);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump(); // Animation frame

    final anomalyIcon = find.byIcon(Icons.bug_report);
    expect(anomalyIcon, findsOneWidget);

    // Tap it
    await tester.tap(anomalyIcon);
    await tester.pumpAndSettle();

    expect(game.isAnomalyActive, false);
    expect(game.chips, 1);
  });
}
