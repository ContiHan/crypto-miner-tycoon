import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:crypto_miner_tycoon/providers/game_logic.dart';
import 'package:crypto_miner_tycoon/widgets/firmware_panel.dart';
import 'test_helper.dart';

Widget _host(GameLogic game) => MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider<GameLogic>.value(
          value: game,
          child: Consumer<GameLogic>(
            builder: (context, g, child) => FirmwarePanel(game: g),
          ),
        ),
      ),
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('renders the affix pool + a live socket counter', (tester) async {
    final game = createTestGameLogic(loadOnStart: false);
    await game.loadGame();
    await tester.pumpWidget(_host(game));
    await tester.pump();
    expect(find.text('RIG FIRMWARE'), findsOneWidget);
    expect(find.text('0 / 3 sockets'), findsOneWidget);
    // Common-first: the first common affix pins to the top of the pool.
    expect(find.text('Crit Capacitor'), findsOneWidget);
    expect(find.text('SOCKET'), findsWidgets);
  });

  testWidgets('socketing equips (updates counter + shows EQUIPPED), fills at cap',
      (tester) async {
    final game = createTestGameLogic(loadOnStart: false);
    await game.loadGame();
    await tester.pumpWidget(_host(game));
    await tester.pump();

    await tester.tap(find.text('SOCKET').first);
    await tester.pump();
    expect(game.equippedFirmwareCount, 1);
    expect(find.text('1 / 3 sockets'), findsOneWidget);
    expect(find.text('EQUIPPED'), findsOneWidget);

    // Fill the remaining 2 base sockets.
    await tester.tap(find.text('SOCKET').first);
    await tester.pump();
    await tester.tap(find.text('SOCKET').first);
    await tester.pump();
    expect(game.equippedFirmwareCount, 3);
    expect(find.text('3 / 3 sockets'), findsOneWidget);
    // The rest are now FULL (un-socketable) — no plain SOCKET buttons remain.
    expect(find.text('SOCKET'), findsNothing);
    expect(find.text('FULL'), findsWidgets);

    // Tapping FULL is a no-op.
    await tester.tap(find.text('FULL').first);
    await tester.pump();
    expect(game.equippedFirmwareCount, 3);
  });
}
