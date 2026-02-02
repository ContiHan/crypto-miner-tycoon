import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto_miner_tycoon/widgets/news_ticker.dart';
import 'package:crypto_miner_tycoon/providers/game_logic.dart';
import 'package:crypto_miner_tycoon/models/news_event.dart';

void main() {
  late GameLogic game;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    game = GameLogic(startTimers: false);
  });

  Widget createWidgetUnderTest() {
    return ChangeNotifierProvider<GameLogic>.value(
      value: game,
      child: const MaterialApp(home: Scaffold(body: NewsTicker())),
    );
  }

  testWidgets('NewsTicker: Shows Idle text by default', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();

    expect(find.textContaining('MARKET STABLE'), findsOneWidget);
  });

  testWidgets('NewsTicker: Updates content on NewsEvent (Long Pump)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createWidgetUnderTest());

    // Trigger News
    game.currentNews = NewsEvent(
      message: 'TEST NEWS',
      type: EventType.bullRun,
      value: 100,
      durationSeconds: 10,
      color: Colors.green,
    );
    game.notifyListeners();

    // Pump frames to allow AnimatedSwitcher to complete (500ms duration)
    // We wait 1 second to be safe
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('TEST NEWS'), findsOneWidget);
    expect(find.textContaining('+100.0% Income'), findsOneWidget);
  });

  testWidgets('NewsTicker: Market Crash formatting', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createWidgetUnderTest());

    // Trigger Crash
    game.currentNews = NewsEvent(
      message: 'CRASH',
      type: EventType.marketCrash,
      value: -50,
      durationSeconds: 10,
      color: Colors.red,
    );
    game.notifyListeners();

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('CRASH'), findsOneWidget);
    expect(find.textContaining('-50.0% Income'), findsOneWidget);
  });
}
