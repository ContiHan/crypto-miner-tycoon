import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:crypto_miner_tycoon/logic/managers/class_manager.dart';
import 'package:crypto_miner_tycoon/providers/game_logic.dart';
import 'package:crypto_miner_tycoon/widgets/abilities_bar.dart';
import 'test_helper.dart';

Widget _host(GameLogic game) => MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider<GameLogic>.value(
          value: game,
          child: const Align(
            alignment: Alignment.topCenter,
            child: AbilitiesBar(),
          ),
        ),
      ),
    );

void main() {
  testWidgets('bar hides before a class is chosen', (tester) async {
    final game = createTestGameLogic(loadOnStart: false);
    await game.loadGame();
    await tester.pumpWidget(_host(game));
    await tester.pump();
    expect(find.byType(GestureDetector), findsNothing);
  });

  testWidgets('shows three ability buttons and a READY label once class chosen',
      (tester) async {
    final game = createTestGameLogic(loadOnStart: false);
    await game.loadGame();
    game.debugSelectClass(BtcClass.corporation);
    await tester.pumpWidget(_host(game));
    await tester.pump(const Duration(milliseconds: 16));
    // Three ability icons (basic1 available => READY; the two locked => M1/M2).
    expect(find.byIcon(Icons.dns), findsOneWidget); // Spin Up (basic1)
    expect(find.text('READY'), findsOneWidget);
    expect(find.text('M1'), findsOneWidget);
    expect(find.text('M2'), findsOneWidget);
  });

  testWidgets('tapping a ready ability casts it (goes on cooldown + buff ticker)',
      (tester) async {
    final game = createTestGameLogic(loadOnStart: false);
    await game.loadGame();
    game.debugSelectClass(BtcClass.corporation);
    game.rigs.firstWhere((r) => r.id == 'cpu_rig').amount = 5;
    await tester.pumpWidget(_host(game));
    await tester.pump(const Duration(milliseconds: 16));

    // Tap the Spin Up (basic1) button — it's the READY one.
    await tester.tap(find.byIcon(Icons.dns));
    await tester.pump(); // process the cast
    await tester.pump(const Duration(milliseconds: 100));

    final spin = game.currentClassAbilities.firstWhere((a) => a.id == 'corp_spin_up');
    expect(game.isAbilityReady(spin), false, reason: 'cast started the cooldown');
    // A buff window is active → the ticker shows at least one countdown chip.
    expect(game.activeAbilityBuffs().isNotEmpty, true);

    // Let the floating cast-text overlay finish so no timers dangle at teardown.
    await tester.pump(const Duration(seconds: 1));
  });
}
